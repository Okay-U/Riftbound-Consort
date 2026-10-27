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
Open for later phases: player colour picker (phase 4), match strip and Report (phase 5). The deck and
opponent pick came with phase 3.
Tests: `ScoreRulesTest`, `DuelTest`, `ResultPickerTest`, `GamesTest` (Swift `games.json` round trip).

### 2 · Cards (`CardsFinal`) · done 2026-10-22
Feed `https://okay-u.github.io/cards.json` with ETag, snapshot first then refresh, 6 h / 15 min refresh,
reject feeds below max(500, old/2), dedupe; `errata.json` once a day. Built as mocked: header with the
count, search with the green focus ring, All + six domain discs, Set · Energy · Type switch, Filter with
its badge, three-column grid whose first 15 tiles rise in on every search/filter change, the tile flies
up and grows into the detail (rules text with Riot's glyphs, keyword chips and italic reminders, stats,
errata box with the printed text struck and the link, flavour, artist and code, tags), "Add to deck" sheet
with a stepper per deck, filter sheet (type/series/rarity chips, energy/power/might two-thumb sliders,
caps 12/12/14 = no limit, live "Show N cards"). Decisions made while building, for Okay's review:
- Riot's real card art in the mock's frame (shade, name, type line with rarity gem, ERRATA and PREVIEW
  stamps) instead of the mock's drawn art; the drawn art is the loading/offline placeholder. The CDN is
  asked for a WebP at tile width (about 20 KB instead of the 780 KB PNG iOS loads). In the detail the frame
  fades off the art, so the whole card shows. Battlefields turn -90° like iOS.
