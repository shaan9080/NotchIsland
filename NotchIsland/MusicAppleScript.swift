//
//  MusicAppleScript.swift
//  NotchIsland
//
//  Thin AppleScript bridge to Music.app. Runs scripts on a dedicated
//  serial queue so the first-launch TCC permission prompt and any
//  multi-hundred-ms first call never block the SwiftUI main thread.
//
//  Requires:
//    • App Sandbox = OFF, or a temporary-exception apple-events
//      entitlement for com.apple.Music.
//    • Info.plist key NSAppleEventsUsageDescription
//      (set via INFOPLIST_KEY_NSAppleEventsUsageDescription).
//

import AppKit

nonisolated enum MusicAppleScript {

    // ASCII RS (0x1E) — vanishingly unlikely to appear in a track title.
    private static let separator = "\u{1E}"

    private static let snapshotSource: String = """
    tell application "Music"
        if it is not running then return "::notrunning::"
        try
            set ps to player state
            if ps is stopped then return "::stopped::"
            set stateText to "paused"
            if ps is playing then set stateText to "playing"
            set t to current track
            set sep to (ASCII character 30)
            set tName to (name of t as text)
            set tArtist to (artist of t as text)
            set tAlbum to (album of t as text)
            set tDuration to (duration of t as real)
            set tPosition to (player position as real)
            return tName & sep & tArtist & sep & tAlbum & sep & tDuration & sep & tPosition & sep & stateText
        on error errMsg number errNum
            return "::error:: " & errNum & ": " & errMsg
        end try
    end tell
    """

    private static let artworkSource: String = """
    tell application "Music"
        try
            if it is not running then return missing value
            if (count of artworks of current track) is 0 then return missing value
            return (data of artwork 1 of current track)
        on error
            return missing value
        end try
    end tell
    """

    private static let queue = DispatchQueue(
        label: "com.notchisland.applescript",
        qos: .userInitiated
    )

    // MARK: - Reads

    static func fetchSnapshot() async -> MusicSnapshot? {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: fetchSnapshotSync())
            }
        }
    }

    private static func fetchSnapshotSync() -> MusicSnapshot? {
        guard let descriptor = runSync(snapshotSource) else { return nil }
        let raw = descriptor.stringValue ?? ""
        if raw.isEmpty || raw == "::notrunning::" || raw == "::stopped::" || raw.hasPrefix("::error::") {
            return nil
        }
        let parts = raw.components(separatedBy: separator)
        guard parts.count == 6 else { return nil }

        let state: MusicPlayerState
        switch parts[5] {
        case "playing": state = .playing
        case "paused":  state = .paused
        default:        state = .stopped
        }

        return MusicSnapshot(
            title: parts[0],
            artist: parts[1],
            album: parts[2],
            state: state,
            duration: TimeInterval(parts[3]) ?? 0,
            position: TimeInterval(parts[4]) ?? 0,
            positionSampledAt: Date(),
            artworkData: fetchArtworkDataSync()
        )
    }

    private static func fetchArtworkDataSync() -> Data? {
        guard let descriptor = runSync(artworkSource) else { return nil }
        let data = descriptor.data
        return data.isEmpty ? nil : data
    }

    // MARK: - Commands (fire-and-forget)

    static func playPause()      { dispatch(#"tell application "Music" to playpause"#) }
    static func nextTrack()      { dispatch(#"tell application "Music" to next track"#) }
    static func previousTrack()  { dispatch(#"tell application "Music" to previous track"#) }
    static func seek(to seconds: TimeInterval) {
        dispatch(#"tell application "Music" to set player position to "# + "\(seconds)")
    }

    private static func dispatch(_ source: String) {
        queue.async { _ = runSync(source) }
    }

    private static func runSync(_ source: String) -> NSAppleEventDescriptor? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if error != nil { return nil }
        return result
    }
}
