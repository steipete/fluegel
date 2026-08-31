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
            // Keep the non-Sendable event store on the main actor; only return the result.
            let granted = await withCheckedContinuation { continuation in
                eventStore.requestFullAccessToReminders { granted, error in
                    continuation.resume(returning: granted && error == nil)
                }
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
