import Darwin
import Foundation
import Testing

@Suite("Unix socket writes")
struct ClosedPeerWriteTests {
    @Test("closed peer write returns EPIPE instead of SIGPIPE")
    func closedPeerWriteReturnsEPIPE() throws {
        let raw = try runProbe("raw")
        #expect(raw.reason == .uncaughtSignal)
        #expect(raw.status == SIGPIPE)

        let product = try runProbe("product")
        if product.reason != .exit || product.status != 0 || product.stdout != "EPIPE\n" {
            Issue.record("product \(product)")
        }
        #expect(product.reason == .exit)
        #expect(product.status == 0)
        #expect(product.stdout == "EPIPE\n")
    }

    private func runProbe(_ mode: String) throws -> ProbeRun {
        let binary = try probeBinary()
        let process = Process()
        process.executableURL = binary
        process.arguments = [mode]
        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        try process.run()
        process.waitUntilExit()
        let stdout = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let stderr = String(decoding: error.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return ProbeRun(
            reason: process.terminationReason,
            status: process.terminationStatus,
            stdout: stdout,
            stderr: stderr
        )
    }

    private func probeBinary() throws -> URL {
        let testExecutable = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        var directory = testExecutable.deletingLastPathComponent()
        var candidates: [URL] = []
        for _ in 0..<6 {
            candidates.append(directory.appendingPathComponent("SocketWriteProbe"))
            directory.deleteLastPathComponent()
        }
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        candidates.append(sourceRoot.appendingPathComponent(".build/debug/SocketWriteProbe"))
        if let match = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) {
            return match
        }
        throw ProbeMissing(paths: candidates.map(\.path))
    }
}

private struct ProbeRun: CustomStringConvertible {
    var reason: Process.TerminationReason
    var status: Int32
    var stdout: String
    var stderr: String

    var description: String {
        let why = reason == .uncaughtSignal ? "signal" : "exit"
        return "\(why) \(status) stdout=\(String(reflecting: stdout)) stderr=\(String(reflecting: stderr))"
    }
}

private struct ProbeMissing: Error, CustomStringConvertible {
    var paths: [String]

    var description: String {
        "SocketWriteProbe was not built. Looked in:\n" + paths.joined(separator: "\n")
    }
}
