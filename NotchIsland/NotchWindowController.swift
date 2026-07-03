//
//  NotchWindowController.swift
//  NotchIsland
//
//  Owns the NotchPanel: computes the primary-screen notch geometry,
//  positions the panel anchored to the top-center of that screen, and
//  re-runs the calculation whenever the display configuration changes.
//

import AppKit
import Combine
import SwiftUI

@MainActor
final class NotchWindowController {

    // Size of the hosting panel. Must be wide / tall enough to contain
    // every island state's maximum bounds — the SwiftUI view stays anchored
    // to the top-center inside it.
    private static let panelSize = CGSize(width: 880, height: 340)

    // Hardcoded fallback for the 16-inch MacBook Pro notch when the
    // screen does not report a safe-area inset (e.g. external display
    // or older macOS).
    private static let fallbackNotchSize = CGSize(width: 200, height: 32)

    let viewModel = NotchViewModel()
    lazy var musicController = MusicController(viewModel: viewModel)
    lazy var pomodoroController = PomodoroController(viewModel: viewModel)
    lazy var remindersController = RemindersController()
    private var panel: NotchPanel?
    private var screenObserver: NSObjectProtocol?
    private var slideoverKeyBinding: AnyCancellable?

    func show() {
        guard let screen = primaryScreen() else { return }
        viewModel.notchSize = detectNotchSize(on: screen)

        let root = NotchIslandView()
            .environmentObject(viewModel)
            .environmentObject(musicController)
            .environmentObject(pomodoroController)
            .environmentObject(remindersController)
        let hosting = NSHostingView(rootView: root)

        let frame = panelFrame(on: screen)
        let panel = NotchPanel(contentRect: frame)
        panel.contentView = hosting
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        self.panel = panel

        // Keyboard focus is only allowed while the slideover is open,
        // so the sticky-notes TextEditor accepts input without the
        // panel stealing focus from other apps at all other times.
        slideoverKeyBinding = viewModel.$isSlideoverOpen
            .removeDuplicates()
            .sink { [weak panel] open in
                panel?.keyboardEnabled = open
                if open { panel?.makeKey() }
            }

        musicController.start()

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reposition() }
        }
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    private func reposition() {
        guard let panel, let screen = primaryScreen() else { return }
        viewModel.notchSize = detectNotchSize(on: screen)
        panel.setFrame(panelFrame(on: screen), display: true)
    }

    private func panelFrame(on screen: NSScreen) -> NSRect {
        let f = screen.frame
        return NSRect(
            x: f.midX - Self.panelSize.width / 2,
            y: f.maxY - Self.panelSize.height,
            width: Self.panelSize.width,
            height: Self.panelSize.height
        )
    }

    private func detectNotchSize(on screen: NSScreen) -> CGSize {
        let height = screen.safeAreaInsets.top
        var width: CGFloat = 0
        if let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            width = screen.frame.width - left.width - right.width
        }
        if height > 0 && width > 0 {
            return CGSize(width: width, height: height)
        }
        return Self.fallbackNotchSize
    }

    private func primaryScreen() -> NSScreen? {
        // The screen whose origin is (0,0) is the one that owns the menu bar.
        NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main
    }
}
