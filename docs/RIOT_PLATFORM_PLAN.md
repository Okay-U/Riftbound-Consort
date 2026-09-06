# Riftcount on Riot's platform — RSO login, gateway, tournament data

**Handoff document.** Written 2026-09-04 for the agent that implements this in the
Riftcount repo. It is self-contained: every fact it relies on is stated here with its
source, so nothing needs to be re-researched. Nothing in it is implemented yet.

## 0. Read this first

**What Riftcount is.** A companion app for the Riftbound TCG: lore/score tracker, card
library, deck builder, and an Events tab that today talks to carde.io (the tournament
platform Riftbound used until now) via `api.riftbound.uvsgames.com/api/v2/` with an
email+password login. iOS in `Riftbound Companiokay/`, Android as a Skip app in
`android/`, independent source files per platform. Published as **Pitopia**, bundle id
`pitopia.Riftcount`, Apple Team `Q24SAC5FD2`, Android package `riftcount.module`.
Current version 3.3 (1). iOS deployment target 18.6.

**Rules that apply to this work** (the repo `CLAUDE.md` has the full set):

- Both platforms, iOS first, Android with full design parity. Fixing one never fixes the
  other. Consult the SkipUI gotcha catalog (memory `android-port.md`) before Android UI.
- The user builds iOS in Xcode himself. Do not run `xcodebuild`. `skip android build` and
  `skip export` are ours to run.
- **Never put the user's personal data — email, name, identifiers — into outbound
  headers, request bodies, query strings, or third-party services.** A User-Agent is app
  name + version only. This has burned us before.
- **This is a personal hobby project.** Do not propose or use any company domain, account,
  or infrastructure for it. Where a domain or hosting is needed, ask Okay which personal one
  to use.
- One feature at a time, small commits, the user reviews each. Commit only when asked.

**Why this document exists.** On Sept 4, 2026 Riot announced that from **Sept 14** all
Riftbound Organized Play — finding events, registering, pairings, recording results —
moves from carde.io to PlayRiftbound.com, with **Riot ID** sign-in. The Events tab as
built stops working that day. Okay has positive signals from Riot about an API key, and
confirmation that showing a player's pairings and reporting results is acceptable use.

## 1. Settled facts (each verified against a first-party source)

| Fact | Source | Consequence |
|---|---|---|
| Sept 14: players **and stores** use PlayRiftbound.com instead of carde.io | Riot announcement, Sept 4 | Local events leave carde.io that day; the old API keeps answering `200 OK` with an emptying list |
| Sign-in is Riot ID via RSO, no account linking | same | Login becomes OAuth against `auth.riotgames.com` |
| *"Do not include your API key in your code, especially if you plan on distributing a binary"* | Riot General Policies → Developer Safety | **A server is mandatory** for every Riot API call, the card catalogue included |
| Once keyed: *"Your App may only use Riftbound assets (including cards) provided by the Riot API. No external or unofficial materials."* | Riftbound Digital Tools Policy | riftcodex (`Cards/CardRepository.swift:17`) must be replaced |
| `riftbound-content-v1` has one endpoint, `GET /riftbound/content/v1/contents`, returning the whole catalogue with licensed art URLs | Developer Portal API reference | Card art becomes licensed — the opposite of the Lorecount/Disney situation |
| No tournament, event, match or registration endpoint exists for Riftbound on the portal today | same | Pairings/reporting are gated on Riot shipping or granting an API |
| RSO integration guidance is provided **after** app approval | Digital Tools Policy | Plan for the standard confidential-client flow; confirm details from the guide |
| Approved use cases named: deckbuilders, card libraries. Optional donations allowed. Prohibited: automated rules enforcement, standalone clients, ads, leaderboards / brackets-in-app / skill indicators, metagame data | Digital Tools Policy | Riftcount's scoreboard, cards and decks are squarely approved. Never add a ranking view |
| Required: official English card text; the Legal Jibber Jabber §6 statement visible in-app; no altered official formats or banlists | Digital Tools Policy | Add the statement to Acknowledgments in Phase 1 |

The server requirement decides the architecture by itself. Because the API key has to
live server-side anyway, the RSO `client_secret` rides on the same server at no extra
cost. There is no separate "do we need a backend for OAuth" decision.

### The content DTO (from the API reference)