- The domain discs use Riot's rune shapes in the mock's disc style.
- Add to deck follows the builder rules (iOS's sheet had none): legend replaces the legend, a champion
  matching the legend fills the chosen-champion slot first, copy limit 3 per card across printings,
  signature limit 3, battlefields 3 and one each, runes 12, main deck 39; decks outside the legend's
  domains are greyed out with the reason. "New deck with this card" opens the builder (phase 3).
- Type sort is alphabetical like iOS. Grid columns grow with the width (3 on a phone, more in landscape);
  the app rotates without restarting like the Skip app, the landscape layout itself is not designed.
- Search and filters stay while another tab is open; the keyboard closes when the grid scrolls.
Tests: `CardQueryTest`, `CardTextTest`, `ErrataTest`, `DeckRulesTest`, `DecksTest` (Swift `decklists_v2.json`
round trip). Emulator: debug grid scroll 17 ms median, staging 1.3 % janky frames.

### 3 · Decks (`DecksMix`) · done 2026-10-22
Built as mocked: the table of piles (legend on top, record, Legal/Draft/n issues chip) rising in, the
new-deck spot, the all-decks win-rate ring and the last games, both growing into the match log (deck
chips, record, win rate, average game, first/second, games); a game opens its review (race to 8 in two
lanes, point by point) and the edit dialog (result, turn order, deck, opponent, delete). A pile opens into
the deck: the legend card grows into the banner, the champion and the battlefields fly out of the pile,
tools (test hand fan with mulligan, odds, stats, match log), champion swap, battlefield picker,
Main/Side/Runes steppers with the 12 pips, export sheet. The builder is the seven-stop light rail
(legend, champion, three battlefields, main, side, runes, name and save). Decisions, for Okay's review:
- Riot's art everywhere the mock draws cards (piles, banner, champion, battlefields, legend tiles, hand).
- iOS functions the mock has no place for: the pencil in the banner (rename, edit in the builder, delete
  with a second tap) and "Delete game" in the edit dialog; search on the legend, battlefield and card
  pages and Unit/Spell/Gear chips (iOS pool picker); runes start split evenly (iOS).
- The mock's "Fill with a starter list" is left out: it fills the 39 cheapest cards, not a real list.
- Mulligan by the game rule: up to two of the opening four, once, to the bottom (iOS shuffles back).
  Odds take several picked cards (iOS), defaults as the mock (6 cards seen, most copies picked).
- Text import/export = iOS `DeckTextFormat`; the import prefers the plain printing over alternate art,
  overnumbered or signature reprints of the same name and names the deck "Imported · <legend>".
- A champion already in the deck trades places with the chosen one (iOS); another one replaces it.
  Issues add the copy and signature limits, which a pasted list can break. Tokens and token
  battlefields stay out of deck building.
- "New deck with this card" (Cards) opens the builder: a legend starts it, another card joins the main
  deck (or the champion slot) once a legend it fits is picked.
- Scoreboard: a half's name opens the game setup (iOS `GameSetupSheet`): your deck and turn order, or
  the opponent's legend; finished games carry them into the match log.
- Riftcodex ids of Skip 3.4 decks are mapped on every card publish (iOS); a rune printing the feed lacks
  (promo) becomes its domain's rune card, then the old snapshot goes. Checked on the emulator with the
  Skip app's real `cards_cache_v1.json`.
Tests: `DeckTextTest` (export/import round trip, migration), `BuilderTest` (builder rules, edit
round trip, kept unknown cards), `DeckMathTest` (odds, stats, hand), `DeckEditsTest`, `MatchLogTest`.
Emulator: builder pool scroll 0.7 % janky frames (debug).

### 4 · Settings + onboarding (`SettingsHybrid`) · done 2026-10-22
Built as mocked: six flip tiles that turn over to say what they do (Haptics, Keep screen on, True black,
Match mode, Sounds, Players with the blurring 2P/4P number), Scoreboard rows (player colours, shake to
roll), Help (both tours, rules), About (acknowledgments, PlayRiftbound log, bug report, wish, share,
rate, Ko-fi, privacy), the version line; sub pages slide in over the pushed-back list. Decisions, for
Okay's review:
- Every switch acts at once: True black turns the app background #000 / #121212 (600 ms), Keep screen on
  sets the window's keep-on flag (whole app, like iOS; the tile text says so instead of "scoreboard"),
  Haptics ticks when turned on. Sounds are real: soft clicks made in code (no files) for points, dice
  and a won game, through the media volume. Match mode is stored for phase 5.
- Player colours: the mock's preview and palettes, one per seat with 4 players. Taking another seat's
  colour swaps them. 2 and 4 players share the iOS keys, so a seat default steps aside when a saved
  pick already has its colour (no two seats alike).
- Rules: all of iOS `RulesLibrary` (rules, set FAQs, patch notes, errata) in the mock's rows, in the
  browser until the in-app browser comes (phase 5).
- Acknowledgments: Riot and riftboundfaq as iOS, eloshowdown left out (the Locator integration is not
  in this app), the two OFL fonts with their licence texts.
- Bug and wish: the mock's two fields; the mail app opens to contact-okaydev@proton.me with "[Bug]" /
  "[Feature]" subjects (iOS) and the app and Android version under the text.
- PlayRiftbound log: reads the iOS/Skip file, newest first, Copy (iOS export text) and Clear. Debug builds
  only since 2026-10-26 (Settings › Debug); removed before 4.0 (2026-10-27).
- Tours (no mock, built from its parts): six pages with this app's tabs (Events instead of Dice, True
  black instead of Live Activity) on first launch; the Events tour (iOS text) the first time Events
  opens; both from Settings. Back goes a page back, on the first page it closes. The builder tip shows
  the first time the builder opens.
Tests: `PlayRiftboundLogTest` (iOS file, export), `ReflowTest` (licence text), `PickColorTest`,
`SeatColorsTest`, `SoundsTest`.

