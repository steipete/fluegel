import FluegelCore
import Foundation

@MainActor
final class BridgeRequestHandler {
    private let expectedToken: String
    private let configStore: ConfigStore
    private let auditStore: AuditLogStore
    private let permissionManager: PermissionManager
    private let whitelist = WhitelistEvaluator()
    private let runner = CommandRunner()
    private let onChange: @Sendable () -> Void

    init(
        expectedToken: String,
        configStore: ConfigStore,
        auditStore: AuditLogStore,
        permissionManager: PermissionManager,
        onChange: @escaping @Sendable () -> Void
    ) {
        self.expectedToken = expectedToken
        self.configStore = configStore
        self.auditStore = auditStore
        self.permissionManager = permissionManager
        self.onChange = onChange
    }

    func handle(_ request: BridgeRequest) async -> BridgeResponse {
        guard request.token == expectedToken else {
            return BridgeResponse(ok: false, message: "Invalid bridge token")
        }

        do {
            switch request.action {
            case .status:
                return BridgeResponse(ok: true, message: "ok", config: try configStore.load())
            case .listWhitelist:
                return BridgeResponse(ok: true, message: "ok", config: try configStore.load())
            case .addWhitelist:
                return await addWhitelist(request)
            case .removeWhitelist:
                return await removeWhitelist(request)
            case .permissionStatus:
                guard let permission = request.permission else {
                    return BridgeResponse(ok: false, message: "Missing permission")
                }
                return BridgeResponse(
                    ok: true,
                    message: "ok",
                    permissionStatus: permissionManager.status(for: permission)
                )
            case .requestPermission:
                guard let permission = request.permission else {
                    return BridgeResponse(ok: false, message: "Missing permission")
                }
                let status = await permissionManager.request(permission)
                onChange()
                return BridgeResponse(ok: status == .authorized, message: status.rawValue, permissionStatus: status)
            case .auditList:
                return BridgeResponse(
                    ok: true,
                    message: "ok",
                    auditEntries: try auditStore.entries(limit: request.auditLimit ?? 50).reversed()
                )
            case .run:
                return try await runCommand(request)
            }
        } catch {
            return BridgeResponse(ok: false, message: error.localizedDescription)
        }
    }

    private func addWhitelist(_ request: BridgeRequest) async -> BridgeResponse {
        guard var command = request.command else {
            return BridgeResponse(ok: false, message: "Missing command")
        }
        guard await LocalAuthenticator.authenticate(reason: "Edit Fluegel command whitelist") else {
            return BridgeResponse(ok: false, message: "Authentication canceled")
        }

        do {
            let config = try configStore.update { config in
                let now = Date()
                command.updatedAt = now
                if let index = config.commands.firstIndex(where: { $0.executablePath == command.executablePath }) {
                    command.id = config.commands[index].id
                    command.createdAt = config.commands[index].createdAt
                    config.commands[index] = command
                } else {
                    command.createdAt = now
                    config.commands.append(command)
                }
            }
            onChange()
            return BridgeResponse(ok: true, message: "Whitelisted \(command.executablePath)", config: config)
        } catch {
            return BridgeResponse(ok: false, message: error.localizedDescription)
        }
    }

    private func removeWhitelist(_ request: BridgeRequest) async -> BridgeResponse {
        guard let path = request.executablePath else {
            return BridgeResponse(ok: false, message: "Missing executable path")
        }
        guard await LocalAuthenticator.authenticate(reason: "Remove a Fluegel command whitelist entry") else {
            return BridgeResponse(ok: false, message: "Authentication canceled")
        }

        do {
            let config = try configStore.update { config in
                config.commands.removeAll { $0.executablePath == path }
            }
            onChange()
            return BridgeResponse(ok: true, message: "Removed \(path)", config: config)
        } catch {
            return BridgeResponse(ok: false, message: error.localizedDescription)
        }
    }

    private func runCommand(_ request: BridgeRequest) async throws -> BridgeResponse {
        guard let run = request.run else {
            return BridgeResponse(ok: false, message: "Missing run request")
        }

        let requester = NSUserName()
        let config = try configStore.load()

        do {
            let entry = try whitelist.entry(for: run, in: config)
            for permission in entry.permissions where permissionManager.status(for: permission) != .authorized {
                let audit = AuditEntry(
                    decision: .denied,
                    executablePath: run.executablePath,
                    arguments: run.arguments,
                    cwd: run.cwd,
                    requester: requester,
                    permissions: entry.permissions,
                    exitCode: nil,
                    stdoutBytes: 0,
                    stderrBytes: 0,
                    reason: "\(permission.displayName) permission is not authorized"
                )
                try auditStore.append(audit)
                onChange()
                return BridgeResponse(ok: false, message: audit.reason)
            }

            let result = try await Task.detached(priority: .userInitiated) {
                try self.runner.run(run)
            }.value
            try auditStore.append(AuditEntry(
                decision: .allowed,
                executablePath: run.executablePath,
                arguments: run.arguments,
                cwd: run.cwd,
                requester: requester,
                permissions: entry.permissions,
                exitCode: result.exitCode,
                stdoutBytes: result.stdout.utf8.count,
                stderrBytes: result.stderr.utf8.count,
                reason: "Executed"
            ))
            onChange()
            return BridgeResponse(ok: result.exitCode == 0, message: "exit \(result.exitCode)", result: result)
        } catch {
            try auditStore.append(AuditEntry(
                decision: .denied,
                executablePath: run.executablePath,
                arguments: run.arguments,
                cwd: run.cwd,
                requester: requester,
                permissions: [],
                exitCode: nil,
                stdoutBytes: 0,
                stderrBytes: 0,
                reason: error.localizedDescription
            ))
            onChange()
            return BridgeResponse(ok: false, message: error.localizedDescription)
        }
    }
}