```
GET /riftbound/content/v1/contents  →  RiftboundContentDTO
  game: string            version: string          lastUpdated: string (ISO)
  sets: [SetDTO]
    id, name
    cards: [CardDTO]
      id, collectorNumber (long), set, name, description, type, rarity, faction,
      stats: { energy, might, cost, power }  (all long)
      keywords: [string], tags: [string], flavorText
      art: { thumbnailURL, fullURL, artist }
```

The regional host for this call is shown in the API reference once logged in; Riot APIs
otherwise use hosts like `americas.api.riotgames.com`. Confirm before hardcoding.

## 2. Architecture: one gateway, stateless

A single Cloudflare Worker (or equivalent) on a domain Okay chooses. Working name
**Riftcount Gateway**. It holds exactly two secrets — the Riot API key and the RSO client
secret — and stores nothing about users.

```
                  ┌──────────────────────────────────────────────┐
  App ── HTTPS ──▶│  gateway.<domain>                            │
                  │                                              │── X-Riot-Token ─▶ Riot API
                  │  GET  /v1/content            cached catalogue│── Basic client ─▶ auth.riotgames.com/token
                  │  POST /v1/auth/exchange      code → tokens   │
                  │  POST /v1/auth/refresh       refresh → tokens│
                  │  POST /v1/auth/revoke        sign-out        │
                  │  GET  /auth/callback         RSO redirect target, static "return to app" page
                  │  GET  /.well-known/apple-app-site-association
                  │  GET  /.well-known/assetlinks.json
                  └──────────────────────────────────────────────┘
```

Gateway rules:

- **Stateless.** No user table, no token store, no cookies. Tokens go straight back to the
  device and live in the Keychain, as the carde.io token does today.
- **Never logs codes or tokens.** Request logging off for `/v1/auth/*`.
- **Secrets only in the Worker environment** (`RIOT_API_KEY`, `RSO_CLIENT_ID`,
  `RSO_CLIENT_SECRET`, `REDIRECT_URI`). Rotatable without an app update.
- `/v1/content` is a **cache**. Fetch once from Riot, serve to everyone with an ETag
  from the DTO's `version`, revalidate hourly. One Riot call per hour for the whole install
  base; rate limits stop mattering.
- `/v1/auth/exchange` takes `{code, code_verifier}` and returns Riot's token response
  unchanged. `redirect_uri` is the server-side constant, never taken from the client.
  Per-IP rate limit. `Cache-Control: no-store`.
- Anything Riot exposes later (tournament endpoints) is proxied the same way: the user's
  bearer forwarded, the app key added server-side.
- User-Agent towards Riot: `Riftcount-Gateway/1.0`. Nothing personal.

Privacy statement gains one paragraph: the gateway transits sign-in codes and tokens and
stores none; the card catalogue is served from our cache of Riot's data.

## 3. The login flow

### iOS

1. Generate `state` (32 random bytes, base64url), `nonce`, and a PKCE pair
   (`code_verifier` 43–128 chars, `code_challenge` = base64url(SHA256(verifier))). Send
   PKCE even if the RSO guide is silent about it: standard servers ignore unknown
   parameters, and if RSO honours it the code is bound to this device.
2. Authorize URL on `https://auth.riotgames.com/authorize` with `client_id`,
   `redirect_uri=https://gateway.<domain>/auth/callback`, `response_type=code`,
   `scope=openid offline_access` (exact scopes from the RSO guide), `state`, `nonce`,
   `code_challenge`, `code_challenge_method=S256`.
3. Present with `ASWebAuthenticationSession`, callback
   `.https(host: "gateway.<domain>", path: "/auth/callback")` — iOS 17.4+, we ship 18.6.
   The host must be in the app's **Associated Domains** entitlement; declare it under both
   `applinks:` and `webcredentials:` so the `.https` callback and the fallback universal
   link both work. `prefersEphemeralWebBrowserSession = false` so a player already signed
   into Riot in Safari is not asked again.
