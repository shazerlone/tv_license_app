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

## Deploy free (Vercel recommended)

Next.js hosts best on **Vercel's free tier** (and it keeps the backend's single
free Render web-service budget intact — see the backend README).

1. Import this repo in Vercel; set **Root Directory** to `millimore-backend/admin`.
2. Add env var `NEXT_PUBLIC_API_BASE_URL = https://<your-backend>.onrender.com/v1`.
3. Deploy. Vercel auto-detects Next.js (`npm run build`).

The backend already sends permissive CORS (`CORS_ORIGINS=*` on Render), so the
Vercel origin can call it out of the box; tighten `CORS_ORIGINS` to the real
admin origin when you go to production.
