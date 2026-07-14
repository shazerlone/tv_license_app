"""Website audit — the actual IP.

Classify each lead's web presence into a bucket and, for live sites, score
weakness by summing signal weights. The heuristics here are where the whole
product succeeds or fails, so thresholds are named constants you can tune.
"""

from __future__ import annotations

import re
import ssl
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any
from urllib.parse import urlparse

import httpx
from bs4 import BeautifulSoup

# --------------------------------------------------------------------------- #
# Buckets
# --------------------------------------------------------------------------- #
NO_SITE = "NO_SITE"
SOCIAL_ONLY = "SOCIAL_ONLY"
BROKEN = "BROKEN"
WEAK = "WEAK"
STRONG = "STRONG"

SOCIAL_HOSTS = (
    "instagram.com",
    "facebook.com",
    "fb.com",
    "fb.me",
    "tiktok.com",
    "linktr.ee",
    "wa.me",
    "api.whatsapp.com",
    "linkedin.com",
    "t.me",
    "youtube.com",
    "twitter.com",
    "x.com",
)

# Signal weights (section 5). Heavy = 20, Medium = 10, Light = 5.
WEIGHTS = {
    "not_responsive": 20,  # no <meta name="viewport">
    "no_https": 20,  # http only / TLS error
    "slow": 10,  # TTFB > 2.5s or page > 3 MB
    "stale": 10,  # footer copyright 2+ yrs old
    "no_cta": 20,  # no tel:/wa.me/mailto:/form
    "builder_default": 5,  # Wix/GoDaddy/Weebly markers
    "thin": 10,  # < 3 internal links or < 500 words
}
WEAK_SCORE_CAP = 50

# Thresholds
TTFB_SLOW_MS = 2500
PAGE_BYTES_MAX = 3 * 1024 * 1024
STALE_YEARS = 2
MIN_WORDS = 500
MIN_INTERNAL_LINKS = 3
REQUEST_TIMEOUT = 10.0

BUILDER_MARKERS = {
    "Wix": ("wix.com", "_wixCssImports", "wix-warmup-data"),
    "GoDaddy": ("godaddy", "websitebuilder", "img.wsimg.com"),
    "Weebly": ("weebly.com", "weeblycloud"),
    "Squarespace": ("squarespace.com", "static1.squarespace"),
    "WordPress": ("wp-content", "wp-includes"),
}

PARKED_MARKERS = (
    "domain for sale",
    "this domain is parked",
    "buy this domain",
    "godaddy.com/domainsearch",
    "sedoparking",
    "hugedomains",
)


