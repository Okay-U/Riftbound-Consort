# Riftcount Android · native rewrite plan

Native Kotlin + Jetpack Compose app in `android-native/`. It replaces the frozen Skip app in `android/`
as an update of the same Play listing. Decided 2026-10-21, plan approved 2026-10-22.

- **Functional spec:** the iOS app (`Riftbound Companiokay/`). Everything iOS does must exist, except the
  Locator/eloshowdown "Old" segment (dies in November), widgets and Live Activity (no lock-screen score
  either, Okay 2026-10-22).
- **Design spec:** the chosen mocks on the design canvas
  (https://claude.ai/artifact/ARcSMfQqecAVKCB4ETYz9A, page "Chosen · all tabs"): `ScoreFinal`,
  `EventsMix`, `CardsFinal`, `DecksMix`, `SettingsHybrid`. Where a mock and iOS disagree, the mock wins
  on look and flow, iOS wins on rules and data.
- **Identity:** true black, green `#2BE38B` for you, violet `#A99BFF` for the opponent, gold `#FFC75E`
  for bubble/cut/today, red `#FF6B61` for danger. Big Shoulders Display numerals, Barlow text.
  Motion is transform/opacity only, exponential ease-out `cubic-bezier(.16,1,.3,1)`, no endless loops
  (spinners only while loading).

## Navigation

Bottom bar: **Score · Events · Cards · Decks · Settings** (floating pill, green knob glides to the tab).
No Dice tab (dice live in the scoreboard seam), no header gears. The bar stays visible on Score too; both
score halves end above it. System back on any tab other than Score returns to Score.

## Build setup

| Item | Value |
|---|---|
| applicationId | `pitopia.Riftcount` (same as the Skip app, so it installs as an update) |
| Debug build | suffix `.native`, label "Riftcount native": runs next to the old app on the emulator |
| Staging build | release code (R8) with the debug key and the same `.native` suffix: judge speed on the emulator |
| namespace | `pitopia.riftcount` |
| versionCode / versionName | 10 / 3.5.0 (Skip app shipped 9 / 3.4.0) |
| minSdk / target / compile | 28 / 36 / 36 (same min as the Skip app) |
| AGP / Kotlin / JVM | 9.2.0 (built-in Kotlin) / 2.3.0 + compose plugin / 17 |
| Compose | BOM 2026.05.01 |
| Gradle | 9.6.1 (wrapper committed) |
| Release signing | `app/keystore.properties` (keys `keyAlias`, `keyPassword`, `storeFile`, `storePassword`, as in the Skip app) + upload key, both gitignored, Okay only; without it the release APK stays unsigned |

Dependencies: AndroidX/Jetpack and official Kotlin libraries (activity-compose, Compose,
kotlinx-serialization, coroutines). A further library only where an animation needs it, and then it is
reported to Okay. Card images load through a small own loader.

Commands (from `android-native/`): `gradle :app:assembleDebug` (or `assembleStaging`),
`gradle :app:testDebugUnitTest`, `adb install -r app/build/outputs/apk/debug/app-debug.apk`.
Phase 0 numbers: release APK 2.1 MB (the Skip app's bundle was 55.9 MB), cold start 180 ms (staging).

## Storage: keep the Skip app's files, so the update keeps every deck and game

The Skip app writes `shared_prefs/defaults.xml` and JSON files in `files/Documents/`. The native app
reads and writes **the same files with the same keys and formats**. No conversion step is needed; the
first launch simply finds the old data.

Preferences (`getSharedPreferences("defaults")`, written only on change, missing key = default):
`playerCount` Int 2, `colorIdx_0`…`colorIdx_3` Int -1, `activeDeckId` String, `activeOpponent` String,
`activeStartedFirst` "first"/"second"/"", `hapticsEnabled` true, `diceShakeToRoll` true, `diceType` 6,
`matchModeEnabled` true, `keepScreenOn` true, `trueBlack` true, `soundsEnabled` false,
`didOnboard`, `didOnboardEvents`, `didSeeBuilderTip`, `didDismissNewEventsIntro`, `cardsFeedETag`,
`riftSearchPlace`, `riftSearchKm` 50. Doubles (`riftSearchLat/Lng`) follow Skip's encoding: `putLong`
of the IEEE bits plus int `__unrepresentable__:<key>` = 1. New Android-only keys get a `native.` prefix.
Ignore `hapticTick.*`, `currentTab` (iOS uses `user` for Decks), `favoriteStoresJSON`, `didDismissLocatorSunset`.

Files in `filesDir/Documents/` (compact JSON, unsorted keys, nil fields omitted, UUIDs uppercase,
`Date` = Double seconds since 2001-01-01Z, i.e. epoch = v + 978307200):

- `decklists_v2.json` `[Decklist]` `{id, name, createdAt, updatedAt, champion?, legend?, battlefields,
  mainDeck, sideDeck, runes}`, entries `{card_id, card_name, count}`
- `games.json` `[GameRecord]` newest first `{id, date, deck_id?, deck_name?, opponent, result:
  "won"|"lost", duration_seconds, events?, started_first?}`, events `{id, elapsed_seconds, slot, type:
  "conquer"|"hold"|"manual", delta}`
- `cards_cache_v2.json` bare `[Card]` (riftcodex schema, snake_case), `errata_v1.json`
- `playriftbound_log.json` (last 150 entries)
- An undecodable decks/games file is copied aside once as `<name>.unreadable-<epoch>.json` and never
  overwritten with an empty list.

## Phases

Each phase ends with: unit tests green, debug build installed on the emulator, every screen driven via
adb and compared against its mock (screenshots), commit on `main`. Okay reviews every page afterwards.

### 0 · Foundation
Gradle project, tokens (colours, type, easing), app icon from the Skip app, edge-to-edge true black,
five-tab shell with the bar and placeholder screens, back-to-Score. Fonts bundled: Big Shoulders Display + Barlow
(OFL, from github.com/google/fonts, approved 2026-10-22), licence credited in Acknowledgments.

### 1 · Scoreboard (`ScoreFinal`) · done 2026-10-22
Built as mocked: opponent half rotated on top, territory fields and glowing line (26 dp per point of
difference, sweeps to the loser on a win or after the duel), blur-morph numbers with the colour drop,
Conquer/Hold/Effect +1 and Fix −1, the 8th point by conquering asks first, win at 8 → "Game n" + next game,
best of three with series pips, XP ± on both halves, undo (50 steps incl. XP), restart with confirm,
match summary with one chip per game on the light rail. Seam: dice duel (D20/D6, tap a half / Roll both /
shake, ties reroll, the winner picks first or second, banner, "GOES FIRST" badge, `activeStartedFirst`),
match clock. Decisions made while building, for Okay's review:
- The match clock runs over the whole best of three (iOS: Won/Lost never reset it); it starts on the first
  point or "Start the game", a tap pauses it, a new match resets it. The restart text says so.
- "End" in the seam opens the mock's result picker ("End the match") for concessions and games nobody kept
  score of; the conceded game is written to `games.json` like iOS Won/Lost. In match mode it becomes Report.
- The status bar is hidden on Score (full screen like the mock, swipe to show); dialogs are real windows
  above the tab bar.
- 4 players (no mock): 2×2 table, far row turned, each corner tinted in its colour, actions as 2×2, no
  target, a 4-way roll for who starts.
- State (scores, series, clock) is saved on every change (`native.scoreboard` in `defaults.xml`).
Open for later phases: deck and opponent pick (phase 3, needs decks and legends), player colour picker
(phase 4), match strip and Report (phase 5).
Tests: `ScoreRulesTest`, `DuelTest`, `ResultPickerTest`, `GamesTest` (Swift `games.json` round trip).

### 2 · Cards (`CardsFinal`)
Feed `https://okay-u.github.io/cards.json` with ETag, snapshot first then refresh, 6 h / 15 min refresh,
reject feeds below max(500, old/2), dedupe. Grid with search, sort (set/energy/type), filters (domains,
types, energy/power/might caps 12/12/14), card grows into the detail (rules text with Riot glyphs, errata
stamp from `errata.json`), add to deck. Image loader with memory + disk cache. iOS sources: `Cards/*`.
Tests: filters, sort order, text parser (`:rb_…:` and bracket codes), feed acceptance, errata matching.

### 3 · Decks (`DecksMix`)
Playmat piles overview with the opening animation, all-decks win-rate tile and match-log tile that
expand into the log (filters, review race to 8, edit game), open deck = detail (tools, champion, fields,
Main/Side/Runes steppers, hand fan with mulligan, draw odds, stats, export), 7-step builder rail, import
from text. Legality, copy limit 3, signature limit 3, legend domains, runes split, text format import and
export exactly as `DeckTextFormat`. iOS sources: `User/*Deck*`, `User/DeckBuilder/*`, `Cards/Deck*`,
`User/Game*`. Tests: legality, builder rules, import/export round trip, hypergeometric odds, stats, log.

### 4 · Settings + onboarding (`SettingsHybrid`)
Flip tiles (Haptics, Keep screen on, True black, Match mode, Sounds, Players), Scoreboard section
(player colours, shake to roll), Help
(tours, rules links), About (acknowledgments, PlayRiftbound log, bug report and wish by mail, share,
rate, Ko-fi, privacy). Six-page main tour, Events tour, builder tip.

### 5 · Events (`EventsMix`)
Section tabs Events · Stores · PlayRiftbound. PlayRiftbound = domain-locked WebView with the iOS policy
(hosts, iframe hosts, external links, social sign-in blocked, sign out clears site data). Session from the
WebView cookies (`__Secure-access_token`, expiry, identity from `__Secure-id_hint`), silent renewal,
GraphQL persisted queries with the iOS op ids + remote override, headers and error mapping as iOS.
Native: my events (live card, upcoming, past), event page with five tabs (Matches with Report, Rounds,
Standings with live preview and Can I draw, Roster, Info with register/cancel/drop), search page,
Stores pane (week rail, favourite cards, finder with radius rail, store sheet, month sheet), scoreboard
match strip. Standings and DrawCalc ported 1:1 and checked against the three public events in
`tools/check-standings`. Live data needs Okay's Riot sign-in, so the agent verifies with recorded and
fake data; Okay does the live test.

### 6 · Upgrade path + release prep
Install the old Skip release over a fresh emulator, create decks/games/settings, install the native
build with the same id and key, confirm everything is there. Release build (R8), arm64 + x86_64 for the
emulator, `keystore.properties` signing like the Skip app. Okay signs and uploads.

## Open points
- 4-player scoreboard has no mock; derived in phase 1, Okay judges it.
- The mocks end a game automatically at 8 (with the conquer check); iOS has manual Won/Lost. The build
  follows the mock and also keeps a manual end via Restart/Report.
