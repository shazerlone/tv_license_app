# Millimore — project memory

Millimore is a "YouTube meets copy trading" platform: a Flutter mobile app (this
repo) plus a backend + admin dashboard (`millimore-backend/`, with the admin in
`millimore-backend/admin/`).

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

## Backend / contract

- Single source of truth for the API: `docs/BACKEND_CONTRACT.md`. Don't invent
  endpoints without adding them there first. Match JSON shapes exactly.
- Credentials (broker/investor passwords, tokens) are **write-only** — stored
  AES-256-GCM encrypted, never returned in responses.
- Backend build must exclude `admin/` (it's a separate Next.js app); the backend
  `tsconfig` excludes it.
