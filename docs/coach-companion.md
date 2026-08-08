# Coach Companion — Design Structure (v0, draft)

> Status: **design draft, nothing implemented.** This document fixes the shape of the
> feature before any code is written. Decisions marked **[OPEN]** still need a call.

---

## 1. Why this exists

Two reasons, one defensive and one offensive.

**Defensive.** From mid-September the Riot/UVS tournament structure changes and
`api.riftbound.uvsgames.com/api/v2/` stops serving us. That is not just "the Events tab
goes away" — everything below dies with it:

| Feature | Where |
|---|---|
| Events, pairings, standings, capacity | `User/Events/LocatorAPI.swift` |
| Register / drop / report result / deck submission | `User/Events/LocatorAPI.swift` |
| Store finder, favorites, store calendar | `StoreSearchView`, `StoreDetailView`, `StoreCalendarView` |
| Match-mode strip **inside the Scoreboard** | `User/Events/MatchMode.swift` |
| Can-I-Draw top-cut math, opponent scouting | `DrawCalc.swift`, `OpponentEloBadge.swift` |
| eloshowdown profile (if its data source is UVS) | `User/Events/EloShowdownAPI.swift` |

Re-engineering whatever replaces it is worth attempting, but it is a dependency on
someone else's undocumented service, twice burned. The Coach is the counterweight: it
runs on **data the app already owns**, needs **no network at all**, and cannot be turned
off by a third party.

**Offensive.** There is no improvement loop for Riftbound today. Players log results and
that is the end of it. A companion that turns those results into feedback, gives weekly
goals, and keeps a streak is a daily-open reason for an app that is currently
open-during-play only.

### The constraint that shapes everything

The League analogy (auto-analyze the replay, verify the quest, grant the streak) breaks
at exactly one point: **in League telemetry is free, because the client records it
anyway. In offline tabletop, every piece of telemetry costs the user taps.**

That gives the two rules this whole design obeys:

> **Rule 1 — Never design a quest whose capture costs more than its insight is worth.**
>
> **Rule 2 — Reward process, not outcome.** Outcome quests ("win 3 games") punish
> variance and invite lying. With self-reported data, a user who lies is only corrupting
> their own statistics — so the system must never make lying attractive.

### The underrated asset: we already have telemetry

`ScoreEvent` stores `elapsedSeconds`, `slot`, `type` (`conquer`/`hold`/`manual`) and
`delta` for every point of every logged game. That is the tabletop equivalent of the
Drake timer, and it is already sitting in `games.json`. A large part of the Coach works
**retroactively on existing history, with zero new input**. See §5.

---

## 2. Decisions taken

| Question | Decision |
|---|---|
| Post-game capture depth | **3-tap check-in**, optional and skippable, depth configurable in Settings |
| Placement | **Own tab**; Events stays until the API dies |
| Companion embodiment | **Custom mascot** with its own artwork and states |
| Data & social | **Local only**, plus a user-initiated shareable weekly recap card |

### 2.1 Placement — the tab-bar problem **[OPEN]**

`RootTabView` already carries six tabs: Score, Events, Cards, Decks, Dice, Settings. On
iPhone SwiftUI renders **four** and pushes the rest behind "More" — so Dice and Settings
are already buried today. A seventh tab appended at the end inherits that fate, and a
companion that needs a daily open cannot live two taps deep.

So Coach must take one of the four visible slots, and something has to move. Options:

| Order (visible ‖ More) | Cost |
|---|---|
| Score, **Coach**, Events, Cards ‖ Decks, Dice, Settings | Deck builder buried — bad, it is the second-most-used feature |
| Score, **Coach**, Cards, Decks ‖ Events, Dice, Settings | Events buried while still live until September |
| Score, Events, **Coach**, Decks ‖ Cards, Dice, Settings | Card DB buried, but it is reachable from deck building and search |

**Recommendation:** the middle one. Events is genuinely only used on tournament days, it
is a known-dying feature, and burying it now is a rehearsal for removing it. In September
Events leaves and everything shifts up on its own with no further churn.

Whichever is picked, `currentTab` (`@AppStorage`) keeps working — tags are strings, and a
new `"coach"` tag defaults cleanly for existing installs.

---

## 3. Product shape

Three layers, stacked. Each is useful without the one above it, which is also the
shipping order.