4. The session returns the callback URL. Verify `state` matches and is single-use.
5. `POST gateway/v1/auth/exchange` with `{code, code_verifier}` → token response.
6. Keychain via the existing `KeychainStore` pattern, three new accounts: `riotAccess`,
   `riotRefresh`, `riotExpiry`, all `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
   Check the id_token's `nonce`, then discard it — identity comes from the API, not from a
   stored JWT.
7. Identity: `GET /riot/account/v1/accounts/me` with `Authorization: Bearer <access>` →
   `puuid`, `gameName`, `tagLine`. Whether this also needs the app key is a question for
   the RSO guide; default direct-with-bearer, fallback via the gateway.
8. Refresh on 401 through `/v1/auth/refresh`. Sign-out calls `/v1/auth/revoke` and deletes
   the Keychain items outright.

The `/auth/callback` route on the gateway is also a real page: if the session does not
intercept the navigation, the page loads and universal-links back into the app.

### Android (Skip)

Same protocol, different plumbing:

- Open the authorize URL with `openURL` (Custom Tab / default browser).
- Riot redirects to `https://gateway.<domain>/auth/callback?code&state`. An **App Link**
  intent filter with `autoVerify` claims it; `assetlinks.json` on the gateway names the
  signing certificate.
- The app receives the URL via `onOpenURL`, then steps 4–8 as on iOS.

**assetlinks gotcha:** with Play App Signing the fingerprint must be the **Play app
signing key's** certificate (Play Console → Test and release → App integrity), not the
upload key in `Android/app/keystore.jks`. Debug builds need the debug cert added too, or
App Link verification fails silently in development.

**Spike first:** confirm SkipUI bridges `onOpenURL` and that the intent filter can be
added to `android/Android/app/src/main/AndroidManifest.xml`. If either fails, a ~40-line
Kotlin bridge does it. Half a day either way.

### What this removes

The email/password form. There is no password to type into a third-party app any more;
RSO never shows Riot credentials to us.

## 4. Code structure — swap implementations behind existing protocols

| Today | Plan |
|---|---|
| `Events/AuthService.swift` — `LocatorAuthService` (email+password → token) | Add `RiotAuthService` (RSO via gateway). Protocol grows `signIn(presenting:)`, `refresh()`, `signOut()` |
| `Events/AuthSession.swift` — signedOut / signedIn(user) | Provider-agnostic `RiotIdentity{puuid, gameName, tagLine}`. Restore-on-launch validates via `/accounts/me`, drops tokens on 401 |
| `Events/KeychainStore.swift` — one token | Accounts `riotAccess`, `riotRefresh`, `riotExpiry` |
| `Events/LoginView.swift` — form | `RiotSignInView`: one button, "Sign in with Riot ID", plus the unaffiliated disclaimer |
| `Events/LocatorAPI.swift` — carde.io REST | Rename the protocol `TournamentAPI`. `CardeioLocatorAPI` stays until Sept 14; `RiotTournamentAPI` when Riot ships endpoints. `EventsHomeView`, `MyEventsView`, `EventDetailView`, `MatchMode`, `ReportResultSheet` keep their shape |
| `Cards/CardRepository.swift:17` — `https://api.riftcodex.com` | `gateway/v1/content`; a mapper `RiftboundContentDTO → Card`. Then delete riftcodex and its line in `AcknowledgmentsView.swift` |

Every file has an independent Android twin in `android/Sources/Riftcount/`; both change.

## 5. Phases, with acceptance criteria

### Phase 0 — now → Sept 14. Needs no Riot credentials.

1. **Sunset notice in the Events tab, both platforms.** Copy in §6. Plus a low-water
   check: remember the count of the last successful nearby-events fetch; if a fresh fetch
   returns well under that (say < 30%) or zero, show the notice instead of an empty list.
   *Done when:* the notice renders in the emulator and simulator with an artificially
   emptied response; the tab still works normally with a full one. Ship as 3.3.x.
2. **Gateway skeleton.** `/v1/content` as a stub until a key exists, `/auth/callback`
   page, AASA and `assetlinks.json`. *Done when:* `curl` of both well-known files returns
   valid JSON with the identifiers above, served as `application/json`.
3. **Associated Domains + App Link.** Entitlement, intent filter, the Skip spike.
   *Done when:* tapping `https://gateway.<domain>/auth/callback?x=1` from Notes/Messages
   opens the app on both platforms.
4. **Client flow against a mock.** A gateway route that fakes `/authorize` (renders a
   button that redirects with a code) and `/token`. *Done when:* full sign-in round trip
   works on device on both platforms with tokens landing in the Keychain and a fake
   identity displayed. No Riot involvement.
5. **Application / follow-up with Riot** — questions in §6.

### Phase 1 — key and RSO credentials in hand

