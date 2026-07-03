//
//  MusicViews.swift
//  NotchIsland
//
//  Compact + Expanded music UI plus a small animated waveform and an
//  artwork cache. The compact layout pushes content to the visible
//  edges of the notch; the expanded layout drops a card down below
//  the notch with artwork, scrub bar, and transport controls.
//

import SwiftUI

// MARK: - Artwork (memoized Data → NSImage)

struct ArtworkView: View {
    let data: Data?
    var cornerRadius: CGFloat = 6

    @State private var image: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.08))
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: data) {
            image = data.flatMap { NSImage(data: $0) }
        }
    }
}

// MARK: - Waveform

struct WaveformView: View {
    let isActive: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08, paused: !isActive)) { timeline in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<3, id: \.self) { idx in
                    Capsule()
                        .fill(.white)
                        .frame(width: 2, height: barHeight(for: idx, at: timeline.date))
                }
            }
            .frame(height: 14, alignment: .center)
        }
        .opacity(isActive ? 1.0 : 0.45)
    }

    private func barHeight(for index: Int, at date: Date) -> CGFloat {
        guard isActive else { return 4 }
        let phase = date.timeIntervalSince1970 * 5 + Double(index) * 0.95
        return 4 + abs(CGFloat(sin(phase))) * 9
    }
}

// MARK: - Compact

struct CompactMusicView: View {
    let snapshot: MusicSnapshot?
    let notchWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            ArtworkView(data: snapshot?.artworkData, cornerRadius: 5)
                .frame(width: 22, height: 22)
                .padding(.leading, 8)
            Spacer(minLength: notchWidth - 8)
            WaveformView(isActive: snapshot?.isPlaying ?? false)
                .frame(width: 26)
                .padding(.trailing, 12)
        }
    }
}

// MARK: - Expanded

struct ExpandedMusicView: View {
    let snapshot: MusicSnapshot
    let controller: MusicController

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ArtworkView(data: snapshot.artworkData, cornerRadius: 8)
                .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)

                scrubBar
                    .padding(.top, 4)

                transport
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
    }

    private var subtitle: String {
        switch (snapshot.artist.isEmpty, snapshot.album.isEmpty) {
        case (false, false): return "\(snapshot.artist) — \(snapshot.album)"
        case (false, true):  return snapshot.artist
        case (true, false):  return snapshot.album
        case (true, true):   return ""
        }
    }

    private var scrubBar: some View {
        TimelineView(.periodic(from: snapshot.positionSampledAt, by: 0.5)) { timeline in
            let pos = snapshot.currentPosition(at: timeline.date)
            let total = max(snapshot.duration, 1)
            VStack(spacing: 3) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.18))
                        Capsule()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: max(0, geo.size.width * CGFloat(pos / total)))
                    }
                }
                .frame(height: 3)

                HStack {
                    Text(formatTime(pos))
                    Spacer()
                    Text("-" + formatTime(max(0, total - pos)))
                }
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private var transport: some View {
        HStack(spacing: 22) {
            Spacer()
            Button { controller.previousTrack() } label: {
                Image(systemName: "backward.fill")
            }
            Button { controller.playPause() } label: {
                Image(systemName: snapshot.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 18)
            }
            Button { controller.nextTrack() } label: {
                Image(systemName: "forward.fill")
            }
            Spacer()
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.white)
        .buttonStyle(.plain)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Expanded empty state

struct ExpandedEmptyView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "music.note.list")
            Text("Nothing playing")
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.white.opacity(0.6))
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
