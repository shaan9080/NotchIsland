//
//  NotchViewModel.swift
//  NotchIsland
//
//  Single source of truth for the island. View state is derived from
//  three inputs: the user's hover/tap intent and the currently-running
//  activities. Activity sources (Music, Pomodoro) toggle the flags;
//  the view reads `viewState` and animates between layouts.
//

import Combine
import SwiftUI

enum NotchViewState: Equatable {
    case idle      // collapsed — matches the physical notch geometry
    case compact   // single activity, small pill around the notch
    case expanded  // hover / tap revealed full card
    case split     // music + pomodoro — primary card + detached side pill
}

@MainActor
final class NotchViewModel: ObservableObject {

    @Published private(set) var viewState: NotchViewState = .idle

    // Geometry of the physical notch on the primary display. Drives the
    // idle-state size so the island sits flush with the hardware cutout.
    @Published var notchSize: CGSize = CGSize(width: 200, height: 32)

    // Activity inputs.
    // `musicSnapshot` is owned by MusicController; `hasPomodoroActivity`
    // will be owned by the timer in step 4.
    @Published var musicSnapshot: MusicSnapshot? = nil {
        didSet {
            // viewState only depends on whether music is *active* —
            // skip the recompute when only position/artwork moved.
            if (oldValue == nil) != (musicSnapshot == nil) {
                recompute()
            }
        }
    }
    @Published var pomodoroState: PomodoroState? = nil {
        didSet {
            if (oldValue == nil) != (pomodoroState == nil) {
                recompute()
            }
        }
    }

    var hasMusicActivity: Bool { musicSnapshot != nil }
    var hasPomodoroActivity: Bool { pomodoroState != nil }

    /// Drives the third pill (left of primary). When `true`, the pill
    /// stretches downward into a slideover-style window.
    @Published var isSlideoverOpen: Bool = false

    func toggleSlideover() {
        isSlideoverOpen.toggle()
    }

    private var isHovering = false
    private var isPinnedOpen = false

    func setHovering(_ hovering: Bool) {
        isHovering = hovering
        recompute()
    }

    func togglePinned() {
        isPinnedOpen.toggle()
        recompute()
    }

    func collapse() {
        isPinnedOpen = false
        isHovering = false
        recompute()
    }

    private func recompute() {
        let shouldExpand = isHovering || isPinnedOpen
        let next: NotchViewState
        if shouldExpand {
            next = .expanded
        } else if hasMusicActivity && hasPomodoroActivity {
            next = .split
        } else if hasMusicActivity || hasPomodoroActivity {
            next = .compact
        } else {
            next = .idle
        }
        guard next != viewState else { return }
        viewState = next
    }
}
