# Millimore — Backend & Admin API Contract (v1)

This is the **single source of truth** shared by two Claude Code sessions:

- **App session** (`millimore-app`, Flutter) — builds the mobile app *to* this contract.
- **Backend session** (`millimore-backend`, new) — builds the API + admin *to* this contract.

The AIs do not share memory. **This document is how they stay in sync.** When
something changes, update this file first, then both sides follow it.

The app is currently wired to a local demo store (`AppState` / `SessionController`).
Goal: swap the demo data source for these live endpoints **without changing the UI**.

---

## 0. Principles

- **One backend, two clients:** the mobile app and the admin dashboard call the
  same API. Admin = elevated role, extra endpoints.
- **REST for actions/queries, WebSocket for realtime** (prices, live trades,
  chat, viewers, reactions).
- Everything the app reads today from `AppState` maps to an endpoint below.

## 1. Conventions

- **Base URL:** `https://api.millimore.app/v1`
- **Auth:** `Authorization: Bearer <JWT>` on all authenticated calls.
- **Content-Type:** `application/json`
- **IDs:** string (UUID).
- **Money:** numbers in account currency (USD default); send as decimals.
- **Timestamps:** ISO-8601 UTC (`2026-07-25T10:00:00Z`).
- **Errors:** `{ "error": { "code": "string", "message": "human text" } }` with
  proper HTTP status (400/401/403/404/409/422/429/500).
- **Pagination:** `?limit=20&cursor=<opaque>` → `{ "items": [...], "nextCursor": "..." }`.

## 2. Roles

- `follower` — copies traders, watches lives.
- `creator` — streams, posts, shares verified trades. Has `creatorStatus`.
- `admin` — platform management (admin dashboard only).

`creatorStatus`: `none | pending | approved | rejected | suspended`.

---

## 3. Data models (entities)

### User
```json
{
  "id": "u_123",
  "name": "Marcus Sterling",
  "username": "marcussterling",
  "email": "marcus@x.com",
  "phone": "+91 90000 00000",
  "photoUrl": "https://...",
  "role": "creator",
  "creatorStatus": "approved",
  "residenceIso": "IN",
  "residenceCountry": "India",
  "market": "Forex",
  "platform": "MetaTrader 5",
  "createdAt": "2026-01-01T00:00:00Z"
}
```

### Trader (public profile card)
```json
{
  "id": "t_1", "name": "Marcus Sterling", "username": "marcussterling",
  "photoUrl": null, "isVerified": true, "isLive": true,
  "returnPercent": 18.45, "returnDays": 30,
  "followers": 12400, "copiers": 1840, "aum": 2300000,
  "winRate": 72, "maxDrawdown": 9.2, "totalTrades": 612,
  "category": "Forex", "tags": ["Price Action","EUR/USD"], "bio": "..."
}
```

### Broker
```json
{ "id": "century", "name": "Century", "domain": "centuryfinancial.ae",
  "logoUrl": "https://...", "recommended": true }
```

### TradingAccount
```json
{ "id": "acc_1", "brokerId": "xm", "brokerName": "XM",
  "accountNumber": "50231487", "masked": "••••1487",
  "server": "XM-Live3", "currency": "USD", "balance": 5000,
  "status": "connected", "connectedAt": "2026-07-01T00:00:00Z" }
```
> Credentials (investor/trading password) are **write-only**: sent on connect,
> never returned. Store encrypted.

### CopyConfig
```json
{ "traderId": "t_1", "accountId": "acc_1", "amount": 500, "risk": 1.0,
  "autoCopy": true, "startedAt": "..." }
```

### CopyPosition
```json
{ "id": "pos_1", "traderId": "t_1", "traderName": "Marcus", "pair": "EUR/USD",
  "isBuy": true, "status": "active|closed", "entryPrice": 1.0876,
  "exitPrice": null, "pnlAmount": 12.4, "pnlPercent": 0.47, "lots": 0.1,
  "openedAt": "...", "closedAt": null, "accountId": "acc_1" }
```

### LiveTrade (broadcaster on-stream order)
```json
{ "id": "lt_1", "symbol": "XAU/USD", "isBuy": true,
  "orderType": "market|limit", "entryPrice": 2015.3, "lots": 0.1,
  "sl": 2008.0, "tp": 2030.0, "limitPrice": null,
  "status": "open|pending|closed", "openedAt": "...", "closedAt": null }
```

### Post
```json
{ "id": "p_1", "trader": { Trader }, "type": "analysis|trade|lesson|update",
  "content": "text", "pair": "EUR/USD", "title": null, "points": [],
  "likes": 284, "comments": 47, "createdAt": "...", "isLiked": false, "saved": false }
```

### Comment
```json
{ "id": "c_1", "author": "Priya", "username": "priyatrades",
  "text": "great!", "createdAt": "...", "byMe": false }
```

### LiveChatMessage
```json
{ "author": "alex_t", "text": "nice entry", "source": "millimore|youtube|facebook",
  "byHost": false, "createdAt": "..." }
```

### Broadcast
```json
{ "id": "b_1", "creatorId": "u_1", "title": "Live trading",
  "phase": "connecting|live|ended",
  "ingestUrl": "rtmps://ingest.millimore.app/live",
  "streamKey": "mlm_xxx",
  "hlsUrl": "https://cdn.millimore.app/b_1/index.m3u8",
  "viewers": 42, "peakViewers": 80, "startedAt": "...", "endedAt": null,
  "destinations": [{ "id":"youtube","connected":true }] }
```

