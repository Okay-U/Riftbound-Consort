# Riftcount — Takeover Assessment (2026-09-06)

Audit written on taking over development. Facts, architecture, and prioritized tickets for
security, code and design. Everything Riot / PlayRiftbound lives in `PLAYRIFTBOUND.md`.
Nothing here was verified on a device or by building.

## 0. Open items from the audit

| # | Action | Where |
|---|---|---|
| 1 | **Rotate the Locator token** in `.claude/settings.local.json`; add that path to the repo `.gitignore` (today only the global git ignore protects it). | repo root |
| 2 | **Android upload keystore** before any Play upload. `build.gradle.kts:70` falls back to the debug key. | `android/Android/app/` |
| 3 | `allowBackup="false"` or `dataExtractionRules`. | `AndroidManifest.xml:17` |
| 4 | Locator sunset notice, date-gated `>= 2026-09-14`, both platforms. | Events segments |
| 5 | Settings → About still links the old Notion privacy page; the live policy is `okay-u.github.io/privacy.html`. | `Settings.swift` |

## 1. Facts

- **Product.** "Riftcount: Score Tracker", publisher Pitopia, by Okay Ünal. Free, no ads, no IAP,
  no accounts of its own. iOS App Store id 6755601459. Android package `riftcount.module`,
  appId `pitopia.Riftcount`. Version 3.3 (iOS build 1, Android versionCode 8).
- **Identifiers.** Bundle `pitopia.Riftcount`, widget `.RiftboundWidgets`, App Group
  `group.pitopia.Riftcount`, Team `Q24SAC5FD2`. iOS deployment target 18.6, `SWIFT_VERSION = 5.0`
  in pbxproj (language mode; code uses Swift 6.2 default-MainActor). Skip 1.9.4, arm64-only release.
- **Repos.** App `Okay-U/Riftbound-Consort`. Site `Okay-U/okay-u.github.io` at
  `~/Desktop/Xcode/okay-u.github.io` (landing, privacy, terms, `errata.json`, Riot `riot.txt`).
  Support `contact-okaydev@proton.me`, donations `ko-fi.com/okayunal`.
- **Branches.** Deletable (merged): `origin/ConquerHold`, `origin/UVStats`,
  `origin/claude/rifbound-coach-companion-w5zron`, local `android-port`, and the two local
  `claude/*` branches. Unmerged: local `UVStats` (untap.in stats WIP, 2026-05, 818 lines). Decide.
- **No test target exists** on either platform. Old memory claiming otherwise is wrong.

## 2. Architecture

- **iOS** `Riftbound Companiokay/`: 102 files, 17.4k lines, zero dependencies. SwiftUI,
  `@MainActor ObservableObject` stores injected at root. Persistence: `@AppStorage` (20 keys,
  literals repeated across 17 files), JSON in Documents (decklists, `games.json`, card cache,
  errata), Keychain (Locator token). Widget extension for Live Activity.
- **Android** `android/Sources/Riftcount/`: 86 files, 17.1k lines, independent ports. **77% of
  paired lines byte-identical, 95% for pure logic (~3,000 duplicated lines).**
- **Network** (all HTTPS, no ATS exceptions, no analytics SDKs): carde.io Locator API (dies
  Sept 14), eloshowdown (public, decays), riftcodex cards (replace if Riot key arrives),
  `okay-u.github.io/errata.json`, Photon geocoder (Android), CLGeocoder (iOS), and now
  PlayRiftbound via the in-app browser.

## 3. Security and privacy findings

No CRITICAL. Clean fundamentals: no `print`, no `try!`, no cleartext, Keychain
`AfterFirstUnlockThisDeviceOnly` without iCloud sync, password never persisted or logged, token
deleted on sign-out/401/expiry, no location permission, privacy manifest accurate.

| Sev | Finding | Fix |
|---|---|---|
| HIGH | Live Locator token in `.claude/settings.local.json`, protected only by the global git ignore. | Rotate; repo `.gitignore`. |
| HIGH | Release signing falls back to the debug keystore (`build.gradle.kts:70-76`). | Upload key; fail the build instead. |
| MED | `allowBackup="true"`, no extraction rules. | `false` or rules. |
| MED | Opponent name + id logged `privacy: .public` (`OpponentEloBadge.swift:175`). | `.private`. |
| MED | Deck import count unbounded → allocation (`DeckTextFormat.swift:126,174`, both platforms). | Cap at 99. |
| MED | Android deps unpinned, `Package.resolved` gitignored, no gradle wrapper checksum. | `.upToNextMinor`, commit resolved, `distributionSha256Sum`. |
| MED | Privacy policy: player *names* go to eloshowdown search; manifest lacks `FileTimestamp` reason (`Errata.swift:114`). | One sentence; add reason. |
| LOW | Any URL scheme reaches `Link`/openURL from store website, errata `source`, card image URLs. | Allowlist http/https. |
| LOW | Keychain write OSStatus ignored; reveal-password field lacks `.autocorrectionDisabled()`; mailto builders use `.urlQueryAllowed`; card cache in Documents not Caches. | Small fixes. |