@dataclass
class AuditResult:
    place_id: str
    bucket: str
    http_status: int | None = None
    has_viewport: int | None = None
    is_https: int | None = None
    ttfb_ms: int | None = None
    page_bytes: int | None = None
    has_cta: int | None = None
    footer_year: int | None = None
    platform: str = ""
    word_count: int | None = None
    weakness_score: int = 0
    reasons: list[str] = field(default_factory=list)

    def as_row(self) -> dict[str, Any]:
        import json

        return {
            "place_id": self.place_id,
            "bucket": self.bucket,
            "http_status": self.http_status,
            "has_viewport": self.has_viewport,
            "is_https": self.is_https,
            "ttfb_ms": self.ttfb_ms,
            "page_bytes": self.page_bytes,
            "has_cta": self.has_cta,
            "footer_year": self.footer_year,
            "platform": self.platform,
            "word_count": self.word_count,
            "weakness_score": self.weakness_score,
            "reasons_json": json.dumps(self.reasons),
            "audited_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        }


def classify_url(url: str) -> str | None:
    """Pre-fetch bucketing from the URL alone. None == needs a live fetch."""
    if not url or not url.strip():
        return NO_SITE
    host = (urlparse(url).hostname or "").lower().lstrip("www.")
    if any(host == h or host.endswith("." + h) or h in host for h in SOCIAL_HOSTS):
        return SOCIAL_ONLY
    return None


def _detect_platform(html: str, headers: dict[str, str]) -> str:
    hay = html.lower()
    for name, markers in BUILDER_MARKERS.items():
        if any(m.lower() in hay for m in markers):
            return name
    gen = headers.get("x-powered-by", "") + headers.get("server", "")
    return gen.strip()


def _footer_year(html: str) -> int | None:
    years = [int(y) for y in re.findall(r"(?:©|&copy;|copyright)[^\d]{0,20}(20\d{2})", html, re.I)]
    years += [int(y) for y in re.findall(r"(20\d{2})\s*(?:©|&copy;)", html)]
    return max(years) if years else None


def _has_cta(html: str, soup: BeautifulSoup) -> bool:
    if soup.find("form"):
        return True
    for a in soup.find_all("a", href=True):
        href = a["href"].lower()
        if href.startswith(("tel:", "mailto:")) or "wa.me" in href or "api.whatsapp" in href:
            return True
    return False


def _word_count(soup: BeautifulSoup) -> int:
    for tag in soup(["script", "style", "noscript"]):
        tag.decompose()
    return len(re.findall(r"\w+", soup.get_text(" ", strip=True)))


def _internal_links(soup: BeautifulSoup, host: str) -> int:
    n = 0
    for a in soup.find_all("a", href=True):
        href = a["href"].strip()
        if href.startswith("/") or host in href:
            if not href.startswith(("tel:", "mailto:", "#", "javascript:")):
                n += 1
    return n


def audit_url(place_id: str, url: str, now_year: int | None = None) -> AuditResult:
    """Fetch and grade a single site. Never raises — failures become BROKEN."""
    now_year = now_year or datetime.now(timezone.utc).year

    pre = classify_url(url)
    if pre == NO_SITE:
        return AuditResult(place_id, NO_SITE, reasons=["No website on the Google listing at all."])
    if pre == SOCIAL_ONLY:
        return AuditResult(
            place_id,
            SOCIAL_ONLY,
            reasons=["Google listing points only at a social / link-in-bio page — they already know they need a site."],
        )

    result = AuditResult(place_id, WEAK)
    parsed = urlparse(url if "://" in url else "http://" + url)
    host = (parsed.hostname or "").lower()

    try:
        start = time.perf_counter()
        with httpx.Client(
            follow_redirects=True, timeout=REQUEST_TIMEOUT, verify=True,
            headers={"User-Agent": "Mozilla/5.0 (SitegapAudit/1.0)"},
        ) as client:
            resp = client.get(url if "://" in url else "https://" + host + parsed.path)
        ttfb_ms = int((time.perf_counter() - start) * 1000)
        result.ttfb_ms = ttfb_ms
        result.http_status = resp.status_code
        result.is_https = 1 if str(resp.url).startswith("https://") else 0

        if resp.status_code >= 400:
            result.bucket = BROKEN
            result.reasons = [f"Site returns HTTP {resp.status_code} — customers hit a dead page."]
            return result

        html = resp.text
        result.page_bytes = len(resp.content)
        if any(m in html.lower() for m in PARKED_MARKERS):
            result.bucket = BROKEN
            result.reasons = ["Domain is parked / for sale — there is no real website behind it."]
            return result

        soup = BeautifulSoup(html, "html.parser")
        result.platform = _detect_platform(html, dict(resp.headers))
        result.has_viewport = 1 if soup.find("meta", attrs={"name": "viewport"}) else 0
        result.has_cta = 1 if _has_cta(html, soup) else 0
        result.word_count = _word_count(soup)
        result.footer_year = _footer_year(html)
        internal = _internal_links(soup, host)

        reasons: list[str] = []
        score = 0
        if not result.has_viewport:
            score += WEIGHTS["not_responsive"]
            reasons.append("No mobile viewport tag — the site is not responsive on phones.")
        if not result.is_https:
            score += WEIGHTS["no_https"]
            reasons.append("Served over plain HTTP — browsers flag it 'Not secure'.")
        if ttfb_ms > TTFB_SLOW_MS or (result.page_bytes or 0) > PAGE_BYTES_MAX:
            score += WEIGHTS["slow"]
            reasons.append(f"Slow to load ({ttfb_ms} ms, {round((result.page_bytes or 0)/1e6,1)} MB).")
        if result.footer_year and (now_year - result.footer_year) >= STALE_YEARS:
            score += WEIGHTS["stale"]
            reasons.append(f"Footer copyright still says {result.footer_year} — the site looks abandoned.")
        if not result.has_cta:
            score += WEIGHTS["no_cta"]
            reasons.append("No click-to-call, WhatsApp, email or enquiry form — no way to convert a visitor.")
        if result.platform in ("Wix", "GoDaddy", "Weebly"):
            score += WEIGHTS["builder_default"]
            reasons.append(f"Built on a {result.platform} default template.")
        if internal < MIN_INTERNAL_LINKS or (result.word_count or 0) < MIN_WORDS:
            score += WEIGHTS["thin"]
            reasons.append(f"Thin content ({result.word_count} words, {internal} internal links).")

        result.weakness_score = min(score, WEAK_SCORE_CAP)
        if score == 0:
            result.bucket = STRONG
            result.reasons = ["Modern, mobile-friendly site with a clear conversion path — care-plan candidate."]
        else:
            result.bucket = WEAK
            result.reasons = reasons
        return result

    except (httpx.TimeoutException, httpx.ConnectError, httpx.ReadError, ssl.SSLError) as exc:
        result.bucket = BROKEN
        kind = "TLS/certificate error" if isinstance(exc, ssl.SSLError) else "connection failed / timed out"
        result.reasons = [f"Site unreachable — {kind}. They may not even know it's down."]
        result.is_https = 0 if isinstance(exc, ssl.SSLError) else result.is_https
        return result
    except Exception as exc:  # noqa: BLE001 — audit must never crash the run
        result.bucket = BROKEN
        result.reasons = [f"Audit failed: {type(exc).__name__}."]
        return result


def run_audit(limit: int | None = None, on_progress=None) -> dict[str, Any]:
    """Audit qualified, not-yet-audited places. Idempotent and resumable."""
    from . import db

    db.init_db()
    counts: dict[str, int] = {}
    with db.connect() as conn:
        todo = db.places_needing_audit(conn, limit)
        for i, place in enumerate(todo, 1):
            res = audit_url(place["place_id"], place["website_uri"] or "")
            db.upsert_audit(conn, res.as_row())
            counts[res.bucket] = counts.get(res.bucket, 0) + 1
            conn.commit()
            if on_progress:
                on_progress(i, len(todo), place, res)
    return {"audited": sum(counts.values()), "buckets": counts}