---

## 4. REST endpoints

### 4.1 Auth & onboarding
```
POST /auth/register/follower   { name, phone, residenceIso, experience?, interests?, photoUrl? }
POST /auth/register/creator    { name, phone, residenceIso, market, platform,
                                 verification: { platform, server?, account?, investorPassword?, statementUrl? } }
POST /auth/otp/request         { phone } → { requestId }
POST /auth/otp/verify          { requestId, code } → { token, user }
POST /auth/login               { email, password } → { token, user }
POST /auth/social/apple        { identityToken } → { token, user }
POST /auth/social/google       { idToken } → { token, user }
GET  /me                       → { user }
PATCH /me                      { name?, photoUrl?, ... } → { user }
POST /auth/logout
```
> App mapping: replaces `SessionController.signInAsFollower/Creator`, OTP screen,
> login demo (`trader@millimore.app`).

### 4.2 Creator verification
```
GET  /creator/status           → { creatorStatus, reason? }
POST /creator/apply            { market, platform, verification{...} } → { creatorStatus:"pending" }
GET  /creator/stats            → { followers, copiers, aum, return30d, earnings }  // creator dashboard
GET  /creator/followers        → [ User ]                                          // who follows me
GET  /creator/earnings         → { balance, currency, pending, history[] }         // Studio → payouts
```
> Admin flips status; app polls or receives WS `creator.status` event.
> This replaces the demo "Mark as verified" button.

### 4.3 Brokers & accounts
```
GET  /brokers?country=IN               → [ Broker ]   // country-gated list
GET  /accounts                         → [ TradingAccount ]
POST /accounts                         { brokerId, accountNumber, server, password } → TradingAccount
DELETE /accounts/{id}
POST /accounts/{id}/password           { current, next }   // change password
```

### 4.4 Discover / traders
```
GET  /traders?category=&q=&sort=copiers|return&cursor=   → paginated [ Trader ]
GET  /traders/{id}                     → Trader (full)
GET  /traders/{id}/posts               → [ Post ]
GET  /traders/{id}/trades?status=      → [ CopyPosition-like public trades ]
GET  /traders/{id}/equity?range=30d    → [ { t, value } ]  // equity curve
GET  /discover/reels                   → [ Reel ]  // mixed live/trade/lesson feed
```
`Reel`: `{ kind:"live|trade|lesson", trader, post, title?, points?, viewers? }`

### 4.5 Social graph
```
POST   /subscriptions/{traderId}       // subscribe
DELETE /subscriptions/{traderId}       // unsubscribe
GET    /subscriptions                  → [ Trader ]
POST   /subscriptions/{traderId}/notify  { on: true|false }  // bell
GET    /feed                           → [ Post ]   // from subscriptions
POST   /posts/{id}/like  / DELETE      → { likes }
POST   /posts/{id}/save  / DELETE
GET    /saved                          → [ Post ]
GET    /posts/{id}/comments            → [ Comment ]
POST   /posts/{id}/comments  { text }  → Comment
```

### 4.6 Creator content (compose)
```
POST /posts   { type:"trade|analysis|lesson", content, pair?, title?, points?[] } → Post
PATCH  /posts/{id}   { content?, title?, pair?, points?[] } → Post   // owner-only edit
DELETE /posts/{id}                                                   // owner-only delete
POST /uploads  { contentType, data(base64) } → { id, url }          // media (photos, statements)
GET  /uploads/{id}                                                  // serve file (public URL)
```

### 4.7 Copy trading
```
POST /copy/{traderId}/start   { accountId, amount, risk, autoCopy } → CopyConfig
POST /copy/{traderId}/stop
GET  /copy                    → [ CopyConfig ]
GET  /positions?status=active|closed  → [ CopyPosition ]
GET  /portfolio/summary       → { netPnl, openPnl, bookedProfit, bookedLoss,
                                  copyingCount, activeCount, closedCount, invested }
POST /copy/live/{broadcastId}/{tradeId}  { accountId }   // copy a trade from a live
```

### 4.8 Market data
```
GET  /symbols                 → ["XAU/USD","EUR/USD",...]
GET  /prices?symbols=XAU/USD,EUR/USD  → { "XAU/USD": 2015.3, ... }   // snapshot
```
> Realtime prices come over WS (below). REST is the initial snapshot.

### 4.9 Live streaming (creator)
```
POST /broadcasts                       { title } → Broadcast (ingestUrl, streamKey, hlsUrl)
POST /broadcasts/{id}/start            → phase:"live"    // after RTMP connects
POST /broadcasts/{id}/end              → summary { duration, peakViewers, trades, pnl }
GET  /broadcasts/{id}                  → Broadcast
GET  /broadcasts/live                  → [ Broadcast ]   // who's live now
POST /broadcasts/{id}/destinations/youtube/connect   // OAuth handshake (returns auth URL)
POST /broadcasts/{id}/destinations/{platform}/disconnect
```
> Backend uses **Cloudflare Stream Live** (or Ant Media): create a Live Input
> (ingestUrl+key+hlsUrl), add Outputs for YouTube/Facebook simulcast.

