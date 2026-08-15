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

## 5f. Money layer — milestone 6 ✅ WIRED
| Method · Path | App expects | Status |
| --- | --- | --- |
| GET `/wallet` · `/wallet/ledger` | `{balance,currency}` / `[LedgerEntry]` | ✅ Wallet screen |
| GET `/deposits/methods` · GET/POST `/deposits` | methods / `[Deposit]` / create | ✅ Add-funds sheet |
| GET/POST `/creator/payouts` | `[Payout]` / request | ✅ Earnings → Request payout |
| PATCH `/creator/commission` `{percent}` | `{commissionPercent}` | ✅ Studio → Commission |

> Admin `/admin/metrics` + `/admin/payouts` are for the **admin dashboard**, not
> the mobile app — intentionally not wired here.
> Open Q: is there a **GET** for current commission? Only PATCH exists, so the
> app can set but not display the current value (defaults the input to 20%).

## 5g. Financial ops, leverage & compliance — milestone 7 ✅ WIRED
| Area | Endpoint | Status |
| --- | --- | --- |
| App config | GET `/config` (no auth, on launch) | ✅ leverage cap, limits, kycRequired |
| Leverage (default) | PATCH `/me {leverage}` | ✅ (via Edit profile — pending a slider; address wired) |
| Leverage (per-copy) | POST `/copy/{id}/start {amount, leverage}` | ✅ slider (max from /config) |
| Margin header | GET `/portfolio/summary` freeMargin/usedMargin/equity/marginLevel | ✅ Copied Trades |
| Wallet-funded copy | insufficient_balance → deposit prompt | ✅ |
| Transactions | GET `/wallet/transactions` | ✅ Wallet |
| Payout methods | GET/POST/DELETE `/wallet/payout-methods` | ✅ |
| Withdraw | POST `/creator/payouts {amount, methodId}` + error codes | ✅ WithdrawScreen |
| KYC | GET `/kyc`, POST `/kyc/start` | ✅ (manual mode; Sumsub SDK hook noted) |
| Address | PATCH `/me {addressLine,city,postalCode}` | ✅ Edit profile |

> **App-side TODO (native):** the Sumsub KYC SDK isn't embedded — manual mode
> works; SDK launch is stubbed where `accessToken` is returned. Same deliberate
> native step as live-streaming video.
> **Open Q for backend:** a GET for current commission and current default
> leverage display; and confirm `/config` field names (app reads maxLeverage,
> kycRequiredForWithdrawal, limits.minWithdrawal/maxWithdrawal, activeDepositMethods).

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

## Newly consumed — M13/M14/M15 (now wired in the app)

- **2FA (M14):** `GET /2fa` → `{ enabled | twofaEnabled }`; `POST /2fa/setup` →
  `{ secret, otpauthUrl }`; `POST /2fa/enable { code }` → `{ backupCodes: [..] }`
  (shown once); `POST /2fa/disable { code }`. Login: `POST /auth/login` may return
  `401 { error.code: "twofa_required" }`, resubmitted with `{ twofaCode }`;
  wrong code → `twofa_invalid`. Surfaced in **Profile › Security & 2FA** and the
  login flow.
- **Simulcast outputs (M13):** `GET /broadcasts/{id}/outputs`,
  `POST /broadcasts/{id}/outputs { platform, streamKey, url? }`,
  `PATCH .../{outputId} { enabled }`, `DELETE .../{outputId}`. Wired into the
  go-live destination sheet (stream-key path); applies once a broadcast is live.
- **YouTube connect (M15):** `GET /youtube/status` → `{ connected }`;
  `POST /youtube/connect` → `{ url }` (consent link, shown copyable — no
  in-app browser dep); `POST /youtube/disconnect`. Chat ingest already handled
  via the `broadcast:{id}` WS `source:"youtube"` badge.

## 🔴 Open bugs / needs from the backend (found in live testing)

These are issues the app **cannot fix on its own** — they need backend changes.
The app side has been made as correct as possible (server-authoritative writes,
shared-state refresh) but the data/endpoints below are the blockers.

