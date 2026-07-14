"""CSV export of ranked leads. Respect Places ToS caching/display limits
before redistributing this data anywhere."""

from __future__ import annotations

import csv
import os
from typing import Any

from . import config, db

COLUMNS = [
    "place_id", "name", "primary_type", "niche_query", "area", "address",
    "rating", "review_count", "phone_national", "phone_intl", "website_uri",
    "maps_uri", "bucket", "opportunity_score", "tier", "package", "price_low",
    "price_high", "roi_hook",
]


def run_export(tier: str | None = None, out: str | None = None) -> dict[str, Any]:
    out = out or os.path.join(config.OUTPUT_DIR, f"leads_{tier or 'all'}.csv")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with db.connect() as conn:
        rows = db.leads(conn, tier=tier)
    with open(out, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(COLUMNS)
        for r in rows:
            w.writerow([r[c] if c in r.keys() else "" for c in COLUMNS])
    return {"rows": len(rows), "out": out}
