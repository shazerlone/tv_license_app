"""SQLite storage. Every stage is idempotent and resumable — a crash at grid
cell 300 must not cost cells 1–299, so writes are upserts keyed on place_id.
"""

from __future__ import annotations

import json
import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone
from typing import Any, Iterator

from . import config

SCHEMA = """
CREATE TABLE IF NOT EXISTS places (
    place_id       TEXT PRIMARY KEY,
    name           TEXT,
    primary_type   TEXT,
    niche_query    TEXT,
    area           TEXT,
    address        TEXT,
    lat            REAL,
    lng            REAL,
    rating         REAL,
    review_count   INTEGER,
    phone_national TEXT,
    phone_intl     TEXT,
    website_uri    TEXT,
    maps_uri       TEXT,
    business_status TEXT,
    first_seen     TEXT,
    last_seen      TEXT
);

CREATE TABLE IF NOT EXISTS audits (
    place_id       TEXT PRIMARY KEY REFERENCES places(place_id),
    bucket         TEXT,
    http_status    INTEGER,
    has_viewport   INTEGER,
    is_https       INTEGER,
    ttfb_ms        INTEGER,
    page_bytes     INTEGER,
    has_cta        INTEGER,
    footer_year    INTEGER,
    platform       TEXT,
    word_count     INTEGER,
    weakness_score INTEGER,
    reasons_json   TEXT,
    audited_at     TEXT
);

CREATE TABLE IF NOT EXISTS scores (
    place_id          TEXT PRIMARY KEY REFERENCES places(place_id),
    opportunity_score INTEGER,
    tier              TEXT,
    package           TEXT,
    price_low         INTEGER,
    price_high        INTEGER,
    roi_hook          TEXT,
    scored_at         TEXT
);

CREATE TABLE IF NOT EXISTS api_cache (
    cache_key     TEXT PRIMARY KEY,
    response_json TEXT,
    fetched_at    TEXT
);

CREATE INDEX IF NOT EXISTS idx_places_niche ON places(niche_query);
CREATE INDEX IF NOT EXISTS idx_places_area ON places(area);
CREATE INDEX IF NOT EXISTS idx_scores_tier ON scores(tier);
"""


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


