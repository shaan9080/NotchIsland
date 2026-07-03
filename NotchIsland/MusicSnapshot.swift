//
//  MusicSnapshot.swift
//  NotchIsland
//
//  Immutable value type describing Music.app's Now Playing state at
//  a moment in time. Sendable so it can be produced on the AppleScript
//  background queue and posted back to the main actor.
//

import Foundation

enum MusicPlayerState: Sendable, Equatable {
    case playing
    case paused
    case stopped
}

struct MusicSnapshot: Sendable, Equatable {
    let title: String
    let artist: String
    let album: String
    let state: MusicPlayerState
    let duration: TimeInterval
    let position: TimeInterval
    let positionSampledAt: Date
    let artworkData: Data?

    var isPlaying: Bool { state == .playing }

    /// Extrapolated playback position at `now`, so the scrub bar can
    /// advance smoothly between AppleScript polls.
    func currentPosition(at now: Date) -> TimeInterval {
        guard isPlaying else { return position }
        let elapsed = now.timeIntervalSince(positionSampledAt)
        return min(max(position + elapsed, 0), duration)
    }
}