```
┌─ Mascot ──────────── the voice. Narrates the two layers below.
├─ Quests + Streak ─── the loop. Weekly board, three tiers of verification.
└─ Insights ────────── the substance. Fully automatic, zero friction, works on day one
                       against history the user already has.
```

Building Insights first matters: it is the only layer that delivers value on install,
because it can analyze every game already in `games.json`. Quests and streaks need weeks
of forward data before they mean anything.

---

## 4. Data model

### 4.1 Extend `GameRecord` (backward compatible)

`GameRecord` already uses explicit `CodingKeys` and a custom `init(from:)` built on
`decodeIfPresent`. Adding one optional field is a non-breaking change — old `games.json`
files decode unchanged.

```swift
struct GameCheckIn: Codable, Hashable, Sendable {
    enum OpeningHand: String, Codable, Sendable { case kept, mulliganed }
    enum Resources: String, Codable, Sendable { case smooth, screwed, flooded }
    enum Takeaway: String, Codable, Sendable {
        case misplay      // I made a mistake I can name
        case matchup      // the matchup was the problem
        case deck         // the deck was the problem
        case variance     // it was luck
        case clean        // it went the way I planned
    }

    var openingHand: OpeningHand?
    var resources: Resources?
    var takeaway: Takeaway?
    var note: String?          // optional free text, capped ~280 chars
    var capturedAt: Date
}

// GameRecord gains:
let checkIn: GameCheckIn?     // + CodingKey "check_in" + decodeIfPresent
```

Keeping the check-in **on the record** rather than in a side table means it survives
deletion/edit of a game automatically and needs no ID reconciliation.

### 4.2 New store: `coach.json`

Mirrors `GameRecordStore` exactly — `@MainActor ObservableObject`, JSON in
`.documentDirectory`, `os.Logger`, atomic writes.

```swift
struct CoachProfile: Codable, Sendable {
    var mascotLevel: Int
    var xp: Int
    var createdAt: Date
    var pausedUntil: Date?          // hiatus mode, see §7.3
}

struct WeeklyBoard: Codable, Sendable {
    var weekStart: Date             // Monday 04:00 local
    var quests: [QuestInstance]     // exactly 3
    var generatedFromCadence: Int   // games/week the targets were scaled to
}

struct QuestInstance: Codable, Identifiable, Sendable {
    let id: UUID
    let definitionID: String        // key into QuestCatalog
    var target: Int                 // scaled at generation time
    var progress: Int
    var completedAt: Date?
    var claimedAt: Date?            // XP granted
}

struct StreakState: Codable, Sendable {
    var currentWeeks: Int
    var longestWeeks: Int
    var lastCreditedWeekStart: Date?
    var freezesBanked: Int          // max 2
}
```

### 4.3 Files

```
Riftbound Companiokay/Coach/
├─ CoachModels.swift        GameCheckIn, CoachProfile, WeeklyBoard, QuestInstance, StreakState
├─ CoachStore.swift         @MainActor ObservableObject, coach.json persistence
├─ InsightEngine.swift      nonisolated pure funcs: [GameRecord] -> [Insight]
├─ QuestCatalog.swift       static QuestDefinition list + evaluators
├─ QuestEngine.swift        weekly board generation, progress evaluation, streak rollover
├─ CoachTabView.swift       nav root
├─ CoachHomeView.swift      mascot + today's line + quest board + top insight
├─ QuestBoardView.swift
├─ InsightListView.swift / InsightDetailView.swift
├─ CheckInSheet.swift       the 3-tap sheet
├─ WeeklyRecapView.swift    the shareable card
└─ MascotView.swift         state machine + art
```

Android mirrors this at `android/Sources/Riftcount/Coach/` per the usual
independent-port rule.

`InsightEngine` and `QuestCatalog` evaluators must be **pure, `nonisolated`, and free of
SwiftUI** — that makes them unit-testable and keeps the Android port to a copy plus
Skip-specific fixes.

---

## 5. Layer 1 — Insights (fully automatic)

Everything here is derived from `GameRecord` + `ScoreEvent` + `Decklist` with **no new
user input**. Note that `GameReviewView` establishes the slot convention already in use:
**slot 1 = you, slot 0 = opponent** in 2p games.

### 5.1 Derived metrics