### 5 · Events (`EventsMix`) · done 2026-10-22
Built as mocked, section tabs Events · Stores · PlayRiftbound:
- Events: find pill, live card (round clock, your pairing, Report / Open event), upcoming, past with
  placement and record. Event page: hero, five tabs (Matches with the current round, its clock and the
  history; Rounds; Standings with the live preview, your standing and Can I draw; Roster; Info with
  register / cancel / drop behind a confirm). Search page: place (Photon geocoding, as the Skip app),
  distance, type, format and player chips, date or distance order, favourite stores only.
- Stores: next two weeks of favourites and yours on a day rail, favourite store cards, store finder with
  the radius rail, store sheet (directions, website, mail and phone leave the app; heart), month sheet.
- PlayRiftbound: the WebView with the iOS policy. Top-level pages only on playriftbound.com,
  riftbound.leagueoflegends.com and Riot's two sign-in hosts over https, frames load as the site needs
  them, web/mail/phone links leave the app, a social sign-in hop from Riot's page is blocked with a
  notice, Sign out clears cookies and web storage. Default WebView profile, so the Skip app's sign-in
  should carry over (checked in phase 6).
- Session and API as iOS: credentials read from the WebView cookies at call time and never stored,
  expiry the sooner of the session expiry and the token's `exp` minus a minute, one silent renewal by an
  off-screen page load (callers fail at once for 20 s after a failed one), persisted queries with the
  built-in ids and the okay-u.github.io feed (one fetch shared by all callers, waited for 10 s at most).
  Every call landed in the PlayRiftbound log until it was removed before 4.0; a response that cannot be decoded
  goes to Logcat.
- Scoreboard match mode (Settings switch, 2 players): with a pairing still to report the seam shows
  "R3 · T5" and Report (End otherwise). Report opens the result picker, then the summary's light rail sends
  the games (the pairing is fetched again first; a re-paired or already reported match is refused). The
  rail says Reported only for the series it sent: a new match never inherits it. The pairing is asked for
  again when a series ends and when a new match starts, so the next round shows up.
Decisions, for Okay's review:
- Mock flow over iOS: the current round card stays after a report (with the result), history lists
  every round, a drop hides the current card and clock; the confirm's cancel says "Keep" for every action.
- Lists refresh each time their section shows and on resume (at most every 30 s), so signing in on the
  PlayRiftbound section counts at once; no pull-to-refresh (not in the mock). Status and placement on the
  cards come from loading each event (two at a time, again after 20 s).
- Times in the phone language's format (24 h in German). Rules links stay in the browser (their PDF host
  is outside the allowlist).
- The slide-to-report knob starts at the left edge, so it is excluded from Android's back gesture.
- Debug builds could answer from a made-up live event until 4.0 (see "Fake live event" in the review rounds);
  every build uses the network.
Tests: `CompeteBracketTest` (the iOS test target: sections, titles, placements, 2v2 names, pending round,
Swiss final, report vs status, live standings), `DrawCalcTest`, `CompeteDecodeTest`, `RiftPolicyTest`,
`OperationIdsTest`. Emulator with fake data: every screen against the mock, report from the event page
and from the scoreboard (SubmitGameResults with the right game ids and winners), drop, register,
favourite toggle, store finder with real geocoding, the live site in the PlayRiftbound pane. Standings
against Riot's official end-of-round tables of three finished public events (30, 8 and 16 players):
192 rows, points, records and ranks equal, tiebreakers within 1e-16 (`StandingsCheckTest`;
`sh tools/check-standings/run.sh` checks iOS and Android). Not done: the live test with Okay's Riot sign-in.

### 6 · Upgrade path + release prep · done 2026-10-22
Upgrade test on a fresh emulator (Android 15): the Skip 3.4.0 (9) build of `pitopia.Riftcount` (its debug
build, so the same code signed with the public debug key), in it a scored and won game, a deck imported
from text (Darius, alt-art champion with riftcodex ids), haptics and match mode off, both player colours,
the PlayRiftbound site opened once. Then the native release build (R8, same id, signed with the same
debug key) installed over it as an update, 3.5.0 (10). Everything was there: the deck with its cards,
the game in the match log and win rate, the colours on the scoreboard, the switches in Settings, the
1408-card cache, no tour again, and the site's cookies (the Events tab tried the silent sign-in, which it
only does with cookies of the site). On the same release build, the store finder and a store sheet loaded
real PlayRiftbound data and the PlayRiftbound log recorded the calls, so R8 keeps the GraphQL models.
Frames on the emulator (release, busy host): card grid scroll 1.9 % janky, scoring 2.6 %, section switch
2.7 %, 99th percentile 20 ms.

