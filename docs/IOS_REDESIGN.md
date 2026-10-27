# Riftcount iOS · redesign plan

The native Android app's design comes to iOS. Work happens on the branch `feature/ios-redesign` (Okay's
checkout is on it to build in Xcode); it reaches `main` only when Okay says so. Decided 2026-10-22.

## Decisions (Okay, 2026-10-22)

- **Design spec:** the chosen mocks on the design canvas
  (https://claude.ai/artifact/ARcSMfQqecAVKCB4ETYz9A, page "Chosen · all tabs") as finished in the Android
  app, including Okay's review rounds (`docs/ANDROID_NATIVE.md`). Close to the mocks, not 1:1: iOS chrome
  (Liquid Glass) where it fits.
- **Behaviour:** as the finished Android app. The scoreboard ends a game at 8 or by hand (won / lost), has
  the dice duel in the seam and, at an event, a green Report (best of three and the light-rail report went
  with Okay's feedback of 2026-10-26).
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
- A tab left behind starts fresh the next time, so its entrance plays again (Okay, 2026-10-23; Android
  builds a tab's screen anew each time): Decks and Settings are rebuilt while hidden (the tab root's `.id`).
  The builder's draft and all data live in the models. Events is not rebuilt: an `.id` inside a kept tab
  makes the new lists appear while the tab is still fading out on iOS 26 (review 2026-10-23), so its
  section, pushed pages and browser simply stay.
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
3. **Cards** (`CardsFinal`) · done 2026-10-22: header with the count, search with the green ring, All + six
   domain discs (Riot's rune glyphs, generated from the Android vectors as template assets), Set · Energy ·
   Type, Filter with its badge, the grid whose first 15 tiles rise in, the tile growing into the detail
   (matched geometry: name and type line, stats, errata box over the struck printed text, rules with keyword
   chips and italic reminders, flavour, artist, code, tags), filter sheet (shortlist, type, series, rarity
   chips, two-thumb ranges, live "Show N cards"), Add to deck with the builder rules (`DeckRules.swift`,
   `sh tools/check-decks/run.sh` runs the Android `DeckRulesTest` on its fixture) and the shortlist. Tiles
   load Riot's CDN WebP at tile width. `Card` gains `publicCode`. For Okay's review: "New deck with this
   card" joins with the new builder (phase 4); the filter and add sheets are native sheets.
4. **Decks** (`DecksMix`) · done 2026-10-22, in three steps:
   - 4a: the table of piles rising in (record, Legal chip), New deck, the shortlist fan and its sheet (a card
     taken off stays dimmed until the sheet closes), the all-decks win rate ring and the last games, both
     growing into the match log (deck chips, record, win rate, average game, first / second, game rows); a game
     slides in as its review (result, race to 8, point by point) with the edit sheet (result, turn order, deck,
     opponent legend, delete by tapping twice); import from pasted text, unmatched lines listed after.
   - 4b: the pile opening into the deck: the legend grows into the banner, champion and battlefields fly out of
     the pile, closing plays it back into the pile; test hand (fan off the pile, one mulligan of up to two to
     the bottom), odds over several picked cards, stats, the deck's match log from its History button, champion
     swap, battlefield picker, export, menu (rename, edit, delete by tapping twice), deck check; main, side and
     runes as gallery or list, grouped by type or energy (the choice stays for every deck).
   - 4c: the builder: seven stops on the light rail, pages sliding by direction, legend tiles, champion,
     battlefields with art, main and side pools as a gallery (tap adds, minus takes back, blocked cards dim and
     say why, Unit/Spell/Gear and Shortlist chips), runes with the full-pool trade, name and deck check; edit
     keeps what the pickers cannot show; the steps card once (`didSeeBuilderTip`, shared with classic). Cards'
     Add to deck gains "New deck with this card" (a legend starts the deck, any other card waits for a legend
     it fits).
   The deck math, the edits and the draft are checked by `sh tools/check-decks/run.sh` on the Android tests
   (84 checks). For Okay's review: the import uses iOS's Paste button (no paste prompt) instead of reading the
   clipboard on open; tool sheets are native sheets; cached card images now show without a placeholder flash
   (shared image cache, both designs).
5. **Settings + onboarding** (`SettingsHybrid`) · done 2026-10-22: "Most used" tiles that turn over to say
   what they do (Haptics, Keep screen on, True black, Match mode, Players 2P / 4P with the morphing number),
   Player colors (live preview of the table, 16 swatches per seat, taking a colour another seat has swaps the
   two, `colorIdx_N` shared with classic), the Classic design switch, Help (both tours, Riot's rules
   documents), About (acknowledgments with the two OFL licences to read in place, bug report and wish through
   Mail, share, rate, Ko-fi, privacy), the version line. True black now really switches the redesign's page
   colour (black or #121212, an environment value). The first launch shows the redesign's tour (classic tour
   with Classic design on). For Okay's review: sub pages are native pushes (back button and swipe) with the
   mock's big title in the page; the PlayRiftbound log row stays out (removed on iOS earlier); the haptics
   default bug is still open (to fix on main).
6. **Events** (`EventsMix`) · done 2026-10-22: section tabs Events · Stores · PlayRiftbound with the glowing
   bar, the sections sliding sideways. Events: the finder pill, the live card (round clock, table, Report),
   upcoming cards with the player's status and past cards with the placement (each event's details are
   fetched two at a time, cached 20 s, one request per event at a time). The event page: hero with the store
   link, the five tabs (Matches with the final standing, the open pairing with both records and Report, the
   round clock and the match history; Rounds with every table and the rounds to come; Standings with Riot's
   tables or the live preview, the player's line, tiebreakers and "Can I draw?"; Roster; Info with register /
   cancel / drop confirmed first). Report: one row per game, nothing after the deciding game, pairing fetched
   again on open and before sending. The finder (place, radius, type / format / players, favourites only,
   date or distance, load more). Stores: the 14-day light rail with the day's events, favourite store cards,
   the store finder with the radius rail; the store sheet (contact rows, heart, its events) and the month.
   PlayRiftbound keeps the existing browser and loads the first time it shows. The scoreboard's "Open the
   event?" now opens the native event page. For Okay's review: pages are native pushes and sheets; the
   Locator "Old" segment is not in the new design (Classic design still has it until November).
7. **Release prep** · 2026-10-22: iPad pass (the same screens: card galleries, the piles, the builder's pools
   and legends get more columns on a wider screen; Settings and the Events lists keep a readable width of
   700pt; Cards and the scoreboard already adapted), version 3.6 (`MARKETING_VERSION`, build 1; Android's
   native app is 3.5.0, change it if the rebrand should be 4.0). App Store screenshots are Okay's. What's new
   for the App Store:

   > Riftcount has a new look.
   > • Scoreboard: territory fields with a glowing line, the dice in the middle decide who goes first, won
   >   or lost by hand, and your tournament table with a Report button right on the board.
   > • Cards: the whole pool in a new grid, filters with sliders, and a card view that grows out of its
   >   tile, with keyword chips and errata.
   > • Decks: your piles on a table, a deck that opens out of its pile, test hands, odds and stats, a
   >   seven-step builder, and a match log with every game's race to 8.
   > • Events: a live card with your table and the round clock, the event page with matches, rounds,
   >   standings and "Can I draw?", stores on a two-week rail and a month view.
   > • Settings: tiles that turn over to tell what they do, 16 player colors, true black or dark grey.
   > Prefer the old look? Settings › Classic design brings it back for a while.
   > The Live Activity and the widgets are gone.

## Feedback round 1 (Okay, 2026-10-26)

Both platforms, step by step:

1. **Scoreboard match flow:** no Start match, no best of 1 / 3 mode, no match summary and no slide to
   report (it stuck halfway). Every game stands alone. With a pairing the seam shows round, table and the
   opponent (the round clock once it runs) and a green Report that opens the Events report sheet (Android:
   its report dialog): the same picks, the pairing fetched again, the confirmation. A flag in the seam opens
   the game menu: I won / I lost end the game as it stands (a concession, points the board missed), Restart
   sets it to 0 (undoable). The flag replaces the restart arrow that looked like Undo. `RiftTournaments`
   moved to the root for the sheet.
2. **Wayfinding:** a tap on a score number (players tap it for points) lights that half's +1 pills in a
   wave from Conquer, with a small bump; no point, no haptic.
3. **Sheets (Android only):** the store sheet (every sheet) closes when pulled down; iOS sheets already do.
4. **Cards sort:** Set sorted each set by energy, so its first rows looked like Energy's. Set is now
   release order in each set's own numbering (a binder); Energy groups each cost by set; Type by energy.
5. **Card tiles:** the shade with name and type line covered the bottom of every card. Tiles show the bare
   card like the classic grid (ERRATA / PREVIEW stamps stay in the corner); the Cards grid names each card
   in a line under it. Everywhere else (piles, galleries, builder, hand) the card speaks for itself.

### Score tile look (Okay's picks 2026-10-26, built on both platforms the same day)

Mocks on the canvas https://claude.ai/artifact/68cipuSRxXGtdgqTKkvXL2 (pages Tile colours, Legend art,
Middle · 4 ways). Okay wants some feedback work done first.

- **Colour model C ("Solid colour") is the board's base look.** Built on iOS (step 1, `SeatShade`): each
  field is the seat colour brought to OKLab lightness 0.44 (linear RGB times (0.44/L)³: same hue, chroma
  down with the lightness; colours darker than that keep their own), so every seat reads alike and white is
  7:1 or more on all 17 player colours. What the board draws in the seat colour on top (the line, dice, WIN,
  GOES FIRST, filled buttons) is the colour lifted to lightness 0.74 by mixing in white, 3.3:1 or more on its
  own field; Rift Green and Rift Violet are already that light and stay. Without the lift blue, purple and
  the dark colours vanished on their own fields (1.0 to 1.3:1). Conquer is white with ink at 0.75 of the
  field's depth; the other pills are black 24 % with a white 28 % rim; no glow at rest, a tapped pill still
  lights up in the seat colour. Four players get it too, the leading seat at 1.125 of the depth, the colours
  under the status bar and the tab bar like the duel's fields, never art. The Colors page preview follows.
  `tools/check-scoreboard` checks every colour.
- **Legend art per half:** variant 1 ("art under a shade") with middle d ("the line uncovers the leader").
  - A half shows its legend's picture when the "Legend art" switch is on, its legend is known (your deck's
    legend, the opponent legend picked in the setup) and the picture has loaded. Otherwise that half uses C.
    Mixed boards are fine: a deck but no opponent legend gives art on your half only.
  - The switch is one setting, **off by default**, in both game setup sheets (deck and opponent) and as a
    tile in Settings.
  - Pictures (storage option A): Data Dragon's base splash,
    `https://ddragon.leagueoflegends.com/cdn/img/champion/centered/<Key>_0.jpg`. Key = the champion's name
    without non-letters, except Kai'Sa → `Kaisa`, LeBlanc → `Leblanc`, Kha'Zix → `Khazix`, Renata Glasc →
    `Renata` (57 legend champions on 2026-10-26). Loaded through the existing image caches (iOS
    `CachedRemoteImage`, Android `CardImages`) and prefetched as soon as the deck or the opponent legend is
    picked; a picture that cannot load leaves its half on C. No app size, new legends work by themselves.
  - Built on iOS (step 3): `LegendArt` takes the champion from the legend's name (before " - " or ", ", a
    printing's "(…)" dropped) and knows all nine Data Dragon ids that are not the letters (checked against
    all 173 champions of Data Dragon 16.13: also Bel'Veth, Cho'Gath, Vel'Koz, Wukong → `MonkeyKing`, Nunu &
    Willump → `Nunu`); `tools/check-scoreboard` checks the names. The board loads both pictures through
    `ImageCache` as soon as the switch is on and a legend is picked, decodes them before they show
    (`byPreparingForDisplay`) and fades them in; `LegendPicture` draws one, `LegendShade` the shade. The
    switch is `legendArt` (off): a tile on top of Settings and a row at the top of both setup
    sheets. On the board pictures come from Riot's Data Dragon only while the switch is on; the deck screen's
    banner uses the same splash regardless (feedback round 4).
  - Layout: the picture is fixed to the screen and anchored at the middle, reaches about 90 pt past it
    with a 70 pt fade, and is clipped at the territory line (in the draw phase, no relayout); the line's
    glow covers the cut, so the leader gets more of their picture. Over the art: the seat tint at 22 %,
    the art at brightness 0.72, a dark radial shade behind the number and a soft text shadow. Art halves
    keep variant 1's pills: Conquer filled in the seat colour with its glow, the others black 50 %.