### 4.10 Live trades (on-stream orders → broker)
```
POST /broadcasts/{id}/orders   { symbol, isBuy, orderType, lots, sl?, tp?, limitPrice? } → LiveTrade
POST /broadcasts/{id}/orders/{tradeId}/close → ClosedTrade
GET  /broadcasts/{id}/orders   → [ LiveTrade ]     // open + pending
GET  /broadcasts/{id}/history  → [ ClosedTrade ]
```
> These execute on the creator's connected MT account (investor pw = read-only
> for verification; a trade-enabled connection is required to actually place).

### 4.11 Live chat (aggregated)
```
GET  /broadcasts/{id}/chat            → [ LiveChatMessage ]   // recent
POST /broadcasts/{id}/chat            { text } → LiveChatMessage  // host or viewer, pushed over WS
POST /broadcasts/{id}/react          { count? }   // heart reactions, pushed over WS
```
> **YouTube chat ingestion (server-side):** backend uses YouTube Data API v3:
> `liveBroadcasts.list` → `activeLiveChatId`, then poll `liveChatMessages.list`
> respecting `pollingIntervalMillis`; push each into the broadcast chat with
> `source:"youtube"`. Optional: `liveChatMessages.insert` to send host replies
> back to YouTube. Requires YouTube OAuth (`youtube.readonly`, `youtube.force-ssl`)
> and quota management.

### 4.12 Notifications & devices
```
GET  /notifications            → [ { id, type, title, body, data?, createdAt, read } ]
POST /notifications/read       { ids: [] }
POST /devices                  { platform:"android|ios", token, appVersion? }  // register push token
DELETE /devices/{token}                                                        // on logout
```
> `data` is an arbitrary payload (e.g. `{ traderId, pair, pnlAmount }`).
> Notifications are the **poll fallback** for the realtime WS channel (milestone 5).

---

## 5. Realtime (WebSocket)

Connect: `wss://api.millimore.app/v1/ws?token=<JWT>`
Subscribe to channels; server pushes events:

```jsonc
// client → server
{ "op": "subscribe", "channels": ["prices", "broadcast:b_1", "portfolio"] }

// server → client events
{ "ch": "prices",          "data": { "XAU/USD": 2015.4, "EUR/USD": 1.0851 } }        // ~1/sec
{ "ch": "broadcast:b_1",   "type": "viewers",  "data": { "viewers": 43 } }
{ "ch": "broadcast:b_1",   "type": "chat",     "data": LiveChatMessage }
{ "ch": "broadcast:b_1",   "type": "reaction", "data": { "count": 3 } }
{ "ch": "broadcast:b_1",   "type": "trade",    "data": LiveTrade }                    // overlay
{ "ch": "portfolio",       "type": "position", "data": CopyPosition }                 // live P/L
{ "ch": "user",            "type": "creator.status", "data": { "creatorStatus": "approved" } }
```

> App mapping: the 1-second price feed, floating P/L, live chat, viewers, hearts,
> and creator-approval that are currently simulated in `AppState` all become
> these WS events.

---

## 6. Admin API (admin dashboard)

Base: `/v1/admin` — requires `role: admin`.

```
GET  /admin/metrics            → { dau, mau, liveNow, streamsToday, totalUsers,
                                   creators, gmv, copyVolume, errors24h, uptime }
GET  /admin/users?q=&role=&cursor=      → paginated [ User ]
PATCH /admin/users/{id}        { role?, banned?, creatorStatus? }
GET  /admin/creators/pending   → [ application ]      // verification queue
POST /admin/creators/{id}/approve  { note? }
POST /admin/creators/{id}/reject   { reason }
GET  /admin/broadcasts/live    → [ Broadcast + health ]
GET  /admin/trades?range=      → volumes, P/L aggregates
GET  /admin/accounts           → broker connection statuses
GET  /admin/payouts            → creator earnings / payout requests
POST /admin/payouts/{id}/approve
GET  /admin/reports            → moderation queue
POST /admin/moderation/{postId}/remove
GET  /admin/system             → server load, queue depth, API quota (YouTube), latency
```

---

## 7. Secrets / env the backend needs
```
DATABASE_URL
JWT_SECRET
OTP_PROVIDER_KEY            # e.g. Twilio/MSG91
CLOUDFLARE_STREAM_TOKEN     # live inputs + outputs (simulcast)
YOUTUBE_OAUTH_CLIENT_ID / SECRET   # live chat + simulcast auth
FACEBOOK_APP_ID / SECRET
BROKER_BRIDGE_URL          # MT4/MT5 gateway / EA bridge for prices+orders
STORAGE_BUCKET             # statements, photos (S3/GCS)
```

## 8. Suggested stack
- **Backend:** NestJS (TS) or FastAPI (Py); Postgres; Redis (WS/pubsub); or **Supabase** for speed (auth + DB + realtime).
- **Admin:** Next.js + Refine/React-Admin.
- **Live:** Cloudflare Stream Live (managed simulcast + HLS) or Ant Media.
- **MT bridge:** MetaAPI.cloud (hosted MT4/MT5 API) or a custom EA gateway for prices + order execution + investor-password verification.

## 9. Build order (backend)
1. Auth + users + JWT + OTP  → app login/register goes live.
2. Brokers + accounts + creator verify + **admin approve queue**.
3. Traders/discover/feed/social (subscribe, saved, comments, likes).
4. Copy engine + positions + portfolio + WS `portfolio`/`prices`.
5. Broadcasts (Cloudflare) + WS chat/viewers/reactions + YouTube chat ingest.
6. Live orders → MT bridge; payouts; full admin metrics/monitoring.