Sizes: APK 3.9 MB, AAB 5.2 MB (Skip 3.4: 156 MB / 58 MB). Pure Kotlin, no native libraries, so one
bundle serves every ABI. The launcher entry keeps the Skip app's component name
(`riftcount.module.MainActivity`, now an alias of the new activity): home-screen icons survive the update
(checked: after the update the launcher component is the old one and opens the new app).

Release, Okay's steps:
1. Copy the Skip app's `android/Android/app/keystore.properties` to `android-native/app/` and point its
   `storeFile` at the same `.jks` (both stay out of git).
2. From `android-native/`: `./gradlew :app:bundleRelease`, then upload
   `app/build/outputs/bundle/release/app-release.aab` to Play as the next release of the existing app.
3. Every later release raises `versionCode` (now 10) and `versionName` in `app/build.gradle.kts`. The first
   release is 4.0.0 with versionCode 10 (Okay 2026-10-27: 4.0 on both platforms; 10 was never uploaded).
4. Play "What's new" for 4.0.0 (Okay approved 2026-10-27, 461 of 500 characters):

   > Riftcount 4.0 is a new app: rebuilt for Android, a fraction of the size and faster, with a new look.
   > • Scoreboard in your colors, optional legend art, your tournament table with Report
   > • Events: your PlayRiftbound events, live table, round clock, standings and "Can I draw?"
   > • Cards with search and filters, decks on a table with a 7-step builder, test hands and odds
   > Your decks, games and settings come along. The dice tab and the old Locator section are gone.

## Okay's review rounds

Scoreboard, round 1 (2026-10-22):
- Every action pill and the XP buttons light up in the half's colour under the finger and fade out.
- Number changes (score, dice, steppers) blur without the box they were cut to.
- The dice winner's "I go first / second" starts the game; no Roll again / Start step.
- Casual by default: every game stands alone (8 points, then Next game), still in the match log.
  Round 2: no series by hand at all, and no clock in casual play; the seam shows just GAME n.
- With a PlayRiftbound pairing the seam shows TABLE n · vs opponent and Start match. The live match
  starts in the event's format; a tap on its round and table switches best of 1 ↔ 3 (organisers enter
  best of 1 for best-of-three play), and a best-of-one summary offers "We play best of 3". Only the
  started live series can be reported. After it the next match is casual again. Only the live match
  shows the clock; a long press on its round and table pauses it.

Scoreboard, round 3 (2026-10-22): casual counts nothing (no game number, no End; a win shows WIN and its
score). With match mode on, the seam has a trophy that asks PlayRiftbound for the pairing now and answers in
a toast (no live event, no pairing yet, bye, round reported, or the table), and its centre names the event
before round 1, a bye or a reported round; a tap opens that event (iOS match strip). After a report the
summary says to ask the scorekeeper for changes instead of offering the result picker.

Scoreboard, round 4 (2026-10-22): the event line asks "Open the event?" before it leaves the board; the live
match's seam counts down the round's clock (start plus its minutes, gold once over) where the event has one,
otherwise the match clock as before.

Scoreboard, round 5 (2026-10-22): the seam's centre only ever leads to the event (after the question), never
starts or changes a match: Start match starts it, the best of 1 ↔ 3 tap is gone (a best-of-one summary still
offers "We play best of 3"). The summary's button reads Return to scoreboard. Before each next game the last
game's loser picks first or second on their half. The seam's dice button shows two thrown dice. The light
along the report rail grows in width instead of being scaled, so its glow fades out softly.

