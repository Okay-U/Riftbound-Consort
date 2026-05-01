# CLAUDE.md — Riftbound Companiokay

> Guidance for future Claude Code sessions working on this codebase.

## Project Overview

**Riftbound Companiokay** (display name "Riftcount: Score Tracker") is an iOS SwiftUI app for tracking scores during the Riftbound trading card game. Fully working and shipped at version 1.1. Single-target Xcode project written entirely in Swift/SwiftUI with **no external package dependencies**.

### Current feature set

- **Scoreboard tab**: 2-player or 4-player layout with large tap targets. Each `ScoreTile` has a top half (+) and bottom half (−). Tile flashes green/red on press, runs particle effects when one point away from victory, and triggers gold confetti + ring burst on win.
- **Dice tab**: D6 roller with shake-to-roll support and a Roll button.
- **Settings tab**: Toggles (battery saver, haptics, shake-to-roll), navigation links to Bug Report / Feature Request / Roadmap / Donation views, version info.
- **Persistence**: Pure `@AppStorage` / `UserDefaults` — no database, no network, no Keychain.
- **Quick settings sheet**: Pick winning score (8–12).
- **Color settings sheet**: Per-slot tile color from a 15-color palette.
- **Polish**: Win confetti, edge-flash on press, idle timer disabled (screen stays on), shake gesture detection, dark mode default with optional true-black background.

---

## File-by-File Architecture Summary

All Swift files live in `Riftbound Companiokay/Riftbound Companiokay/`.

| File | Role |
|------|------|
| `Riftbound_CompaniokayApp.swift` | `@main` entry point. Hosts `RootTabView` with three tabs (`score`, `dice`, `settings`). Owns `IdleTimerManager` and `ScoreboardViewModel` as `@StateObject`s and injects them via `.environmentObject`. |
| `Models.swift` | `Player` struct: `Identifiable`, `Hashable`, `id: UUID`, `name`, `score`. |
| `ScoreboardViewModel.swift` | `final class ObservableObject`. Owns `@Published var players`, `@AppStorage` for `playerCount` (2 or 4) and per-slot color indexes (`colorIdx_0`..`colorIdx_3`). Maintains a 50-step undo `history`. Methods: `increment`, `decrement`, `resetScores`, `undo`, `colorIndex(for:)`, `setColorIndex(_:for:)`, `applyPlayerCount(_:)`. |
| `ScoreboardView.swift` | Main scoreboard. Uses `GeometryReader` to compute tile heights. 2-player = vertical stack with rotation 180/0. 4-player = `LazyVGrid` 2×2 with top row rotated 180. Header has Reset, footer has Undo, Color sheet, Quick settings, and player-count `Picker`. |
| `ScoreTile.swift` | Visual tile. `VStack` of two `Button`s (plus on top, minus on bottom) clipped to a `RoundedRectangle`. Uses `PressDimButtonStyle` (defined in this file). Contains private subviews: `EdgeFlashOutside`, `WinBurstOutside`, `OutsideRingMask`, `ParticleOverlay`, `SparkView`, `WinConfettiOverlay`. |
| `DiceView.swift` | D6 dice roller. Local `@State` for `value`, `isRolling`, `rollScale`. `roll()` schedules ~11–14 hops at 0.05s intervals. Subscribes to `ShakeManager.shared.publisher` for shake-to-roll. |
| `Settings.swift` | Settings `Form` with `@AppStorage` toggles. Includes `Bundle.appVersion`/`appBuild` extension. |
| `ColorSettingsSheet.swift` | Sheet UI for per-slot tile color. Reads/writes via `vm.colorIndex(for:)` and `vm.setColorIndex(_:for:)`. |
| `QuickSettingsSheet.swift` | Sheet UI for winning-score `Picker` (8–12) bound to `@AppStorage("targetScore")`. |
| `Palette.swift` | 15-color named palette + `Color(hex:)` extension. |
| `DimWhenPressed.swift` | `DimWhenPressed` `ButtonStyle` (overlays black at 0.16 opacity when pressed). Currently unused — `ScoreTile` uses its own `PressDimButtonStyle`. |
| `Haptics.swift` | Static `enum Haptics`: `success`, `warning`, `error`, `light`, `medium`, `rigid`, `selection`. All gated on `UserDefaults.standard.bool(forKey: "hapticsEnabled")`. |
| `ShakeCatcherView.swift` | `UIView`/`UIViewRepresentable` pair catching `motionShake`, posts `.deviceDidShake`. `ShakeManager.shared.publisher` exposes a Combine publisher. |
| `IdleTimerManager.swift` | `@MainActor ObservableObject` toggling `UIApplication.shared.isIdleTimerDisabled`. |
| `SupportConfig.swift` | Email config for Bug Report / Feature Request screens. |
| `BugReportView.swift`, `FeatureRequestView.swift`, `RoadmapView.swift` | Static info / mailto views. |

