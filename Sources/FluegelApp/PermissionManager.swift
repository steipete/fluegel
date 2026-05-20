import EventKit
import FluegelCore
import Foundation

@MainActor
final class PermissionManager: ObservableObject {
    @Published private(set) var remindersStatus: PermissionStatus = .unknown
    private let eventStore = EKEventStore()

    init() {
        refresh()
    }

    func refresh() {
        remindersStatus = Self.remindersStatus()
    }

    func status(for permission: PermissionKind) -> PermissionStatus {
        switch permission {
        case .reminders:
            let status = Self.remindersStatus()
            remindersStatus = status
            return status
        }
    }

    func request(_ permission: PermissionKind) async -> PermissionStatus {
        switch permission {
        case .reminders:
            let granted: Bool
            do {
                if #available(macOS 14.0, *) {
                    granted = try await eventStore.requestFullAccessToReminders()
                } else {
                    granted = try await eventStore.requestAccess(to: .reminder)
                }
            } catch {
                granted = false
            }
            remindersStatus = granted ? .authorized : Self.remindersStatus()
            return remindersStatus
        }
    }

    static func remindersStatus() -> PermissionStatus {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .authorized:
            .authorized
        case .denied:
            .denied
        case .restricted:
            .restricted
        case .notDetermined:
            .notDetermined
        case .fullAccess:
            .authorized
        case .writeOnly:
            .writeOnly
        @unknown default:
            .unknown
        }
    }
}
