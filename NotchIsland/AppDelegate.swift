//
//  AppDelegate.swift
//  NotchIsland
//
//  Brings the app up as a UI-only accessory (no Dock icon, no main menu),
//  spins up the NotchPanel, and installs a menu-bar entry for starting
//  and stopping the Pomodoro timer.
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private let controller = NotchWindowController()
    private var statusItem: NSStatusItem?
    private var toggleMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        controller.show()
        installMenuBarItem()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Menu bar

    private func installMenuBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.topthird.inset.filled",
            accessibilityDescription: "NotchIsland"
        )

        let menu = NSMenu()
        menu.delegate = self

        let toggle = NSMenuItem(
            title: "Start Pomodoro",
            action: #selector(togglePomodoro),
            keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit NotchIsland",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
        toggleMenuItem = toggle
    }

    @objc private func togglePomodoro() {
        controller.pomodoroController.toggle()
    }

    /// Refresh the toggle item's title each time the menu opens — covers
    /// auto-phase transitions that happen without user interaction.
    func menuNeedsUpdate(_ menu: NSMenu) {
        let running = controller.pomodoroController.isRunning
        toggleMenuItem?.title = running ? "Stop Pomodoro" : "Start Pomodoro"
    }
}
