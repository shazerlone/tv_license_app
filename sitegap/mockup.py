"""Mockup stage — the differentiator.

Don't pitch a service; send a screenshot of the site you already built for
them. This module produces a fully pre-filled generation prompt (their real
name, services, area, review count) and, if Playwright is available, can
render a placeholder HTML mock to a PNG. Run on Tier A only — it costs time.
"""

from __future__ import annotations

import os
from typing import Any

from . import config
from .config import AREAS, NICHES


def _label(mapping: dict, key: str, fallback: str = "") -> str:
    val = mapping.get(key, fallback)
    return val if isinstance(val, str) else fallback


def mockup_prompt(row: Any) -> str:
    name = row["name"] or "the business"
    niche = NICHES.get(row["niche_query"], row["niche_query"] or "local business").split(" in ")[0]
    area = AREAS[row["area"]].label if row["area"] in AREAS else (row["area"] or "").replace("_", " ").title()
    reviews = row["review_count"] or 0
    rating = row["rating"] or 0
    phone = row["phone_national"] or ""

    return (
        f"Design a modern, mobile-first homepage for \"{name}\", a {niche} in {area}. "
        f"Hero section with a bold headline, a real photo of the service, and two clear "
        f"call-to-action buttons: 'Book Now' and 'WhatsApp Us' ({phone}). "
        f"Show a trust strip: '{rating:.1f}★ from {reviews}+ happy customers'. "
        f"Include sections for Services, Why Choose Us, a gallery, an online booking / "
        f"enquiry form, an embedded Google map for {area}, and a footer with phone, "
        f"WhatsApp and opening hours. Clean typography, generous white space, a colour "
        f"palette that fits a premium {niche}. The design should make it obvious a "
        f"customer can book in under 30 seconds."
    )


def render_mock_html(row: Any) -> str:
    """A self-contained placeholder homepage, ready to screenshot."""
    name = row["name"] or "Your Business"
    niche = NICHES.get(row["niche_query"], row["niche_query"] or "").split(" in ")[0].title()
    area = AREAS[row["area"]].label if row["area"] in AREAS else (row["area"] or "").title()
    reviews = row["review_count"] or 0
    rating = row["rating"] or 0
    phone = row["phone_national"] or "+971 00 000 0000"
    return f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{name} — {niche} in {area}</title>
<style>
:root{{--ink:#0f172a;--brand:#1d4ed8;--accent:#f97316;--paper:#f8fafc}}
*{{box-sizing:border-box;margin:0;font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif}}
body{{color:var(--ink);background:var(--paper)}}
.wrap{{max-width:1080px;margin:0 auto;padding:0 24px}}
header{{display:flex;justify-content:space-between;align-items:center;padding:18px 0}}
.logo{{font-weight:800;font-size:20px;color:var(--brand)}}
.btn{{background:var(--brand);color:#fff;padding:12px 20px;border-radius:10px;font-weight:700;text-decoration:none;display:inline-block}}
.btn.wa{{background:#25d366}}
.hero{{background:linear-gradient(135deg,#1e3a8a,#1d4ed8);color:#fff;padding:72px 0}}
.hero h1{{font-size:44px;line-height:1.1;max-width:640px}}
.hero p{{margin:18px 0 28px;font-size:18px;opacity:.9;max-width:560px}}
.cta{{display:flex;gap:14px;flex-wrap:wrap}}
.trust{{background:#fff;padding:16px 0;border-bottom:1px solid #e2e8f0}}
.trust b{{color:var(--accent)}}
.grid{{display:grid;grid-template-columns:repeat(3,1fr);gap:20px;padding:56px 0}}
.card{{background:#fff;border:1px solid #e2e8f0;border-radius:14px;padding:24px}}
.card h3{{margin-bottom:8px}}
footer{{background:var(--ink);color:#cbd5e1;padding:32px 0;margin-top:24px}}
@media(max-width:720px){{.grid{{grid-template-columns:1fr}}.hero h1{{font-size:32px}}}}
</style></head><body>
<div class="wrap"><header>
  <div class="logo">{name}</div>
  <a class="btn" href="tel:{phone}">Call {phone}</a>
</header></div>
<section class="hero"><div class="wrap">
  <h1>{niche or 'Trusted service'} in {area}, done right.</h1>
  <p>The best-rated {niche.lower() or 'local business'} in {area} — now bookable online in 30 seconds.</p>
  <div class="cta"><a class="btn" href="#book">Book Now</a>
  <a class="btn wa" href="https://wa.me/">WhatsApp Us</a></div>
</div></section>
<div class="trust"><div class="wrap">⭐ <b>{rating:.1f}★</b> from <b>{reviews}+</b> happy customers in {area}</div></div>
<div class="wrap"><div class="grid">
  <div class="card"><h3>Our Services</h3><p>Everything {name} is known for, laid out clearly with prices.</p></div>
  <div class="card"><h3>Why Choose Us</h3><p>{reviews}+ reviews at {rating:.1f}★. Trusted across {area}.</p></div>
  <div class="card" id="book"><h3>Book Online</h3><p>Pick a time and we'll confirm on WhatsApp instantly.</p></div>
</div></div>
<footer><div class="wrap">{name} · {area} · <a style="color:#93c5fd" href="tel:{phone}">{phone}</a> · Open 7 days
<br><small>Mock-up prepared by Sitegap — not affiliated with {name}.</small></div></footer>
</body></html>"""


def write_mock_html(row: Any, out_dir: str | None = None) -> str:
    out_dir = out_dir or config.MOCKUP_DIR
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, f"{row['place_id']}.html")
    with open(path, "w", encoding="utf-8") as f:
        f.write(render_mock_html(row))
    return path


def screenshot(row: Any, out_dir: str | None = None) -> str | None:
    """Render the mock to PNG via Playwright, if it's installed."""
    out_dir = out_dir or config.MOCKUP_DIR
    html_path = write_mock_html(row, out_dir)
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        return None
    png_path = os.path.join(out_dir, f"{row['place_id']}.png")
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={"width": 1200, "height": 900})
        page.goto("file://" + os.path.abspath(html_path))
        page.screenshot(path=png_path, full_page=True)
        browser.close()
    return png_path


def run_mockup(place_id: str) -> dict[str, Any]:
    from . import db

    with db.connect() as conn:
        row = db.full_lead(conn, place_id)
    if not row:
        return {"error": f"place_id {place_id} not found"}
    html = write_mock_html(row)
    png = None
    try:
        png = screenshot(row)
    except Exception:  # noqa: BLE001 — screenshot is best-effort
        png = None
    return {"prompt": mockup_prompt(row), "html": html, "png": png}
