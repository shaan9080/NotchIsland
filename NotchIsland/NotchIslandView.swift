//
//  NotchIslandView.swift
//  NotchIsland
//
//  Top-level SwiftUI surface inside the panel. Reads the view-model
//  state and animates between Idle / Compact / Expanded / Split layouts
//  using a single spring. Placeholder content is wired in for each state;
//  Music + Pomodoro views slot in later.
//

import SwiftUI

struct NotchIslandView: View {
    @EnvironmentObject private var viewModel: NotchViewModel
    @EnvironmentObject private var musicController: MusicController
    @EnvironmentObject private var pomodoroController: PomodoroController

    private static let spring: Animation = .spring(response: 0.45, dampingFraction: 0.78)
    private static let secondaryWidth: CGFloat = 78
    private static let secondaryGap: CGFloat = 8
    private static let leftPillGap: CGFloat = 8
    private static let leftPillClosedWidth: CGFloat = 58
    private static let slideoverOpenSize = CGSize(width: 200, height: 280)

    var body: some View {
        // ZStack so the primary stays centered on the notch and the side
        // pills are positioned by absolute offset to either side — an
        // HStack centers the whole assembly, which would shove the
        // primary off the notch center.
        ZStack(alignment: .top) {
            primaryIsland

            if viewModel.viewState != .idle {
                leftPill
                    .offset(x: leftPillOffsetX)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.3, anchor: .trailing)
                            .combined(with: .opacity),
                        removal: .scale(scale: 0.3, anchor: .trailing)
                            .combined(with: .opacity)
                    ))
            }

            if viewModel.viewState == .split {
                secondaryPill
                    .offset(x: secondaryOffsetX)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.3, anchor: .leading)
                            .combined(with: .opacity),
                        removal: .scale(scale: 0.3, anchor: .leading)
                            .combined(with: .opacity)
                    ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(Self.spring, value: viewModel.viewState)
        .animation(Self.spring, value: viewModel.isSlideoverOpen)
    }

    private var secondaryOffsetX: CGFloat {
        primaryWidth / 2 + Self.secondaryGap + Self.secondaryWidth / 2
    }

    private var leftPillSize: CGSize {
        viewModel.isSlideoverOpen
            ? Self.slideoverOpenSize
            : CGSize(width: Self.leftPillClosedWidth, height: viewModel.notchSize.height)
    }

    private var leftPillOffsetX: CGFloat {
        -(primaryWidth / 2 + Self.leftPillGap + leftPillSize.width / 2)
    }

    // MARK: - Primary island

    private var primaryIsland: some View {
        IslandShape()
            .fill(Color.black)
            .frame(width: primaryWidth, height: primaryHeight)
            .overlay(primaryContent)
            .contentShape(IslandShape())
            .onHover { hovering in viewModel.setHovering(hovering) }
            .onTapGesture { viewModel.togglePinned() }
    }

    private var primaryWidth: CGFloat {
        switch viewModel.viewState {
        case .idle:               return viewModel.notchSize.width
        case .compact, .split:    return viewModel.notchSize.width + 100
        case .expanded:           return 420
        }
    }

    private var primaryHeight: CGFloat {
        switch viewModel.viewState {
        case .idle, .compact, .split: return viewModel.notchSize.height
        case .expanded:               return 152
        }
    }

    @ViewBuilder
    private var primaryContent: some View {
        switch viewModel.viewState {
        case .idle:
            EmptyView()
        case .compact, .split:
            compactBody
        case .expanded:
            expandedBody
                .padding(.top, viewModel.notchSize.height + 6)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
        }
    }

    /// In split mode, primary always shows Music; pomodoro lives on the
    /// secondary pill. In plain compact, fall back to pomodoro if there's
    /// no music.
    @ViewBuilder
    private var compactBody: some View {
        if let snapshot = viewModel.musicSnapshot {
            CompactMusicView(snapshot: snapshot, notchWidth: viewModel.notchSize.width)
        } else if let pomodoro = viewModel.pomodoroState {
            CompactPomodoroView(state: pomodoro, notchWidth: viewModel.notchSize.width)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var expandedBody: some View {
        if let snapshot = viewModel.musicSnapshot {
            ExpandedMusicView(snapshot: snapshot, controller: musicController)
        } else if let pomodoro = viewModel.pomodoroState {
            ExpandedPomodoroView(state: pomodoro, controller: pomodoroController)
        } else {
            ExpandedEmptyView()
        }
    }

    // MARK: - Secondary pill (split state)

    private var secondaryPill: some View {
        IslandShape()
            .fill(Color.black)
            .frame(width: Self.secondaryWidth, height: viewModel.notchSize.height)
            .overlay {
                if let state = viewModel.pomodoroState {
                    HStack(spacing: 4) {
                        Image(systemName: state.phase.iconName)
                        Text(state.displayTime).monospacedDigit()
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                }
            }
    }

    // MARK: - Left pill (slideover)

    private var leftPill: some View {
        IslandShape()
            .fill(Color.black)
            .frame(width: leftPillSize.width, height: leftPillSize.height)
            .overlay {
                if viewModel.isSlideoverOpen {
                    SlideoverWindowView()
                        .padding(.top, viewModel.notchSize.height + 8)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .transition(.opacity)
                } else {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .transition(.opacity)
                }
            }
            .contentShape(IslandShape())
            .onTapGesture { viewModel.toggleSlideover() }
    }
}

// MARK: - Shape

private struct IslandShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(
            roundedRect: rect,
            cornerRadius: min(rect.height / 2, 22),
            style: .continuous
        )
    }
}

// MARK: - Placeholder content