| Metric | Derivation |
|---|---|
| First score rate | Which slot owns the earliest `ScoreEvent` with `delta > 0` |
| Time to first point | `elapsedSeconds` of that event, yours vs theirs |
| Score pace | Total points ÷ `durationSeconds` |
| Lead curve | Running cumulative diff over ordered events |
| Comeback rate | Won games where your lead curve hit −3 or worse |
| Closeout rate | Games where you led by 3+ — how often that converted |
| Aggression profile | Your `conquer` count ÷ (`conquer` + `hold`) |
| Conquer share | Your conquers ÷ all conquers in the game |
| Length vs result | Winrate bucketed by duration (<15 / 15–25 / 25–40 / 40+ min) |
| Turn-order split | Winrate on the play vs on the draw (`startedFirst`) |
| Matchup table | Winrate by `opponent` legend name |
| Deck rotation | Games per deck, days since each deck last played |
| Cadence | Median games/week over the last 4 active weeks |
| Tracking hygiene | Share of events typed `manual` rather than `conquer`/`hold` |

### 5.2 Check-in–backed metrics

| Metric | Value |
|---|---|
| Mulligan rate + winrate on kept vs mulliganed hands | The single most common TCG leak, and it becomes measurable. A high keep rate paired with a low keep-winrate is a nameable, fixable habit. |
| Resource-trouble rate per deck | `screwed`/`flooded` share per deck cross-referenced with `DeckStatsView`'s energy buckets and domain power totals — turns a feeling into a deck-construction recommendation. Direct Coach → Deck Builder handoff. |
| Attribution mix | Distribution of `takeaway` across losses. If most losses are tagged `variance`, that is itself the finding. |

### 5.3 Honesty rules — non-negotiable

A coach that states confident nonsense from four games is worse than no coach.

- Every insight declares a **minimum sample size**. Below it, it is **not** shown as a
  finding — it is shown as a progress row: *"On the draw — collecting data (7/12 games)."*
  Thin data becomes a reason to log more, instead of a wrong conclusion.
- Suggested minimums: splits (turn order, mulligan) **n ≥ 12** with **n ≥ 5 per side**;
  per-matchup **n ≥ 6**; per-deck **n ≥ 8**; whole-profile **n ≥ 20**.
- Insights are phrased as observations plus one concrete next action, never as verdicts.
  *"You win 68% on the play and 39% on the draw (n=31). Your on-the-draw plan is the gap
  — try mulliganing more aggressively when you are second."*
- No insight is ever gated behind mascot level or streak. Progression unlocks cosmetics
  only. Gating self-improvement behind engagement is a dark pattern.

---

## 6. Layer 2 — The check-in (3 taps)

Fires after the user taps Won/Lost on the Scoreboard, replacing nothing in the existing
flow — the record is written first, the sheet is decoration on top and can be dismissed
with no consequence.

```
┌──────────────────────────────┐
│  Quick check-in      [Skip]  │
│                              │
│  Opening hand                │
│   [ Kept ]  [ Mulliganed ]   │   ← tap 1
│                              │
│  Resources                   │
│   [Smooth] [Screwed] [Flood] │   ← tap 2
│                              │
│  Takeaway (optional)         │
│   [Misplay][Matchup][Deck]   │   ← tap 3
│   [Variance][Clean]          │
│   ⌨︎ add a note…              │
└──────────────────────────────┘
```

Settings toggle `coachCheckInDepth`: **Off / Quick (taps 1–2) / Full (taps 1–3 + note)**.
Default **Quick**. Partial check-ins are valid — every field is optional, and the
Insight engine treats `nil` as "not captured", never as a value.

Design notes:
- Two rows of segmented buttons and a dismiss. No scrolling, no keyboard unless the user
  asks for one. If this ever takes longer than ~4 seconds it has failed.
- The sheet is also reachable later from `GameHistoryView` / `GameRecordEditSheet`, so a
  skipped check-in is recoverable without re-playing the game.
- On Android, watch the SkipUI segmented-control and sheet-sizing gotchas — see the
  `android-port.md` catalog before writing this screen.

---

## 7. Layer 3 — Quests, streak, progression

### 7.1 Three tiers of verification

| Tier | Verified by | Trust |
|---|---|---|
| **A — Auto** | Derived from records; user cannot claim it | Hard |
| **B — Check-in** | Structured self-report from §6 | Soft but honest — it is private |
| **C — Reflection** | Completing the quest *is* using the app feature | Hard by construction |

