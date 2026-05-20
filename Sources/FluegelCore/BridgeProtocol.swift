import Foundation

public enum BridgeAction: String, Codable, Sendable {
    case status
    case run
    case listWhitelist
    case addWhitelist
    case removeWhitelist
    case permissionStatus
    case requestPermission
    case auditList
}

public struct BridgeRequest: Codable, Sendable {
    public var token: String
    public var action: BridgeAction
    public var run: RunRequest?
    public var command: CommandEntry?
    public var executablePath: String?
    public var permission: PermissionKind?
    public var auditLimit: Int?

    public init(
        token: String,
        action: BridgeAction,
        run: RunRequest? = nil,
        command: CommandEntry? = nil,
        executablePath: String? = nil,
        permission: PermissionKind? = nil,
        auditLimit: Int? = nil
    ) {
        self.token = token
        self.action = action
        self.run = run
        self.command = command
        self.executablePath = executablePath
        self.permission = permission
        self.auditLimit = auditLimit
    }
}

public struct BridgeResponse: Codable, Sendable {
    public var ok: Bool
    public var message: String
    public var config: FluegelConfig?
    public var result: CommandResult?
    public var permissionStatus: PermissionStatus?
    public var auditEntries: [AuditEntry]?

    public init(
        ok: Bool,
        message: String,
        config: FluegelConfig? = nil,
        result: CommandResult? = nil,
        permissionStatus: PermissionStatus? = nil,
        auditEntries: [AuditEntry]? = nil
    ) {
        self.ok = ok
        self.message = message
        self.config = config
        self.result = result
        self.permissionStatus = permissionStatus
        self.auditEntries = auditEntries
    }
}
