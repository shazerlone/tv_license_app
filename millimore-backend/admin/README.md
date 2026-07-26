# Millimore Admin

The admin dashboard for the Millimore platform — a **Next.js 14** (App Router)
app that talks to the same backend API as the mobile app. Admin-only endpoints
are role-gated server-side (`role: admin`); this UI just calls them.

Deliberately lean: plain Next.js + a small `fetch` layer (`lib/api.ts`), no
Refine/React-Admin. Easy to build, deploy, and extend as later milestones add
screens (broadcasts, payouts, moderation, metrics).

## Run locally

```bash
cp .env.example .env.local          # point at your backend
npm install
npm run dev                         # http://localhost:3001
```

`NEXT_PUBLIC_API_BASE_URL` must include the `/v1` prefix, e.g.
`http://localhost:3000/v1` or `https://millimore-backend.onrender.com/v1`.

Log in with a seeded admin account: `admin@millimore.app` / `password`.
(Non-admin accounts are rejected at login.)

## Screens (milestone 2)

- **Login** — email/password, admin-only.
- **Overview** — sampled user/creator counts + pending-approval count. (Full
  DAU/MAU/GMV metrics arrive with the milestone-6 `/admin/metrics` endpoint.)
- **Users** — search + role filter + cursor pagination; inline edit of role /
  creatorStatus and ban/unban (`PATCH /admin/users/{id}`).
- **Creator queue** — pending verification applications with approve/reject
  (`/admin/creators/pending`, `/approve`, `/reject`). Investor passwords are
  shown only as "provided (encrypted, not shown)" — never the value.

## Deploy (single origin — nothing to do)

The admin is a **fully static export** (`output: 'export'`). The repo-root
`render.yaml` builds it into `admin/out` as the **last step of the backend
build**, and the API server serves it at its own root. So there is **one
service, one URL**:

- `https://millimore-backend.onrender.com/`      → this admin UI (login, etc.)
- `https://millimore-backend.onrender.com/v1/...` → the API

Same origin ⇒ no `NEXT_PUBLIC_API_BASE_URL` needed (defaults to relative `/v1`)
and no CORS. Just deploy the backend; the admin comes with it.

### Local

- Split dev (hot reload): `npm run dev` (:3001) + backend on :3000, with
  `NEXT_PUBLIC_API_BASE_URL=http://localhost:3000/v1` in `.env.local`.
- Single-origin preview: build the admin (`npm run build`) then run the backend
  — it serves `admin/out` at `/`, exactly like production.

### Host it separately instead (optional)

The static `out/` also deploys to Vercel/Netlify/any static host. There, set
`NEXT_PUBLIC_API_BASE_URL` to the backend's `https://…/v1` and the backend's
`CORS_ORIGINS` to that web origin.
