# PlayRiftbound integration

Single reference for everything about Riot's organized-play platform: the plan, the in-app
browser, the approved session client, and what the site's public code reveals. Replaces
`RIOT_PLATFORM_PLAN.md`, `IN_APP_BROWSER.md` and `PLAYRIFTBOUND_SITE_MAP.md` (2026-09-07).

## 1. Situation

- On 2026-09-14 Riftbound organized play moves from carde.io (the Locator the Events tab
  talks to) to PlayRiftbound.com with Riot ID sign-in. Everything the Locator segments do
  (events, pairings, standings, register, drop, report, match-mode strip, store calendar,
  opponent scouting) stops receiving data that day. Store finder and eloshowdown profile decay.
- Riot has no public tournament API and announced no timeline. Riftbound RSO clients are
  granted only to gameplay simulators, so a companion app cannot get its own Riot login.
- Riot's Digital Tools Policy: card libraries, deckbuilders, scoreboards approved; leaderboards,
  brackets-in-app, skill indicators, metagame data prohibited; an API key must never ship in a
  binary; Legal Jibber Jabber ties App Store presence to a valid key. Okay's developer
  application is filed (`riot.txt` on okay-u.github.io).
- Riot gave Okay written approval (2026-09-07, held by Okay, not in the repo) for an approved
  app to read `PlayerTournaments` and `GetCompeteTournamentForRiftboundPlayer` and call
  `SubmitGameResults` on behalf of the signed-in player using their own Riot session.

## 2. Plan

| Phase | When | What | Status |
|---|---|---|---|
| 0 | before Sept 14 | "New Events" segment in the Events tab: domain-locked browser to PlayRiftbound, both platforms. Locator segments get a date-gated sunset notice. Ship as 3.3.x. | iOS done on `feature/playriftbound-browser`, device-tested (login, persistence, card gallery). Android port next. Sunset notice open. |
| 1 | Sept 14+ | Okay walks the live player flow from Xcode. Capture: URL paths (debug log), one request/response per GraphQL operation via Safari Web Inspector (endpoint, header names, query text vs persisted hash, cookie names). Never share cookie values. | open |
| 2 | after 1 | **Session client** (approved scope, §4). Match-mode strip and Report button return, fed by the Compete GraphQL. Navigation-only deep links as fallback. | open |
| 3 | if Riot grants a content API key | Gateway for the card catalogue (§6); riftcodex removed per policy. | open |
| later | | Delete `CardeioLocatorAPI`, `LocatorAuthService`, email/password `LoginView`, carde.io models, on both platforms, after a module-wide dead-code check. | open |

## 3. The in-app browser ("New Events" segment)

Why a web view: `SFSafariViewController` and Chrome Custom Tabs cannot restrict navigation
(notification-only delegates, no allowlist option). Only `WKWebView` (iOS) and Android
`WebView` via SkipWeb expose a navigation-policy hook.

**Files.** iOS `User/Events/PlayRiftboundView.swift` (policy + `WKWebView` model/delegate + view),
`EventsHomeView.swift` (segment "New Events", second in the strip, model created on first tap and owned there so
the page survives segment switches and Locator sign-in/out; Locator segments show `LoginView`
when signed out), `EventsTabView.swift` (no longer gates the whole tab). Android twins under
`android/Sources/Riftcount/Events/`, `skip-web` dependency in `android/Package.swift`.

