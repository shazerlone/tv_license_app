# Sitegap — Lead Finder → Quotation → Pitch Pack

Find UAE / US / UK / Australia SMBs that are **commercially healthy but
digitally weak**, and output a pitch-ready pack per lead: contact details,
diagnosis, a priced quote, and draft outreach.

The product isn't a list of businesses. It's a **ranked queue of businesses
with money, customers, and a bad or missing website.**

> **Buy signal** = high rating + high review count + weak/absent website.
> Reviews prove revenue. A missing site proves the gap. Both must be true.

---

## Quick start

```bash
pip install -r sitegap/requirements.txt

# Option A — explore with realistic demo data (no API key, no spend)
python -m sitegap.cli seed
python -m sitegap.web.app          # http://127.0.0.1:5001

# Option B — pull real leads from Google Places
export GOOGLE_PLACES_API_KEY=xxxx
python -m sitegap.cli search --niches all --areas dubai --max-queries 50
python -m sitegap.cli audit  --limit 200
python -m sitegap.cli score
python -m sitegap.cli pitch  --tier A
python -m sitegap.cli export --tier A --out outputs/leads_A.csv
```

Every stage is **idempotent and resumable** — a crash at grid cell 300 never
costs you cells 1–299, and re-running a search costs nothing for cached cells.

---

## The web dashboard — everything under one roof

`python -m sitegap.web.app` gives you the whole pipeline in one place:

- **Dashboard** — the funnel (fetched → qualified → audited → scored), website
  buckets, live spend estimate, and one-click buttons to run each stage.
- **Lead Queue** — every lead ranked by opportunity score, filterable by tier,
  website bucket, niche and area.
- **Lead detail** — the full pitch pack: the ROI hook, diagnosis, a **live
  embedded mock-up of the site you'd build them**, the quotation, contact
  block, audit signals, and tabbed WhatsApp / email / walk-in outreach.

---

## How it works

| Stage | Module | What it does |
|-------|--------|--------------|
| Search | `places.py` | Google Places API (New) Text Search over a `niche × area` grid, cached on `place_id` so you never pay Google twice. |
| Qualify | `db.qualified_places` | Keep `OPERATIONAL`, rating ≥ 4.0, ≥ 20 reviews, has a phone. Applied **before** any audit. |
| Audit | `site_audit.py` | Bucket each site: `NO_SITE` / `SOCIAL_ONLY` / `BROKEN` / `WEAK` / `STRONG`, and score weakness by summing signal weights (viewport, HTTPS, TTFB, staleness, conversion path, builder default, thin content). |
| Score | `scoring.py` | `opportunity = web_weakness (0–60) + business_quality (0–40)`, then tier (A/B/C) + package + ROI hook. |
| Quote | `scoring.build_quote` | Starter / Growth / Premium / Care, chosen from bucket, review volume and niche. |
| Pitch | `pitch.py` | `outputs/pitch/{place_id}.md` — contact, diagnosis, hook, quote, outreach, mock-up prompt. |
| Mock-up | `mockup.py` | Pre-filled generation prompt + a self-contained placeholder homepage (PNG via Playwright if installed). |

---

## Scoring

```
opportunity_score (0–100) = web_weakness (0–60) + business_quality (0–40)

web_weakness:      NO_SITE 60 · SOCIAL_ONLY 55 · BROKEN 55
                   WEAK 20–50 (capped signal-weight sum) · STRONG 0–10
business_quality:  rating (4.0→10 … 4.8+→20) + reviews (20→5 … 300+→20, log)
```

Tiers: **A** ≥ 75 (call today) · **B** 55–74 · **C** < 55.

## Quotation (indicative AED)

| Package | Scope | Price |
|---------|-------|-------|
| Starter | 5 pages, mobile-first, WhatsApp + call CTA, GBP sync, basic SEO | 2,500–4,000 |
| Growth  | 10–12 pages, booking form, service pages, local SEO, 1mo support | 6,000–9,000 |
| Premium | Custom, booking + payments, EN/AR, CRM, 3mo support | 12,000–20,000 |
| Care plan | Hosting, updates, backups, monthly report | 300–800/mo |

Rules: `NO_SITE + <60 reviews → Starter` · `NO_SITE/SOCIAL_ONLY + 60+ →
Growth` · booking-driven niches → Growth minimum · `200+ reviews` or high-LTV
niches (real estate, accounting, clinics) → Premium · `STRONG` → care plan.

Prices are a starting frame — set them against your real delivery cost and
close rate.

---

## Constraints (built in, not bolted on)

- **Cost** — the field mask sets the billing SKU (`websiteUri` is not in the
  cheapest tier). `search` prints a worst-case spend estimate and takes a
  `--max-queries` budget cap. Check live Google pricing before a big fan-out.
- **ToS** — Places data has caching/display restrictions. Read them before
  redistributing anything the CSV export produces.
- **Outreach law** — unsolicited marketing SMS/WhatsApp is regulated (TDRA in
  the UAE). Every template carries an opt-out line; email, phone and walk-ins
  are safer. Log consent.

---

## CLI reference

```
search  --niches all --areas dubai [--max-queries N]
audit   [--limit N]
score
export  [--tier A|B|C] [--out PATH]
pitch   [--tier A|B|C]
mockup  --place-id XXXX
seed    [--per-area N]     # demo data, no API key
stats
```

`--areas` accepts a group (`dubai`, `uae`, `us`, `uk`, `au`, `all`) or
individual area keys. Approx lat/lng per area seeds a 4–6 km bias circle —
approximate is fine, it's a bias, not a filter.