## 10. Integration note for the app session
Each `AppState` / `SessionController` method has a matching endpoint above.
Introduce a thin `ApiClient` + repository layer; flip a `useBackend` flag to
swap the demo store for live calls, screen by screen — UI stays identical.

**→ Step-by-step app-side instructions: [`APP_INTEGRATION.md`](./APP_INTEGRATION.md)**
(base URL, which screens are live, demo-method → endpoint map, and a skip rule so
already-integrated screens are left alone).

---

## 11. Implementation notes (backend — kept in sync as milestones land)

These clarify decisions made while implementing the contract. Shapes above are
unchanged; this section only pins down details the prose left open.

### Auth (milestone 1)
- `register/follower` and `register/creator` return `{ token, user }` (the user
  is signed in immediately), consistent with the OTP/login responses.
- `otp/request` returns `{ requestId, devCode? }`. `devCode` is present **only**
  when `OTP_PROVIDER=console` (dev), so the app can log in without an SMS gateway.
- `otp/verify` signs in the existing phone owner, or creates a minimal follower
  if the phone is new.

### Brokers & accounts (milestone 2)
- `GET /brokers?country=` gating: a broker with an empty country list is global;
  otherwise the ISO code must be in its list.
- `TradingAccount.masked` is derived server-side (`••••` + last 4).
  `balance` is `0` until the MT bridge populates it (milestone 6).
- `POST /accounts` and `POST /accounts/{id}/password` take the password
  write-only; it is AES-256-GCM encrypted at rest and never returned.

### Creator verification (milestone 2)
- `POST /creator/apply` moves the user to `role: creator`, `creatorStatus:
  pending` (same as `register/creator`) and opens a pending application.
- `GET /creator/status` returns `{ creatorStatus, reason? }`; `reason` is the
  latest application's reject reason when status is `rejected`/`suspended`.

### Admin (milestone 2)
- `GET /admin/users` items are the §3 `User` shape **plus** an admin-only
  `banned: boolean`. The mobile app never reads this field.
- `PATCH /admin/users/{id}` accepts `{ role?, banned?, creatorStatus? }` and
  returns the updated admin user. Banned users are blocked at `POST /auth/login`.
- `GET /admin/creators/pending` returns `application` objects shaped as:
  ```json
  { "id": "capp_1", "userId": "u_1",
    "user": { "id","name","username","email","phone","photoUrl","residenceCountry" },
    "status": "pending", "market": "Forex", "platform": "MetaTrader 5",
    "verification": { "platform","server","account","statementUrl",
                      "hasInvestorPassword": true },
    "reviewerNote": null, "rejectReason": null, "createdAt": "..." }
  ```
  The investor password is **never** returned — only `hasInvestorPassword`.
- `POST /admin/creators/{id}/approve|reject` — `{id}` is the **application id**
  (the `id` field of a queue item). Approve/reject also flips the applicant's
  `creatorStatus`. (WS `user → creator.status` push lands in milestone 5; until
  then the app learns via `GET /creator/status`.)

### Traders / discover / social (milestone 3)
- `GET /traders` — paginated `{ items, nextCursor }`; `sort=copiers|return`
  (default `copiers`), plus `category` and `q` (name/username) filters.
- `Trader` is returned exactly per §3 (no `isSubscribed` field). The app derives
  follow state from `GET /subscriptions`.
- `GET /traders/{id}/trades` and `/equity` are **synthetically generated**
  (deterministic per trader id) until the real trade feed lands (milestone 4/6).
  Trades match the `CopyPosition`-like shape; equity is `[{ t, value }]` ending
  at `10000 × (1 + returnPercent/100)`.
- `GET /discover/reels` returns `live` reels (one per live trader, with
  `viewers`) followed by `trade`/`lesson` reels built from recent posts.
- `Post` carries `likes`/`comments` **counts** plus per-user `isLiked`/`saved`.
- `POST /posts` (compose) auto-creates a `Trader` profile for the author if they
  don't have one yet (from their user name/username/market).
- Response conventions:
  - `POST|DELETE /posts/{id}/like` → `{ likes }` (200).
  - `POST|DELETE /posts/{id}/save`, `POST|DELETE /subscriptions/{traderId}`,
    `POST /subscriptions/{traderId}/notify` → `204 No Content`.
  - `notify` requires an existing subscription (404 otherwise).

### Answers to APP_REQUIREMENTS open questions (app session ↔ backend)
1. **Approved creators appear in `GET /traders` immediately** — on admin approval
   the backend creates the creator's public `Trader` profile (zeroed stats,
   `isVerified:true`), so approved-but-inactive creators are discoverable and
   searchable (`?q=`) right away. (Fixes "Aisha not showing".) Composing a post
   also ensures the profile exists.
2. **List shapes:** `GET /traders` and `GET /admin/users` return
   `{ items, nextCursor }`; `GET /subscriptions`, `/feed`, `/saved`,
   `/traders/{id}/posts`, `/brokers`, `/notifications` return **raw arrays**.
   (The app accepts both, as noted.)
3. **`GET /me` returns `{ user }`** (envelope) — safe to refresh session on launch.
   `PATCH /me` also returns `{ user }`.
