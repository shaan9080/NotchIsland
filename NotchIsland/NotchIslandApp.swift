//
//  NotchIslandApp.swift
//  NotchIsland
//
//  Created by Shaan Rehal on 2026-06-28.
//

import SwiftUI

@main
struct NotchIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // No primary window — the island is hosted in NotchPanel.
        // A Settings scene is the conventional way to provide a "scene"
        // for an overlay-only macOS SwiftUI app.
        Settings { EmptyView() }
    }
}
