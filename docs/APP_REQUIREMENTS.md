# App → Backend Requirements (single source of what the APP needs)

**Purpose.** This file is maintained by the **Flutter app session** and lists
**every backend endpoint the app actually calls**, the exact request it sends,
and the exact response shape it expects (i.e. how the app parses it). The
**backend session should read this file from the repo and build/verify against
it** so the two sides stay aligned.

- Direction: **app consumes → backend provides.** (The full formal API lives in
  `BACKEND_CONTRACT.md`; this file is the app's live consumption checklist.)
- Base URL: `https://millimore-backend.onrender.com/v1`
- Auth: `Authorization: Bearer <JWT>` on every authed call.
- Error shape the app parses: `{ "error": { "code", "message" } }` + HTTP status.
- List shape the app parses: either a raw array `[...]` **or** `{ "items": [...], "nextCursor": "?" }` (the app accepts both).
- Client code that defines these expectations:
  `lib/services/auth_api.dart`, `lib/services/backend_api.dart`,
  `lib/models/api_models.dart`.

**Status legend:** ✅ wired & relied on · 🟡 wired, needs backend verify ·
🔴 app needs this, not confirmed live yet · ⏳ future (milestone 4–6).

---

## 1. Auth & user — milestone 1 ✅
| Method · Path | App sends | App expects back | Status |
| --- | --- | --- | --- |
| POST `/auth/login` | `{ email, password }` | `{ token, user }` | ✅ |
| POST `/auth/register/follower` | `{ name, phone, residenceIso, experience?, interests?, photoUrl? }` | `{ token, user }` | ✅ |
| POST `/auth/register/creator` | `{ name, phone, residenceIso, market, platform, verification }` | `{ token, user }` (creatorStatus `pending`) | ✅ |
| POST `/auth/otp/request` | `{ phone }` | `{ requestId, devCode? }` | 🟡 |
| POST `/auth/otp/verify` | `{ requestId, code }` | `{ token, user }` | 🟡 |
| GET `/me` | — | `{ user }` | 🟡 |
| PATCH `/me` | `{ name?, photoUrl?, username?, market?, platform? }` | `{ user }` | 🔴 (edit-profile screen pending) |

**`user` object the app reads** (into `UserProfile`): `id, name, photoUrl,
role (follower|creator|admin), creatorStatus (none|pending|approved|rejected|suspended),
market, platform, residenceIso, residenceCountry`.

---

## 2. Creator verification — milestone 2 ✅
| Method · Path | App sends | App expects | Status |
| --- | --- | --- | --- |
| GET `/creator/status` | — | `{ creatorStatus, reason? }` | ✅ (Studio "Check status") |
| POST `/creator/apply` | `{ market, platform, verification }` | `{ creatorStatus }` | 🟡 |

---

## 3. Brokers & accounts — milestone 2
| Method · Path | App sends | App expects | Status |
| --- | --- | --- | --- |
| GET `/brokers?country=<iso>` | — | `[ { id, name, domain, logoUrl?, recommended } ]` | ✅ (add-account sheet) |
| GET `/accounts` | — | `[ TradingAccount ]` | 🔴 (screen still shows locally-added; needs wiring to list) |
| POST `/accounts` | `{ brokerId, accountNumber, server, password, currency? }` | the created account (password never returned) | ✅ |
| DELETE `/accounts/{id}` | — | 200 | 🔴 (needs real account id round-trip) |
| POST `/accounts/{id}/password` | `{ current, next }` | 200 | 🔴 |

`TradingAccount` app reads: `id, brokerId, brokerName, accountNumber, masked,
server, currency, balance, status (connected|pending|disconnected|error), connectedAt`.

---

## 4. Traders / discover — milestone 3 ✅ (drives Discover, Home, Leaderboard, Search)
| Method · Path | App sends | App expects | Status |
| --- | --- | --- | --- |
| GET `/traders?sort=copiers|return&q=&category=&cursor=` | — | `{ items: [Trader], nextCursor? }` | ✅ Home rail, Leaderboard, Search |
| GET `/traders/{id}` | — | `Trader` (or `{ trader }`) | 🟡 (profile uses passed trader) |
| GET `/traders/{id}/posts` | — | `[Post]` | ✅ trader profile |
| GET `/traders/{id}/trades?status=active|closed` | — | `[PublicTrade]` | ✅ trader profile |
| GET `/traders/{id}/equity?range=30d` | — | `[ { t, value } ]` | 🔴 (chart still synthetic) |
| GET `/discover/reels` | — | `[Reel]` | ✅ Discover feed |

**IMPORTANT for "Aisha not showing":** `GET /traders` (and search `?q=`) **must
include creators immediately after they are approved** in admin. If an approved
creator has no trades yet, they should still appear (with zeroed stats), or the
app can never surface them. Please confirm approved-but-no-activity creators are
returned.

`Trader` app reads: `id, name, username, photoUrl?, isVerified, isLive,
returnPercent, returnDays, followers, copiers, aum, winRate, maxDrawdown,
totalTrades, category, tags[], bio?`.

`Reel` app reads: `kind (live|trade|lesson), trader (Trader), post? (Post),
title?, points[], viewers?`.

---

## 5. Feed & social — milestone 3 (drives Home feed, likes, saves, comments, follows)
| Method · Path | App sends | App expects | Status |
| --- | --- | --- | --- |
| GET `/feed?cursor=` | — | `[Post]` (posts from traders the user follows) | ✅ Home feed |
| GET `/subscriptions` | — | `[Trader]` | ✅ loaded on home open |
| POST `/subscriptions/{traderId}` | — | 200/201 | ✅ follow |
| DELETE `/subscriptions/{traderId}` | — | 200 | ✅ unfollow |
| POST `/subscriptions/{traderId}/notify` | `{ on }` | 200 | 🟡 |
| POST `/posts/{id}/like` · DELETE | — | `{ likes }` | ✅ (count optimistic) |
| POST `/posts/{id}/save` · DELETE | — | 200 | ✅ |
| GET `/saved` | — | `[Post]` | ✅ saved screen |
| GET `/posts/{id}/comments` | — | `[Comment]` | ✅ comment sheet |
| POST `/posts/{id}/comments` | `{ text }` | the created `Comment` | ✅ |
| POST `/posts` | `{ type, content, pair?, title?, points? }` | `Post` | ✅ creator compose |
| GET `/traders/{myId}/posts` | — | `[Post]` (own posts on creator home) | ✅ (needs `user.id` in auth response — see below) |

`Post` app reads: `id, trader (Trader), type (analysis|trade|lesson|update),
content, pair?, title?, points[], likes, comments, createdAt, isLiked, saved`.
`Comment` app reads: `id, author, username, text, createdAt, byMe`.

> Because follow state is now server-side, **the feed and `isLiked`/`saved`/
> counts must reflect the authenticated user** — the app trusts server state.

---

## 5b. Creator side — needed to finish the creator experience 🔴

The follower flow is fully wired; the **creator** flow is the next gap. The app
already calls these / is built for them — please implement:

| Method · Path | App sends | App expects | Priority |
| --- | --- | --- | --- |
| **`user.id` in every auth/me response** | — | the `UserDto.id` (app now stores it and calls `/traders/{id}/posts` for "my posts") | **P0 — small, unblocks creator home** |
| GET `/creator/stats` (or fields on `/me`) | — | `{ followers, copiers, aum, return30d, earnings }` for the creator dashboard card (currently zeros) | P1 |
| GET `/creator/followers?cursor=` | — | `[User]` — "See who copies you" | P1 |
| GET `/creator/earnings` | — | `{ balance, currency, pending, history[] }` — Studio → Earnings & payouts | P1 |
| POST `/uploads` (or presigned URL) | multipart / `{ contentType }` | `{ url }` — for **profile photos** and **P&L statements** (app currently sends base64 data URLs as `photoUrl`, which won't scale) | **P1 — media storage** |
| PATCH `/posts/{id}` · DELETE `/posts/{id}` | — | edit / delete own post | P2 |

> **P0 note:** please confirm `AuthResponseDto.user` and `GET /me` both include
> `id`. The app persists it and uses it for the creator's own posts; without it
> the creator home can't show their posts.

## 5c. Copy engine & portfolio — milestone 4 ✅ WIRED
| Method · Path | App expects | Status |
| --- | --- | --- |
| GET `/copy` | `[CopyConfig]` | ✅ |
| POST `/copy/{traderId}/start` | `{ accountId, amount, risk?, autoCopy? }` → `CopyConfig` | ✅ |
| POST `/copy/{traderId}/stop` | 200 | ✅ |
| GET `/positions` | `[CopyPosition]` | ✅ Copied Trades |
| GET `/portfolio/summary` | `PortfolioSummary` | ✅ Home card + Profile |
| GET `/prices` | `{ "XAU/USD": 2015.3, … }` | 🟡 client ready (live overlay still demo) |
| GET `/symbols` | `[string]` | 🟡 |
| GET `/accounts` · DELETE `/accounts/{id}` | list / disconnect | ✅ (now loaded + real disconnect) |
| GET `/notifications` · POST `/notifications/read` | `[Notification]` / read | ✅ notification center |
| GET `/creator/stats` · `/creator/followers` | stats / `[User]` | 🟡 client ready, screens pending |

> Still needs backend for full realtime: **WS `prices`/`portfolio` push** and the
> **live events** in §6a (so positions/pnl update without a manual refresh), plus
> **`POST /devices`** wiring on the client (needs Firebase — deliberate later step).

## 5d. Live streaming — milestone 5 (backend ✅, app wiring in progress)
Backend endpoints exist; the app's client methods are added. Status:

| Method · Path | Purpose | App status |
| --- | --- | --- |
| POST `/broadcasts` `{title}` → BroadcastDto | create (returns `ingestUrl`,`streamKey`,`hlsUrl`,`phase`) | 🟡 client ready |
| POST `/broadcasts/{id}/start` · `/end` | go live / end (`end`→ summary) | 🟡 client ready |
| GET `/broadcasts/live` · `/broadcasts/{id}` | live list / detail (`viewers`,`hlsUrl`) | 🟡 client ready |
| GET·POST `/broadcasts/{id}/chat` | live chat (poll + send) | 🟡 client ready |
| POST `/broadcasts/{id}/react` | hearts | 🟡 client ready |
| POST `/broadcasts/{id}/destinations/youtube/connect` | simulcast to YouTube | 🟡 client ready |

> **App-side blocker for real video** (not a backend issue): publishing the
> camera to `ingestUrl` needs a native **RTMP publisher** (`apivideo_live_stream`)
> and playing `hlsUrl` needs a **video player** (`video_player`/`better_player`).
> These are native deps that must be added and build-verified deliberately.
> Until then the app can wire the **broadcast lifecycle + real shared
> chat/reactions/viewer-count** (no video), which is the next step.

## 5e. Uploads & earnings — ✅ WIRED
- POST `/uploads` `{contentType, data, kind?}` → `{url,id}` — used for profile photos. ✅
- GET `/creator/earnings` → `{balance, currency, pending, history[]}` — Earnings screen. ✅
- PATCH/DELETE `/posts/{id}` — client ready (edit/delete own post).

## 6. NEW things the app needs (please add to the contract, then build)

These are **not yet in the backend** but the app is being built to use them. Flag
and schedule; the app will wire them behind a flag when they land.

### 6a. Real-time events (milestone 5) — 🔴 requested
The app wants live in-app + push notifications for:
- **`trader.live.started`** — a trader the user follows went live → `{ traderId, name, broadcastId }`.
- **`trade.opened`** — a followed/copied trader opened a position → `{ traderId, name, pair, isBuy, entryPrice, sl?, tp? }`.
- **`trade.closed`** — `{ traderId, pair, pnlPercent, pnlAmount }`.

Preferred delivery: WebSocket channel (e.g. `wss://.../v1/ws`) with topic
subscription for followed trader ids, **and** a fallback REST poll:
- GET `/notifications?cursor=` → `[ { id, type, title, body, data, createdAt, read } ]`
- POST `/notifications/read` `{ ids[] }`

### 6b. Push notifications (FCM/APNs) — 🔴 requested
- POST `/devices` `{ platform: 'android'|'ios', token, appVersion }` — register a push token.
- DELETE `/devices/{token}` on logout.
- Server sends push for the events in 6a to a user's registered devices.

### 6c. Live streaming (milestone 5) — ⏳
- GET `/broadcasts/live` → live sessions; broadcast create/ingest; WS chat/viewers/reactions;
  YouTube live-chat ingest. (App has the UI; currently demo.)

### 6d. Copy engine / portfolio (milestone 4) — ⏳
- Copy config create/update, positions list, portfolio summary, WS `prices`/`portfolio`.
  (App has the UI on the demo store.)

---

## 7. Open questions for the backend session
1. Does `GET /traders` / `?q=` include **approved creators with no trades yet**? (blocks "Aisha shows up")
2. Are list endpoints returning **`{ items, nextCursor }`** or a raw array? (app accepts both, just confirming.)
3. `GET /me` — confirm it returns `{ user }` (envelope) so the app can refresh session on launch.
4. For 6a/6b — is a WebSocket gateway planned, or should the app poll `/notifications`?

## 8. Proposed milestone sequencing (app is ready for these)

The app UI already exists for all of these behind `kUseBackend`/demo fallbacks,
so it lights up as each ships:

- **Milestone 4 — Copy engine & portfolio:** copy config CRUD, positions,
  portfolio summary, WS `prices`/`portfolio`. Unblocks the real numbers on Home,
  Copied Trades and Profile.
- **Milestone 5 — Realtime & notifications:** WS gateway + `GET /notifications`
  + `POST /devices` (FCM/APNs) + events `trader.live.started`, `trade.opened`,
  `trade.closed` (§6a/6b). Unblocks push + the in-app notification center's
  server feed.
- **Milestone 5 — Live streaming:** broadcast create/ingest (Cloudflare), WS
  chat/viewers/reactions, YouTube chat ingest (§6c).
- **Milestone 6 — Payouts & real trade feed:** creator earnings/payouts, real
  (non-synthetic) trades & equity, admin metrics.

Also fold in **§5b (creator side)** and the **P0 `user.id`** item — small, high
value, unblocks the creator home now.

_Maintained by the app session. Last updated for app build `894a4c0`._
