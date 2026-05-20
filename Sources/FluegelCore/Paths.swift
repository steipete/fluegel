import Foundation

public enum FluegelPaths {
    public static let appName = "Fluegel"
    public static let bundleIdentifier = "me.steipete.Fluegel"

    public static func applicationSupportDirectory(
        fileManager: FileManager = .default
    ) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent(appName, isDirectory: true)
        try createPrivateDirectory(directory, fileManager: fileManager)
        return directory
    }

    public static func logsDirectory(fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(
            for: .libraryDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent(appName, isDirectory: true)
        try createPrivateDirectory(directory, fileManager: fileManager)
        return directory
    }

    public static func configFile(fileManager: FileManager = .default) throws -> URL {
        try applicationSupportDirectory(fileManager: fileManager)
            .appendingPathComponent("config.json")
    }

    public static func tokenFile(fileManager: FileManager = .default) throws -> URL {
        try applicationSupportDirectory(fileManager: fileManager)
            .appendingPathComponent("bridge.token")
    }

    public static func bridgeSocketFile(fileManager: FileManager = .default) throws -> URL {
        try applicationSupportDirectory(fileManager: fileManager)
            .appendingPathComponent("bridge.sock")
    }

    public static func auditLogFile(fileManager: FileManager = .default) throws -> URL {
        try logsDirectory(fileManager: fileManager)
            .appendingPathComponent("audit.jsonl")
    }

    public static func createPrivateDirectory(
        _ url: URL,
        fileManager: FileManager = .default
    ) throws {
        try fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }
}
