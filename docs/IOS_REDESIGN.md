# Riftcount iOS · redesign plan

The native Android app's design comes to iOS. Work happens on the branch `feature/ios-redesign` (Okay's
checkout is on it to build in Xcode); it reaches `main` only when Okay says so. Decided 2026-10-22.

## Decisions (Okay, 2026-10-22)

- **Design spec:** the chosen mocks on the design canvas
  (https://claude.ai/artifact/ARcSMfQqecAVKCB4ETYz9A, page "Chosen · all tabs") as finished in the Android
  app, including Okay's review rounds (`docs/ANDROID_NATIVE.md`). Close to the mocks, not 1:1: iOS chrome
  (Liquid Glass) where it fits.
- **Behaviour:** as the finished Android app. The scoreboard ends a game at 8, plays best of three, has the
  dice duel in the seam and the light-rail report.
- **Tabs:** Score · Events · Cards · Decks · Settings. No Dice tab; the dice live in the scoreboard seam.
- **Classic design:** a Settings switch "Classic design" brings back the current look, for a transition of
  one or two releases. The classic screens are frozen (bug fixes only), then deleted.
- **Default:** the new design is on after the update; the switch goes back.
- **Live Activity:** removed from both designs (nobody uses it): app code, the widget extension target,
  its Settings section.
- **Checks:** my swiftc compile check, then Okay builds and reviews in Xcode. No simulator screenshots.
- **Name and icon:** unchanged for now; a new icon maybe later.

## Architecture

- New screens live in `Riftbound Companiokay/Redesign/` (synced folder, joins the app target).
- The app root shows `RedesignRoot` or the classic `RootTabView` by `@AppStorage("classicDesign")`. Both get
  the same environment objects, so switching loses nothing.
- Stores and files stay shared: decks, games, cards, errata, shortlist, PlayRiftbound session, API and
  events. No data migration.
- Until a tab's phase lands, the new shell shows that tab's classic screen.
- The new scoreboard keeps its own state (Android's rules), apart from `ScoreboardViewModel`. Finished
  games land in the same `games.json`.
- Identity as on Android: true black, green `#2BE38B` for you, violet `#A99BFF` for the opponent, gold
  `#FFC75E`, red `#FF6B61`; Big Shoulders Display numerals, Barlow text (OFL, registered by `UIAppFonts`);
  motion is transform/opacity only with the ease-out `cubic-bezier(.16,1,.3,1)`, no endless loops.
- Liquid Glass: the system chrome (native `TabView` tinted green, sheets, navigation) and the seam pill on
  iOS 26; iOS 18.6 shows materials instead. The playfield (territory fields, glowing line, light rail)
  stays drawn as mocked.
- No packages; SwiftUI only.
- Accessibility: Dynamic Type for text styles; slide-to-report also works as a VoiceOver button.

## Phases

Each phase: compile check, commit on `feature/ios-redesign` (Okay's checkout follows), Okay builds and
reviews in Xcode.

0. **Foundation:** tokens (colours, fonts, easing), the two font families bundled, `RedesignRoot` with the
   five tabs (classic screens inside), the root switch, the "Classic design" switch in Settings.
1. **Live Activity out** · done 2026-10-22, from both designs: `GameActivityController`,
   `GameActivityAttributes`, `ScoreIntent`, the shared scoreboard in `AppGroup` with its App Group
   entitlement, the widget extension target (removed by Okay in Xcode) and folder, `NSSupportsLiveActivities`,
   the Settings section and the tour bullet. Done before the scoreboard, so the new one needs no lock-screen
   sync. The App Group never kept scores over a relaunch (`init` wrote the fresh zeros before reading), so
   nothing is lost.
2. **Scoreboard** (`ScoreFinal` + Android rounds 1–6): opponent half turned, territory fields and glowing
   line, blur-morph numbers, Conquer/Hold/Effect/Fix −1, XP chips, the final-point prompt, best of three
   with pips, undo, restart, seam (dice duel, clock, match line, trophy, Report), summary with the light
   rail, result picker, match mode report, game setup (deck, opponent, turn order), 4 players. Rules ported
   from `ScoreRules.kt`, `Duel.kt` and `ResultPicker` (`tools/check-scoreboard/run.sh` runs the Android tests
   on the Mac). In three steps:
   - 2a · done 2026-10-22: casual board, the roll for who goes first, 4 players. For Okay's review: the
     restart question is the native alert (the mock's dialog elsewhere); the seam is Liquid Glass on iOS 26;
     the board keeps its own game (`redesign.scoreboard`), so switching designs mid-game shows the other
     design's score; the player count still comes from the classic quick settings until phase 5.
   - 2b · done 2026-10-22: game setup (your deck and turn order, the opponent's legend) by tapping a
     half's name; native sheets.
   - 2c · done 2026-10-22: match mode (Settings "Match mode", two players): the trophy checks
     PlayRiftbound, the event line before round 1 / bye / reported, the pairing's table and opponent with
     Start match, the round countdown (gold once over) or the match clock (long press pauses), Report /
     End, the summary with the light rail and slide to report (the pairing is fetched again first, as in
     the classic report sheet), the result picker. The strip now carries the round chip and its clock's
     end. For Okay's review: "Open the event?" opens the event's PlayRiftbound page in Events (like the
     classic strip; the native event screen joins with phase 6); the result picker is a native sheet.
3. **Cards** (`CardsFinal`): grid with the rising tiles, tile grows into the detail, filter sheet with the
   sliders, Add to deck with the builder rules, shortlist.
4. **Decks** (`DecksMix`): table of piles, the pile opening into the deck, test hand, odds, stats, match log
   and game review, the seven-stop builder rail, shortlist spot.
5. **Settings + onboarding** (`SettingsHybrid`): flip tiles, player colours, help, about, the fonts in
   Acknowledgments, both tours, the Classic design switch.
6. **Events** (`EventsMix`): Events · Stores · PlayRiftbound tabs, live card, event page with five tabs,
   search, stores week rail, store and month sheets; the PlayRiftbound tab keeps the existing browser. The
   Locator "Old" segment is not ported (it goes in November).
7. **Release prep:** iPad pass (same screens, wider), App Store screenshots, What's new, version.

Size: the Android screens are about 12k lines; iOS will be similar. Most logic already exists on iOS; the
scoreboard rules are new.
