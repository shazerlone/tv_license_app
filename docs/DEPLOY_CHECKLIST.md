# Millimore — deploy checklist

Everything needed to run the backend + admin live on AWS (ECS), with a smoke
test to confirm it. The app is a single stateless container that, on startup,
runs database migrations, seeds the demo/admin accounts, and serves both the API
(`/v1/...`) and the admin UI (`/`).

Verified deploy-ready: all 16 migrations apply on a fresh database and the seed
runs (the exact container startup sequence). Full app boots with 139 routes.

---

## 1. Environment variables (ECS → service → container → environment)

### Required (the app will not work without these)
| Name | What | Notes |
| --- | --- | --- |
| `DATABASE_URL` | Postgres connection string | `postgresql://USER:PASS@HOST:5432/DB?sslmode=require` — URL-encode symbols in the password |
| `JWT_SECRET` | Signs login tokens | Any long random string; keep it stable |
| `CREDENTIAL_ENCRYPTION_KEY` | Encrypts secrets (broker/investor passwords, 2FA secrets, payout methods, YouTube tokens) | **Keep it stable forever** — rotating it makes existing encrypted data undecryptable |

### Recommended defaults
| Name | Value | Notes |
| --- | --- | --- |
| `NODE_ENV` | `production` | |
| `API_PREFIX` | `v1` | The app serves under `/v1` |
| `PORT` | `3000` | Match your ECS/container port |
| `CORS_ORIGINS` | `*` | Native app needs no CORS; tighten to real web origins if you add browser clients |
| `OTP_PROVIDER` | `console` | Dev OTP (code returned as `devCode`). Swap to `twilio`/`msg91` + `OTP_PROVIDER_KEY` for real SMS |
| `REDIS_URL` | (ElastiCache URL) | Optional but recommended before scaling past 1 instance — enables cross-instance realtime |

### Optional integrations — all gated (leave unset = dev/synthetic, nothing breaks)
| Feature | Env vars | Get them from |
| --- | --- | --- |
| **Push (FCM)** | `FCM_SERVICE_ACCOUNT_B64` (or `FCM_SERVICE_ACCOUNT_JSON`) | Firebase → Project settings → Service accounts → Generate key → base64 the JSON |
| **Live video (Cloudflare)** | `CLOUDFLARE_STREAM_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_STREAM_SUBDOMAIN` | Cloudflare dash → Stream (Account ID, subdomain) + My Profile → API Tokens |
| **YouTube chat** | `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`, `GOOGLE_OAUTH_REDIRECT_URI` | Google Cloud Console → OAuth client. Redirect = `https://<your-host>/v1/youtube/callback` |
| **KYC (Sumsub)** | `SUMSUB_APP_TOKEN`, `SUMSUB_SECRET_KEY`, `SUMSUB_LEVEL_NAME` | Sumsub dashboard. Unset = manual KYC review in admin |
| **Uploads (S3)** | `STORAGE_BUCKET`, `STORAGE_REGION`, `STORAGE_ACCESS_KEY_ID`, `STORAGE_SECRET_ACCESS_KEY`, `STORAGE_PUBLIC_BASE_URL` | AWS S3 + IAM. Unset = files stored in Postgres |
| **Broker execution** | `BROKER_BRIDGE_URL`, `BROKER_BRIDGE_TOKEN` | Your MT/broker gateway (Century). Unset = synthetic prices/fills |

> **Fees, leverage, limits, referral rates, deposit toggles** are edited live in
> the admin **Settings** page — the env vars (`PLATFORM_FEE_SHARE`,
> `MAX_LEVERAGE`, `DEPOSIT_AUTO_CONFIRM`, …) are only first-run defaults.
> **Set `DEPOSIT_AUTO_CONFIRM=false` (or toggle it off in Settings) before real
> launch** so deposits require admin/webhook confirmation.

---

## 2. Deploy / redeploy steps
1. Push to the branch → the GitHub Action builds the image and pushes it to ECR.
2. Wait for the Action to go green.
3. AWS Console → **ECS** → your service → **Update service** → set/confirm the
   env vars above → tick **Force new deployment** → **Update**.
4. On boot the container runs `prisma migrate deploy` (creates/updates tables),
   `db:seed` (idempotent), then starts. Wait ~2–3 min for the task to be healthy.

## 3. Smoke test (confirm it's live)
Run the script against your live URL (replace the host):
```
BASE="https://<your-host>/v1" ./millimore-backend/scripts/smoke.sh
```
It checks health, config, login (seeded admin), an authed call, and the admin UI.
All green = you're live. Seeded logins (password `password`):
`admin@millimore.app`, `trader@millimore.app`, `priya@millimore.app`.

## 4. Point the Flutter app at the backend
In `lib/config.dart` set `kApiBaseUrl` to `https://<your-host>/v1` (WebSocket
derives from it as `wss://<your-host>/v1/ws`). See `docs/APP_INTEGRATION.md`.

---

## 5. What's live vs. what needs your config
- **Live out of the box:** auth/2FA, wallet + ledger, deposits/withdrawals,
  copy engine + leverage/margin, traders/social/feed, realtime WS, broadcasts
  (dev video), admin console (users, transactions, payouts, KYC, referrals,
  support, announcements, analytics, audit, team/RBAC, settings, security).
- **Turns on with the env above:** real push (FCM), real video (Cloudflare),
  YouTube chat, Sumsub KYC, S3 uploads, real broker prices/fills.
