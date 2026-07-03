//
//  NotchPanel.swift
//  NotchIsland
//
//  Borderless, transparent NSPanel that hosts the SwiftUI island.
//  Sits above all windows (including full-screen apps) and never steals focus.
//

import AppKit

final class NotchPanel: NSPanel {

    /// Gated so the panel only steals keyboard focus while the slideover
    /// is open (needed for TextEditor). At other times we stay firmly
    /// out of the user's typing context.
    var keyboardEnabled: Bool = false {
        didSet {
            if !keyboardEnabled, isKeyWindow {
                resignKey()
            }
        }
    }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]

        isMovable = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        worksWhenModal = true
        animationBehavior = .none

        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
    }

    override var canBecomeKey: Bool { keyboardEnabled }
    override var canBecomeMain: Bool { false }
}
