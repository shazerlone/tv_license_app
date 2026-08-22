# Millimore — Design Language

**Read this before touching any UI.** Every surface (admin dashboard, marketing,
future web) must feel like a **premium, multi-million-dollar fintech product** —
in the tier of Linear, Stripe, Robinhood, Arc. Clean, light, confident,
generous whitespace, restrained color. Never "dashboard template" or 2000s-era.

Source of truth for tokens: the Flutter app's `lib/theme/app_theme.dart`. The
web UI mirrors it exactly so the two products look like one brand.

## Non-negotiables

- **Light theme.** White canvas, near-black text. No dark navy admin chrome.
- **Font: Inter**, everywhere. Tight negative letter-spacing on large headings
  (`-0.02em` to `-0.03em`), heavy weights (700–800) for display, 400–500 for body.
- **Color is restrained.** Blue `#2563EB` is an accent for primary actions and
  active states only — not large fills, not backgrounds. Most of the screen is
  white / slate-50 / slate text. Status uses soft tinted chips, not loud blocks.
- **Depth is subtle.** 1px slate borders + very soft shadows
  (`0 1px 2px rgba(15,23,42,.04)`), never heavy drop shadows or gradients-as-decor.
- **Radii:** 14px cards/containers, 10px inputs/buttons, 999px pills/avatars.
- **Whitespace is a feature.** Roomy padding (20–28px in cards), 12–16px gaps.

## Tokens (mirror of the Flutter theme)

| Token | Value | Use |
| ----- | ----- | --- |
| `--primary` | `#2563EB` | primary buttons, active nav, links, focus ring |
| `--primary-hover` | `#1D4ED8` | button hover |
| `--primary-50` | `#EFF4FF` | active nav bg, subtle blue tint |
| `--purple` | `#A78BFA` | secondary accent (charts, highlights) |
| `--green` | `#22C55E` | success / approved / connected |
| `--amber` | `#F59E0B` | pending / warning |
| `--red` | `#EF4444` | destructive / rejected / banned |
| `--bg` | `#FFFFFF` | page canvas |
| `--surface` | `#F8FAFC` | inset fields, muted panels |
| `--surface-2` | `#F1F5F9` | table header, hover |
| `--border` | `#E2E8F0` | hairlines, card borders |
| `--text` | `#0F172A` | primary text |
| `--text-secondary` | `#64748B` | secondary text |
| `--text-muted` | `#94A3B8` | muted / captions |

## Components

- **Buttons:** primary = solid blue, white text, soft shadow, 10px radius,
  weight 600. Secondary = white + 1px border. Danger = red text on red-50, or
  solid red for confirm. Small = 6/12 padding.
- **Status chips:** soft tint bg + saturated text (e.g. green-50 bg / green-700
  text), 999px radius, 12px, weight 600. One per state — never rainbow rows.
- **Avatars:** initials on a soft slate/brand tint, circular. Use for every user.
- **Tables:** slate-50 header, uppercase 11px muted labels, 56px+ rows, hairline
  dividers, hover = slate-50. IDs / account numbers in a monospace tint.
- **Cards / stat tiles:** white, 1px border, soft shadow, uppercase muted label
  + large tight-tracked number.
- **Inputs:** white or slate-50 fill, 1px border, blue focus ring (2px), 10px radius.
- **Empty states:** centered, muted, a short friendly line — never a bare table.

## Do / Don't

- ✅ Lots of white, one clear accent, crisp type, aligned grids.
- ✅ Monospace for identifiers, tabular numbers for money.
- ❌ Dark admin themes, neon blue, heavy borders, drop shadows, clip-art icons,
  cramped rows, multiple competing accent colors.
