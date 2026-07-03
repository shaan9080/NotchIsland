# NotchIsland

A macOS overlay app that turns the MacBook Pro notch into a Dynamic-Island-style status surface similar to what you will find on iPhone, but with macOS workflow features. It sits above every window (including full-screen apps), stays hidden behind the physical notch when idle, and expands into Music controls, a Pomodoro timer, and a slideover with sticky notes plus Apple Reminders.

## Features

- **Idle** — a black pill matched to the physical notch geometry so it disappears behind the hardware cutout.
- **Music (Now Playing)** — reads Music.app via AppleScript. The compact pill shows album art on the left of the notch and an animated waveform on the right. Hover to spring into an expanded card with title, artist, album, a scrub bar that extrapolates smoothly between polls, and prev / play-pause / next controls.
- **Pomodoro** — 25/5 auto-looping timer started from the menu-bar item. Expanded view shows a progress ring, a large MM:SS countdown, and a stop button.
- **Split-pill** — with Music playing and Pomodoro running, the primary pill stays anchored to the notch and a secondary detached pill appears to the right with the timer countdown.
- **Slideover** — a third pill to the left of the primary. Tap to expand it downward into a card with two tabs:
  - **Notes** — a scratch pad persisted via `@AppStorage`.
  - **Reminders** — live-linked to Apple Reminders via EventKit. Overdue items show in red. Completing a row syncs to the system Reminders app immediately.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+ with Swift 5+
- Apple Music.app (for the music integration)
- Signed into iCloud with Reminders enabled (for the reminders integration)

## Setup

The Xcode template ships with settings that block Apple Events. You need to relax two of them before AppleScript can talk to Music, and add two Privacy strings before macOS will prompt for permission.

### 1. Disable App Sandbox and Hardened Runtime

In the target's **Signing & Capabilities** tab:

- Remove the **App Sandbox** capability if present.
- Remove **Hardened Runtime** if present.

Or in **Build Settings** (apply to both Debug and Release):

- `ENABLE_APP_SANDBOX` → `No`
- `ENABLE_HARDENED_RUNTIME` → `No`

Both are required — Hardened Runtime blocks Apple Events silently even with sandbox off.

### 2. Add Info.plist usage descriptions

Add via **Build Settings** → **+** (both Debug and Release):

| Build Setting Key | Value |
|---|---|
| `INFOPLIST_KEY_NSAppleEventsUsageDescription` | `NotchIsland reads Now Playing from the Music app.` |
| `INFOPLIST_KEY_NSRemindersFullAccessUsageDescription` | `NotchIsland shows your reminders next to the notch.` |

Without these keys, the TCC prompt never fires and the corresponding integration silently returns nothing.

### 3. Grant permissions on first run

macOS will prompt twice:

- **Automation → Music** on first AppleScript call.
- **Reminders access** on first open of the Reminders tab in the slideover.

Approve both. If a prompt was dismissed or denied and you need to redo it:

```bash
tccutil reset AppleEvents Harshaan-Rehal.NotchIsland
tccutil reset Reminders Harshaan-Rehal.NotchIsland
```

## Running

- **Build & Run** in Xcode (`⌘R`). No Dock icon appears — the app runs as an accessory.
- The notch stays idle until Music plays or you start the Pomodoro from the menu bar.
- **Menu bar item** (notched-rectangle icon): **Start / Stop Pomodoro**, **Quit NotchIsland**.

## Architecture

Everything lives in `NotchIsland/`:

```
App entry
  NotchIslandApp.swift          @main + NSApplicationDelegateAdaptor
  AppDelegate.swift             Activation policy, menu-bar item

Panel + positioning
  NotchPanel.swift              Borderless NSPanel, key-window gated
  NotchWindowController.swift   Screen detection, positioning, DI

State machine
  NotchViewModel.swift          viewState { idle, compact, expanded, split }
  NotchIslandView.swift         ZStack of primary + optional side pills

Music
  MusicSnapshot.swift           Sendable value type
  MusicAppleScript.swift        Serial-queue AppleScript bridge
  MusicController.swift         Polling + distributed-notification driver
  MusicViews.swift              Artwork, waveform, compact + expanded card

Pomodoro
  PomodoroState.swift           Value type
  PomodoroController.swift      25/5 auto-loop
  PomodoroViews.swift           Compact + expanded (progress ring)

Slideover
  RemindersController.swift     EventKit wrapper
  SlideoverViews.swift          Tab bar + StickyNotes + RemindersList
```

## How it works

### Panel positioning

`NotchWindowController` picks the primary display (screen with origin `(0, 0)`), reads notch geometry from `screen.safeAreaInsets.top` plus `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`, and centers a fixed `880 × 340` panel at the top of the screen. Falls back to a hardcoded 16" MBP cutout (`200 × 32`) if the OS reports no insets. Repositions on `NSApplication.didChangeScreenParametersNotification`.

The panel is `.borderless + .nonactivatingPanel`, level `.statusBar`, `collectionBehavior: [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]` — so it floats above full-screen apps and follows the user between Spaces without ever activating the app.

### State machine

`NotchViewModel.viewState` is derived purely from inputs:

- `isHovering || isPinnedOpen` → `.expanded`
- `hasMusicActivity && hasPomodoroActivity` → `.split`
- either one alone → `.compact`
- neither → `.idle`

`hasMusicActivity` and `hasPomodoroActivity` are computed from `musicSnapshot != nil` and `pomodoroState != nil`. `didSet` only calls `recompute()` on nil / non-nil flips, so per-second position ticks and timer updates don't churn the state machine.

### Layout

`NotchIslandView` uses a `ZStack(alignment: .top)`. Primary is always centered on the panel — meaning centered on the notch. The left slideover pill and the right pomodoro pill use absolute `offset(x:)` derived from the current primary width, so they auto-shift outward when the primary expands and inward when it collapses.

### Music integration

`MusicAppleScript` is `nonisolated` and runs every script on a serial `DispatchQueue`. That keeps the first-launch TCC prompt (which can block for many seconds) off the SwiftUI main thread. The snapshot script returns a `\u{1E}`-separated string; the artwork script returns raw bytes decoded into `NSImage` in the view.

`MusicController` refreshes on both a 1 Hz timer (for the scrub bar) and the `com.apple.Music.playerInfo` distributed notification (for instant reactions to play/pause/track changes).

### Slideover keyboard focus

The panel's `canBecomeKey` is gated on a `keyboardEnabled` flag. `NotchWindowController` toggles it in a Combine sink on `viewModel.$isSlideoverOpen`: on when the slideover opens (TextEditor accepts input), off the instant it closes (panel resigns key and focus returns to whatever the user was typing in elsewhere).

## Known limits

- The `880 × 340` panel consumes hit-tests over its transparent area, blocking menu-bar clicks in the central strip. Fix would be a custom `NSView.hitTest` that only claims the shape paths.
- Scrub bar is display-only. Interactive scrubbing needs a `DragGesture` calling `MusicController.seek(to:)`. This has been left out due to increased consumption of CPU, GPU and battery.
- Legacy PICT artwork returned by some tracks won't decode — falls back to the music-note icon.
- Pomodoro auto-loops. No configurable durations, no chime on phase transitions. TO BE ADDED.
- Not sandboxed. Ships as-is for local use only; App Store distribution would require re-adding the sandbox with a temporary-exception `apple-events` entitlement and a real `.entitlements` file.
