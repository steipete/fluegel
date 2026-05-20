import Darwin
import FluegelCore
import Foundation

@MainActor
final class BridgeServer {
    private let handler: BridgeRequestHandler
    private var socketFile: URL?
    private var socketDescriptor: Int32 = -1
    private let encoder = JSONEncoder.fluegelDefault
    private let decoder = JSONDecoder.fluegelDefault
    private nonisolated static let ioQueue = DispatchQueue(label: "me.steipete.Fluegel.bridge", attributes: .concurrent)

    init(handler: BridgeRequestHandler) {
        self.handler = handler
    }

    deinit {
        if socketDescriptor >= 0 {
            close(socketDescriptor)
        }
        if let socketFile {
            try? FileManager.default.removeItem(at: socketFile)
        }
    }

    func start() throws {
        let socketFile = try FluegelPaths.bridgeSocketFile()
        try? FileManager.default.removeItem(at: socketFile)

        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
        do {
            try bindUnixSocket(descriptor, path: socketFile.path)
            guard listen(descriptor, 16) == 0 else {
                throw POSIXError(.init(rawValue: errno) ?? .EIO)
            }
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: socketFile.path)
        } catch {
            close(descriptor)
            throw error
        }

        self.socketFile = socketFile
        socketDescriptor = descriptor
        Self.ioQueue.async { [weak self] in
            self?.acceptLoop(descriptor)
        }
    }

    nonisolated private func acceptLoop(_ descriptor: Int32) {
        while true {
            let client = accept(descriptor, nil, nil)
            if client < 0 {
                return
            }
            Self.ioQueue.async { [weak self] in
                let data = Self.readRequest(from: client)
                Task { @MainActor [weak self] in
                    guard let self else {
                        close(client)
                        return
                    }
                    let response = await self.decodeAndHandle(data)
                    guard let encoded = try? self.encoder.encode(response) else {
                        close(client)
                        return
                    }
                    Self.ioQueue.async {
                        try? Self.writeData(encoded, to: client)
                    }
                }
            }
        }
    }

    nonisolated private static func readRequest(from client: Int32) -> Data {
        var request = Data()
        var buffer = [UInt8](repeating: 0, count: 8_192)
        while true {
            let count = read(client, &buffer, buffer.count)
            if count <= 0 {
                return request
            }
            if let newline = buffer[..<count].firstIndex(of: 0x0a) {
                request.append(buffer, count: newline)
                return request
            }
            request.append(buffer, count: count)
            if request.count > 1_048_576 {
                return Data()
            }
        }
    }

    private func decodeAndHandle(_ data: Data) async -> BridgeResponse {
        do {
            let request = try decoder.decode(BridgeRequest.self, from: data)
            return await handler.handle(request)
        } catch {
            return BridgeResponse(ok: false, message: error.localizedDescription)
        }
    }

    nonisolated private static func writeData(_ data: Data, to client: Int32) throws {
        defer { close(client) }
        try data.withUnsafeBytes { pointer in
            guard let baseAddress = pointer.bindMemory(to: UInt8.self).baseAddress else {
                return
            }
            var sent = 0
            while sent < data.count {
                let count = write(client, baseAddress.advanced(by: sent), data.count - sent)
                guard count > 0 else {
                    throw POSIXError(.init(rawValue: errno) ?? .EIO)
                }
                sent += count
            }
        }
    }
}

private func bindUnixSocket(_ descriptor: Int32, path: String) throws {
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
            bind(descriptor, socketAddress, length)
        }
    }
    guard result == 0 else {
        throw POSIXError(.init(rawValue: errno) ?? .EIO)
    }
}
