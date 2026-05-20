import FluegelCore
import SwiftUI

@main
struct FluegelApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra("Fluegel", systemImage: "bird") {
            Text(model.statusMessage)
            Divider()
            Button {
                openWindow(id: "settings")
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            Button {
                model.requestReminders()
            } label: {
                Label("Enable Reminders", systemImage: "checkmark.shield")
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)

        Window("Fluegel Settings", id: "settings") {
            SettingsView(model: model)
        }
    }
}