@contextmanager
def connect(path: str | None = None) -> Iterator[sqlite3.Connection]:
    conn = sqlite3.connect(path or config.DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def init_db(path: str | None = None) -> None:
    with connect(path) as conn:
        conn.executescript(SCHEMA)


# --------------------------------------------------------------------------- #
# places
# --------------------------------------------------------------------------- #
def upsert_place(conn: sqlite3.Connection, p: dict[str, Any]) -> None:
    """Insert or refresh a place. Preserves first_seen, bumps last_seen."""
    now = _now()
    conn.execute(
        """
        INSERT INTO places (place_id, name, primary_type, niche_query, area,
            address, lat, lng, rating, review_count, phone_national, phone_intl,
            website_uri, maps_uri, business_status, first_seen, last_seen)
        VALUES (:place_id, :name, :primary_type, :niche_query, :area, :address,
            :lat, :lng, :rating, :review_count, :phone_national, :phone_intl,
            :website_uri, :maps_uri, :business_status, :now, :now)
        ON CONFLICT(place_id) DO UPDATE SET
            name=excluded.name,
            rating=excluded.rating,
            review_count=excluded.review_count,
            website_uri=excluded.website_uri,
            phone_national=excluded.phone_national,
            phone_intl=excluded.phone_intl,
            business_status=excluded.business_status,
            last_seen=excluded.last_seen
        """,
        {**p, "now": now},
    )


def get_place(conn: sqlite3.Connection, place_id: str) -> sqlite3.Row | None:
    return conn.execute(
        "SELECT * FROM places WHERE place_id = ?", (place_id,)
    ).fetchone()


def qualified_places(conn: sqlite3.Connection) -> list[sqlite3.Row]:
    """Places that pass the qualification filter (section 4)."""
    return conn.execute(
        """
        SELECT * FROM places
        WHERE business_status = 'OPERATIONAL'
          AND rating >= ?
          AND review_count >= ?
          AND (phone_national IS NOT NULL AND phone_national != '')
        ORDER BY review_count DESC
        """,
        (config.MIN_RATING, config.MIN_REVIEWS),
    ).fetchall()


def places_needing_audit(conn: sqlite3.Connection, limit: int | None = None) -> list[sqlite3.Row]:
    rows = conn.execute(
        """
        SELECT p.* FROM places p
        LEFT JOIN audits a ON a.place_id = p.place_id
        WHERE a.place_id IS NULL
          AND p.business_status = 'OPERATIONAL'
          AND p.rating >= ? AND p.review_count >= ?
          AND (p.phone_national IS NOT NULL AND p.phone_national != '')
        ORDER BY p.review_count DESC
        """,
        (config.MIN_RATING, config.MIN_REVIEWS),
    ).fetchall()
    return rows[:limit] if limit else rows


# --------------------------------------------------------------------------- #
# audits
# --------------------------------------------------------------------------- #
def upsert_audit(conn: sqlite3.Connection, a: dict[str, Any]) -> None:
    conn.execute(
        """
        INSERT INTO audits (place_id, bucket, http_status, has_viewport,
            is_https, ttfb_ms, page_bytes, has_cta, footer_year, platform,
            word_count, weakness_score, reasons_json, audited_at)
        VALUES (:place_id, :bucket, :http_status, :has_viewport, :is_https,
            :ttfb_ms, :page_bytes, :has_cta, :footer_year, :platform,
            :word_count, :weakness_score, :reasons_json, :audited_at)
        ON CONFLICT(place_id) DO UPDATE SET
            bucket=excluded.bucket, http_status=excluded.http_status,
            has_viewport=excluded.has_viewport, is_https=excluded.is_https,
            ttfb_ms=excluded.ttfb_ms, page_bytes=excluded.page_bytes,
            has_cta=excluded.has_cta, footer_year=excluded.footer_year,
            platform=excluded.platform, word_count=excluded.word_count,
            weakness_score=excluded.weakness_score,
            reasons_json=excluded.reasons_json, audited_at=excluded.audited_at
        """,
        a,
    )


def get_audit(conn: sqlite3.Connection, place_id: str) -> sqlite3.Row | None:
    return conn.execute(
        "SELECT * FROM audits WHERE place_id = ?", (place_id,)
    ).fetchone()


def audited_places(conn: sqlite3.Connection) -> list[sqlite3.Row]:
    return conn.execute(
        """
        SELECT p.*, a.bucket, a.weakness_score, a.reasons_json
        FROM places p JOIN audits a ON a.place_id = p.place_id
        """
    ).fetchall()


# --------------------------------------------------------------------------- #
# scores
# --------------------------------------------------------------------------- #
def upsert_score(conn: sqlite3.Connection, s: dict[str, Any]) -> None:
    conn.execute(
        """
        INSERT INTO scores (place_id, opportunity_score, tier, package,
            price_low, price_high, roi_hook, scored_at)
        VALUES (:place_id, :opportunity_score, :tier, :package, :price_low,
            :price_high, :roi_hook, :scored_at)
        ON CONFLICT(place_id) DO UPDATE SET
            opportunity_score=excluded.opportunity_score, tier=excluded.tier,
            package=excluded.package, price_low=excluded.price_low,
            price_high=excluded.price_high, roi_hook=excluded.roi_hook,
            scored_at=excluded.scored_at
        """,
        s,
    )


def leads(
    conn: sqlite3.Connection,
    tier: str | None = None,
    niche: str | None = None,
    area: str | None = None,
    bucket: str | None = None,
) -> list[sqlite3.Row]:
    """Full joined lead rows, optionally filtered. Ranked by opportunity."""
    q = """
        SELECT p.*, a.bucket, a.weakness_score, a.reasons_json, a.platform,
               a.http_status, a.has_cta, a.has_viewport, a.is_https,
               s.opportunity_score, s.tier, s.package, s.price_low,
               s.price_high, s.roi_hook
        FROM places p
        JOIN audits a ON a.place_id = p.place_id
        JOIN scores s ON s.place_id = p.place_id
        WHERE 1=1
    """
    args: list[Any] = []
    if tier:
        q += " AND s.tier = ?"
        args.append(tier.upper())
    if niche:
        q += " AND p.niche_query = ?"
        args.append(niche)
    if area:
        q += " AND p.area = ?"
        args.append(area)
    if bucket:
        q += " AND a.bucket = ?"
        args.append(bucket)
    q += " ORDER BY s.opportunity_score DESC, p.review_count DESC"
    return conn.execute(q, args).fetchall()


def full_lead(conn: sqlite3.Connection, place_id: str) -> sqlite3.Row | None:
    return conn.execute(
        """
        SELECT p.*, a.bucket, a.weakness_score, a.reasons_json, a.platform,
               a.http_status, a.has_cta, a.has_viewport, a.is_https,
               a.footer_year, a.ttfb_ms, a.page_bytes, a.word_count,
               s.opportunity_score, s.tier, s.package, s.price_low,
               s.price_high, s.roi_hook
        FROM places p
        LEFT JOIN audits a ON a.place_id = p.place_id
        LEFT JOIN scores s ON s.place_id = p.place_id
        WHERE p.place_id = ?
        """,
        (place_id,),
    ).fetchone()


# --------------------------------------------------------------------------- #
# api_cache — never pay Google twice
# --------------------------------------------------------------------------- #
def cache_get(conn: sqlite3.Connection, key: str) -> dict[str, Any] | None:
    row = conn.execute(
        "SELECT response_json FROM api_cache WHERE cache_key = ?", (key,)
    ).fetchone()
    return json.loads(row["response_json"]) if row else None


def cache_put(conn: sqlite3.Connection, key: str, payload: dict[str, Any]) -> None:
    conn.execute(
        """
        INSERT INTO api_cache (cache_key, response_json, fetched_at)
        VALUES (?, ?, ?)
        ON CONFLICT(cache_key) DO UPDATE SET
            response_json=excluded.response_json, fetched_at=excluded.fetched_at
        """,
        (key, json.dumps(payload), _now()),
    )


# --------------------------------------------------------------------------- #
# aggregate stats for the dashboard funnel
# --------------------------------------------------------------------------- #
def funnel_stats(conn: sqlite3.Connection) -> dict[str, Any]:
    def scalar(sql: str, args: tuple = ()) -> int:
        return conn.execute(sql, args).fetchone()[0]

    buckets = {
        row["bucket"]: row["n"]
        for row in conn.execute(
            "SELECT bucket, COUNT(*) n FROM audits GROUP BY bucket"
        ).fetchall()
    }
    tiers = {
        row["tier"]: row["n"]
        for row in conn.execute(
            "SELECT tier, COUNT(*) n FROM scores GROUP BY tier"
        ).fetchall()
    }
    return {
        "total": scalar("SELECT COUNT(*) FROM places"),
        "qualified": len(qualified_places(conn)),
        "audited": scalar("SELECT COUNT(*) FROM audits"),
        "scored": scalar("SELECT COUNT(*) FROM scores"),
        "buckets": buckets,
        "tiers": tiers,
        "cache_entries": scalar("SELECT COUNT(*) FROM api_cache"),
    }