- **Steps:** 1 iOS colour C (2b48ccb) · 2 Android colour C (7f86ff1) · 3 iOS legend art (140d9e4) · 4 Android
  legend art (a052c70) · 5 docs and memory. All done; Okay checks each.

## Feedback round 2 (Okay, 2026-10-26)

1. Deck screen: back, edit and export sat under the status bar. The top inset was read inside a reader that
   ignores the safe area, where it is always 0; an outer reader keeps the safe area now (42e8785).
2. Swipe back from the left edge in Cards (the card detail) and Decks (deck screen, match log, game review, the
   shortlist's card): a screen-edge recognizer, as Events and Settings get from their pushes. The builder keeps
   its buttons, so a slip cannot close a draft (729df81).
3. The chosen round chip's glow was cut by its scroll row (306a44b).
4. A shortlist card opens the card detail with Add to deck (both platforms).
5. Crash on Players 4 → 2: SwiftUI updated the four-player table once more with the duel's state and seats 3
   and 4 read past the end; seats the state lacks draw nothing now (31e30e7). Found with a scratch simulator
   build (swiftc and actool, no xcodebuild) that drives the switch and reads the crash report.
6. Debug builds: Settings › Debug › Fake live event, so event mode can be tried without a live event.
   `FakeLiveEvent` answers every PlayRiftbound call from a made-up Summoner Skirmish (round 3 running, your
   table open, best of 3), every time moved to the moment of the switch; a report or registration is only
   noted, nothing goes to Riot. `tools/fake-live-event/build.sh` packs the answers into
   `FakeLiveEventData.swift` (and Android's assets). All of it is `#if DEBUG`: release builds have none.
   Removed again before 4.0 (feedback round 5).

## Feedback round 3 (Okay, 2026-10-26, both platforms)

1. The seam's flag is a text button, "Reset Score" ("Reset" where a pairing leaves no room on a narrow
   phone: `ViewThatFits`, Android `FirstThatFits`). It opens the same menu, now led by Reset score, then I won
   and I lost; the tour says so.
2. The score tap's cue: the three +1 pills no longer light up one after the other. A first try breathed twice
   in a halo ("too jerky, and twice with a pause is not good"); from three mocks (canvas page "Score tap · 3
   ways": bloom, sheen, ripple) Okay picked C · Ripple: once, on all three at once, a ring of the half's colour
   (2.5 pt, a soft glow) runs out 20 % wider and 60 % taller and fades while the pill dips to 96.5 % and springs
   to 103 %, 0.85 s on the curve (0.2, 0.7, 0.2, 1) (`keyframeAnimator`, `Ripple`).

## Feedback round 4 (Okay, 2026-10-27, both platforms)

1. The deck screen's banner shows the legend's centred splash, the picture Legend art puts on the board, instead
   of the card's art, which is rarely centred and cropped badly in the wide banner. It is not tied to the Legend
   art switch. The Decks table fetches every deck's splash ahead, so a deck opens as its splash from the first
   frame (a first version faded from the card to the splash, which looked off); closing fades it back to the
   card as it lands on its pile. The card's art stays underneath while a splash is still on its way (then it
   fades in on the banner) or where it cannot load.

Review before the 4.0 release (2026-10-27): one pass, four read-only reviewers (iOS and Android, each the scoreboard
and the rest) over everything since the round-1 review (iOS 7ab01a0, Android 8c7df64). One MEDIUM, fixed: "New deck
with this card" in the shortlist's card detail started the builder under the still open shortlist (iOS only; Android
already closed it). The debug tools stay out of Release on both platforms.

## Feedback round 5 (Okay, 2026-10-27, both platforms)

1. Settings: Legend art and Players are small tiles like the others, so the six sit two to a row (the Players
   number box is as wide as a switch's icon now, so the texts line up); the "Most used" / "Tap i for what it does"
   line above them is gone, and the Events tour says "One tap on its tile at the top".
2. No debug tools before the release: the fake live event is gone on both platforms (iOS `FakeLiveEvent` and its
   data, Android's debug source set with its answers, `tools/fake-live-event`), and so is Android's PlayRiftbound
   log (its Settings page and the API's recording); the iOS log went on 2026-10-22, and 3.5's leftover
   `playriftbound_log.json` is deleted on the first start. Left in on purpose, none of it reaches Release: an
   Xcode preview, the web view's Safari inspector and its console timings in Debug builds.

Size: the Android screens are about 12k lines; iOS will be similar. Most logic already exists on iOS; the
scoreboard rules are new.
