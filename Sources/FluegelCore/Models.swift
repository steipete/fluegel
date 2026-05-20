import Foundation

public enum PermissionKind: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case reminders

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .reminders:
            "Reminders"
        }
    }
}

public struct CommandEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var executablePath: String
    public var permissions: Set<PermissionKind>
    public var enabled: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        executablePath: String,
        permissions: Set<PermissionKind>,
        enabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.executablePath = executablePath
        self.permissions = permissions
        self.enabled = enabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct FluegelConfig: Codable, Equatable, Sendable {
    public var commands: [CommandEntry]

    public init(commands: [CommandEntry] = []) {
        self.commands = commands
    }
}

public enum AuditDecision: String, Codable, Sendable {
    case allowed
    case denied
}

public struct AuditEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var timestamp: Date
    public var decision: AuditDecision
    public var executablePath: String
    public var arguments: [String]
    public var cwd: String?
    public var requester: String
    public var permissions: Set<PermissionKind>
    public var exitCode: Int32?
    public var stdoutBytes: Int
    public var stderrBytes: Int
    public var reason: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        decision: AuditDecision,
        executablePath: String,
        arguments: [String],
        cwd: String?,
        requester: String,
        permissions: Set<PermissionKind>,
        exitCode: Int32?,
        stdoutBytes: Int,
        stderrBytes: Int,
        reason: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.decision = decision
        self.executablePath = executablePath
        self.arguments = arguments
        self.cwd = cwd
        self.requester = requester
        self.permissions = permissions
        self.exitCode = exitCode
        self.stdoutBytes = stdoutBytes
        self.stderrBytes = stderrBytes
        self.reason = reason
    }
}

public enum PermissionStatus: String, Codable, Sendable {
    case authorized
    case writeOnly
    case denied
    case restricted
    case notDetermined
    case unknown
}

public struct CommandResult: Codable, Equatable, Sendable {
    public var exitCode: Int32
    public var stdout: String
    public var stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public struct RunRequest: Codable, Equatable, Sendable {
    public var executablePath: String
    public var arguments: [String]
    public var cwd: String?
    public var timeoutSeconds: TimeInterval

    public init(
        executablePath: String,
        arguments: [String],
        cwd: String? = nil,
        timeoutSeconds: TimeInterval = 30
    ) {
        self.executablePath = executablePath
        self.arguments = arguments
        self.cwd = cwd
        self.timeoutSeconds = timeoutSeconds
    }
}