4. **Realtime (6a) / push (6b):** the WS gateway is planned for **milestone 5**.
   Until then use the REST fallback, which is **live now**: `GET /notifications`,
   `POST /notifications/read`, and push-token registration `POST /devices` /
   `DELETE /devices/{token}` (contract §4.12). Creator approve/reject already
   writes a `creator.status` notification; trade/live events populate
   notifications from milestone 4/5.

### Copy engine, market data & realtime (milestone 4)
- `POST /copy/{traderId}/start` `{ accountId, amount, risk?, autoCopy? }` → `CopyConfig`;
  opens 2–3 mirrored positions at current prices. One active config per (user, trader).
- `POST /copy/{traderId}/stop` → `204`; closes that trader's open positions at the
  current price and books their P/L.
- `GET /copy` → active `[CopyConfig]`. `GET /positions?status=active|closed` →
  `[CopyPosition]` — **P/L on active rows is computed live** from current prices.
- `GET /portfolio/summary` → `{ netPnl, openPnl, bookedProfit, bookedLoss,
  copyingCount, activeCount, closedCount, invested }` (openPnl is live).
- `GET /symbols` → `[string]`; `GET /prices?symbols=A,B` → `{ "A": 1.23, … }` snapshot.
  Prices tick ~1/sec (synthetic now → MT bridge in milestone 6; shape unchanged).
- **WebSocket** `wss://…/v1/ws?token=<JWT>` (contract §5). Client sends
  `{ op:"subscribe", channels:["prices","portfolio"] }`. Server pushes
  `{ ch:"prices", data:{sym:price,…} }` ~1/sec and
  `{ ch:"portfolio", type:"position", data: CopyPosition }` with live P/L. Single
  instance today; Redis pub/sub makes it multi-instance without protocol change.

### Creator side (milestone 4 / §5b)
- `AuthResponseDto.user` and `GET /me` **include `user.id`** (P0 — confirmed).
- `GET /creator/stats` → `{ followers, copiers, aum, return30d, earnings }` — copiers
  and aum are real (from active copy configs); `earnings` is 0 until payouts (milestone 6).
- `GET /creator/followers` → `[User]` who subscribe to the creator.

