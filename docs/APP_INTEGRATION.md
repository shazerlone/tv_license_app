# Millimore — App Integration Guide (for the app session)

**Who this is for:** the `millimore-app` (Flutter) Claude session. The backend is
built and live; this is how you connect the app to it, screen by screen, without
changing the UI.

**Sync model:** the API is defined in [`BACKEND_CONTRACT.md`](./BACKEND_CONTRACT.md)
(single source of truth). This file is the *app-side how-to* for consuming it.

> **SKIP RULE — read before doing anything.** This guide is idempotent. Before
> each step, check whether it's already done in the repo (search for the file/flag
> named). **If it already exists and works, skip that step.** Only do what's
> missing. Don't recreate an `ApiClient` if one is already there; don't re-wire a
> screen that already calls the API.

---

## 0. The backend

- **Base URL (production — AWS):**
  `https://mi-41bae9db1d7c40e2846cc32d8ac9f51f.ecs.us-west-2.on.aws/v1`
  - This is the live AWS (ECS) backend. Set `kApiBaseUrl` in `lib/config.dart`
    to this (or pass `--dart-define=API_BASE_URL=…`). WebSocket base is the same
    host with `wss://` and `/v1/ws`.
  - (Old Render URL `https://millimore-backend.onrender.com/v1` still works as a
    fallback but AWS is now primary.)
  - Same host serves the admin UI at `/` — the app only ever calls `/v1/...`.
- **Base URL (local backend):** `http://localhost:3000/v1`
- **Auth:** `Authorization: Bearer <JWT>` on every authenticated call.
- **Content-Type:** `application/json`
- **Errors:** `{ "error": { "code": "string", "message": "human text" } }` with a
  real HTTP status. Parse `error.message` for user-facing text.
- **Pagination:** `?limit=20&cursor=<opaque>` → `{ "items": [...], "nextCursor": "..." }`.

**Seeded test logins** (password is `password`):
`trader@millimore.app` (creator), `priya@millimore.app` (follower),
`admin@millimore.app` (admin — dashboard only).

---

## 1. One-time setup (do once, then skip)

**a) Config flag** — in `lib/config.dart`, add (if not present):
```dart
const bool useBackend = true; // flip to false to fall back to the demo store
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://millimore-backend.onrender.com/v1',
);
```
Run with a local backend via: `flutter run --dart-define=API_BASE_URL=http://localhost:3000/v1`.

**b) `lib/services/api_client.dart`** (if not present) — a thin HTTP client that:
- prefixes `kApiBaseUrl`, sets JSON headers, adds the bearer token,
- decodes JSON, and throws a typed `ApiException(code, message, status)` on non-2xx
  by reading the `{ error }` envelope,
- exposes `get/post/patch/delete` + a cursor-paginated helper.
Use `package:http` (already common) or `dio`. Store the token with
`flutter_secure_storage` (preferred) or `shared_preferences`.

**c) Repository layer** — thin repos (`AuthRepository`, `TradersRepository`,
`SocialRepository`, `AccountsRepository`) that call `ApiClient` and return the
existing models in `lib/models/`. Keep `SessionController` / `AppState` as the
UI-facing API; swap their **internals** to call repos when `useBackend` is true,
demo store when false. **The widgets don't change.**

---

## 2. What's LIVE now — flip these screens

Map of demo-store method → live endpoint. Check each; **skip if already wired.**

### Auth & onboarding (contract §4.1) — milestone 1 ✅
| App (demo) | Endpoint | Notes |
| ---------- | -------- | ----- |
| `SessionController.signInAsFollower` | `POST /auth/register/follower` | returns `{ token, user }` — store token, set session |
| `SessionController.signInAsCreator` | `POST /auth/register/creator` | returns `{ token, user }`; sets `creatorStatus: pending` |
| OTP screen (`otp_screen.dart`) | `POST /auth/otp/request` → `{ requestId }`, then `POST /auth/otp/verify` → `{ token, user }` | in dev the code is returned as `devCode` so you can test without SMS |
| `login_screen.dart` (demo `trader@millimore.app`) | `POST /auth/login` | `{ email, password }` → `{ token, user }` |
| Apple / Google buttons | `POST /auth/social/apple` / `/google` | send provider token |
| `SessionController.signOut` | `POST /auth/logout` | then discard the token locally |
| profile load / edit | `GET /me`, `PATCH /me` | |

> The `user` object matches the contract §3 `User`. Map it into `UserProfile`
> (role, creatorStatus, market, platform, residenceIso/Country all line up).

