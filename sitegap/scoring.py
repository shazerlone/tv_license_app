"""Scoring + quotation.

opportunity_score (0–100) = web_weakness (0–60) + business_quality (0–40)

Then map to a tier (A/B/C) and a quotation package, and mint a one-line ROI
hook written in the lead's own numbers.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

from . import config, db, site_audit
from .config import BOOKING_NICHES, HIGH_LTV_NICHES, PACKAGES

WEB_WEAKNESS_FIXED = {
    site_audit.NO_SITE: 60,
    site_audit.SOCIAL_ONLY: 55,
    site_audit.BROKEN: 55,
}


def web_weakness(bucket: str, weakness_score: int) -> int:
    if bucket in WEB_WEAKNESS_FIXED:
        return WEB_WEAKNESS_FIXED[bucket]
    if bucket == site_audit.STRONG:
        return min(weakness_score, 10)
    # WEAK: signal-weight sum, capped into the 20–50 band.
    return max(20, min(weakness_score, 50)) if weakness_score else 20


def business_quality(rating: float, reviews: int) -> int:
    rating = rating or 0.0
    reviews = reviews or 0
    # rating: 4.0 -> 10, 4.8+ -> 20 (linear)
    r = 10 + (min(rating, 4.8) - 4.0) / (4.8 - 4.0) * 10
    r = max(10.0, min(r, 20.0)) if rating >= 4.0 else max(0.0, rating / 4.0 * 10)
    # reviews: log-scaled 20 -> 5, 300+ -> 20
    if reviews <= 0:
        v = 0.0
    else:
        lo, hi = math.log(20), math.log(300)
        frac = (math.log(min(max(reviews, 1), 300)) - lo) / (hi - lo)
        v = 5 + max(0.0, min(frac, 1.0)) * 15
    return round(r + v)


def opportunity_score(bucket: str, weakness_score: int, rating: float, reviews: int) -> int:
    return int(web_weakness(bucket, weakness_score) + business_quality(rating, reviews))


def tier_for(score: int) -> str:
    if score >= config.TIER_A_MIN:
        return "A"
    if score >= config.TIER_B_MIN:
        return "B"
    return "C"


@dataclass
class Quote:
    package: str
    name: str
    price_low: int
    price_high: int
    scope: list[str]
    care_low: int
    care_high: int


def choose_package(bucket: str, niche: str, reviews: int) -> str:
    """Section 7 rules, evaluated most-specific first."""
    if bucket == site_audit.STRONG:
        return "care"

    reviews = reviews or 0
    # Premium: heavy social proof or a high-LTV niche.
    if reviews >= 200 or niche in HIGH_LTV_NICHES:
        return "premium"

    # Booking-driven niches — the form is the ROI story, so Growth minimum.
    if niche in BOOKING_NICHES:
        return "growth"

    if bucket in (site_audit.NO_SITE, site_audit.SOCIAL_ONLY):
        return "starter" if reviews < 60 else "growth"

    # BROKEN / WEAK sites default on review volume.
    return "growth" if reviews >= 60 else "starter"


def build_quote(bucket: str, niche: str, reviews: int) -> Quote:
    pkg = PACKAGES[choose_package(bucket, niche, reviews)]
    care = config.CARE_ADDON
    return Quote(
        package=pkg.key,
        name=pkg.name,
        price_low=pkg.price_low,
        price_high=pkg.price_high,
        scope=list(pkg.scope),
        care_low=care.price_low,
        care_high=care.price_high,
    )


def roi_hook(name: str, rating: float, reviews: int, bucket: str, niche: str) -> str:
    """One line, in their own numbers — the strongest asset vs the gap."""
    stars = f"{rating:.1f}★" if rating else "great reviews"
    rc = f"{reviews} reviews" if reviews else "a loyal customer base"
    if bucket == site_audit.NO_SITE:
        gap = "no website at all, so every one of those customers found you in spite of it"
    elif bucket == site_audit.SOCIAL_ONLY:
        gap = "only an Instagram page — no site a customer can book or trust from"
    elif bucket == site_audit.BROKEN:
        gap = "a website that's currently broken, quietly turning those customers away"
    elif bucket == site_audit.STRONG:
        gap = "a solid site already — worth keeping it fast, updated and backed up"
    else:
        gap = "a website that's costing you bookings on mobile"
    return f"You have {rc} at {stars} and {gap}."


def run_scoring(on_progress=None) -> dict[str, Any]:
    """Score every audited place. Idempotent — re-runs overwrite cleanly."""
    db.init_db()
    tiers: dict[str, int] = {}
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")
    with db.connect() as conn:
        rows = db.audited_places(conn)
        for i, row in enumerate(rows, 1):
            bucket = row["bucket"]
            score = opportunity_score(
                bucket, row["weakness_score"] or 0, row["rating"] or 0, row["review_count"] or 0
            )
            tier = tier_for(score)
            quote = build_quote(bucket, row["niche_query"], row["review_count"] or 0)
            hook = roi_hook(
                row["name"], row["rating"] or 0, row["review_count"] or 0, bucket, row["niche_query"]
            )
            db.upsert_score(
                conn,
                {
                    "place_id": row["place_id"],
                    "opportunity_score": score,
                    "tier": tier,
                    "package": quote.package,
                    "price_low": quote.price_low,
                    "price_high": quote.price_high,
                    "roi_hook": hook,
                    "scored_at": now,
                },
            )
            tiers[tier] = tiers.get(tier, 0) + 1
            conn.commit()
            if on_progress:
                on_progress(i, len(rows), row, score, tier)
    return {"scored": sum(tiers.values()), "tiers": tiers}