Bug reports contain only what the user typed (`DeviceDiagnostics.summary` is unused). Keep it so.

## 4. Code quality tickets

| # | Ticket | Value |
|---|---|---|
| 1 | Local Swift package `RiftcountCore` for the 14 pure-logic files (`Card`, `Decklist`, `GameRecord`, `LocatorModels`, `EloModels`, `DrawCalc`, `DeckTextFormat`, `DeckLegality`, `CardClassifier`, `CardFilters`, `LocatorAPI`, `EloShowdownAPI`, `EloCache`, `LocatorCache`), path-dependency from both targets. Divergence is mechanical (`public`, `FoundationNetworking` shim, `nonisolated` vs `@unchecked Sendable`). | Deletes ~3,000 lines, ends silent drift. |
| 2 | Shipped parity bug: `DeckTextFormat` paren stripping differs (iOS regex vs Android `stripParens`). | Reconcile + round-trip test. |
| 3 | Add test targets; seed with `DrawCalc`, `DeckTextFormat`, `DeckLegality`, `CardClassifier`, decode fixtures. | 0% → something. |
| 4 | `User/Events/EventDetailView.swift` 1,652 lines, 25 `@State`. Extract view model + split MARK sections. Decide Events' future first. | Worst liability. |
| 5 | 43 iOS / 44 Android `try? await` swallow network errors (worst `EventDetailView` 9, `OpponentEloBadge` 7, `ProfileView` 5). | Surface + retry. |
| 6 | Silent data loss: `GameRecordStore.swift:68`, `DecklistStore.swift:154` log save failures only. | `@Published saveError` + alert. |
| 7 | `ProfileView.swift` 795/852 lines. | Extract chart + match pager. |
| 8 | Hypergeometric math on a View (`DrawProbabilityView.swift:178-201`). | Move to core. |
| 9 | 20 `@AppStorage` key literals across 17 files. | `AppStorageKeys` enum. |
| 10 | 22 `URL(string:)!` literals; 5 singletons (`GameActivityController.shared` blocks tests). | Opportunistic. |

Order: 1 → 3 → 2, then 4–6.

## 5. Design tickets

Dark-only, forced. Four colour systems, none authoritative; Events ("Arena", green, custom nav)
reads as a different app from the system-nav tabs. ~157 raw colour sites outside token files,
299 fixed font sizes (no Dynamic Type), 68 radius literals, 19 sheets without detents, 16
hand-rolled empty states, 5 `accessibilityLabel`s, no `reduceMotion`, no iOS 26 glass idioms.

| # | Ticket |
|---|---|
| 1 | `Assets.xcassets/AccentColor.colorset` defines no colour → 10 sites render stock blue. Fill with the Events green. |
| 2 | 6 tabs → iOS "More" buries Dice and Settings. Consolidate to 5 (Settings → toolbar gear, or Dice into Scoreboard). |
| 3 | `trueBlack` (`Riftbound_CompaniokayApp.swift:13,38`, `ScoreboardView.swift:18,42`) has no toggle and both branches paint black. Delete. |
| 4 | `DiceView.swift:90` `.navigationTitle` without a `NavigationStack`; `:57` fakes a title. |
| 5 | Score text hardcoded `.primary` on light tile colours (~1.6:1); `isDarkTileColor` exists at `ScoreTile.swift:189` but only drives icons. Same on Android `ScoreTile.swift:73`. |
| 6 | VoiceOver cannot score: `ScoreTile.swift:408` collapses the tile, no `accessibilityAction`s. Label the 3 unlabeled icon buttons. |
| 7 | Promote `EventsTheme` → app-wide `Theme` with radius/space scales; port Android `cardSurface()` to iOS; replace the 3 copy-pasted card gradients. |
| 8 | Replace the 16 hand-rolled empty states with `ContentUnavailableView`. |
| 9 | Win/loss colour-only (`DecksOverviewView.swift:254`). |
| 10 | Respect `accessibilityReduceMotion` on the LiveBadge pulse, tile flip, dice roll. |

Android parity risks: `Color.accentColor` resolves to Material default on Compose (15 sites in
`CardsScreen.swift`); Decks rows hardcode `Color.black`; Dice re-inlines the gradient.

## 6. Open questions for Okay

1. Was Android 3.3.0 (versionCode 8) uploaded to Play; is the listing live?
2. Is the `UVStats` branch worth anything?
3. Does eloshowdown plan to ingest PlayRiftbound data? One message to the dev Okay knows.
4. Which Locator pieces stay visible after Sept 14 (profile? store finder?) versus hide.
