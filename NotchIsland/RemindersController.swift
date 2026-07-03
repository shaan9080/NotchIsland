//
//  RemindersController.swift
//  NotchIsland
//
//  Reads incomplete reminders from the system Reminders app via EventKit
//  and lets the slideover mark them complete. Uses the macOS 14+
//  full-access API — requires the Info.plist key
//  `NSRemindersFullAccessUsageDescription`.
//

import EventKit
import Combine

@MainActor
final class RemindersController: ObservableObject {

    @Published private(set) var reminders: [EKReminder] = []
    @Published private(set) var authorizationStatus: EKAuthorizationStatus

    private let eventStore = EKEventStore()
    private var storeObserver: NSObjectProtocol?

    init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
        // Refresh when Reminders.app writes a change (mark complete, add,
        // etc.). Broadcast on any thread — hop to main to update state.
        storeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    deinit {
        if let storeObserver {
            NotificationCenter.default.removeObserver(storeObserver)
        }
    }

    /// Called on first appearance of the Reminders tab. Prompts once,
    /// then loads.
    func requestAccessIfNeeded() async {
        switch authorizationStatus {
        case .fullAccess:
            await refresh()
        case .notDetermined:
            do {
                let granted = try await eventStore.requestFullAccessToReminders()
                authorizationStatus = granted ? .fullAccess : .denied
                if granted { await refresh() }
            } catch {
                authorizationStatus = .denied
            }
        default:
            break
        }
    }

    func refresh() async {
        guard authorizationStatus == .fullAccess else { return }
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )
        let fetched: [EKReminder] = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { result in
                continuation.resume(returning: result ?? [])
            }
        }
        reminders = fetched.sorted { lhs, rhs in
            let lhsDate = lhs.dueDateComponents?.date ?? .distantFuture
            let rhsDate = rhs.dueDateComponents?.date ?? .distantFuture
            return lhsDate < rhsDate
        }
    }

    func complete(_ reminder: EKReminder) {
        reminder.isCompleted = true
        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            return
        }
        Task { await refresh() }
    }
}
