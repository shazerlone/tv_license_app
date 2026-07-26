# Millimore Backend

One backend API serving two clients — the **Flutter mobile app** and the
**admin dashboard** — for Millimore ("YouTube meets copy trading").

- **Source of truth:** [`docs/BACKEND_CONTRACT.md`](docs/BACKEND_CONTRACT.md).
  Do not add endpoints that aren't in the contract without adding them there first.
- **Stack:** NestJS (TypeScript) · PostgreSQL (Prisma) · Redis (WebSocket pub/sub) ·
  Next.js admin (added in a later milestone as `./admin`).

> This folder is self-contained (own `package.json`, `.gitignore`, Prisma schema)
> so it can be lifted into a standalone `millimore-backend` repo unchanged.

## Quick start

```bash
cp .env.example .env            # fill in secrets; dev defaults work as-is
npm install
npm run prisma:generate

# Postgres + Redis (either works):
docker compose up -d            # if you have Docker
# ...or point DATABASE_URL / REDIS_URL at existing instances

npm run prisma:migrate          # create tables
npm run db:seed                 # demo users + a pending creator application
npm run start:dev               # http://localhost:3000/v1  (Swagger UI at /v1/docs)
```

### Seeded logins

| email                  | password   | role     |
| ---------------------- | ---------- | -------- |
| `admin@millimore.app`  | `password` | admin    |
| `trader@millimore.app` | `password` | creator  |
| `priya@millimore.app`  | `password` | follower |

Plus one pending creator application (Aisha Khan) for the admin approval queue.

## API docs / OpenAPI

- Live Swagger UI: `GET /v1/docs` while the server runs.
- Static spec (committed for the app team): [`openapi.json`](./openapi.json).
  Regenerate with `npm run openapi:gen` — no running server or DB required.

## Conventions (from contract §1)

- Base path `/v1`; auth via `Authorization: Bearer <JWT>`.
- Errors: `{ "error": { "code", "message" } }` with the right HTTP status.
- **Credentials are write-only:** broker/investor passwords and tokens are sent
  on write, stored **AES-256-GCM encrypted**, and never returned in responses.

## Deploy to Render (free)

A Render **Blueprint** lives at the repo root ([`../render.yaml`](../render.yaml)):
one free web service + one free Postgres. Redis is added later when the realtime
milestones need it.

1. Push this branch to GitHub (done).
2. In Render: **New → Blueprint**, pick this repo, and confirm the branch
   (`claude/millimore-backend-admin-yl2ffz`, or `main` after you merge).
3. Render reads `render.yaml`, provisions the Postgres DB, injects `DATABASE_URL`,
   generates `JWT_SECRET` + `CREDENTIAL_ENCRYPTION_KEY`, builds the API **and the
   admin UI**, migrates, seeds, and starts. **Apply** and wait for the first deploy.
4. **One URL does both** (single origin):
   - `https://<service>.onrender.com/` → the **admin dashboard** (login page).
   - `https://<service>.onrender.com/v1/...` → the **API** (point the app here).
   - Health: `/v1/health` · Swagger: `/v1/docs`.

> The API server serves the admin's static export at `/` via
> `@nestjs/serve-static`; everything under `/v1` stays the API. Nothing at `/`
> returns raw JSON anymore — it's the login page.

### Keeping it warm (free)

`.github/workflows/keep-warm.yml` pings `/v1/health` every ~10 min so the app
usually hits a warm instance. After deploying, set the URL once:
**repo → Settings → Secrets and variables → Actions → Variables →** add
`RENDER_HEALTH_URL = https://<service>.onrender.com/v1/health` (or edit
`DEFAULT_HEALTH_URL` in the workflow). Until set, the job safely no-ops.
GitHub disables cron workflows after 60 days of repo inactivity — push anything
or use the manual "Run workflow" button to re-enable.

Notes on the free tier:

- The web service **sleeps after ~15 min idle** and cold-starts (~30–60s) on the
  next request. The keep-warm workflow above mitigates this; upgrading the
  instance removes sleep entirely.
- Free **Postgres expires ~30 days** after creation (Render policy) — upgrade the
  DB plan before then to keep data.
- OTP runs in `console` mode, so codes come back as `devCode` in the response —
  the app can log in without an SMS gateway. Set `OTP_PROVIDER=twilio|msg91` +
  `OTP_PROVIDER_KEY` in the Render dashboard to send real SMS.
- Keep `CREDENTIAL_ENCRYPTION_KEY` stable; rotating it makes already-encrypted
  credentials undecryptable.

## Milestone status

### ✅ Milestone 1 — Auth + users + JWT + OTP (LIVE)

The app can flip login/register/onboarding from the demo store to these:

