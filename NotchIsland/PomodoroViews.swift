//
//  PomodoroViews.swift
//  NotchIsland
//
//  Pomodoro UI for compact and expanded states. The secondary split-pill
//  view is built inline in NotchIslandView since it shares the IslandShape.
//

import SwiftUI

struct CompactPomodoroView: View {
    let state: PomodoroState
    let notchWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: state.phase.iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.leading, 12)
            Spacer(minLength: notchWidth - 10)
            Text(state.displayTime)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.trailing, 12)
        }
    }
}

struct ExpandedPomodoroView: View {
    let state: PomodoroState
    let controller: PomodoroController

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            progressRing
                .frame(width: 70, height: 70)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.phase.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                Text(state.displayTime)
                    .font(.system(size: 26, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 0)

            Button { controller.stop() } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 4)
            Circle()
                .trim(from: 0, to: CGFloat(state.progress))
                .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: state.progress)
            Image(systemName: state.phase.iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}
