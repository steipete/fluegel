import Foundation

public enum WhitelistError: LocalizedError, Equatable {
    case notWhitelisted(String)
    case disabled(String)
    case missingPermissions(String)

    public var errorDescription: String? {
        switch self {
        case .notWhitelisted(let path):
            "Command is not whitelisted: \(path)"
        case .disabled(let path):
            "Command is disabled: \(path)"
        case .missingPermissions(let path):
            "Command has no permissions assigned: \(path)"
        }
    }
}

public struct WhitelistEvaluator: Sendable {
    public init() {}

    public func entry(for request: RunRequest, in config: FluegelConfig) throws -> CommandEntry {
        guard let entry = config.commands.first(where: { $0.executablePath == request.executablePath }) else {
            throw WhitelistError.notWhitelisted(request.executablePath)
        }
        guard entry.enabled else {
            throw WhitelistError.disabled(request.executablePath)
        }
        guard !entry.permissions.isEmpty else {
            throw WhitelistError.missingPermissions(request.executablePath)
        }
        return entry
    }
}
