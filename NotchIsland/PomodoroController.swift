//
//  PomodoroController.swift
//  NotchIsland
//
//  Drives `viewModel.pomodoroState`. 25-min focus → 5-min break,
//  auto-looping until the user stops it via the menu bar.
//

import Foundation
import Combine

@MainActor
final class PomodoroController: ObservableObject {

    static let workDuration: TimeInterval = 25 * 60
    static let breakDuration: TimeInterval = 5 * 60
    private static let tickInterval: TimeInterval = 1.0

    @Published private(set) var state: PomodoroState? = nil {
        didSet { viewModel?.pomodoroState = state }
    }

    private weak var viewModel: NotchViewModel?
    private var timer: Timer?

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
    }

    var isRunning: Bool { state != nil }

    func toggle() {
        if isRunning { stop() } else { start() }
    }

    func start() {
        beginPhase(.work)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        state = nil
    }

    private func beginPhase(_ phase: PomodoroPhase) {
        let total = (phase == .work) ? Self.workDuration : Self.breakDuration
        let endsAt = Date().addingTimeInterval(total)
        state = PomodoroState(phase: phase, remaining: total, total: total, endsAt: endsAt)
        scheduleTicker()
    }

    private func scheduleTicker() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard let current = state else { return }
        let remaining = current.endsAt.timeIntervalSinceNow
        if remaining <= 0 {
            beginPhase(current.phase == .work ? .shortBreak : .work)
        } else {
            state = PomodoroState(
                phase: current.phase,
                remaining: remaining,
                total: current.total,
                endsAt: current.endsAt
            )
        }
    }
}
