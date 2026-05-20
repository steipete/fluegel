import Darwin
import FluegelCore
import Foundation

enum BridgeClientError: LocalizedError {
    case connectionFailed
    case emptyResponse
    case timeout

    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            "Fluegel app is not reachable. Start Fluegel.app in the GUI session."
        case .emptyResponse:
            "Fluegel app returned an empty response"
        case .timeout:
            "Fluegel app did not respond"
        }
    }
}

final class BridgeClient {
    private let encoder = JSONEncoder.fluegelJSONLines
    private let decoder = JSONDecoder.fluegelDefault
    private let timeout: TimeInterval

    init(timeout: TimeInterval = 10) {
        self.timeout = timeout
    }

    func send(_ request: BridgeRequest) throws -> BridgeResponse {
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
        defer { close(descriptor) }
        try configureTimeout(descriptor)
        try connect(descriptor, to: FluegelPaths.bridgeSocketFile().path)

        let requestData = try encoder.encode(request) + Data([0x0a])
        try writeAll(requestData, to: descriptor)
        let responseData = try readResponse(from: descriptor)
        guard !responseData.isEmpty else {
            throw BridgeClientError.emptyResponse
        }
        return try decoder.decode(BridgeResponse.self, from: responseData)
    }

    private func configureTimeout(_ descriptor: Int32) throws {
        let seconds = Int(timeout)
        var microseconds = Int((timeout - Double(seconds)) * 1_000_000)
        if microseconds < 0 {
            microseconds = 0
        }
        var value = timeval(tv_sec: seconds, tv_usec: Int32(microseconds))
        guard setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &value, socklen_t(MemoryLayout<timeval>.size)) == 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
        guard setsockopt(descriptor, SOL_SOCKET, SO_SNDTIMEO, &value, socklen_t(MemoryLayout<timeval>.size)) == 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
    }

    private func connect(_ descriptor: Int32, to path: String) throws {
        var address = sockaddr_un()
        let pathBytes = Array(path.utf8) + [0]
        guard pathBytes.count <= MemoryLayout.size(ofValue: address.sun_path) else {
            throw POSIXError(.ENAMETOOLONG)
        }
        address.sun_family = sa_family_t(AF_UNIX)
        let length = socklen_t(MemoryLayout.offset(of: \sockaddr_un.sun_path)! + pathBytes.count)
        address.sun_len = UInt8(length)
        withUnsafeMutablePointer(to: &address.sun_path) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { destination in
                for (index, byte) in pathBytes.enumerated() {
                    destination[index] = CChar(bitPattern: byte)
                }
            }
        }
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                Darwin.connect(descriptor, socketAddress, length)
            }
        }
        guard result == 0 else {
            if errno == ENOENT || errno == ECONNREFUSED {
                throw BridgeClientError.connectionFailed
            }
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
    }

    private func writeAll(_ data: Data, to descriptor: Int32) throws {
        try data.withUnsafeBytes { pointer in
            guard let baseAddress = pointer.bindMemory(to: UInt8.self).baseAddress else {
                return
            }
            var sent = 0
            while sent < data.count {
                let count = write(descriptor, baseAddress.advanced(by: sent), data.count - sent)
                guard count > 0 else {
                    if errno == EAGAIN || errno == EWOULDBLOCK {
                        throw BridgeClientError.timeout
                    }
                    throw POSIXError(.init(rawValue: errno) ?? .EIO)
                }
                sent += count
            }
        }
    }

    private func readResponse(from descriptor: Int32) throws -> Data {
        var response = Data()
        var buffer = [UInt8](repeating: 0, count: 8_192)
        while true {
            let count = read(descriptor, &buffer, buffer.count)
            if count > 0 {
                response.append(buffer, count: count)
            } else if count == 0 {
                return response
            } else if errno == EAGAIN || errno == EWOULDBLOCK {
                throw BridgeClientError.timeout
            } else {
                throw POSIXError(.init(rawValue: errno) ?? .EIO)
            }
        }
    }
}