### Creator verification (contract §4.2) — milestone 2 ✅
- Replace the demo **"Mark as verified"** (`SessionController.approveCreator`)
  with the real flow: creator submits `POST /creator/apply`; status becomes
  `pending`; **poll `GET /creator/status`** (or refresh on focus) to pick up
  `approved`/`rejected` after an admin acts. (Realtime push arrives in milestone 5.)

### Brokers & accounts (contract §4.3) — milestone 2 ✅
| App (demo) | Endpoint |
| ---------- | -------- |
| broker list (`data/brokers.dart`, add-account sheet) | `GET /brokers?country=<iso>` |
| `AppState.accounts` | `GET /accounts` |
| `AppState.addAccount` | `POST /accounts` (`{ brokerId, accountNumber, server, password }`) |
| `AppState.removeAccount` | `DELETE /accounts/{id}` |
| change password | `POST /accounts/{id}/password` |
> `password` is **write-only** — never expect it back. Show `masked` + `status`.

### Traders / discover / feed / social (contract §4.4–4.6) — milestone 3 ✅
| App (demo) | Endpoint |
| ---------- | -------- |
| discover / leaderboard lists | `GET /traders?category=&q=&sort=copiers\|return&cursor=` |
| `trader_profile_screen.dart` | `GET /traders/{id}` + `/{id}/posts` + `/{id}/trades?status=` + `/{id}/equity?range=30d` |
| discover reels | `GET /discover/reels` |
| `AppState.subscribe/unsubscribe` | `POST/DELETE /subscriptions/{traderId}` |
| `AppState.subscribedTraderIds` | `GET /subscriptions` (returns `[Trader]`) |
| `AppState.toggleNotify` | `POST /subscriptions/{traderId}/notify` `{ on }` |
| home feed | `GET /feed` |
| `AppState.toggleLike` / `likeCount` | `POST/DELETE /posts/{id}/like` → `{ likes }` |
| `AppState.toggleSave` / `savedPostIds` | `POST/DELETE /posts/{id}/save`, `GET /saved` |
| `AppState.commentsFor` / `addComment` | `GET/POST /posts/{id}/comments` |
| compose (studio) | `POST /posts` |

> **Trader IDs are real strings** (`t_marcus`, …), not `'1','2','3'`. The demo
> seeds `_subscribed = {'1','2','3'}` — drop those hardcoded ids; use ids from the
> API. `Post.isLiked`/`saved` and `likes`/`comments` counts come from the API, so
> you can lean on server state instead of the local `_liked`/`_likeCount` maps.

---

## 3. NOT live yet — keep the demo store for these

Do **not** wire these; they arrive next. Leave `useBackend`-guarded fallbacks:
- **Copy engine / positions / portfolio** (`copy_*`, `copied_trades_screen`,
  portfolio summary) — milestone 4.
- **Live streaming / go-live / live chat / viewers / reactions** — milestone 5.
- **Realtime prices, floating P/L, WebSocket** — milestone 4/5.
- **Live on-stream orders, payouts** — milestone 6.

`GET /traders/{id}/trades` and `/equity` currently return **deterministic
synthetic** data (stable per trader) — fine to render; they become real in
milestone 4/6 with no shape change.

---

## 4. Suggested order (flip screen-by-screen, verify, move on)

1. ApiClient + token storage + `useBackend` flag (§1).
2. Login / register / OTP → real auth; persist token; `GET /me` on launch.
3. Brokers + accounts screens.
4. Discover / trader profile / feed / social (likes, saves, comments, subscribe).
5. Leave copy/live/portfolio on demo until milestones 4–6 land.

After each screen, test against the live URL with a seeded login. Keep the UI
identical — only the data source changes.

---

## 5. When the contract changes

If you need a field/endpoint that isn't in `BACKEND_CONTRACT.md`, **add it to the
contract first** and flag it — the backend session implements against that file.
Don't invent client-only endpoints. The two sessions only stay in sync through
these docs.

---

## 6. Wallet & money model (milestone 6) — NEW, live

The trading model is **in-app wallet → corporate broker account** (not per-user
MT logins). Users deposit into a Millimore wallet; copying draws from it; profit,
trader commission, and Millimore's fee are settled to wallets. All live now
against the AWS backend.

**Screens to wire:**
- **Wallet** — `GET /wallet` → `{ balance, currency }`; `GET /wallet/ledger` →
  money-movement list. Show balance on the portfolio/home header.
- **Deposit** — `GET /deposits/methods` (render **Crypto** active; MetaTrader /
  card / bank as **"Coming soon"** chips). `POST /deposits { amount, asset? }`
  returns a `Deposit` (address + status). In test mode it auto-confirms and the
  wallet is credited immediately; refresh `GET /wallet` after.