Cards, round 1 (2026-10-22): the search also reads the rules text (without its icon tokens) and the tags,
so "Repeat" or "friendly" finds every card that says it; cards named so come first.

Decks, round 1 (2026-10-22): a finished deck is to look at: main and side show as a gallery (the Cards tab's
faces, grouped Units · Spells · Gear or by energy) or as the list, without steppers; runes read only. Changes
go through the builder, whose battlefields, main and side are galleries now (a tap adds a copy, the minus on a
card takes one back). A full rune pool of a two-domain legend stays at 12: one domain down is the other up.
The match log closing dissolves into its tile instead of shrinking as a black box.

Decks and Cards, round 2 (2026-10-22): New hand gathers the cards back onto the pile, then deals four new
ones with their own images (a card face that changed card in place kept the last card's image). The list
view keeps the Type · Energy switch and its groups. Every blur fades out at its edge (`softBlur`, decal edge)
instead of ending in a box. Shortlist (Okay's "Merkliste"): Save on a card's Add to deck sheet; the builder's
main and side show a Shortlist chip with the kept cards the legend may play, the Cards filter has
"My shortlist".

Decks, round 3 (2026-10-22): a test-hand card now leaves the pile from the pile itself (pile size, upright,
fading in as it moves) and at once; before, it waited its turn as a small card under the pile. A mulligan sends
the marked cards back onto the pile before their replacements come off it. The table has a Shortlist spot right
after New deck (the latest three kept cards fanned, or an empty frame); it opens the list, grouped like a deck,
where the star takes a card off or puts it back.

Settings, round 1 (2026-10-22): no sounds at all (the Sounds tile, its clicks and `Sounds.kt` are gone) and no
shake to roll (the row and the shake listener; Roll both in the seam stays). Four switch tiles, Players takes the
last row. Keep screen on checked: the window carries `KEEP_SCREEN_ON` while the switch is on. Report a bug / Wish
a feature put address, subject and text into the mailto link like iOS (Gmail ignores them as SENDTO extras, the
mail would have opened empty). Acknowledgments gained the Skip app's Photon / OpenStreetMap credit (store search
geocodes with Photon) and the Apache 2.0 libraries (AndroidX/Compose, Kotlin, kotlinx) with the licence text.

Events, round 1 (2026-10-22): the PlayRiftbound browser rendered Riot's sign-in see-through (no white panel,
faint fields, buttons without colour) and the site's 100vh parts empty (home hero, My events). Cause: Compose
adds a view without layout params as wrap_content, and a wrap_content WebView lays pages out at zero height,
so `100vh` was 0 (checked over DevTools: Riot's form sits in a `height: 100vh` scroller). The web view now has
MATCH_PARENT params; `vh` is the pane height again and the sign-in looks like Chrome's. Scrolling the site on
the emulator stays slow (same with and without the rounded clip): its WebView/Chrome are 124 from 2024 on GPU
emulation; judge smoothness on a phone.

Events, round 2 (2026-10-22): the PlayRiftbound section starts on the site's events page (lighter than the front
page, and it asks to sign in; Riot picks the locale). Favourite store cards keep two lines for every name, so they
stand the same height. "Munich" found nothing: Photon's first hit was Munich, North Dakota; the geocoder now asks
for five hits and takes the largest place among them when the best hit is a place (an address keeps the best hit).
The rail and the month showed a new registration only after the store events reloaded (10 min): the calendar now
reads registrations from the player's event list each time (`mergeCalendar`), so register / cancel / drop show at once.

Scoreboard and tab bar, round 6 (2026-10-22): "Go first or second?" stayed on the loser's half until someone
picked or scored, so it greeted the board hours (or a restart) later. It is asked for 10 minutes after the game
(`chooserSinceMs`); older saved states never ask. Tab bar icons: Score upright like the board (two halves, a score
in each; the lying one read as a football pitch), Decks with three layers, Settings a gear (was a sun).

