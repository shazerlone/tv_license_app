# Millimore — project memory

Millimore is a "YouTube meets copy trading" platform: a Flutter mobile app (this
repo) plus a backend + admin dashboard (`millimore-backend/`, with the admin in
`millimore-backend/admin/`).

## Compete with the giants — RESEARCH FIRST, ALWAYS

We are building to compete with market leaders (B2Core/B2Broker, Syntellicore,
Leverate, Brokeret, cTrader, eToro, Binance-tier exchange back-offices), **not** a
toy. Before creating ANY new feature, endpoint, page, or module:

1. **Research the giants first.** Look up how the leading platforms do this exact
   thing — what pages they have, what fields/states/actions, what a real
   production flow includes, what edge cases they handle. Use `WebSearch` when the
   answer isn't already obvious from prior research.
2. **Match their capability set, then exceed it.** Ours must cover at least what
   they cover, then add clear improvements — better UX, smarter defaults, fewer
   steps, a cleaner design. Never ship a "silly"/half version that's obviously
   behind the standard.
3. **Write down the benchmark.** Keep `docs/ADMIN_BENCHMARK.md` (and add
   equivalents for app-side areas when relevant) updated: what leaders have, what
   we have, what's still missing. Mark each capability ✅ / ⚠️ / ❌ honestly.
4. **State the research in the plan.** When proposing/building a feature, briefly
   say what the giants do and how ours matches-or-beats it — so the founder
   (non-technical) can trust we're at market standard.

This applies to backend AND UI. The design must also feel giant-tier (see below);
the feature set must be giant-tier too.

## Design language — ALWAYS follow this

Every UI — mobile app, admin dashboard, marketing, anything web — must look like
a **premium, professional, multi-million-dollar fintech product** (Linear /
Stripe / Robinhood tier). Clean, light, generous whitespace, restrained color.
**Never** a dark "admin template", neon blue, cramped rows, or 2000s styling.

Canonical tokens live in `lib/theme/app_theme.dart` (Flutter) and are mirrored
for web in `millimore-backend/admin/DESIGN.md` — **read that file before writing
or changing any web UI.** Summary:

- **Light theme**, white canvas (`#FFFFFF`), near-black text (`#0F172A`).
- **Font: Inter**, tight negative letter-spacing on big headings, weights 700–800
  for display / 400–500 body.
- **Accent blue `#2563EB` used sparingly** — primary buttons, active states,
  links, focus rings only; not big fills or backgrounds.
- Slate palette: secondary `#64748B`, muted `#94A3B8`, borders `#E2E8F0`,
  surfaces `#F8FAFC`/`#F1F5F9`.
- Semantic: green `#22C55E`, amber `#F59E0B`, red `#EF4444` — as soft tinted chips.
- Radii 14px cards / 10px controls / 999px pills. Subtle 1px borders + very soft
  shadows only.

## This is a real product headed for AWS at scale — keep it portable

The founder is non-technical and relies on Claude as developer/advisor. The app
must later move to AWS (or similar) and serve millions. **Never** paint us into a
corner. Non-negotiable guardrails (full detail: `millimore-backend/ARCHITECTURE.md`):

- **Stateless API** — no in-memory sessions, no local-disk source of truth. State
  lives in Postgres / Redis / object storage so we can run many copies behind a
  load balancer (horizontal scale).
- **12-factor config** — everything via environment variables; secrets never in
  code (env now → AWS Secrets Manager later, same names).
- **Swappable managed services** — Postgres via Prisma (→ Aurora/RDS by changing
  `DATABASE_URL`), Redis (→ ElastiCache), storage via `STORAGE_*` env (→ S3+CloudFront).
- **Isolate integrations behind small modules** (OTP, MT bridge, streaming,
  storage) so each can be swapped without touching the app or the API contract.
- **Heavy/slow work goes through queues/workers**, not the request path.
- **Don't over-engineer early.** Build clean + portable on cheap infra; turn on
  scale layers (replicas, cache, CDN, autoscaling) when real metrics demand it.
  Each step must be an upgrade, not a rewrite.
- A production `Dockerfile` exists — the API is a stateless container, ready for
  ECS/Fargate/EKS.

## Backend / contract

- Single source of truth for the API: `docs/BACKEND_CONTRACT.md`. Don't invent
  endpoints without adding them there first. Match JSON shapes exactly.
- Credentials (broker/investor passwords, tokens) are **write-only** — stored
  AES-256-GCM encrypted, never returned in responses.
- Backend build must exclude `admin/` (it's a separate Next.js app); the backend
  `tsconfig` excludes it.
