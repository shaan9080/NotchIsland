//
//  PomodoroState.swift
//  NotchIsland
//
//  Immutable snapshot of the Pomodoro timer. The controller publishes
//  a new value once per second while a session is active.
//

import Foundation

enum PomodoroPhase: Sendable, Equatable {
    case work
    case shortBreak

    var displayName: String {
        switch self {
        case .work:       return "Focus"
        case .shortBreak: return "Break"
        }
    }

    var iconName: String {
        switch self {
        case .work:       return "timer"
        case .shortBreak: return "cup.and.saucer.fill"
        }
    }
}

struct PomodoroState: Sendable, Equatable {
    let phase: PomodoroPhase
    let remaining: TimeInterval
    let total: TimeInterval
    let endsAt: Date

    var progress: Double {
        guard total > 0 else { return 0 }
        return max(0, min(1, (total - remaining) / total))
    }

    var displayTime: String {
        let s = max(0, Int(remaining.rounded(.down)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
