import Darwin
import Foundation

public enum CommandRunnerError: LocalizedError {
    case timedOut

    public var errorDescription: String? {
        switch self {
        case .timedOut:
            "Command timed out"
        }
    }
}

public struct CommandRunner: Sendable {
    public init() {}

    public func run(_ request: RunRequest) throws -> CommandResult {
        var stdoutDescriptors: [Int32] = [0, 0]
        var stderrDescriptors: [Int32] = [0, 0]
        guard pipe(&stdoutDescriptors) == 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
        guard pipe(&stderrDescriptors) == 0 else {
            close(stdoutDescriptors[0])
            close(stdoutDescriptors[1])
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }

        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_adddup2(&actions, stdoutDescriptors[1], STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&actions, stderrDescriptors[1], STDERR_FILENO)
        posix_spawn_file_actions_addclose(&actions, stdoutDescriptors[0])
        posix_spawn_file_actions_addclose(&actions, stderrDescriptors[0])
        posix_spawn_file_actions_addclose(&actions, stdoutDescriptors[1])
        posix_spawn_file_actions_addclose(&actions, stderrDescriptors[1])
        if let cwd = request.cwd {
            _ = cwd.withCString { posix_spawn_file_actions_addchdir_np(&actions, $0) }
        }

        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP))
        posix_spawnattr_setpgroup(&attributes, 0)

        var pid: pid_t = 0
        let arguments = [request.executablePath] + request.arguments
        let environment = ProcessInfo.processInfo.environment.map { "\($0.key)=\($0.value)" }
        let spawnResult = withCStringArray(arguments) { argv in
            withCStringArray(environment) { envp in
                posix_spawn(&pid, request.executablePath, &actions, &attributes, argv, envp)
            }
        }
        close(stdoutDescriptors[1])
        close(stderrDescriptors[1])
        guard spawnResult == 0 else {
            close(stdoutDescriptors[0])
            close(stderrDescriptors[0])
            throw POSIXError(.init(rawValue: spawnResult) ?? .EIO)
        }

        let stdoutBuffer = LockedDataBuffer()
        let stderrBuffer = LockedDataBuffer()
        let stdout = FileHandle(fileDescriptor: stdoutDescriptors[0], closeOnDealloc: true)
        let stderr = FileHandle(fileDescriptor: stderrDescriptors[0], closeOnDealloc: true)
        stdout.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                stdoutBuffer.append(data)
            }
        }
        stderr.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                stderrBuffer.append(data)
            }
        }

        let finished = DispatchSemaphore(value: 0)
        let waitState = ProcessWaitState()
        let spawnedPID = pid
        DispatchQueue.global(qos: .userInitiated).async {
            var status: Int32 = 0
            waitpid(spawnedPID, &status, 0)
            waitState.setStatus(status)
            finished.signal()
        }

        if finished.wait(timeout: .now() + request.timeoutSeconds) == .timedOut {
            kill(-spawnedPID, SIGTERM)
            let parentFinished = finished.wait(timeout: .now() + 2)
            // The parent can exit on SIGTERM while children in its group ignore it.
            kill(-spawnedPID, SIGKILL)
            if parentFinished == .timedOut {
                _ = finished.wait(timeout: .now() + 2)
            }
            stdout.readabilityHandler = nil
            stderr.readabilityHandler = nil
            throw CommandRunnerError.timedOut
        }

        stdout.readabilityHandler = nil
        stderr.readabilityHandler = nil
        stdoutBuffer.append(drainAvailable(stdout.fileDescriptor))
        stderrBuffer.append(drainAvailable(stderr.fileDescriptor))
        let stdoutData = stdoutBuffer.data()
        let stderrData = stderrBuffer.data()
        return CommandResult(
            exitCode: exitCode(from: waitState.status()),
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? ""
        )
    }
}

private func drainAvailable(_ fileDescriptor: Int32) -> Data {
    var result = Data()
    let flags = fcntl(fileDescriptor, F_GETFL)
    if flags >= 0 {
        _ = fcntl(fileDescriptor, F_SETFL, flags | O_NONBLOCK)
    }

    var buffer = [UInt8](repeating: 0, count: 8_192)
    while true {
        let count = read(fileDescriptor, &buffer, buffer.count)
        if count > 0 {
            result.append(buffer, count: count)
        } else {
            break
        }
    }
    return result
}

private func exitCode(from status: Int32?) -> Int32 {
    guard let status else {
        return 1
    }
    let waitStatus = status & 0x7f
    if waitStatus == 0 {
        return (status >> 8) & 0xff
    }
    if waitStatus != 0x7f {
        return 128 + waitStatus
    }
    return status
}

private func withCStringArray<R>(
    _ strings: [String],
    _ body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws -> R
) rethrows -> R {
    let cStrings = strings.map { strdup($0)! }
    defer {
        for string in cStrings {
            free(string)
        }
    }
    var pointers = cStrings.map { Optional($0) }
    pointers.append(nil)
    return try pointers.withUnsafeMutableBufferPointer { buffer in
        try body(buffer.baseAddress!)
    }
}

private final class ProcessWaitState: @unchecked Sendable {
    private let lock = NSLock()
    private var waitStatus: Int32?

    func setStatus(_ status: Int32) {
        lock.lock()
        waitStatus = status
        lock.unlock()
    }

    func status() -> Int32? {
        lock.lock()
        defer { lock.unlock() }
        return waitStatus
    }
}

private final class LockedDataBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ data: Data) {
        lock.lock()
        storage.append(data)
        lock.unlock()
    }

    func data() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