| Method & path                  | Contract | Notes |
| ------------------------------ | -------- | ----- |
| `POST /v1/auth/register/follower` | §4.1 | Creates follower, returns `{ token, user }` |
| `POST /v1/auth/register/creator`  | §4.1 | Creates creator (`creatorStatus: pending`) + verification application |
| `POST /v1/auth/otp/request`       | §4.1 | `{ phone } → { requestId }` (+ `devCode` in console mode) |
| `POST /v1/auth/otp/verify`        | §4.1 | `{ requestId, code } → { token, user }` |
| `POST /v1/auth/login`             | §4.1 | Email + password → `{ token, user }` |
| `POST /v1/auth/social/apple`      | §4.1 | `{ identityToken } → { token, user }` * |
| `POST /v1/auth/social/google`     | §4.1 | `{ idToken } → { token, user }` * |
| `POST /v1/auth/logout`            | §4.1 | Stateless JWT — client discards token |
| `GET  /v1/me`                     | §4.1 | Current user |
| `PATCH /v1/me`                    | §4.1 | Update name/photo/username/… |

\* Social login decodes the provider token to bootstrap accounts. Signature
verification against Apple/Google JWKS is a hardening TODO before production
(marked in `auth.service.ts`).

### ✅ Milestone 2 — Brokers + accounts + creator verify + admin queue (LIVE)

Backend endpoints:

| Method & path | Contract | Notes |
| ------------- | -------- | ----- |
| `GET  /v1/brokers?country=` | §4.3 | Country-gated broker list |
| `GET  /v1/accounts` | §4.3 | My trading accounts (masked, no password) |
| `POST /v1/accounts` | §4.3 | Connect account; password write-only/encrypted |
| `DELETE /v1/accounts/{id}` | §4.3 | Disconnect |
| `POST /v1/accounts/{id}/password` | §4.3 | Change account password |
| `GET  /v1/creator/status` | §4.2 | `{ creatorStatus, reason? }` |
| `POST /v1/creator/apply` | §4.2 | Apply → `creatorStatus: pending` |
| `GET  /v1/admin/users` | §6 | Paginated, `?q=&role=&cursor=` (admin) |
| `PATCH /v1/admin/users/{id}` | §6 | `role? / banned? / creatorStatus?` (admin) |
| `GET  /v1/admin/creators/pending` | §6 | Verification queue (admin) |
| `POST /v1/admin/creators/{id}/approve` | §6 | Approve application (admin) |
| `POST /v1/admin/creators/{id}/reject` | §6 | Reject application (admin) |

Plus the **admin dashboard** (`./admin`, Next.js) with login, users, and the
creator approval queue. See [`admin/README.md`](./admin/README.md).

### ✅ Milestone 3 — Traders / discover / feed / social (LIVE)

| Method & path | Contract | Notes |
| ------------- | -------- | ----- |
| `GET /v1/traders` | §4.4 | Discover: `category`, `q`, `sort=copiers\|return`, cursor |
| `GET /v1/traders/{id}` | §4.4 | Full trader profile |
| `GET /v1/traders/{id}/posts` | §4.4 | A trader's posts |
| `GET /v1/traders/{id}/trades` | §4.4 | Public trades (`status=active\|closed`) |
| `GET /v1/traders/{id}/equity` | §4.4 | Equity curve (`range=30d`) |
| `GET /v1/discover/reels` | §4.4 | Mixed live/trade/lesson feed |
| `GET/POST/DELETE /v1/subscriptions[...]` | §4.5 | Follow / unfollow / list / `notify` bell |
| `GET /v1/feed` | §4.5 | Posts from subscribed traders |
| `POST/DELETE /v1/posts/{id}/like` | §4.5 | → `{ likes }` |
| `POST/DELETE /v1/posts/{id}/save` · `GET /v1/saved` | §4.5 | Save / unsave / list |
| `GET/POST /v1/posts/{id}/comments` | §4.5 | List / add comment |
| `POST /v1/posts` | §4.6 | Compose (creator) |

> Trader `trades`/`equity` are deterministic **synthetic** data until the real
> trade feed arrives in milestone 4/6.

### ⏳ Next milestones (per contract §9)

4. Copy engine + positions + portfolio + WS `prices`/`portfolio`
5. Broadcasts (Cloudflare) + WS chat/viewers/reactions + YouTube chat ingest
6. Live orders → MT bridge; payouts; full admin metrics/monitoring

## Scripts

| Script | Purpose |
| ------ | ------- |
| `npm run start:dev` | Watch-mode dev server |
| `npm run build` / `npm start` | Compile / run production build |
| `npm run prisma:migrate` | Create/apply a dev migration |
| `npm run db:seed` | Seed demo/mock data (idempotent) |
| `npm run openapi:gen` | Write `openapi.json` from the code |
| `npm run lint` | ESLint |

## Project layout

```
millimore-backend/
├─ prisma/            schema.prisma · migrations · seed.ts
├─ scripts/           generate-openapi.ts
├─ src/
│  ├─ auth/           register / otp / login / social + JWT strategy
│  ├─ users/          GET/PATCH /me + User serializer
│  ├─ common/         crypto (AES-GCM) · guards · decorators · error filter · ids
│  ├─ prisma/         PrismaService
│  └─ main.ts         bootstrap + Swagger
└─ .env.example       every secret from contract §7
```