### @AppStorage keys in use

| Key | Type | Default | Owner |
|-----|------|---------|-------|
| `"keepScreenOn"` | Bool | true | App root |
| `"trueBlack"` | Bool | true | App root, ScoreboardView |
| `"batterySaver"` | Bool | false | Settings, ScoreTile |
| `"hapticsEnabled"` | Bool | true | Settings, Haptics |
| `"soundsEnabled"` | Bool | false | Settings, ScoreTile |
| `"diceShakeToRoll"` | Bool | true | Settings, DiceView |
| `"currentTab"` | String | "score" | RootTabView, DiceView |
| `"playerCount"` | Int | 2 | ScoreboardViewModel |
| `"targetScore"` | Int | 8 | ScoreboardView, QuickSettingsSheet, ScoreTile |
| `"colorIdx_0"`..`"colorIdx_3"` | Int | -1 | ScoreboardViewModel |

---

## Coding Conventions

- **SwiftUI MVVM**: Views are structs. Single `ScoreboardViewModel` (`final class : ObservableObject`) lives at app root as `@StateObject`, propagated via `.environmentObject`.
- **Persistence**: Always `@AppStorage` / `UserDefaults`. No Core Data, SwiftData, files, network, or Keychain today. New persistence layers must be introduced deliberately, one feature at a time.
- **No external dependencies**: Pure SwiftUI / UIKit interop. Do not add SPM packages without explicit user approval.
- **Combine imports**: This project requires `internal import Combine` (not bare `import Combine`) in every file that uses Combine or `ObservableObject`. Bare `import Combine` causes "Initializer 'init(wrappedValue:)' is not available" build errors.
- **Concurrency**: Existing code uses `DispatchQueue.main.asyncAfter` and Combine. New async work should prefer Swift structured concurrency (`Task`, `async`/`await`) and `@MainActor` for UI state.
- **Immutability**: Models are structs; favor `let` over `var`. Mutations only on the view model.
- **File size**: Target 200–400 lines, max 800. `ScoreTile.swift` (~500 lines) is the exception due to inline particle subviews.
- **Haptics**: Always go through `Haptics.*` helpers. Never call `UIImpactFeedbackGenerator` directly from views.
- **No `print()`**: Use `os.Logger` for any new logging.
- **Secrets**: If an API key is ever needed, use Keychain or build-time `.xcconfig`, never source.

---

## Working Style — IMPORTANT

> **Implement features one at a time, in small focused tasks. The user reviews every change before approving the next step. Avoid large multi-file rewrites in a single pass.**

When starting work on a new fix or phase:
1. Re-read this CLAUDE.md.
2. Re-read the specific files you intend to touch.
3. Propose a step-by-step plan with file paths and approximate line ranges.
4. Wait for the user's go-ahead.
5. Make the smallest possible change, then stop and ask the user to verify.

---

## Immediate Fixes

### Fix 1 — Better press feedback on `ScoreTile` (`ScoreTile.swift`)

Currently `PressDimButtonStyle` dims only the +/- icon label. Goal: the **entire pressed half** of the tile visibly darkens when held.

- The two `Button` blocks at lines ~115–137 already fill their half via `.frame(maxWidth: .infinity, maxHeight: .infinity)` and `.contentShape(Rectangle())`.
- Solution: introduce a new `ButtonStyle` (e.g. `HalfTilePressStyle`) whose overlay covers the full label frame, not just the icon. Apply `.opacity(configuration.isPressed ? 0.18 : 0)` on a `Color.black` fill.
- The outer `VStack` at line ~138 has `.clipShape(shape)` which keeps the dim inside the rounded corners.
- Replace `.buttonStyle(PressDimButtonStyle())` on both buttons with the new style.