Scoreboard, round 7 (Okay at the table, 2026-10-26, both platforms): Start match and the best of 1 / 3 mode got
in the way, the slide to report stuck halfway, a game ended by a concession (or points nobody tracked) had no
way to finish, and restart looked like undo. Now every game stands alone; no series, summary, light rail or
result picker (`Summary.kt` is `BoardDialogs.kt`, `ReportRail.kt` and `ResultPicker` are gone). With a pairing
the seam shows round and table over the opponent (the round clock once it runs) and a green Report that opens
the Events report dialog (`TableLink.report`). The restart arrow became a flag: I won / I lost end the game as
it stands and record it, Restart sets it to 0 (undoable). A tap on a score number (players tap it for points)
lights that half's +1 pills in a wave from Conquer, with a small bump; no point, no haptic.

Sheets, round 1 (2026-10-26): a sheet (the store sheet first) only closed with the back button or a tap on the
dim. `Sheet` now follows a pull down from the top of its content and closes past 120dp or on a downward fling,
like iOS sheets; short of that it slides back.

Cards, round 3 (2026-10-26): Set sorted each set by energy, so its first rows looked just like Energy (both open
with the 0-energy Seals; a friend of Okay's found it). Set is now release order in each set's own numbering, like
a binder; Energy groups each cost by set; Type stays by energy (`CardQuery.comparator`, iOS the same). Card faces
are bare like the Skip app's grid (the shade with name and type line covered the card's bottom); ERRATA / PREVIEW
stamps stay in the corner and the Cards grid names each card in a line under it.

Decks, round 4 (2026-10-26): a tap on a shortlist card opens it as the Cards tab does (the tile flies into the
detail inside the sheet's window, back closes it), with Add to deck; "New deck with this card" from there closes
the shortlist and starts the builder.

Scoreboard, round 8 (2026-10-26, iOS the same): the seam's flag became a text button, "Reset Score" ("Reset"
where a pairing leaves no room: `FirstThatFits` picks the first row that fits, like iOS `ViewThatFits`); its menu
now reads Reset the score or end the game. The score tap's cue is Okay's pick from three mocks, "C · Ripple": once,
on the three +1 pills at once, a ring of the half's colour runs out 20 % wider and 60 % taller and fades (drawn behind
the pill, a wider faint stroke as its glow) while the pill dips to 96.5 % and springs to 103 %, 850 ms on the curve
(0.2, 0.7, 0.2, 1) (`Give`). A first try that breathed twice in a halo was too jerky.