6. Real RSO. Ship **"Sign in with Riot ID"** showing the connected Riot ID, and an honest
   line that tournament data follows. *Done when:* sign-in, restore-on-launch, refresh,
   and sign-out all work on device, both platforms.
7. Cards via `gateway/v1/content`. Licensed art. Remove riftcodex. Add the Legal Jibber
   Jabber §6 statement to Acknowledgments. *Done when:* the card count matches the DTO's
   total (count it two ways — the catalogue layer has shipped short before), and no
   request to riftcodex remains (grep module-wide).

### Phase 2 — tournament endpoints available

8. `RiotTournamentAPI`: my events, my-match, pairings, standings, result submission.
   Match mode returns. Effort unknowable until shapes are known; 3–5 days if they resemble
   carde.io's.

### Phase 3 — cleanup

9. Delete `CardeioLocatorAPI`, `LocatorAuthService`, the email/password `LoginView`, the
   carde.io models. Module-wide dead-code check on both platforms before deleting anything
   — a symbol that looks unused in one file has broken the Android build before.

## 6. Ready-to-use artifacts

### Sunset notice (English UI)

```
Title:  Events are moving
Body:   From September 14, Riftbound tournaments run on PlayRiftbound.com with your
        Riot ID, and new events no longer appear here. We're connecting Riftcount to
        the new platform — until then, find and register for events on PlayRiftbound.com.
Button: Open PlayRiftbound.com   →  https://playriftbound.com
```

### Associated Domains entitlement (iOS)

```xml
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:gateway.<domain></string>
  <string>webcredentials:gateway.<domain></string>
</array>
```

### `/.well-known/apple-app-site-association` (no file extension, `application/json`)

```json
{
  "applinks": {
    "details": [
      { "appIDs": ["Q24SAC5FD2.pitopia.Riftcount"],
        "components": [ { "/": "/auth/callback*" } ] }
    ]
  },
  "webcredentials": { "apps": ["Q24SAC5FD2.pitopia.Riftcount"] }
}
```

### `/.well-known/assetlinks.json`

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "pitopia.Riftcount",
    "sha256_cert_fingerprints": ["<PLAY APP SIGNING CERT SHA-256>", "<DEBUG CERT SHA-256>"]
  }
}]
```

### Android intent filter (in the app's `<activity>`)

```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW"/>
  <category android:name="android.intent.category.DEFAULT"/>
  <category android:name="android.intent.category.BROWSABLE"/>
  <data android:scheme="https" android:host="gateway.<domain>" android:path="/auth/callback"/>
</intent-filter>
```

### Worker sketch (TypeScript, Cloudflare). Token endpoint and client-auth method to be confirmed from the RSO guide.

```ts
export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const { pathname } = new URL(req.url);
    if (pathname === "/v1/content") return content(env);
    if (pathname === "/v1/auth/exchange" && req.method === "POST") return token(req, env, "authorization_code");
    if (pathname === "/v1/auth/refresh"  && req.method === "POST") return token(req, env, "refresh_token");
    if (pathname === "/auth/callback") return html(RETURN_TO_APP_PAGE);
    if (pathname === "/.well-known/apple-app-site-association") return json(AASA);
    if (pathname === "/.well-known/assetlinks.json") return json(ASSETLINKS);
    return new Response("not found", { status: 404 });
  }
};

