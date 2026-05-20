import FluegelCore
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var config = FluegelConfig()
    @Published private(set) var auditEntries: [AuditEntry] = []
    @Published private(set) var statusMessage = "Starting"

    let permissionManager = PermissionManager()
    let configStore: ConfigStore
    let auditStore: AuditLogStore
    let tokenStore: TokenStore
    private var bridgeServer: BridgeServer?

    init() {
        do {
            configStore = try ConfigStore()
            auditStore = try AuditLogStore()
            tokenStore = try TokenStore()
            reload()
            startBridge()
        } catch {
            fatalError("Failed to initialize Fluegel: \(error)")
        }
    }

    func reload() {
        do {
            config = try configStore.load()
            auditEntries = try auditStore.entries(limit: 100).reversed()
            permissionManager.refresh()
            statusMessage = "Ready"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func startBridge() {
        do {
            let token = try tokenStore.token()
            let handler = BridgeRequestHandler(
                expectedToken: token,
                configStore: configStore,
                auditStore: auditStore,
                permissionManager: permissionManager,
                onChange: { [weak self] in
                    Task { @MainActor in self?.reload() }
                }
            )
            let server = BridgeServer(handler: handler)
            try server.start()
            bridgeServer = server
            statusMessage = "Bridge listening on private socket"
        } catch {
            statusMessage = "Bridge failed: \(error.localizedDescription)"
        }
    }

    func requestReminders() {
        Task {
            _ = await permissionManager.request(.reminders)
            reload()
        }
    }

    func addCommand(name: String, path: String, permissions: Set<PermissionKind>) {
        Task {
            guard await LocalAuthenticator.authenticate(reason: "Edit Fluegel command whitelist") else {
                statusMessage = "Authentication canceled"
                return
            }
            do {
                _ = try configStore.update { config in
                    let now = Date()
                    if let index = config.commands.firstIndex(where: { $0.executablePath == path }) {
                        config.commands[index].name = name
                        config.commands[index].permissions = permissions
                        config.commands[index].enabled = true
                        config.commands[index].updatedAt = now
                    } else {
                        config.commands.append(CommandEntry(
                            name: name,
                            executablePath: path,
                            permissions: permissions,
                            createdAt: now,
                            updatedAt: now
                        ))
                    }
                }
                reload()
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    func removeCommand(path: String) {
        Task {
            guard await LocalAuthenticator.authenticate(reason: "Remove a Fluegel command whitelist entry") else {
                statusMessage = "Authentication canceled"
                return
            }
            do {
                _ = try configStore.update { config in
                    config.commands.removeAll { $0.executablePath == path }
                }
                reload()
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }
}