- **Copy** — `POST /copy/{traderId}/start { amount }` now **spends wallet balance**
  (`accountId` is optional). If the wallet is short it returns
  `error.code = "insufficient_balance"` — prompt the user to deposit.
  `POST /copy/{traderId}/stop` returns principal + profit to the wallet minus the
  performance fee; the user gets a `copy.settled` user event.
- **Trader commission** — a trader sets their performance fee (1–30%) via
  `PATCH /creator/commission { percent }`. Show `commissionPercent` on trader
  profiles (it's on the Trader object).
- **Earnings (creator studio)** — `GET /creator/earnings` is now real:
  `{ balance, currency, pending, lifetimeEarned, history[] }`.
- **Withdraw** — `POST /creator/payouts { amount, method?, note? }` (holds funds);
  `GET /creator/payouts` for history. Admin approves/rejects in the dashboard.

> Fees: the trader's performance fee is split — the trader keeps most, Millimore
> keeps a configurable share (`PLATFORM_FEE_SHARE`, default 30%). The copier only
> ever sees one fee deducted from profit. Losing trades incur no fee.

**Contract details:** `BACKEND_CONTRACT.md` §11 "Wallet, deposits, copy
settlement & payouts (milestone 6)".

---

## 7. Financial ops, leverage & KYC (milestone 7) — NEW, live

- **App config** — call `GET /config` (no auth) on launch to get `maxLeverage`,
  limits, and which deposit methods are active. Render leverage sliders/caps and
  deposit method chips from this.
- **Leverage** — wallet balance = **margin**; exposure = `amount × leverage`.
  - User default: `PATCH /me { leverage }` (1..maxLeverage). Shows on `GET /me`
    and `GET /wallet` (`leverage`).
  - Per-copy: `POST /copy/{traderId}/start { amount, leverage? }` — pass a
    leverage slider value (max from `/config`); server clamps it.
  - `GET /portfolio/summary` now returns `freeMargin`, `usedMargin`, `equity`,
    `marginLevel` — build the MT-style margin header from these.
- **Transactions screen** — `GET /wallet/transactions` (unified: deposits,
  trades, fees, commissions, withdrawals). `GET /wallet/ledger` is the raw
  ledger if you need it.
- **Profile/address** — `PATCH /me { addressLine, city, postalCode, name, … }`.
- **Payout methods** — `GET/POST/DELETE /wallet/payout-methods`
  (`{ type:'crypto'|'bank', label, address?/asset? | bankName?/accountNumber?/iban? }`).
  Responses are masked. A withdrawal **requires** a saved method.
- **Withdraw** — `POST /creator/payouts { amount, methodId, note? }`. Handle these
  error codes with clear UI: `kyc_required`, `invalid_payout_method`,
  `below_min_withdrawal`, `above_max_withdrawal`, `daily_limit_exceeded`,
  `insufficient_balance`.
- **KYC** — `POST /kyc/start` → launch the Sumsub SDK with `accessToken` (if
  `manual:true`, just show “submitted — pending review”). `GET /kyc` for status;
  also on `GET /me` as `kycStatus`. Gate the withdraw screen on
  `kycStatus === 'verified'` when `/config.kycRequiredForWithdrawal` is true.

**Contract details:** `BACKEND_CONTRACT.md` → "Financial operations, leverage &
compliance (milestone 7)".

---

## 8. Answers to app-session questions (resolved)

1. **WebSocket schemas** — now fully documented in `BACKEND_CONTRACT.md` →
   "WebSocket message schemas (realtime — M4/M5)": connect URL, subscribe op,
   the `{ ch, type, data }` envelope, and every payload for `prices`,
   `portfolio`, `user` (incl. `copy.settled`), and `broadcast:{id}`.
2. **Read current commission / leverage** —
   - Commission: `GET /creator/commission` → `{ commissionPercent }` (new).
   - Default leverage: already on `GET /me` (`leverage`) and `GET /wallet`
     (`leverage`). Set via `PATCH /me { leverage }`.
3. **`commissionPercent` on trader** — added to `TraderDto` (also on
   `GET /traders/{id}`), so you can render it on trader profiles.
4. **Typed responses** — `GET /config` (`PublicConfigDto`), `GET /kyc`
   (`KycStatusResponseDto`), `POST /kyc/start` (`KycStartResponseDto`), and
   `GET /wallet/transactions` (`[UserTxnDto]`) now publish real schemas in
   `openapi.json`. Field names to rely on for `/config`: `maxLeverage`,
   `defaultLeverage`, `minDeposit`, `minWithdrawal`, `maxWithdrawalPerTx`,
   `maxWithdrawalPerDay`, `kycRequiredForWithdrawal`, `depositMethods[]`
   (`{ id, label, active, comingSoon? }`), `maintenanceMode`.