Tier C is quietly the strongest design: "review a loss and write a takeaway" has no
verification gap at all, because the act and the proof are the same event.

### 7.2 Catalog sketch

Targets below are written against a cadence of 4 games/week and scale (see §7.4).

**Tier A — auto**

| ID | Quest | Evaluation |
|---|---|---|
| `volume.play` | Play 4 games this week | Count records in week |
| `volume.deck_focus` | Play 3 games with one deck | Max games on a single `deckId` |
| `diversity.legends` | Face 3 different legends | Distinct `opponent` |
| `hygiene.typed_events` | Log 5 games using conquer/hold instead of manual adjust | Share of non-`manual` events |
| `tempo.first_score` | Score first in 3 games | Earliest positive-delta event is slot 1 |
| `tempo.fast_close` | Close a game in under 20 minutes | `durationSeconds` |
| `resilience.comeback` | Win a game after trailing by 3+ | Lead curve minimum |
| `practice.on_the_draw` | Play 2 games on the draw | `startedFirst == false` |

**Tier B — check-in backed**

| ID | Quest | Why it is a good quest |
|---|---|---|
| `discipline.mulligan` | Mulligan at least twice this week | Deliberately counterintuitive. Most players keep too much; the quest gives permission to throw a hand back and makes the habit visible. |
| `discipline.log_resources` | Record resources for 5 games | Feeds the deck-construction insight |
| `honesty.tag_losses` | Tag a takeaway on every loss this week | Builds the attribution dataset |

**Tier C — reflection**

| ID | Quest |
|---|---|
| `review.open_loss` | Open Game Review on a loss and write one sentence |
| `review.deck_stats` | Check Deck Stats for your lowest-winrate deck |
| `review.draw_odds` | Run Draw Odds on the deck you played most |
| `review.iterate` | Change a deck after losing with it (`Decklist.updatedAt` moves after a loss with that deck) |

### 7.3 Streak

**Weekly, never daily.** TCG players play on locals night. A daily streak is broken by
week two and the feature dies with it.

- A week counts if **at least one** of the three quests completes. Not all three.
- Week boundary: Monday 04:00 local. Late Sunday-night play belongs to the week it felt
  like.
- **Freeze**: one banked per 4 credited weeks, max 2 held, applied automatically on a
  missed week. The user is told after the fact, not asked.
- **Pause**: explicit hiatus in Settings (`pausedUntil`). Vacation, injury, format break.
  A paused week neither credits nor breaks.
- A broken streak is never rendered as failure. No red, no flame going out, no guilt
  copy. "Back at it — week 1" and the longest-streak record stays visible.

### 7.4 Cadence scaling — the thing that makes or breaks it

Quest targets are generated against the player's **own** median games/week over the last
four active weeks, clamped to 1…10, defaulting to 3 for a new user. Somebody who plays
twice a week must never see "play 8 games". Rough scaling: volume quests at
`ceil(cadence × 0.8)`, count quests at `max(1, round(cadence × 0.5))`.

Board generation each Monday picks exactly three: **one volume/rhythm, one skill
(Tier A or B) targeting the weakest measured area, one reflection**. No repeat of the
same `definitionID` two weeks running.

### 7.5 Progression

XP per completed quest → mascot levels. Levels unlock **cosmetics only**: expressions,
color variants, poses, maybe a title. Never analytics, never insights, never history.

---

## 8. The mascot

### 8.1 Role

Narrator, not gamemaster. It reads out one insight, hands over the quest board, reacts to
a completed week. Short lines. Encouraging, never scolding, never guilt-tripping about a
missed week or a lost game.

**Name [OPEN].** The repo is already called *Riftbound-**Consort***, which is sitting
right there. Alternatives welcome, but "your Consort" as a companion framing is strong
and costs nothing.

### 8.2 States

Minimum viable set, one illustration each:

| State | Trigger |
|---|---|
| `idle` | Default |
| `thinking` | A new insight crossed its minimum sample size |
| `happy` | Quest completed |
| `celebrating` | Streak milestone, level-up |
| `concerned` | A leak was detected (a bad split crossed threshold) |
| `sleepy` | No game logged in 7+ days |

Never a "disappointed" or "angry" state. The mascot does not have opinions about losing.

### 8.3 Asset pipeline — the real risk **[OPEN]**

