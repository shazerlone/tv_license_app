"""Pitch pack generator → outputs/pitch/{place_id}.md

Six blocks per lead: contact, diagnosis, the hook, quotation, draft outreach
(WhatsApp / email / walk-in), and a pre-filled mockup prompt.

Outreach templates carry an opt-out line by design — unsolicited marketing is
regulated (TDRA in the UAE), and that compliance risk is bigger to the
business than any slow scraper.
"""

from __future__ import annotations

import json
import os
from typing import Any

from . import config, db, scoring
from .config import AREAS, NICHES, PACKAGES, OPT_OUT_LINE
from .mockup import mockup_prompt

BUCKET_LABEL = {
    "NO_SITE": "No website",
    "SOCIAL_ONLY": "Social-only",
    "BROKEN": "Broken site",
    "WEAK": "Weak site",
    "STRONG": "Strong site",
}


def _reasons(row: Any) -> list[str]:
    try:
        return json.loads(row["reasons_json"]) if row["reasons_json"] else []
    except (TypeError, KeyError, json.JSONDecodeError):
        return []


def _area_label(key: str) -> str:
    return AREAS[key].label if key in AREAS else (key or "").replace("_", " ").title()


def _niche_label(key: str) -> str:
    return NICHES.get(key, key or "").split(" in ")[0]


def outreach_parts(row: Any) -> dict[str, str]:
    """The three draft messages, shared by the markdown pack and the web UI."""
    name = row["name"] or "This business"
    area = _area_label(row["area"])
    niche = _niche_label(row["niche_query"])
    bucket = row["bucket"] or "WEAK"
    reviews = row["review_count"] or 0
    rating = row["rating"] or 0
    quote = scoring.build_quote(bucket, row["niche_query"], reviews)
    hook = row["roi_hook"] or scoring.roi_hook(name, rating, reviews, bucket, row["niche_query"])
    scope_md = "\n".join(f"- {s}" for s in quote.scope)

    wa = (
        f"Hi {name} 👋 — I came across your {niche} in {area}. "
        f"Really impressive: {reviews or 'lots of'} reviews at {rating:.1f}★. "
        f"I noticed there's a gap on the website side, so I built a quick mock-up of how "
        f"a modern site for you could look — can I send it over? No obligation. {OPT_OUT_LINE}"
    )
    email = f"""Subject: A website mock-up for {name}

Hello,

I run a small web studio and I came across {name} while looking at top-rated
{niche} businesses in {area}. {hook}

Rather than pitch you a service, I've already built a mock-up of what a modern,
mobile-first site for {name} could look like — I'd love to send you the
screenshot and a fixed quote.

The {quote.name} package ({quote.price_low:,}–{quote.price_high:,} AED) would cover:
{scope_md}

If it's useful, a reply gets you the mock-up. If not, no worries at all.

Best regards,
[Your name] · [Phone] · [Website]

{OPT_OUT_LINE}"""
    no_site = bucket == "NO_SITE"
    walk_in = (
        f'"Hi — are you the owner or manager? I help {niche} businesses in {area} '
        f"with their websites. I noticed {name} has {reviews or 'a lot of'} "
        f"reviews at {rating:.1f}★ — genuinely one of the best-rated around — "
        f"but {'they have no website yet' if no_site else 'the website could be working a lot harder'}. "
        f'I actually mocked up a design for you. Have you got two minutes for me to show you on my phone?"'
    )
    return {"whatsapp": wa, "email": email, "walk_in": walk_in}


def build_markdown(row: Any) -> str:
    name = row["name"] or "This business"
    area = _area_label(row["area"])
    niche = _niche_label(row["niche_query"])
    bucket = row["bucket"] or "WEAK"
    score = row["opportunity_score"] or 0
    tier = row["tier"] or "C"
    reasons = _reasons(row)
    quote = scoring.build_quote(bucket, row["niche_query"], row["review_count"] or 0)
    site = row["website_uri"] or "_none_"
    hook = row["roi_hook"] or scoring.roi_hook(
        name, row["rating"] or 0, row["review_count"] or 0, bucket, row["niche_query"]
    )

    reasons_md = "\n".join(f"- {r}" for r in reasons) or "- (no signals recorded)"
    scope_md = "\n".join(f"- {s}" for s in quote.scope)
    parts = outreach_parts(row)
    wa, email, walk_in = parts["whatsapp"], parts["email"], parts["walk_in"]

    return f"""# Pitch Pack — {name}

> **Tier {tier}** · Opportunity score **{score}/100** · {BUCKET_LABEL.get(bucket, bucket)}

## 1. Contact
| | |
|---|---|
| **Business** | {name} |
| **Category** | {niche} |
| **Area** | {area} |
| **Address** | {row['address'] or '—'} |
| **Phone** | {row['phone_national'] or '—'}{(' · ' + row['phone_intl']) if row['phone_intl'] else ''} |
| **Current site** | {site} |
| **Google Maps** | {row['maps_uri'] or '—'} |
| **Rating** | {(row['rating'] or 0):.1f}★ over {row['review_count'] or 0} reviews |

## 2. Diagnosis
- **Bucket:** {BUCKET_LABEL.get(bucket, bucket)}
- **Opportunity score:** {score}/100
- **Why this is a lead:**
{reasons_md}

## 3. The hook
> {hook}

## 4. Quotation
**{quote.name}** — **{quote.price_low:,}–{quote.price_high:,} AED**
{scope_md}

_Optional care plan: {quote.care_low}–{quote.care_high} AED/mo (hosting, updates, backups, monthly report)._

## 5. Draft outreach
**WhatsApp (short)**
> {wa}

**Email (formal)**
```
{email}
```

**Walk-in script**
> {walk_in}

## 6. Mockup prompt
```
{mockup_prompt(row)}
```
"""


def write_pitch(row: Any, out_dir: str | None = None) -> str:
    out_dir = out_dir or config.PITCH_DIR
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, f"{row['place_id']}.md")
    with open(path, "w", encoding="utf-8") as f:
        f.write(build_markdown(row))
    return path


def run_pitch(tier: str | None = "A", on_progress=None) -> dict[str, Any]:
    db.init_db()
    written: list[str] = []
    with db.connect() as conn:
        rows = db.leads(conn, tier=tier)
        for i, row in enumerate(rows, 1):
            written.append(write_pitch(row))
            if on_progress:
                on_progress(i, len(rows), row)
    return {"written": len(written), "dir": config.PITCH_DIR}
