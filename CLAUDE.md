# CLAUDE.md — Riftbound Companiokay

> Guidance for future Claude Code sessions working on this codebase.

## Project Overview

**Riftbound Companiokay** (display name "Riftcount: Score Tracker") is a companion app for the Riftbound trading card game — **iOS and Android from one repo** since 2026-07-03:

- **iOS** (shipped on the App Store, v3.0): SwiftUI app in `Riftbound Companiokay/`, built via `Riftbound Companiokay.xcodeproj`. Zero external package dependencies.
- **Android** (v3.0.0, pre-Play-Store): [Skip](https://skip.dev) native Fuse app in `android/` (module `Riftcount`, appid `pitopia.Riftcount`). Compiled Swift + SkipUI→Compose bridging. Deps: skip, skip-fuse-ui, skip-keychain.

**iOS-first policy: the shipped iOS app must never regress for the sake of Android.** Feature requests target BOTH platforms by default (iOS first, then Android port with full design parity) unless the user scopes to one platform. See memory `dual-platform-workflow.md`.

### Feature set (both platforms, full parity)

- **Scoreboard tab**: 2p/4p tiles (conquer/hold/minus), sliding score↔XP faces, per-slot colors, game timer, deck pill + opponent, Won/Lost game records, undo (50 steps), tournament match strip (match mode).
- **Events tab**: Riftbound Locator integration (login via Keychain-stored token, my events, event detail with pairings/standings/register/drop/report result, Can-I-Draw top-cut math), store finder (search, favorites, calendar), eloshowdown player profile (ELO, rank crests, Summoner's DNA radar, match history, percentile), opponent scouting + H2H. Elo requests go through a TTL cache (`EloCache`).
- **Dice tab**: D6/D8/D12/D20. Shake-to-roll (iOS only).
- **Cards tab**: riftcodex card DB, search/sort/filters, card detail, add to deck.
- **Decks tab**: 7-step builder wizard, deck detail editing, import/export as text, draw hand, draw odds (hypergeometric), deck stats, game history + review.
- **Settings**: battery saver, haptics, match mode, tours replay, acknowledgments, about.
- **Onboarding**: 6-page main tour, Events tour, builder tip overlay.
- iOS-only: Live Activity (lock screen scoreboard), shake-to-roll, keep-screen-on, widgets. Android-only: Photon geocoder (replaces CLGeocoder).

Detailed feature/spec history lives in memory `session_state.md`; Android port specifics + SkipUI gotcha catalog in memory `android-port.md`.

## Repo layout

| Path | What |
|------|------|
| `Riftbound Companiokay/` | iOS app sources (synced folder groups — new files on disk auto-join the target) |
| `Riftbound Companiokay/User/Events/` | Locator + eloshowdown integration |
| `Riftbound Companiokay/User/DeckBuilder/`, `User/Onboarding/`, `Cards/` | feature folders |
| `RiftboundWidgets/` | iOS widget extension (Live Activity) |
| `android/` | entire Skip Android project (own Package.swift, `Sources/Riftcount/`, `Android/` gradle shell) |
| `android/Sources/Riftcount/` | Android Swift sources (flat + `Events/`) |

## Build & run

- **iOS: the user builds in Xcode themselves — do NOT run xcodebuild.**
- **Android**: from `android/`: `skip android build` (compile gate), `skip app launch --android` (build+install+launch on booted emulator; boot via `emulator -avd SkipSpike`). Deploy to emulator, the USER verifies — no screenshot verification.
- Android release packaging currently broken (see memory `android-port.md`); debug APK path works.

## Coding Conventions (iOS)

- **SwiftUI MVVM**: Views are structs; stores/VMs are `@MainActor ObservableObject` at app root via `.environmentObject`. Project uses Swift 6.2 default-MainActor — `Decodable+Sendable` models need `nonisolated`.
- **Persistence**: `@AppStorage`/`UserDefaults` + JSON files (decklists, game records) + Keychain (Locator token only). No Core Data/SwiftData.
- **No external dependencies** on the iOS target. Do not add SPM packages without explicit user approval.
- **Combine imports**: `internal import Combine` (bare `import Combine` breaks the build).
- **Haptics**: always through `Haptics.*` helpers.
- **No `print()`**: use `os.Logger`.
- **File size**: target 200–400 lines, max ~800.
- SourceKit cross-file "Cannot find type" diagnostics are false positives from synced folders — ignore; only real compile errors matter.

## Coding Conventions (Android / Skip)

- Same names/structure as iOS where possible, but files are independent ports — **fixing one platform does not auto-fix the other**.
- `@Observable @MainActor` stores + `.environment`/`@Environment(T.self)`.
- No `private` on `@State`/`@AppStorage`/View structs (bridging).
- URLSession needs `#if canImport(FoundationNetworking) import FoundationNetworking`.
- Consult the **SkipUI gotcha catalog in memory `android-port.md` before writing Android UI** (menu-Picker crashes, ignoresSafeArea paint-over, LazyVGrid limits, symbol map, park-commit animation buffer, etc.). Unmapped SF Symbols → drawn Shapes or bundled symbolset SVGs (full Apple template required).

## Working Style — IMPORTANT

> **Implement features one at a time, in small focused tasks. The user reviews every change before approving the next step. Avoid large multi-file rewrites in a single pass.**

1. Re-read this CLAUDE.md and the specific files you intend to touch.
2. Propose a short plan, wait for go.
3. Smallest possible change → deploy/build → user verifies → next.
4. Commit only when the user asks. Caveman mode (terse replies) is the default register; code/commits written normally.
