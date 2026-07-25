# Millimore Backend

One backend API serving two clients — the **Flutter mobile app** and the
**admin dashboard** — for Millimore ("YouTube meets copy trading").

- **Source of truth:** [`../docs/BACKEND_CONTRACT.md`](../docs/BACKEND_CONTRACT.md).
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

### ⏳ Next milestones (per contract §9)

2. Brokers + trading accounts + creator verification + **admin approval queue**
3. Traders / discover / feed / social (subscribe, saved, comments, likes)
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
