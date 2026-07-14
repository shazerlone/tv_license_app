"""Seed the DB with realistic demo leads so the whole pipeline and the web
dashboard are usable without a Google API key or any spend.

`python -m sitegap.seed` populates places, audits and scores end-to-end.
The data is synthetic but shaped like real Places output.
"""

from __future__ import annotations

import random
from datetime import datetime, timezone

from . import db, scoring, site_audit
from .config import AREAS, NICHES

random.seed(42)

_PREFIX = {
    "accounting": ["Prime", "Gulf", "Meridian", "Falcon", "Emirates"],
    "real_estate": ["Skyline", "Oasis", "Pinnacle", "Harbour", "Crown"],
    "car_wash": ["Sparkle", "AutoShine", "Crystal", "Elite", "Prestige"],
    "dental": ["Bright Smile", "Pearl", "White", "Cedar", "Aster"],
    "salon": ["Glow", "Bloom", "Velvet", "Luxe", "Rose"],
    "gym": ["Iron", "Peak", "Forge", "Pulse", "Titan"],
    "laundry_pickup": ["Fresh", "Snap", "Crisp", "Swift", "Bubble"],
    "movers": ["Swift", "Cargo", "Reliable", "Pro", "Express"],
    "physio": ["Motion", "Revive", "Core", "Align", "Active"],
    "barber": ["Sharp", "Gents", "Classic", "The Cut", "Blade"],
}
_SUFFIX = {
    "accounting": "Accounting & Tax",
    "real_estate": "Real Estate",
    "car_wash": "Auto Care",
    "dental": "Dental Clinic",
    "salon": "Beauty Lounge",
    "gym": "Fitness Club",
    "laundry_pickup": "Laundry",
    "movers": "Movers",
    "physio": "Physiotherapy",
    "barber": "Barbershop",
}

# Distribution of web buckets we synthesise (weighted toward opportunities).
_BUCKET_WEIGHTS = [
    (site_audit.NO_SITE, 0.28),
    (site_audit.SOCIAL_ONLY, 0.18),
    (site_audit.BROKEN, 0.12),
    (site_audit.WEAK, 0.30),
    (site_audit.STRONG, 0.12),
]


def _pick_bucket() -> str:
    r = random.random()
    acc = 0.0
    for b, w in _BUCKET_WEIGHTS:
        acc += w
        if r <= acc:
            return b
    return site_audit.WEAK


def _fake_audit(place_id: str, bucket: str, year: int) -> site_audit.AuditResult:
    res = site_audit.AuditResult(place_id, bucket)
    if bucket == site_audit.NO_SITE:
        res.reasons = ["No website on the Google listing at all."]
    elif bucket == site_audit.SOCIAL_ONLY:
        res.reasons = ["Google listing points only at an Instagram / link-in-bio page."]
    elif bucket == site_audit.BROKEN:
        res.http_status = random.choice([404, 500, 503])
        res.reasons = [f"Site returns HTTP {res.http_status} — customers hit a dead page."]
    elif bucket == site_audit.STRONG:
        res.has_viewport, res.is_https, res.has_cta = 1, 1, 1
        res.ttfb_ms, res.platform, res.word_count = random.randint(200, 900), "WordPress", random.randint(800, 2000)
        res.reasons = ["Modern, mobile-friendly site with a clear conversion path — care-plan candidate."]
    else:  # WEAK
        score = 0
        reasons = []
        res.is_https = random.choice([0, 1])
        res.has_viewport = random.choice([0, 1])
        res.has_cta = random.choice([0, 1])
        res.platform = random.choice(["Wix", "GoDaddy", "WordPress", ""])
        res.word_count = random.randint(150, 700)
        res.ttfb_ms = random.randint(1500, 4200)
        res.footer_year = random.choice([year - 3, year - 4, None])
        if not res.has_viewport:
            score += 20
            reasons.append("No mobile viewport tag — the site is not responsive on phones.")
        if not res.is_https:
            score += 20
            reasons.append("Served over plain HTTP — browsers flag it 'Not secure'.")
        if res.ttfb_ms > 2500:
            score += 10
            reasons.append(f"Slow to load ({res.ttfb_ms} ms).")
        if res.footer_year:
            score += 10
            reasons.append(f"Footer copyright still says {res.footer_year}.")
        if not res.has_cta:
            score += 20
            reasons.append("No click-to-call, WhatsApp or form — no way to convert a visitor.")
        if res.platform in ("Wix", "GoDaddy"):
            score += 5
            reasons.append(f"Built on a {res.platform} default template.")
        if res.word_count < 500:
            score += 10
            reasons.append(f"Thin content ({res.word_count} words).")
        res.weakness_score = min(score, 50)
        res.reasons = reasons or ["Underperforming site with several weak signals."]
    return res


def seed(n_per_area: int = 6) -> dict:
    db.init_db()
    year = datetime.now(timezone.utc).year
    niches = list(_PREFIX.keys())
    made = 0
    with db.connect() as conn:
        for area_key, area in AREAS.items():
            for _ in range(n_per_area):
                niche = random.choice(niches)
                pre = random.choice(_PREFIX[niche])
                name = f"{pre} {_SUFFIX[niche]}"
                pid = f"seed_{area_key}_{made}"
                rating = round(random.uniform(4.0, 4.9), 1)
                reviews = random.choice([22, 34, 48, 61, 88, 120, 143, 210, 305, 412])
                bucket = _pick_bucket()
                website = ""
                if bucket == site_audit.SOCIAL_ONLY:
                    website = f"https://instagram.com/{pre.lower().replace(' ', '')}"
                elif bucket in (site_audit.WEAK, site_audit.BROKEN, site_audit.STRONG):
                    website = f"https://{pre.lower().replace(' ', '')}-{niche}.example.com"
                db.upsert_place(
                    conn,
                    {
                        "place_id": pid,
                        "name": name,
                        "primary_type": _SUFFIX[niche],
                        "niche_query": niche,
                        "area": area_key,
                        "address": f"{random.randint(1,120)} {area.label}, {area.region_code}",
                        "lat": area.lat + random.uniform(-0.01, 0.01),
                        "lng": area.lng + random.uniform(-0.01, 0.01),
                        "rating": rating,
                        "review_count": reviews,
                        "phone_national": f"0{random.randint(50,59)} {random.randint(100,999)} {random.randint(1000,9999)}",
                        "phone_intl": f"+971 {random.randint(50,59)} {random.randint(100,999)} {random.randint(1000,9999)}",
                        "website_uri": website,
                        "maps_uri": f"https://maps.google.com/?cid={made}",
                        "business_status": "OPERATIONAL",
                    },
                )
                audit = _fake_audit(pid, bucket, year)
                db.upsert_audit(conn, audit.as_row())
                made += 1
        conn.commit()
    scoring.run_scoring()
    with db.connect() as conn:
        stats = db.funnel_stats(conn)
    return {"seeded": made, **stats}


if __name__ == "__main__":
    result = seed()
    print(f"Seeded {result['seeded']} leads.")
    print(f"  Qualified: {result['qualified']} | Audited: {result['audited']} | Scored: {result['scored']}")
    print(f"  Buckets: {result['buckets']}")
    print(f"  Tiers:   {result['tiers']}")
