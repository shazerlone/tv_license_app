# Millimore — full audit (what's missing)

Snapshot after 15 milestones. Grouped by: (A) integrations to configure,
(B) backend feature gaps, (C) app/design updates, (D) hardening/quality.
Legend: 🔴 blocker for real launch · 🟡 important · 🟢 nice-to-have.

## A. Integrations to CONFIGURE (code is built + gated; just add creds)
These all work in dev/synthetic today and turn on when you add env vars.
- 🟡 **Cloudflare Stream (live video)** — `CLOUDFLARE_STREAM_TOKEN`,
  `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_STREAM_SUBDOMAIN`. Until set, broadcasts
  return a placeholder ingest/HLS (no real video).
- 🟡 **FCM push** — `FCM_SERVICE_ACCOUNT_B64`. Until set, pushes are logged only.
- 🟢 **YouTube chat** — `GOOGLE_OAUTH_CLIENT_ID/SECRET/REDIRECT_URI`.
- 🟡 **KYC (Sumsub)** — `SUMSUB_APP_TOKEN/SECRET_KEY/LEVEL_NAME`. Until set, KYC is
  manual admin review (works, but not automated identity checks).
- 🟡 **Uploads (S3)** — `STORAGE_*`. Until set, files are stored in Postgres
  (fine for low volume, not ideal at scale).
- 🔴 **Broker execution (Century / MT)** — `BROKER_BRIDGE_URL/TOKEN`. Until set,
  **prices, trades, P/L are synthetic** (see B1). This is the big one for a real
  trading product.
- 🟡 **OTP SMS provider** — `OTP_PROVIDER=twilio|msg91` + `OTP_PROVIDER_KEY`.
  Until set, OTP runs in console mode (dev codes, no real SMS).
- 🟢 **Redis** — `REDIS_URL` (ElastiCache). Needed only before scaling past one
  instance (cross-instance realtime).

## B. Backend feature gaps (genuinely not built yet)
- 🔴 **B1. Real market data & execution.** Prices, copy positions, and a trader's
  trades/equity are deterministic **synthetic** data until the broker bridge is
  wired. The seam exists (`src/mt/`), but no real broker is connected. Needs
  Century's API docs.
- 🟡 **B2. Trading-account credential verification.** `POST /accounts` stores the
  investor password but doesn't yet verify it against the broker (TODO in
  `accounts.service.ts`).
- ✅ **B3. Account password reset / forgot-password.** DONE (M17). `POST
  /auth/password/forgot|reset|change` — email token flow (no account
  enumeration, single-use tokens, ≥8-char policy) + authenticated change with
  security-alert emails.
- ⚠️ **B4. Transactional email.** Mail seam DONE (M17): `src/mail/` sends via SMTP
  (SES/SendGrid) gated by `MAIL_PROVIDER`, console fallback in dev. Wired for
  password reset + security alerts. Still to add: deposit/withdrawal/KYC receipt
  templates on the money + KYC flows.
- 🟢 **B5. On-stream trade overlays / live orders.** Broadcast `trades`/`pnl`
  return 0 until the broker bridge (B1).
- 🟢 **B6. Programmatic YouTube simulcast.** Manual simulcast (paste stream key)
  works; auto-creating the YouTube broadcast via their API is not done.
- 🟢 **B7. Multi-currency wallets.** USD only today.

## C. App (Flutter) — the biggest update area
The **backend for milestones 6–15 is live, but the mobile app UI hasn't been
built for most of it yet** (that's the other session's job — see
`docs/APP_INTEGRATION.md` §6–§13). Screens still to build/wire in the app:
- 🔴 Wallet + balance + transaction history (M6/M7)
- 🔴 Deposit (crypto) + "coming soon" methods (M6/M7)
- 🔴 Leverage selector (per-copy + default) + margin view (M7)
- 🟡 Withdraw + saved payout methods + address (M7)
- 🟡 KYC flow (Sumsub SDK / pending state) (M7)
- 🟡 Referral dashboard + share link (M9)
- 🟡 Support tickets + notification bell/announcements (M10)
- 🟡 2FA setup + login code prompt (M14)
- 🟢 Simulcast destinations + YouTube connect on go-live (M13/M15)
- 🔴 Point `lib/config.dart` `kApiBaseUrl` at the AWS URL (if not already)

## D. Admin design polish (small — admin is already premium-tier)
- 🟢 2FA setup shows the secret for manual entry but **no QR image** — add a QR
  render for one-tap authenticator setup.
- 🟢 Overview page is light; could fold in a couple of analytics sparklines.
- 🟢 A few pages use inline styles rather than shared classes (cosmetic only).

## E. Hardening & quality (pre-scale)
- ✅ **Rate limiting** — DONE (M17). `@nestjs/throttler` global (200/min/IP) with
  a tighter 10/min on login/otp/password routes; health exempt; `trust proxy` set
  so the real client IP is used behind the ALB. Returns 429 `rate_limited`.
- ✅ **Security headers** — DONE (M17). `helmet` enabled in `main.ts`.
- 🟡 **Automated tests** — 0 `.spec.ts`. Logic was verified per-milestone via
  scripts, but there's no CI test suite guarding regressions.
- 🟢 **CSRF on OAuth `state`** — YouTube callback uses `state=userId`; sign it.
- ✅ Already in place: input validation (global ValidationPipe), error envelope
  filter, graceful shutdown hooks, encrypted secrets, RBAC, audit log, 2FA.

## Suggested priority order
1. 🔴 App UI for wallet/deposit/leverage/withdraw (money loop) — M6/M7 screens.
2. 🔴 Broker execution (B1) when Century's API docs arrive.
3. 🟡 Transactional email (B4) + password reset (B3).
4. 🟡 Rate limiting (E) before public launch.
5. 🟡 Configure Cloudflare / FCM / Sumsub / S3 creds (A).
6. 🟢 Everything else.