Decks, round 5 (2026-10-27, iOS the same): the deck screen's banner shows the legend's centred splash (Data Dragon,
through `rememberLegendPicture` like the board's Legend art, switch or not) over the card's art, which is rarely
centred and cropped badly there. The table puts every deck's splash on disk ahead (`CardImages.prefetch`) and a tap
decodes it before the deck opens (300 ms at most), so the deck opens as its splash from the first frame; closing
fades it back to the card as it lands on its pile. A splash still on its way fades in on the banner.

Settings, round 2 (2026-10-27, iOS the same): Legend art and Players are small tiles like the others, the six two to a
row (the Players number box 42dp like a switch's icon, so the texts line up); the "Most used" / "Tap i for what it
does" line above them is gone (`SectionHead` lost its aside), and the Events tour says "One tap on its tile at the top".

Fake live event (2026-10-26, so event mode can be tried without a live event): debug builds have Settings › Debug ›
Fake live event. It restarts the app, then every PlayRiftbound call is answered on the phone from a made-up Summoner
Skirmish (round 3 running, your table open, best of 3), every time moved to the moment of the switch; a report or
registration is only noted and changes the later answers, nothing goes to Riot. `tools/fake-live-event/build.sh`
writes the answers (`src/debug/assets/fake_compete`, iOS the same event). The PlayRiftbound log row moved there
too. Release and staging compile the stub in `src/nondebug`: no Debug section, no log, always the network.
Removed before 4.0 (2026-10-27, iOS the same): `src/debug` (DebugEvents and its answers), the `src/nondebug` stub
and its source-set wiring, `tools/fake-live-event`, the PlayRiftbound log (`PlayRiftboundLog`, `LogPage`, the
API's recording, `RiftError.logName`) and RiotSession's stand-in credentials. Nothing debug-only is left.

Scoreboard, colour model C (2026-10-26, Okay's pick from the mocks, iOS the same): each field is its seat colour
brought to OKLab lightness 0.44 (`SeatShade.deep`: linear RGB times (0.44/L)³, same hue; darker colours keep theirs),
so every seat reads alike and white is 7:1 or more on all 16 colours. What the board draws in the seat colour on top
(line, dice, WIN, GOES FIRST, filled buttons) is lifted to lightness 0.74 by mixing in white (`SeatShade.lift`,
3.3:1 or more on its field; Rift Green and Rift Violet stay); without it blue, purple and the dark colours vanished on
their own fields. Conquer is white with ink at 0.75 of the depth, the other pills black 24 % with a white 28 % rim, no
glow at rest. Four players: the leader at 1.125 of the depth, the near row's colours under the tab bar. The Colors
page preview follows. `SeatShadeTest` checks every colour.

Scoreboard, Legend art (2026-10-26, Okay's pick from the mocks, iOS the same; spec in the redesign branch's
`docs/IOS_REDESIGN.md` "Score tile look", mocks on https://claude.ai/artifact/68cipuSRxXGtdgqTKkvXL2): with the
`legendArt` switch on (off by default; a tile on top of Settings and a row at the top of both setup sheets,
`ToggleRow`) a half shows its legend's champion as Data Dragon's base splash. `LegendArt` turns the legend's name
into the id (all nine exceptions of Data Dragon's 173 champions; `LegendArtTest`); `rememberLegendPicture` loads it
through `CardImages` (memory and disk) as soon as a legend is picked. `LegendPicture` draws it fixed to the screen,
hanging from the board's middle, 90dp past it with a 70dp fade (`BlendMode.DstIn` in an offscreen layer), cut at the
territory line while drawing (no recomposition), darkened to 72 %; the far half's is turned round. Over it the
seat's colour at 22 %; `legendShade` puts the radial shade behind the number, which gets a soft shadow; the pills
take the mock's art look. A half without its picture keeps colour model C. Legend art and Players each take a whole row.

## Code review before release (2026-10-22)
One pass, five reviewers in parallel (Android by area, plus the new iOS commits), every finding checked against
the code before fixing; no second full round (fd73591, efe9349, df62e13). Fixed: a later round with the same games
showed REPORTED and was never sent; dice pills squeezed on 360 × 800 phones; a crash in very short windows; casual
game durations counting the wait since the last game; card images after a cache clear; the soft keyboard over
Riot's sign-in; the calendar after a favourite change; and, on both platforms, the deck rules: Signature cards are
the Signature supertype (not the signed printing), at most three of the legend's champion, champions by the
legend's champion tag, a sideboard of up to 10. Clean areas: domain lock, cookies, report/register paths,
standings, the old app's preferences, the card feed and image cache.

Second pass before 4.0 (2026-10-27): everything since 8c7df64 (colour model C, Legend art, Reset Score and the ripple,
the debug split, the deck banner's splash), two read-only reviewers, no findings. Checked on the way: the debug tools,
their assets, the Debug rows and the PlayRiftbound log stay out of release and staging; the deck's open waits for its
splash with a timeout that fires even while the download blocks.

## Open points
- 4-player scoreboard has no mock; derived in phase 1, Okay judges it.
- The mocks end a game automatically at 8 (with the conquer check); iOS has manual Won/Lost. The build
  follows the mock and also keeps a manual end via Restart/Report.
