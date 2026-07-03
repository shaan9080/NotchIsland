//
//  MusicController.swift
//  NotchIsland
//
//  Drives `viewModel.musicSnapshot`. Two sources of updates:
//    1. com.apple.Music.playerInfo distributed notification — fires
//       instantly on play/pause/track change.
//    2. 1Hz poll — keeps the scrub position fresh while playing.
//  Commands (playPause / next / previous / seek) round-trip through
//  AppleScript and then refresh immediately so the UI feels instant.
//

import AppKit
import Combine

@MainActor
final class MusicController: ObservableObject {

    private static let playerInfoNotification = NSNotification.Name("com.apple.Music.playerInfo")
    private static let pollInterval: TimeInterval = 1.0

    private weak var viewModel: NotchViewModel?
    private var pollTimer: Timer?
    private var distributedObserver: NSObjectProtocol?

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
    }

    func start() {
        distributedObserver = DistributedNotificationCenter.default()
            .addObserver(
                forName: Self.playerInfoNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in await self?.refresh() }
            }

        pollTimer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }

        Task { @MainActor in await refresh() }
    }

    func stop() {
        if let observer = distributedObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            distributedObserver = nil
        }
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Commands

    func playPause()      { MusicAppleScript.playPause();     scheduleRefresh() }
    func nextTrack()      { MusicAppleScript.nextTrack();     scheduleRefresh() }
    func previousTrack()  { MusicAppleScript.previousTrack(); scheduleRefresh() }
    func seek(to seconds: TimeInterval) {
        MusicAppleScript.seek(to: seconds)
        scheduleRefresh()
    }

    // MARK: - Refresh

    private func refresh() async {
        viewModel?.musicSnapshot = await MusicAppleScript.fetchSnapshot()
    }

    /// Commands are async on Music's side; give it ~120ms to settle
    /// before reading state back.
    private func scheduleRefresh() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)
            await refresh()
        }
    }
}