**Allowlist (top-level navigations, https only, suffix match).**
- `playriftbound.com` (covers `events.`, `rgn.`, `xsso.`)
- `riftbound.leagueoflegends.com` (the site's nav sends Card Gallery, News, Rules Hub there; the server redirects each to the same path on playriftbound.com, so this is a redirect hop that also costs a WebKit process swap)
- `authenticate.riotgames.com`, `auth.riotgames.com` (Riot sign-in; not all of riotgames.com)

Deliberately not allowed, opens in the system browser: `locator.riftbound.uvsgames.com`
(native segments exist; nav flips to PlayRiftbound on Sept 14), `support.riotgames.com`,
`merch.riotgames.com`, `www.riotgames.com` legal pages, `account.riotgames.com`
(add-a-password page, opened from the hint), social links.

**Rules.**
- iOS: `decidePolicyFor` polices main-frame navigations only (`targetFrame == nil || isMainFrame`);
  sub-frames (hCaptcha, consent) and sub-resources pass. `about:` allowed for page setup.
  Popups (`createWebViewWith`) load allowed https URLs in the same view, else hand off, return nil.
- Android: `shouldOverrideUrlLoading` also fires for iframe navigations and never for POST, so
  known frame hosts (hcaptcha.com, osano.com, googletagmanager.com) are allowed silently.
- Hand-off schemes: http, https, mailto, tel. Everything else dropped.
- **Social sign-in block:** a non-Riot destination reached from a `riotgames.com` page is a
  third-party identity provider. Cancel, show the notice, never hand off (the Riot session would
  land in the system browser's cookie jar). Riot's own off-allowlist pages (password recovery,
  signup, legal) do hand off.
- Web view frame ignores the keyboard safe area; WKWebView scrolls the field itself.
- Killed web-content process reloads (`backForwardList.currentItem`), no error card.
- KVO publishers without a `RunLoop.main` hop (it stalls while the page scrolls).

**Sign-in options and the Google ceiling.** Riot's login page for the PlayRiftbound client
offers Riot ID + password and Facebook, Google, Apple, Xbox, PlayStation. Google refuses every
embedded web view (`disallowed_useragent`, enforced since 2021). Decision: Riot ID + password
only inside the app. Hint on Riot pages links social-only users to account.riotgames.com →
"Riot Account Sign-In" to add a password (Riot-documented; accounts cannot be merged).

**Session and sign-out.** iOS: own persistent store `WKWebsiteDataStore(forIdentifier:)`,
isolated from `HTTPCookieStorage.shared` and every app URLSession. "Sign out of Riot" removes
records whose `displayName` matches `playriftbound.com` / `riotgames.com`. Android: `CookieManager`
persists automatically; no per-host clear, `clearCookies()` removes all (only Riot cookies live
there). Never `evaluateJavaScript`, user scripts, or message handlers in the browser itself.

**Known gaps.** Events onboarding tour still describes a Locator-only tab. `LoginView` title says
"Events" under the Stores/Profile segments. Both wait for the final tab shape after Sept 14.

## 4. Session client (approved scope)

Purpose: match-mode strip (table, opponent, round) and Report button on the scoreboard, fed by
Riot's platform, without the player leaving the app.

- **Mechanics.** At call time read the `playriftbound.com` cookies from the web view's cookie
  store into memory; POST the GraphQL operation to the site's `/api/gql` with the same
  `URLSession` pattern as `LocatorAPI`; decode into the existing match-mode models behind the
  existing protocol (`LocatorService` → `TournamentAPI`). `SubmitGameResults` drives Report.
  Nothing persisted beyond the web view's own store.
- **Fallback if Cloudflare bot management rejects a non-browser client:** run our own
  `fetch('/api/gql')` inside the web view via `evaluateJavaScript`. Still our request; never read
  Riot's page or login screens. Decide after the Phase 1 spike.
- **Failure mode.** 401/403/`PersistedQueryNotFound` → strip shows "Open in PlayRiftbound"
  (navigation into the New Events segment) and logs. The browser is the site itself and never breaks.
- **Change resilience.** Keep operation texts / persisted-query hashes in a small JSON on
  okay-u.github.io (same pattern as `errata.json`) so a Riot deploy is a file edit, not an app
  release. Add when the first breakage happens, not before.
- **Never:** JavaScript injection that reads Riot's pages or patches `fetch`; anything on
  `riotgames.com` hosts; rank or leaderboard views built on Riot data.
- **Paperwork.** Privacy policy §4 reworded (session cookies stored by the system web view in
  the app sandbox; the app sends the player's own requests with them). App Store Notes for
  Review cite Riot's approval.

## 5. What the site's public code reveals

Source: 34 JavaScript chunks served from `events.playriftbound.com/_next/static/chunks/`,
referenced by the not-yet-live `playriftbound.com/en-US/events/` page. Read for structure only.
Shapes may change at launch.

- Riot's shared **Compete** tournament platform (TFT/LoL esports code in the same bundles,
  `competitiveops.riotgames.com` referenced). Next.js, same-origin GraphQL at `/graphql` and
  `/api/gql` (Apollo). Sign-in via Riot's XSSO widget (`window.xsso`), client
  `prod-xsso-playriftbound`, redirect `xsso.playriftbound.com`, scope
  `openid account email offline_access`, PKCE S256.
- Telemetry on Riot's pages: Datadog RUM, Google Tag Manager, Statsig, `data.riotgames.com`.
- Client routes: `/{locale}/events/{eventId}`, `/{locale}/tournament/{tournamentId}`,
  `/{locale}/player/profile`. Sub-routes for pairings/report not visible in client code.
- Sign-in hosts observed live: `authenticate.riotgames.com`, `auth.riotgames.com`,
  `xsso.playriftbound.com`, `rgn.playriftbound.com`. Frame/resource hosts:
  `lolstatic-a.akamaihd.net`, `*.hcaptcha.com`, `cmp.osano.com`.

| Operation | Kind | Purpose |
|---|---|---|
| `CompeteTournamentSearch` | query | event finder with filter / sort / cursor paging |
| `PlayerTournaments` | query | my upcoming + past registrations (**approved**) |
| `PlayerRegisteredTournamentIds` | query | ids of my registrations |
| `GetCompeteTournamentForRiftboundPlayer` | query | one tournament: stages > sections > rounds > matches, standings, registrants (**approved**) |
| `SubmitGameResults` | mutation | player result report (**approved**) |
| `DropCompetePlayerFromTournament` | mutation | drop |
| `GetCompetePlayer` / `AddCompetePlayer` / `UpdateCompetePlayer` | query/mutation | Compete player profile |
| `FavoriteOrganizer` / `UnfavoriteOrganizer` / `FavoritedOrganizers` | mutation/query | favourite stores |

Organizer-side (not for us): `GetCompeteTournamentForRiftboundAdmin`, `GeneratePairings`,
`PublishPairings`, `FinalizeRound`, `SubmitGameResultsAsOrganizer`, `RegisterTournamentRegistrants`.

Same nouns as the Locator models in `User/Events/LocatorModels.swift`: tournament > stage >
round > match with per-team outcomes and games, end-of-round standings with tiebreakers,
registrant status with check-in, drop, player result submission. A model swap, not a rewrite.

### Exact GraphQL text (from the bundles)

### CompeteRbTournament
```graphql
fragment CompeteRbTournament on CompeteTournament {
    id
    name
    description
    tournamentProgram {
      id
      programName
    }
    registrationStartAt
    registrationEndAt
    startsAt
    endsAt
    registrationPolicy
    visibility
    pricing
    entryFee {
      currency
      minorUnits
    }
    registrantCounts {
      status
      count
    }
    stages {
      ...CompeteRbStage
    }
    config {
      ... on RiftboundTournamentConfig {
        tournamentType
        format
        playerFormat
        structure
        matchFormat
        participantCapacity
        waitlistCapacity
        roundCount
        deckSubmissionPolicy
      }
    }
    tournamentRegistrants {
      ...CompeteRbRegistrant
    }
    tournamentParticipants {
      ...CompeteRbParticipant
    }
  }
```

### CompeteRbStage
```graphql
fragment CompeteRbStage on CompeteStage {
    esportsStageId
    name
    sections {
      ...CompeteRbSection
    }
  }
```

### CompeteRbSection
```graphql
fragment CompeteRbSection on CompeteSection {
    esportsSectionId
    rounds {
      ...CompeteRbRound
    }
    ranks {
      position
      esportsTeamId
    }
  }
```

### CompeteRbRound
```graphql
fragment CompeteRbRound on CompeteRound {
    roundNumber
    status
    byeTeamIds
    startedAt
    droppedTeamIds
    matches {
      ...CompeteRbMatch
    }
    endOfRoundStandings {
      rank
      esportsTeamId
      matchPoints
      matchWinPercentage
      opponentMatchWinPercentage
      gameWinPercentage
      opponentGameWinPercentage
      matchWins
      matchLosses
      matchDraws
    }
  }
```

### CompeteRbMatch
```graphql
fragment CompeteRbMatch on CompeteMatch {
    config {
      ... on CompeteBestOfConfig {
        count
      }
      ... on CompetePlayAllConfig {
        count
      }
    }
    esportsMatchId
    status
    teamOutcomes {
      outcome
      esportsTeamId
    }
    games {
      esportsGameId
      number
      teamOutcomes {
        esportsTeamId
        outcome
      }
    }
    teams {
      ...CompeteRbTeam
    }
  }
```

### CompeteRbTeam
```graphql
fragment CompeteRbTeam on CompeteTeam {
    esportsTeamId
    players {
      id
      displayName
    }
  }
```

### CompeteRbParticipant
```graphql
fragment CompeteRbParticipant on CompeteTournamentParticipant {
    id
    type
    position
    points
    status
    esportsTeamId
    status
    player {
      id
      type
      tagLine
      displayName
    }
  }
```

### CompeteRbRegistrant
```graphql
fragment CompeteRbRegistrant on TournamentRegistrant {
    id
    status
    checkedIn
    checkedInAt
    acceptedTermsAt
    waitlistPosition
    player {
      id
      type
      tagLine
      displayName
    }
  }
```

### GetCompeteTournamentForRiftboundPlayer
```graphql
query GetCompeteTournamentForRiftboundPlayer($tournamentId: String!) {
    competeTournaments(
      esportsTournamentIds: [$tournamentId]
      showDraftPairings: true
    ) {
      ...CompeteRbTournament
    }
  }
```

### PlayerTournaments
```graphql
query PlayerTournaments(
    $upcomingFirst: Int
    $pastFirst: Int
    $upcomingAfter: String
    $pastAfter: String
  ) {
    playerTournaments {
      upcoming(first: $upcomingFirst, after: $upcomingAfter) {
        edges {
          cursor
          node {
            ... on RbPlayerTournamentResult {
              organizer {
                id
                name
                isFavorited
                physicalAddress {
                  city
                  adminArea1
                }
              }
              tournament {
                id
                name
                startsAt
                pricing
                entryFee {
                  currency
                  minorUnits
                }
                registrantCounts {
                  status
                  count
                }
                config {
                  ... on RiftboundTournamentConfig {
                    tournamentType
                    format
                    playerFormat
                    participantCapacity
                  }
                }
              }
            }
          }
        }
        pageInfo {
          endCursor
          hasNextPage
        }
      }
      past(first: $pastFirst, after: $pastAfter) {
        edges {
          cursor
          node {
            ... on RbPlayerTournamentResult {
              organizer {
                id
                name
                isFavorited
                physicalAddress {
                  city
                  adminArea1
                }
              }
              tournament {
                id
                name
                startsAt
                pricing
                entryFee {
                  currency
                  minorUnits
                }
                registrantCounts {
                  status
                  count
                }
                config {
                  ... on RiftboundTournamentConfig {
                    tournamentType
                    format
                    playerFormat
                    participantCapacity
                  }
                }
              }
            }
          }
        }
        pageInfo {
          endCursor
          hasNextPage
        }
      }
    }
  }
```

### PlayerRegisteredTournamentIds
```graphql
query PlayerRegisteredTournamentIds($first: Int) {
    playerTournaments {
      upcoming(first: $first) {
        edges {
          node {
            ... on RbPlayerTournamentResult {
              tournament {
                id
              }
            }
          }
        }
      }
    }
  }
```

### CompeteTournamentSearch
```graphql
query CompeteTournamentSearch(
    $sport: Sport!
    $filter: CompeteTournamentSearchFilterInput!
    $sortBy: CompeteTournamentSearchSortInput
    $first: Int
    $after: String
  ) {
    competeTournamentSearch(
      sport: $sport
      filter: $filter
      sortBy: $sortBy
      first: $first
      after: $after
    ) {
      edges {
        cursor
        node {
          ... on RbTournamentSearchResult {
            distanceMeters
            organizer {
              id
              name
              isFavorited
              physicalAddress {
                city
                adminArea1
                formattedAddress
                latitude
                longitude
              }
            }
            tournament {
              id
              name
              startsAt
              pricing
              entryFee {
                currency
                minorUnits
              }
              registrantCounts {
                status
                count
              }
              config {
                ... on RiftboundTournamentConfig {
                  tournamentType
                  format
                  playerFormat
                  participantCapacity
                }
              }
            }
          }
        }
      }
      pageInfo {
        endCursor
        hasNextPage
      }
    }
  }
```

### SubmitGameResults
```graphql
mutation SubmitGameResults($input: SubmitGameResultsInput!) {
    submitGameResults(input: $input) {
      submittedGameIds
    }
  }
```

### DropCompetePlayerFromTournament
```graphql
mutation DropCompetePlayerFromTournament($esportsTournamentId: String!) {
    dropCompetePlayerFromTournament(esportsTournamentId: $esportsTournamentId)
  }
```

### GetCompetePlayer
```graphql
query GetCompetePlayer($sport: Sport) {
    competePlayer(sport: $sport) {
      id
      displayName
      tagLine
      shard
      tournamentRealmDisplayNameCurrent
      tournamentRealmDisplayNameRequested
      tournamentRealmLogin
      tournamentRealmPassword
      assets {
        id
        playerId
        type
        value
      }
    }
  }
```

### UpdateCompetePlayer
```graphql
mutation UpdateCompetePlayer($input: CompetePlayerInput!) {
    updateCompetePlayer(input: $input) {
      id
      tournamentRealmDisplayNameCurrent
      tournamentRealmDisplayNameRequested
      assets {
        id
        playerId
        type
        value
      }
    }
  }
```

### AddCompetePlayer
```graphql
mutation AddCompetePlayer($input: CompetePlayerInput!) {
    addCompetePlayer(input: $input) {
      id
      tournamentRealmDisplayNameCurrent
      tournamentRealmDisplayNameRequested
      assets {
        id
        playerId
        type
        value
      }
    }
  }
```

### FavoriteOrganizer
```graphql
mutation FavoriteOrganizer($organizerId: ID!) {
    favoriteOrganizer(organizerId: $organizerId)
  }
```

### FavoritedOrganizers
```graphql
query FavoritedOrganizers {
    favoritedOrganizers {
      id
      name
      isFavorited
      physicalAddress {
        formattedAddress
      }
    }
  }
```


## 6. If Riot grants a content API key: cards gateway

Policy requires the key to stay off devices, and once keyed the app may only use card assets
from the Riot API (riftcodex must go, `Cards/CardRepository.swift`). One stateless Cloudflare
Worker (or equivalent) on a personal domain Okay chooses:

- `GET /v1/content` → cached `GET /riftbound/content/v1/contents` (whole catalogue with licensed
  art URLs; DTO: sets[] > cards[] with id, collectorNumber, name, description, type, rarity,
  faction, stats{energy, might, cost, power}, keywords, tags, flavorText, art{thumbnailURL,
  fullURL, artist}). ETag from the DTO `version`, revalidate hourly. One Riot call per hour for
  the whole install base.
- Secrets only in the Worker environment. No user data, no logs of anything personal.
  User-Agent `Riftcount-Gateway/1.0`.
- App: mapper `RiftboundContentDTO → Card`, then delete riftcodex and its acknowledgment line.
  Count the catalogue two ways (it has shipped short before). Add the Legal Jibber Jabber §6
  statement to Acknowledgments (already on the website).
- Regional host for the content call is shown in the API reference once logged in.

## 7. Review and policy notes

- Apple 4.2 (repackaged website) is not a risk given the native feature set. 5.2.2 (third-party
  content needs permission) is the exposure: describe the browser and the approved session client
  in Notes for Review. 4.8 does not apply (no app account, Riot's own sign-in on Riot's page).
- Riot TOS §7.1 (third-party programs interacting with Riot Services) is what the approval covers;
  stay inside the approved three operations.
- Never add a ranking or leaderboard view on Riot data; never retain metagame data.