async function token(req: Request, env: Env, grant: string): Promise<Response> {
  const b = await req.json();
  const form = new URLSearchParams({ grant_type: grant });
  if (grant === "authorization_code") {
    form.set("code", b.code);
    form.set("redirect_uri", env.REDIRECT_URI);            // server constant, never from client
    if (b.code_verifier) form.set("code_verifier", b.code_verifier);
  } else {
    form.set("refresh_token", b.refresh_token);
  }
  const r = await fetch("https://auth.riotgames.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      "Authorization": "Basic " + btoa(`${env.RSO_CLIENT_ID}:${env.RSO_CLIENT_SECRET}`),
      "User-Agent": "Riftcount-Gateway/1.0",
    },
    body: form,
  });
  return new Response(r.body, { status: r.status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" } });
}

async function content(env: Env): Promise<Response> {
  const cache = caches.default;
  const key = new Request("https://gateway.internal/v1/content");
  const hit = await cache.match(key);
  if (hit) return hit;
  const r = await fetch(`https://${env.RIOT_CONTENT_HOST}/riftbound/content/v1/contents`, {
    headers: { "X-Riot-Token": env.RIOT_API_KEY, "User-Agent": "Riftcount-Gateway/1.0" },
  });
  if (!r.ok) return new Response("upstream", { status: 502 });
  const body = await r.text();
  const res = new Response(body, { headers: {
    "Content-Type": "application/json",
    "Cache-Control": "public, max-age=3600",
    "ETag": `"${JSON.parse(body).version}"`,
  }});
  await cache.put(key, res.clone());
  return res;
}
```

### Swift sketch (iOS)

```swift
import AuthenticationServices
import CryptoKit

let verifier  = randomBase64URL(bytes: 32)
let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded
let state     = randomBase64URL(bytes: 32)

var c = URLComponents(string: "https://auth.riotgames.com/authorize")!
c.queryItems = [
    .init(name: "client_id", value: rsoClientID),           // public, not a secret
    .init(name: "redirect_uri", value: "https://gateway.<domain>/auth/callback"),
    .init(name: "response_type", value: "code"),
    .init(name: "scope", value: "openid offline_access"),   // confirm from the RSO guide
    .init(name: "state", value: state),
    .init(name: "nonce", value: randomBase64URL(bytes: 16)),
    .init(name: "code_challenge", value: challenge),
    .init(name: "code_challenge_method", value: "S256"),
]

let session = ASWebAuthenticationSession(
    url: c.url!,
    callback: .https(host: "gateway.<domain>", path: "/auth/callback")
) { url, error in
    // verify state, extract code, POST {code, code_verifier} to gateway/v1/auth/exchange
}
session.prefersEphemeralWebBrowserSession = false
session.presentationContextProvider = contextProvider
session.start()
```

### Questions to send Riot (in the key application or its support thread)

```
1. Redirect URIs for a native mobile app: HTTPS only, or are custom URL schemes accepted?
2. Does RSO support PKCE (code_challenge / code_verifier) and/or public clients without
   a client secret? We can run a confidential client behind our own gateway either way,
   but a public client would let us drop that component.
3. Which scopes does a Riftbound companion need for identity (accounts/me), and does
   that call require the application API key in addition to the user's bearer token?
4. Tournament data: is an API for a player's registrations, current pairing/table,
   standings and result submission planned or available on request for an approved
   Riftbound app? Timeline and shape, if so.
5. Token lifetimes and refresh policy.
```

## 7. Security checklist

- `state` (CSRF) single-use, verified before the code leaves the device. `nonce` checked on
  the id_token. PKCE for code binding.
- Gateway validates nothing from the client except the code and verifier; `redirect_uri`
  is a constant. It never proxies arbitrary URLs.
- No code or token in gateway logs. Secrets in environment only.
- Tokens in Keychain, `ThisDeviceOnly`. Refresh on 401 rather than retry. Revoke on
  sign-out. Never persist the id_token.
- Universal Links / App Links tie the callback host to the Team ID and signing cert; no
  other app can claim the callback.
- Riot's API key never reaches a device. This is the policy requirement, satisfied by
  design.
- No personal identifiers in any outbound header. User-Agent is app name + version.

## 8. Open questions

| Question | Answered by |
|---|---|
| PKCE / public client support | RSO guide, post-approval. Architecture unchanged either way — the gateway exists for the API key regardless |
| Redirect URI rules for mobile | RSO guide |
| Scopes; auth for `accounts/me` | RSO guide |
| Tournament endpoints: exist? timeline? shape? | Riot, in the key thread. **Phase 2 is gated on this** |
| SkipUI `onOpenURL` and manifest intent filters | Our spike, Phase 0 step 3 |
| Content API regional host | API reference, logged in |
| App Store guideline 4.8 (Sign in with Apple) | Does not apply: the app creates no account of its own, it accesses the user's existing Riot data through a standard OAuth flow |

## 9. Decisions needed from Okay before Phase 0 step 2

1. **Domain for the gateway** — one that belongs to him personally or to the project.
   The host appears in the callback URL, in the AASA/assetlinks files, and in Riot's
   consent redirect. It does not need to be pretty; it needs to be his.
2. **Hosting** — Cloudflare Workers suggested (free tier covers this, edge cache for the
   catalogue, secrets built in). Vercel functions are equivalent.
3. **Go for Phase 0.** Steps 1–4 need no Riot credentials; step 1 has a hard date.
