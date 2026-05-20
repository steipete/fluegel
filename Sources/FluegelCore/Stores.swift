import Foundation

public final class ConfigStore: @unchecked Sendable {
    public let url: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager

    public init(
        url: URL,
        fileManager: FileManager = .default,
        encoder: JSONEncoder = .fluegelDefault,
        decoder: JSONDecoder = .fluegelDefault
    ) {
        self.url = url
        self.fileManager = fileManager
        self.encoder = encoder
        self.decoder = decoder
    }

    public convenience init(fileManager: FileManager = .default) throws {
        try self.init(url: FluegelPaths.configFile(fileManager: fileManager), fileManager: fileManager)
    }

    public func load() throws -> FluegelConfig {
        guard fileManager.fileExists(atPath: url.path) else {
            return FluegelConfig()
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode(FluegelConfig.self, from: data)
    }

    public func save(_ config: FluegelConfig) throws {
        let data = try encoder.encode(config)
        try data.write(to: url, options: [.atomic])
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public func update(_ transform: (inout FluegelConfig) throws -> Void) throws -> FluegelConfig {
        var config = try load()
        try transform(&config)
        try save(config)
        return config
    }
}

public final class AuditLogStore: @unchecked Sendable {
    public let url: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager

    public init(
        url: URL,
        fileManager: FileManager = .default,
        encoder: JSONEncoder = .fluegelJSONLines,
        decoder: JSONDecoder = .fluegelDefault
    ) {
        self.url = url
        self.fileManager = fileManager
        self.encoder = encoder
        self.decoder = decoder
    }

    public convenience init(fileManager: FileManager = .default) throws {
        try self.init(url: FluegelPaths.auditLogFile(fileManager: fileManager), fileManager: fileManager)
    }

    public func append(_ entry: AuditEntry) throws {
        let data = try encoder.encode(entry) + Data([0x0a])
        if fileManager.fileExists(atPath: url.path) {
            let handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()
        } else {
            try data.write(to: url, options: [.atomic])
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
    }

    public func entries(limit: Int = 100) throws -> [AuditEntry] {
        guard limit > 0 else {
            return []
        }
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }
        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8), !content.isEmpty else {
            return []
        }
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        return try lines.suffix(limit).map { line in
            guard let data = String(line).data(using: .utf8) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return try decoder.decode(AuditEntry.self, from: data)
        }
    }
}

public final class TokenStore: @unchecked Sendable {
    public let url: URL
    private let fileManager: FileManager

    public init(url: URL, fileManager: FileManager = .default) {
        self.url = url
        self.fileManager = fileManager
    }

    public convenience init(fileManager: FileManager = .default) throws {
        try self.init(url: FluegelPaths.tokenFile(fileManager: fileManager), fileManager: fileManager)
    }

    public func token() throws -> String {
        if fileManager.fileExists(atPath: url.path) {
            return try String(contentsOf: url, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let token = UUID().uuidString + "-" + UUID().uuidString
        try token.write(to: url, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return token
    }
}

public extension JSONEncoder {
    static var fluegelDefault: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static var fluegelJSONLines: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

public extension JSONDecoder {
    static var fluegelDefault: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
