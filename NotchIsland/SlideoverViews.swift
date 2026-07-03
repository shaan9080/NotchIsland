//
//  SlideoverViews.swift
//  NotchIsland
//
//  Contents of the left-pill slideover: a tab bar switching between
//  StickyNotes (a UserDefaults-backed scratch pad) and RemindersList
//  (EventKit-backed Apple Reminders integration).
//

import SwiftUI
import EventKit

// MARK: - Container

struct SlideoverWindowView: View {

    enum Tab: Hashable { case notes, reminders }

    @State private var selectedTab: Tab = .notes

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            tabBar
            Group {
                switch selectedTab {
                case .notes:     StickyNotesView()
                case .reminders: RemindersListView()
                }
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            tabButton(.notes,     icon: "note.text", title: "Notes")
            tabButton(.reminders, icon: "checklist", title: "Reminders")
            Spacer(minLength: 0)
        }
    }

    private func tabButton(_ tab: Tab, icon: String, title: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.55))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                if selectedTab == tab {
                    Capsule().fill(Color.white.opacity(0.14))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sticky notes

struct StickyNotesView: View {
    @AppStorage("notchIsland.stickyNotes") private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.06))

            if text.isEmpty && !focused {
                Text("Jot down a note…")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .font(.system(size: 11))
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .tint(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .focused($focused)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Reminders

struct RemindersListView: View {
    @EnvironmentObject private var controller: RemindersController

    var body: some View {
        Group {
            switch controller.authorizationStatus {
            case .fullAccess:
                if controller.reminders.isEmpty {
                    emptyState
                } else {
                    reminderList
                }
            case .notDetermined:
                ProgressView().controlSize(.small).tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            default:
                deniedState
            }
        }
        .task { await controller.requestAccessIfNeeded() }
    }

    private var reminderList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 2) {
                ForEach(controller.reminders, id: \.calendarItemIdentifier) { reminder in
                    ReminderRow(reminder: reminder) { controller.complete(reminder) }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.5))
            Text("All caught up")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var deniedState: some View {
        VStack(spacing: 4) {
            Text("Reminders access denied")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
            Text("Enable in System Settings → Privacy & Security → Reminders")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ReminderRow: View {
    let reminder: EKReminder
    let onComplete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: onComplete) {
                Image(systemName: "circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(reminder.title ?? "")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)

                if let due = reminder.dueDateComponents?.date {
                    Text(due, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.system(size: 9))
                        .foregroundStyle(dueColor(for: due))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
    }

    private func dueColor(for date: Date) -> Color {
        date < Date() ? Color.red.opacity(0.75) : Color.white.opacity(0.45)
    }
}
