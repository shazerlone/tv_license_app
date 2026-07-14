"""Google Places API (New) v1 client — Text Search.

This is not scraping. The API returns `websiteUri` directly, and that single
field is the whole product: it tells us who has no site, a social-only
presence, or a real domain to audit.

Every response is cached in `api_cache` keyed on the query cell, so re-running
a grid never pays Google twice.
"""

from __future__ import annotations

import hashlib
import json
import sqlite3
from dataclasses import dataclass
from typing import Any, Iterable

import httpx

from . import config, db
from .config import AREAS, NICHES


@dataclass
class GridCell:
    niche: str
    area: str

    @property
    def query(self) -> str:
        return f"{NICHES[self.niche]} in {AREAS[self.area].label}"


def build_grid(niches: Iterable[str], areas: Iterable[str]) -> list[GridCell]:
    """niche × area. Coverage comes from the grid, not one big query."""
    return [GridCell(n, a) for a in areas for n in niches]


def _cache_key(cell: GridCell, page: int) -> str:
    raw = f"{cell.niche}|{cell.area}|{page}|{config.PLACES_FIELD_MASK}"
    return hashlib.sha256(raw.encode()).hexdigest()[:24]


def _request_body(cell: GridCell, page_token: str | None) -> dict[str, Any]:
    area = AREAS[cell.area]
    body: dict[str, Any] = {
        "textQuery": cell.query,
        "pageSize": config.PAGE_SIZE,
        "regionCode": area.region_code,
        "locationBias": {
            "circle": {
                "center": {"latitude": area.lat, "longitude": area.lng},
                "radius": float(area.radius_m),
            }
        },
    }
    if page_token:
        body["pageToken"] = page_token
    return body


def _normalise(place: dict[str, Any], cell: GridCell) -> dict[str, Any]:
    loc = place.get("location", {})
    return {
        "place_id": place.get("id"),
        "name": (place.get("displayName") or {}).get("text", ""),
        "primary_type": place.get("primaryTypeDisplayName", {}).get("text", "")
        if isinstance(place.get("primaryTypeDisplayName"), dict)
        else place.get("primaryTypeDisplayName", ""),
        "niche_query": cell.niche,
        "area": cell.area,
        "address": place.get("formattedAddress", ""),
        "lat": loc.get("latitude"),
        "lng": loc.get("longitude"),
        "rating": place.get("rating"),
        "review_count": place.get("userRatingCount", 0),
        "phone_national": place.get("nationalPhoneNumber", ""),
        "phone_intl": place.get("internationalPhoneNumber", ""),
        "website_uri": place.get("websiteUri", ""),
        "maps_uri": place.get("googleMapsUri", ""),
        "business_status": place.get("businessStatus", ""),
    }


class PlacesClient:
    def __init__(self, api_key: str | None = None):
        self.api_key = api_key or config.PLACES_API_KEY
        self._client = httpx.Client(timeout=20.0)

    def close(self) -> None:
        self._client.close()

    def __enter__(self) -> "PlacesClient":
        return self

    def __exit__(self, *_exc: object) -> None:
        self.close()

    def _fetch_page(
        self, conn: sqlite3.Connection, cell: GridCell, page: int, token: str | None
    ) -> dict[str, Any]:
        key = _cache_key(cell, page)
        cached = db.cache_get(conn, key)
        if cached is not None:
            cached["_cached"] = True
            return cached

        if not self.api_key:
            raise RuntimeError(
                "GOOGLE_PLACES_API_KEY is not set. Export a key, or seed the DB "
                "with demo data via `python -m sitegap.seed`."
            )

        resp = self._client.post(
            config.PLACES_SEARCH_URL,
            headers={
                "Content-Type": "application/json",
                "X-Goog-Api-Key": self.api_key,
                "X-Goog-FieldMask": config.PLACES_FIELD_MASK,
            },
            content=json.dumps(_request_body(cell, token)),
        )
        resp.raise_for_status()
        payload = resp.json()
        db.cache_put(conn, key, payload)
        payload["_cached"] = False
        return payload

    def search_cell(
        self, conn: sqlite3.Connection, cell: GridCell
    ) -> tuple[list[dict[str, Any]], int]:
        """Return (normalised places, live_requests_made) for one grid cell."""
        results: list[dict[str, Any]] = []
        token: str | None = None
        live = 0
        for page in range(config.MAX_PAGES_PER_QUERY):
            payload = self._fetch_page(conn, cell, page, token)
            if not payload.get("_cached", False):
                live += 1
            for place in payload.get("places", []):
                if place.get("id"):
                    results.append(_normalise(place, cell))
            token = payload.get("nextPageToken")
            if not token:
                break
        return results, live


def estimate_spend(n_cells: int) -> float:
    """Worst-case USD estimate: every cell fans out to MAX_PAGES_PER_QUERY."""
    return n_cells * config.MAX_PAGES_PER_QUERY * config.COST_PER_QUERY_USD


def run_search(
    niches: list[str],
    areas: list[str],
    max_queries: int | None = None,
    on_progress=None,
) -> dict[str, Any]:
    """Execute the grid. Idempotent: cached cells cost nothing and stored
    places upsert, so a re-run resumes rather than duplicates."""
    db.init_db()
    grid = build_grid(niches, areas)
    if max_queries is not None:
        grid = grid[:max_queries]

    live_requests = 0
    new_places = 0
    with db.connect() as conn, PlacesClient() as client:
        for i, cell in enumerate(grid, 1):
            places, live = client.search_cell(conn, cell)
            live_requests += live
            for p in places:
                before = db.get_place(conn, p["place_id"])
                db.upsert_place(conn, p)
                if before is None:
                    new_places += 1
            conn.commit()
            if on_progress:
                on_progress(i, len(grid), cell, len(places))

    return {
        "cells": len(grid),
        "live_requests": live_requests,
        "new_places": new_places,
        "estimated_spend_usd": round(live_requests * config.COST_PER_QUERY_USD, 2),
    }
