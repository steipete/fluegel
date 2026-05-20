import FluegelCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var newName = "rem"
    @State private var newPath = "/opt/homebrew/bin/rem"
    @State private var allowReminders = true

    var body: some View {
        TabView {
            permissionsView
                .tabItem { Label("Permissions", systemImage: "checkmark.shield") }
            whitelistView
                .tabItem { Label("Whitelist", systemImage: "list.bullet.rectangle") }
            auditView
                .tabItem { Label("Audit", systemImage: "doc.text.magnifyingglass") }
        }
        .frame(width: 760, height: 520)
        .padding(18)
    }

    private var permissionsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Permissions")
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reminders")
                        .font(.headline)
                    Text(model.permissionManager.remindersStatus.rawValue)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Request Access") {
                    model.requestReminders()
                }
            }
            Spacer()
        }
    }

    private var whitelistView: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Whitelist")
            List {
                ForEach(model.config.commands) { command in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(command.name)
                                .font(.headline)
                            Text(command.executablePath)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(command.permissions.map(\.displayName).sorted().joined(separator: ", "))
                            .foregroundStyle(.secondary)
                        Button(role: .destructive) {
                            model.removeCommand(path: command.executablePath)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Add Command")
                    .font(.headline)
                TextField("Name", text: $newName)
                TextField("Full path", text: $newPath)
                    .font(.system(.body, design: .monospaced))
                Toggle("Reminders", isOn: $allowReminders)
                Button {
                    model.addCommand(
                        name: newName.isEmpty ? URL(fileURLWithPath: newPath).lastPathComponent : newName,
                        path: newPath,
                        permissions: allowReminders ? [.reminders] : []
                    )
                } label: {
                    Label("Add or Update", systemImage: "plus")
                }
                .disabled(newPath.isEmpty || !newPath.hasPrefix("/") || !allowReminders)
            }
        }
    }

    private var auditView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle("Audit Log")
                Spacer()
                Button {
                    model.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            List(model.auditEntries) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.timestamp.formatted(date: .abbreviated, time: .standard))
                        Text(entry.decision.rawValue)
                            .foregroundStyle(entry.decision == .allowed ? .green : .red)
                        Text(entry.executablePath)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Text(entry.reason)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 3)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title2.bold())
    }
}