### Fix 2 — Dice improvements (`DiceView.swift`)

1. **Die type selector**: D4, D6, D8, D10, D12, D20 (introduce `DieType` enum with `rawValue` = number of sides).
2. **Tap-on-dice rolls**: Wrap the dice display `ZStack` in a `Button { roll() }` with `.buttonStyle(.plain)` and `.contentShape(Rectangle())`.
3. **Roll range by die type**: Replace `Int.random(in: 1...6)` with `Int.random(in: 1...selectedDie.rawValue)`.
4. Persist selection via `@AppStorage("diceType")`.
5. Reset displayed value to 1 on die change.

---

## Phased Feature Roadmap

### Phase A — Game Timer on Scoreboard

A `MM:SS` stopwatch displayed in the scoreboard header. Start/pause/reset. Persists across tab switches via wall-clock `Date()` math.

**New files**:
- `GameTimer.swift` — `@MainActor final class GameTimer: ObservableObject`. Published: `elapsed: TimeInterval`, `isRunning: Bool`. Methods: `start()`, `pause()`, `reset()`. Uses accumulated-plus-current-segment pattern for correct pause/resume math.
- `TimerBadgeView.swift` — Small SwiftUI view showing `MM:SS` + start/pause/reset controls.

**Modified files**:
- `Riftbound_CompaniokayApp.swift` — inject `GameTimer` as `@StateObject`/`.environmentObject`.
- `ScoreboardView.swift` — embed `TimerBadgeView` in or below the header. Reset Scores button also calls `gameTimer.reset()`.
- `Settings.swift` — optional toggle for auto-start on first score.

### Phase B — Card Database

New "Cards" tab. Requires evaluating two data sources before any code:
- `https://github.com/vikkumar2021/RiftboundCardDatabase` (structured JSON — likely better)
- `https://riftcodex.com` (check for a real API vs. HTML scraping)

**Evaluation criteria**: completeness, structured fields, card images, update frequency, licensing/TOS, stability, size, auth requirements.

After deciding, implement:
- `Card.swift`, `Decklist.swift`, `DecklistEntry.swift` structs (Codable)
- `CardRepository` protocol + `BundledCardRepository` (reads bundled `cards.json`)
- `DecklistStore` persisting to `Documents/decklists.json`
- UI: `CardsTabView`, `CardSearchView`, `CardDetailView` (with `AsyncImage`), `DecklistView`, `DecklistDetailView`
- New tab added to `RootTabView`

**Persistence**: `Codable` + JSON in `FileManager.default.urls(for: .documentDirectory)` — no Core Data / SwiftData.

### Phase C — Game Tracking / Win-Loss History

Log game results; show win-rates per deck. Depends on Phase B for "my deck" picker (can use free-text fallback before B ships).

**Data model**:
- `GameRecord`: `id`, `date`, `myDeckID` (optional), `myDeckName`, `opponent` (free-text), `result: GameResult` (won/lost), `durationSeconds` (from Phase A timer)
- `GameRecordStore` persisting to `Documents/games.json`

**UI**:
- `GameSetupSheet` — pick deck + opponent before game
- `GameEndOverlay` — two large "Won" / "Lost" buttons, shown from scoreboard footer "End game" button or auto-prompted on win score
- `StatsView` — overall win rate, per-deck breakdown, newest-first list of records

---

## Open Decisions Pending

| Decision | Notes |
|----------|-------|
| Phase B data source | Evaluate GitHub JSON vs. riftcodex.com before any networking code |
| Phase B persistence | Recommendation: `Codable` + JSON file; revisit if data grows large |
| Phase C "opponent" shape | Free-text first; migrate to structured legend list once card DB is in |
| Timer auto-start | Offer as a toggle; default = auto-start on first score change |
| Stats tab vs Settings entry | Start Stats under Settings; graduate to its own tab if used heavily |