### Realtime events, live streaming & media (milestone 5)
- **WS `user` channel** (contract §5): the server pushes per-user events —
  `creator.status`, `trade.opened` `{ traderId, name, pair, isBuy, entryPrice }`,
  `trade.closed` `{ traderId, pair, pnlPercent, pnlAmount }`,
  `trader.live.started` `{ traderId, name, broadcastId }` (to the trader's followers).
  Each event is also written to `GET /notifications` and fires a push (when a
  device is registered + FCM configured).
- **Push** (§6b): `POST /devices` / `DELETE /devices/{token}` register tokens.
  Real FCM/APNs send needs `FCM_SERVER_KEY` — a deliberate later step; the
  registry and all trigger points are already live.
- **Broadcasts** (§4.9): `POST /broadcasts` returns `ingestUrl`+`streamKey`+`hlsUrl`
  **to the owner only** — `GET /broadcasts/live` and non-owner `GET /broadcasts/{id}`
  omit the ingest credentials. `start` notifies followers (`trader.live.started`);
  `end` returns `{ duration, peakViewers, trades, pnl }`. Cloudflare Stream Live is
  used when `CLOUDFLARE_STREAM_TOKEN`+`CLOUDFLARE_ACCOUNT_ID` are set; otherwise a
  synthetic dev input is returned (same shape).
- **WS `broadcast:{id}` channel:** `type:"chat"` (from `POST …/chat`),
  `type:"reaction"` (from `POST …/react`), `type:"viewers"` (auto on join/leave).
  Viewer count is derived from live subscribers. YouTube chat ingest and on-stream
  MT orders (§4.10) arrive in milestone 6 with the MT bridge.
- **Uploads** (§5b): `POST /uploads { contentType, data(base64) }` → `{ id, url }`;
  served at `GET /uploads/{id}`. Dev stores bytes in Postgres; set `STORAGE_*` for
  S3+CloudFront in production. Retires base64 photoUrls.

### Wallet, deposits, copy settlement & payouts (milestone 6)
The trading model is **corporate-account / liquidity-provider**, not per-user MT
logins. Users fund an **in-app wallet**; Millimore routes net exposure to its
corporate broker account (Century Financial et al.) via the broker bridge. All
money movement is an **internal, audited ledger** (real crypto/broker rails plug
in above it later). MetaAPI is intentionally parked behind the same bridge seam.

- **Wallet**
  - `GET /wallet` → `{ balance, currency }` — the user's spendable balance.
  - `GET /wallet/ledger?limit=` → `[{ id, type, amount(signed), balanceAfter,
    currency, refId, note, createdAt }]`. Every balance change writes one row.
    `type` ∈ `deposit | withdrawal_hold | withdrawal_refund | copy_allocate |
    copy_return | trade_pnl | commission | commission_earned | platform_fee |
    adjustment`.
- **Deposits** (crypto live; others "coming soon")
  - `GET /deposits/methods` → `[{ id, label, active, comingSoon?, assets? }]`
    (crypto active; metatrader/card/bank `comingSoon`).
  - `POST /deposits { amount, asset?, method? }` → `Deposit`. In test mode
    (`DEPOSIT_AUTO_CONFIRM=true`) it confirms and credits the wallet immediately;
    in prod a crypto webhook calls confirm exactly once.
  - `GET /deposits` → my deposits.
- **Copy funding & settlement** — `POST /copy/{traderId}/start` now debits the
  wallet by `amount` (`copy_allocate`; throws `insufficient_balance` if unfunded —
  the "deposit first" flow). `accountId` is now optional (a broker hint).
  `POST /copy/{traderId}/stop` returns principal + realized P/L and splits the
  performance fee: **copier keeps the profit**, **trader earns commission**,
  **Millimore keeps a share** (`PLATFORM_FEE_SHARE`, default 0.30). Losses are
  capped at the allocated principal.
- **Trader commission** — `Trader.commissionPercent` (1–30%, trader-set) is the
  performance fee charged on a copier's profit. `PATCH /creator/commission
  { percent }` → `{ commissionPercent }`.
- **Creator earnings** — `GET /creator/earnings` is now real: `{ balance,
  currency, pending, lifetimeEarned, history[] }` (wallet-backed). `GET
  /creator/stats.earnings` = lifetime commission earned.
- **Withdrawals** — `POST /creator/payouts { amount, method?, note? }` holds funds
  immediately (debits wallet); `GET /creator/payouts` lists mine. Admin: `GET
  /admin/payouts?status=&cursor=`, `POST /admin/payouts/{id}/approve`,
  `POST /admin/payouts/{id}/reject` (refunds the held funds).
- **Admin metrics** — `GET /admin/metrics` is now real live aggregates:
  `{ dau, mau, liveNow, streamsToday, totalUsers, creators, gmv, copyVolume,
  depositsTotal, walletLiabilities, platformRevenue, pendingPayouts,
  pendingPayoutAmount, errors24h, uptime }`. DAU/MAU come from a throttled
  `User.lastSeenAt` (updated by the JWT strategy). `platformRevenue` is the sum of
  `platform_fee` ledger rows.
- **Broker bridge** — `BROKER_BRIDGE_URL` (+ `BROKER_BRIDGE_TOKEN`) switches order
  routing / account info / investor-password checks from synthetic to a live
  MT4/MT5 gateway. Unset ⇒ deterministic synthetic values (same shapes).

### Financial operations, leverage & compliance (milestone 7)
Adds the controls a real fintech needs: admin-editable settings, leverage/margin,
full transaction history with verify/flag/approve, saved payout methods, profile
address, KYC (Sumsub-ready), and an admin audit trail.

- **Public config** — `GET /config` (no auth) → `{ maxLeverage, defaultLeverage,
  minDeposit, minWithdrawal, maxWithdrawalPerTx, maxWithdrawalPerDay,
  kycRequiredForWithdrawal, depositMethods[], maintenanceMode }`. The app reads
  this to render limits, leverage cap and deposit methods.
- **Admin settings** — `GET /admin/settings`, `PATCH /admin/settings`
  (`platformFeeShare`, `maxLeverage`, `defaultLeverage`, `minDeposit`,
  `minWithdrawal`, `maxWithdrawalPerTx`, `maxWithdrawalPerDay`,
  `depositAutoConfirm`, `kycRequiredForWithdrawal`, `cryptoEnabled`,
  `cardEnabled`, `bankEnabled`, `maintenanceMode`). The Millimore fee lives here
  now (env is only the first-run default). Cached ~15s.
- **Leverage & margin** — wallet balance is the **margin**; a copy's exposure is
  `amount × leverage`. `User.leverage` is the default; `POST /copy/{id}/start`
  accepts an optional `leverage`, clamped to `maxLeverage`. `PATCH /me` accepts
  `leverage` (+ `addressLine`, `city`, `postalCode`). `GET /wallet` →
  `{ balance, currency, leverage }`. `GET /portfolio/summary` now also returns
  `freeMargin`, `usedMargin`, `equity`, `marginLevel`.
- **Transactions** — user: `GET /wallet/transactions` (unified timeline:
  deposits, trades, fees, commissions, withdrawals). Admin: `GET
  /admin/transactions?kind=&status=&flagged=&cursor=` (deposits + withdrawals),
  with `POST /admin/deposits/{id}/approve|reject|flag` and
  `POST /admin/payouts/{id}/flag` (approve/reject already exist).
- **Payout methods** — `GET/POST/DELETE /wallet/payout-methods`. Crypto address
  or bank details are AES-256-GCM encrypted (write-only); responses expose only
  `masked` + `label`. A withdrawal must reference a saved method (`methodId`).
- **Withdrawal gating** — `POST /creator/payouts` now enforces: amount ≥
  `minWithdrawal`, ≤ `maxWithdrawalPerTx`, running 24h total ≤
  `maxWithdrawalPerDay`, **KYC verified** (when `kycRequiredForWithdrawal`), and a
  valid saved `methodId` — plus the existing admin approve/reject. Error codes:
  `below_min_withdrawal`, `above_max_withdrawal`, `daily_limit_exceeded`,
  `kyc_required`, `invalid_payout_method`.
- **KYC (Sumsub-ready)** — `POST /kyc/start` → `{ provider, applicantId,
  accessToken, manual? }` (SDK token; `manual:true` when no provider configured).
  `GET /kyc` → `{ kycStatus, provider, reason }`. `POST /kyc/webhook` (provider
  callback, signature-checked). Admin: `GET /admin/kyc?status=`,
  `POST /admin/kyc/{userId}/verify|reject`. Enable Sumsub with `SUMSUB_APP_TOKEN`
  + `SUMSUB_SECRET_KEY` (+ `SUMSUB_LEVEL_NAME`); otherwise manual admin review.
  `User.kycStatus` ∈ `none|pending|verified|rejected` (on `GET /me`).
- **Audit log** — every admin decision writes an `AdminAuditLog` row;
  `GET /admin/audit?targetType=&cursor=`.
- **New env** — `SUMSUB_APP_TOKEN`, `SUMSUB_SECRET_KEY`, `SUMSUB_LEVEL_NAME`,
  `MAX_LEVERAGE`, `DEFAULT_LEVERAGE` (all optional; settings row overrides).

### WebSocket message schemas (realtime — M4/M5)
**Connect:** `wss://<host>/v1/ws?token=<JWT>` (same host as the API).
**Subscribe/unsubscribe (client → server):**
```json
{ "op": "subscribe",   "channels": ["prices", "portfolio", "user", "broadcast:b_1"] }
{ "op": "unsubscribe", "channels": ["broadcast:b_1"] }
```
**Every server → client message has the envelope:** `{ "ch": string, "type"?: string, "data": object }`

On connect the server sends: `{ "ch":"system", "type":"connected", "data":{ "ok":true } }`

**Channel `prices`** (~1/sec):
```json
{ "ch":"prices", "data": { "EUR/USD": 1.0876, "XAU/USD": 2411.3, "BTC/USD": 64210.5 } }
```
`data` is a map of `symbol → price` (numbers).

**Channel `portfolio`** (on each tick, one message per open position):
```json
{ "ch":"portfolio", "type":"position", "data": CopyPosition }
```
`CopyPosition` = the `/positions` object (id, traderId, traderName, pair, isBuy,
status, entryPrice, exitPrice, pnlAmount, pnlPercent, lots, openedAt, closedAt, accountId).

**Channel `user`** (per-user events; envelope `{ ch:"user", type, data }`):
| type | data |
| ---- | ---- |
| `creator.status` | `{ creatorStatus: "approved"|"rejected", reason?: string }` |
| `trade.opened` | `{ traderId, name, pair, isBuy, entryPrice }` |
| `trade.closed` | `{ traderId, pair, pnlPercent, pnlAmount }` |
| `copy.settled` | `{ traderId, netToCopier, fee }` |
| `trader.live.started` | `{ traderId, name, broadcastId }` (sent to the trader's followers) |
| `payout.status` | `{ status: "approved"|"rejected", reason?: string }` |
| `kyc.status` | `{ kycStatus: "verified"|"rejected"|"pending", reason?: string }` |

> Every `user` event is also persisted to `GET /notifications` and fires a push
> (when a device is registered). So the app can rely on either the socket or the
> REST feed.

**Channel `broadcast:{id}`** (live room; envelope `{ ch:"broadcast:b_1", type, data }`):
| type | data |
| ---- | ---- |
| `chat` | `LiveChatMessage` = `{ id, broadcastId, author, text, source, byHost, createdAt }` |
| `reaction` | `{ count: number }` |
| `viewers` | `{ viewers: number }` (auto on join/leave) |
| `trade` | `LiveTrade` (on-stream order overlay) |

### Admin analytics & reporting (milestone 8)
- `GET /admin/analytics?days=30` → `{ range, series[], totals, topTraders[] }`
  - `series[]`: one row per day — `{ date, signups, deposits, withdrawals, revenue }`.
  - `totals`: `{ users, newUsers30d, creators, kycVerified, depositsTotal,
    withdrawalsTotal, revenueTotal, copyVolume, walletLiabilities, activeCopies }`.
  - `topTraders[]`: `{ id, name, username, photoUrl, copiers, aum, returnPercent }`.
- Admin dashboard adds an **Analytics** page (signups line, deposits-vs-withdrawals
  bars, revenue line, top-traders table) and an **Audit log** page over
  `GET /admin/audit`. All charts are dependency-free SVG (CSP-safe).

### Admin user management & balance ops (milestone 8)
- `GET /admin/users/{id}` → user 360: `{ user (incl. banned, frozen, adminNote,
  leverage, kycStatus, address), wallet:{balance,currency}, stats:{deposits,
  depositsTotal, withdrawals, withdrawalsTotal, activeCopies, lifetimeCommission,
  payoutMethods, isTrader}, ledger[] }`.
- `POST /admin/users/{id}/adjust { amount, reason }` → manual wallet credit
  (`amount > 0`) or debit (`amount < 0`), written to the ledger as `adjustment`
  and to the audit log; notifies the user (`wallet.adjusted`).
- `PATCH /admin/users/{id}` now also accepts `frozen` and `adminNote`.
- **Frozen** accounts can still log in but are blocked from **withdrawals** and
  **starting copies** (`error.code = "account_restricted"`). Banned blocks login.
- Admin UI: the Users page detail drawer now shows wallet balance, deposit/
  withdrawal/copy stats, recent transactions, a credit/debit form, freeze
  toggle, and an internal note. Market gap analysis: `docs/ADMIN_BENCHMARK.md`.

### Referral / affiliate (IB) program (milestone 9)
Users earn by referring others: a share of Millimore's revenue from their
referrals' trading, plus an optional first-deposit bonus.
- **My dashboard** — `GET /referrals/me` → `{ code, link, enabled,
  revenueSharePercent, signupBonus, stats:{ referred, activeReferred,
  totalEarned, earned30d } }`. The code is generated on first access.
- **My referrals** — `GET /referrals` → `[{ id, name, username, photoUrl,
  kycVerified, hasDeposited, joinedAt, earned }]`.
- **Apply a code** — `POST /referrals/apply { code }` (once; can't self-refer).
  Codes can also be passed at signup: `referralCode` on
  `POST /auth/register/follower` and `/creator`.
- **Earnings** are paid automatically: when a referred user's copy settles with a
  profit, the referrer gets `referralRevenueShare × Millimore's platform cut`
  (booked out of the platform fee, as a `referral_commission` ledger credit to
  the referrer's wallet). On a referred user's first confirmed deposit, the
  referrer gets `referralSignupBonus`. All go to the normal wallet (withdrawable).
- **Admin** — `GET /admin/referrals` (top referrers). Rates in settings:
  `referralEnabled`, `referralRevenueShare` (0..1), `referralSignupBonus`.
- Admin UI adds a **Referrals** leaderboard page + referral controls in Settings.

### Support tickets & announcements (milestone 10)
Researched against B2Core's helpdesk + notification center; matches (threaded
tickets, internal notes, required-read announcements) and adds realtime delivery.

**Support (helpdesk):**
- `POST /support/tickets { subject, message, category?, priority? }` → Ticket.
  Categories: general|deposit|withdrawal|kyc|trading|account. Priority:
  low|normal|high|urgent.
- `GET /support/tickets` → my tickets. `GET /support/tickets/{id}` → thread
  (public messages only — internal notes are never returned to the user).
- `POST /support/tickets/{id}/messages { body }` → reply (reopens if resolved).
- Admin: `GET /admin/support/tickets?status=`, `GET /admin/support/tickets/{id}`
  (incl. internal notes), `POST /admin/support/tickets/{id}/messages { body,
  internal? }` (internal=true = private note), `PATCH /admin/support/tickets/{id}
  { status?, priority? }`. A public admin reply pushes a `support.reply` user
  event + notification and sets status `pending`.

**Announcements (notification bell):**
- `GET /announcements` → `{ items:[{ id, title, body, requiredRead, createdAt,
  read }], unread }` — active, in-window, audience-matched, with per-user read
  state. `POST /announcements/{id}/read` acknowledges one.
- Admin: `GET /admin/announcements` (with read counts), `POST /admin/announcements
  { title, body, audience?(all|followers|creators), requiredRead?, active?,
  startsAt?, endsAt? }`, `PATCH /admin/announcements/{id}`, `DELETE
  /admin/announcements/{id}`.
- Admin UI adds **Support** (ticket console w/ thread, internal notes, status/
  priority) and **Announcements** (compose + audience + required-read) pages.

### Back-office roles & permissions — RBAC (milestone 11)
Admin-only. Researched against B2Core's back-office user groups; staff are scoped
by role. Roles: `superadmin` (all), `finance` (deposits/withdrawals/balances/
analytics), `compliance` (KYC/audit/withdrawal review), `support` (tickets/
announcements), `analyst` (read-only analytics/reports). A legacy admin with no
`adminRole` is treated as superadmin.
- Every sensitive `/admin/*` endpoint is gated by a permission (e.g.
  `wallet.adjust`, `kyc.decide`, `payouts.approve`, `settings.write`,
  `announcements.write`, `admins.manage`). Insufficient role →
  `403 { error.code: "insufficient_permission" }`.
- `GET /admin/me/permissions` → `{ adminRole, permissions[] }` — the admin UI
  hides nav/actions the signed-in admin can't use.
- `GET /admin/team` + `POST /admin/team/{id}/role { adminRole }` (require
  `admins.manage`) manage staff roles. `AdminUserDto` now includes `adminRole`.
- Admin UI adds a **Team** page (assign roles) and a permission-filtered sidebar.

### Real integrations — push & live video (milestone 12)
No API/shape changes — these swap dev-mode stubs for real providers when their
env is set (isolated behind their modules, per the portability guardrails).
- **Push (FCM HTTP v1)** — the legacy server-key API was removed by Google in
  2024, so we use HTTP v1 with a service account. Set `FCM_SERVICE_ACCOUNT_JSON`
  (raw JSON) or `FCM_SERVICE_ACCOUNT_B64` (base64). The server signs a JWT →
  OAuth2 token (cached) → `messages:send`. Invalid device tokens are auto-pruned.
  Unset ⇒ dev logging (registry + triggers already live).
- **Live video (Cloudflare Stream)** — with `CLOUDFLARE_STREAM_TOKEN` +
  `CLOUDFLARE_ACCOUNT_ID`, `POST /broadcasts` now creates a real Live Input
  (RTMPS ingest + auto-recording) and returns real `ingestUrl`/`streamKey` +
  an HLS `hlsUrl` (`https://customer-<sub>.cloudflarestream.com/<uid>/manifest/
  video.m3u8`; set `CLOUDFLARE_STREAM_SUBDOMAIN`). Any provider hiccup falls back
  to a dev input so going live never hard-fails. Unset ⇒ synthetic input.
- **YouTube simulcast/chat ingest** remains the documented next step (OAuth +
  Data API) — the auth-URL hook is in place.
- **New env:** `FCM_SERVICE_ACCOUNT_JSON` | `FCM_SERVICE_ACCOUNT_B64`,
  `CLOUDFLARE_STREAM_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_STREAM_SUBDOMAIN`.