1. **`GET /subscriptions` / `GET /feed` returning non-subscribed traders.**
   Users report traders they never subscribed to appear in the Subscriptions
   list and their posts appear in the feed. The app only ever calls
   `POST/DELETE /subscriptions/{id}` on explicit user taps (verified — no
   auto-subscribe). Please confirm `GET /subscriptions` returns **only** the
   caller's active subscriptions, and `GET /feed` returns **only** posts from
   those subscriptions. Suspect seed data or a follow-vs-notify mix-up.

2. **Post images.** `Post` has no image field. The app needs `imageUrl?` (or
   `images[]`) on `POST /posts` (upload via existing `POST /uploads`) and on the
   returned/listed `Post`, so creators can attach a chart/setup screenshot to an
   analysis or trade post.

3. **Real trade posts with SL/TP (copyable).** Today a "trade" post is just
   `pair + content`. To let a creator post an actual trade and followers copy it
   from their wallet, we need a trade-post shape:
   `{ pair, side(buy/sell), entryType(market/limit), entryPrice?, sl?, tp?,
   slPct?, tpPct?, lots?/riskPct? }`, plus an endpoint
   `POST /copy/trade/{postId} { amount, leverage? }` that opens the position
   from the follower's wallet balance (like `/copy/{traderId}/start` but for a
   single posted trade).

4. **Live prices (real, not synthetic).** `GET /prices` + the WS `prices`
   channel are synthetic. For the trade composer + a live price on the selected
   pair we need real quotes for majors, gold (XAU/USD), indices and crypto.
   Options discussed: a market-data provider (Twelve Data / Finnhub / Yahoo)
   behind `/prices`, or the app embeds TradingView for the chart. Please expose
   real quotes on `/prices` (same shape) when a provider is configured.

5. **Per-pair live chat.** For an Exness/eToro-style chat under the chart, add a
   WS channel `pair:{symbol}` (e.g. `pair:XAU/USD`) carrying
   `{ author, text, createdAt }`, plus `GET /pairs/{symbol}/chat` (recent) and
   `POST /pairs/{symbol}/chat { text }`. Reuses the existing WS envelope.

_Maintained by the app session. Last updated: live-testing bug report (subscriptions, real-time wallet, trade/price/chat/photo needs)._

## 🚨 PRODUCTION READINESS — clear demo/seed data (backend, blocking launch)

The app faithfully renders whatever the API returns. In live testing it shows
**seeded demo data**, which makes the product look broken. None of this is fixable
in the app — it is server data. Status tracked against backend M19 (`da95f5b`):

1. ✅ **Wipe / gate the demo seed.** Seed now behind `SEED_DEMO` (off in prod) with
   `npm run db:wipe-demo` to purge existing seed rows.
2. ✅ **`trader.isLive` only from real broadcast start/end** — no longer seeded true.
3. ✅ **`GET /broadcasts/live` carries trader identity** — `BroadcastDto` now includes
   `{ traderId, name, username, photoUrl }`. **App synced:** home renders "Live now"
   by matching `traderId`/`creatorId` from real broadcasts against loaded traders.
4. ⚠️ **Real crypto deposits — STILL AUTO-CREDITING IN PROD (regression/not deployed).**
   The M19 code gates auto-credit behind `DEPOSIT_AUTO_CONFIRM` and adds real crypto
   via `POST /webhooks/deposits/crypto` (HMAC-SHA256, idempotent) failing closed with
   `deposits_unavailable`. **But live testing (2026-08-15) shows a crypto deposit is
   still credited to the user's wallet instantly.** The production server must have
   `DEPOSIT_AUTO_CONFIRM=true` (or the demo seed path) still active. **Backend action:**
   set `DEPOSIT_AUTO_CONFIRM=false` in the prod env and redeploy; verify `POST /deposits`
   returns a pending deposit (or `deposits_unavailable`) and only the signed webhook
   credits the wallet. **App synced:** deposit sheet already handles `deposits_unavailable`
   with a friendly "Deposits are being set up — please check back soon." message.
5. 🟡 **Real market data** on `GET /prices` + WS `prices` from a **licensed provider**
   (the app's Yahoo fetch is a testing placeholder only — ToS-restricted, not
   production-safe). Backend now throttles Twelve Data usage (`43426530`). Still
   pending: a backend `GET /candles?symbol=&range=&interval=` so the app charts pull
   OHLC from the backend instead of Yahoo.

_Maintained by the app session. M19 items 1–4 resolved; item 5 (licensed candles) open._