This is the one decision with an unresolved technical cost, and it should be de-risked
**before** any mascot art is commissioned or drawn:

- **iOS** is easy: PNG imageset @1x/2x/3x, or a vector PDF, in `Assets.xcassets`.
- **Android/Skip** is the unknown. `CLAUDE.md` records that unmapped SF Symbols must
  become drawn `Shape`s or bundled symbolset SVGs with the full Apple template — that
  guidance is about *symbols*. How a plain raster imageset bridges through SkipUI is not
  yet established in this project.

**Action before art exists:** bundle one throwaway placeholder PNG imageset, render it in
the Android build, confirm it survives. A wrong assumption here is six illustrations
thrown away.

Fallback if raster bridging is painful: a single static body pose plus a swappable
expression drawn with SwiftUI `Shape`s — the parts that change stay code, the part that
does not stays an image.

---

## 9. Weekly recap card

Sunday evening (or on demand), a single shareable image: streak, quests completed, the
week's headline insight, games played, W/L. User-initiated export only — nothing leaves
the device unless the user taps share.

- **iOS**: SwiftUI view → `ImageRenderer` → `ShareLink`.
- **Android**: `ImageRenderer` bridging is unverified. Fallback is a full-screen
  screenshot-friendly layout with a share intent. Verify early, same as §8.3.

Design it as a card people would actually post — deck name, legend art, the numbers. It
is the only outward-facing surface of an otherwise fully private feature, and it is the
cheapest growth mechanism the app has.

---

## 10. Privacy

Everything stays on device: `coach.json` plus the extended `games.json`. No accounts, no
sync, no analytics, no backend. This matches the README's existing promise ("We do not
use or save any data") and is what makes the self-reported tier trustworthy — nobody is
watching, so there is nothing to game.

Consequence to accept deliberately: **no leaderboards and no friend comparison for Coach
progression.** A leaderboard built on self-reported data is a cheating contest.

---

## 11. Roadmap

Each phase ships to iOS first, then ports to Android with full design parity before the
next phase starts — per the standing dual-platform rule. Do not stack three iOS phases
and port at the end.

| Phase | Contents | Ships value? |
|---|---|---|
| **0 — Foundation** | `GameCheckIn` on `GameRecord`, `CoachStore`, `coach.json`, Settings toggle | No (plumbing) |
| **1 — Insights** | `InsightEngine`, Coach tab, insight list + detail, min-n gating | **Yes — instantly, on existing history** |
| **2 — Check-in** | `CheckInSheet`, hook into Won/Lost, retro-fill from history view | Yes |
| **3 — Quests + streak** | `QuestCatalog`, `QuestEngine`, board UI, cadence scaling, freeze/pause | Yes |
| **4 — Mascot** | Art, state machine, XP/levels, cosmetics | Yes |
| **5 — Recap card** | `WeeklyRecapView`, share export | Yes |

Phase 1 before Phase 2 is deliberate: Insights work retroactively against games the user
already logged, so the tab is not an empty shell on first open. Asking for check-ins
before the user has seen what check-ins buy them is the wrong order.

---

## 12. Open decisions

1. **Tab order** — which of the four visible slots Coach takes, and what gets pushed to
   "More" (§2.1). Recommendation: `Score, Events, Coach, Decks`.
2. **Mascot name** — "Consort" or something else (§8.1).
3. **Android asset bridging** — must be spiked before art is produced (§8.3).
4. **Android `ImageRenderer`** — must be spiked before the recap card is designed (§9).
5. **Takeaway tag set** — are five tags right? Fewer is faster, more is more diagnostic.
6. **Does the Coach ever use Events data** while it still exists — e.g. crediting a
   tournament day as a quest? Cheap now, but it builds a dependency on a service that is
   about to be removed. Recommendation: no.

---

## 13. Relationship to the Events sunset

The Coach is not a replacement for Events, and this document does not propose deleting
Events code. Recommended handling when the API goes dark:

- Keep `User/Events/` in the repo. If the successor service is reverse-engineered,
  swapping the base URL and the model layer is far cheaper than rebuilding the UI.
- The Scoreboard's match-mode strip degrades on its own — `MatchModeStore.refresh` fails
  closed and clears `active`, so the strip simply stops appearing. No crash path.
- The store finder is the biggest standalone loss and deserves its own decision later; it
  is unrelated to the Coach.
