"""Sitegap web dashboard — everything under one roof.

A single Flask app that ties the whole pipeline together: run the funnel,
browse the ranked lead queue, open a full pitch pack, and preview the
generated site mock-up. Runs on the same SQLite DB as the CLI.

    python -m sitegap.web.app        # http://127.0.0.1:5001
"""

from __future__ import annotations

import json
import os
import threading

import markupsafe
from flask import Flask, abort, jsonify, redirect, render_template, request, url_for

from .. import config, db, export, pitch as pitch_mod, places, scoring, site_audit
from ..config import AREAS, AREA_GROUPS, NICHES

app = Flask(__name__, template_folder="templates", static_folder="static")

# In-process job state so long stages (search/audit) don't block the request.
_JOB: dict = {"running": False, "stage": "", "line": "", "done": True, "log": []}


BUCKET_META = {
    "NO_SITE": ("No site", "#ef4444", "Best lead — nowhere for customers to book."),
    "SOCIAL_ONLY": ("Social only", "#f97316", "Instagram-only — they already know they need a site."),
    "BROKEN": ("Broken", "#dc2626", "Site is down or parked — they may not even know."),
    "WEAK": ("Weak", "#eab308", "Loads, but fails key signals."),
    "STRONG": ("Strong", "#22c55e", "Deprioritise — care-plan candidate."),
}
TIER_META = {"A": ("#22c55e", "Call today"), "B": ("#eab308", "Warm"), "C": ("#64748b", "Backlog")}


def _rows_to_dicts(rows) -> list[dict]:
    out = []
    for r in rows:
        d = {k: r[k] for k in r.keys()}
        try:
            d["reasons"] = json.loads(r["reasons_json"]) if r["reasons_json"] else []
        except (KeyError, TypeError, json.JSONDecodeError):
            d["reasons"] = []
        d["area_label"] = AREAS[d["area"]].label if d["area"] in AREAS else d.get("area", "")
        d["niche_label"] = NICHES.get(d["niche_query"], d["niche_query"] or "").split(" in ")[0]
        d["bucket_meta"] = BUCKET_META.get(d.get("bucket"), (d.get("bucket", "—"), "#64748b", ""))
        d["tier_meta"] = TIER_META.get(d.get("tier"), ("#64748b", ""))
        out.append(d)
    return out


@app.template_filter("aed")
def _aed(v) -> str:
    try:
        return f"{int(v):,}"
    except (TypeError, ValueError):
        return str(v)


# --------------------------------------------------------------------------- #
# Pages
# --------------------------------------------------------------------------- #
@app.route("/")
def dashboard():
    db.init_db()
    with db.connect() as conn:
        stats = db.funnel_stats(conn)
        top = _rows_to_dicts(db.leads(conn, tier="A")[:8])
    return render_template(
        "dashboard.html",
        stats=stats,
        top=top,
        bucket_meta=BUCKET_META,
        tier_meta=TIER_META,
        job=_JOB,
        cost_per_query=config.COST_PER_QUERY_USD,
        has_key=bool(config.PLACES_API_KEY),
    )


@app.route("/leads")
def leads():
    tier = request.args.get("tier") or None
    niche = request.args.get("niche") or None
    area = request.args.get("area") or None
    bucket = request.args.get("bucket") or None
    with db.connect() as conn:
        rows = _rows_to_dicts(db.leads(conn, tier=tier, niche=niche, area=area, bucket=bucket))
    return render_template(
        "leads.html",
        rows=rows,
        niches=NICHES,
        areas=AREAS,
        buckets=BUCKET_META,
        active={"tier": tier, "niche": niche, "area": area, "bucket": bucket},
    )


@app.route("/lead/<place_id>")
def lead_detail(place_id: str):
    with db.connect() as conn:
        row = db.full_lead(conn, place_id)
    if not row:
        abort(404)
    d = _rows_to_dicts([row])[0]
    parts = pitch_mod.outreach_parts(row)
    quote = scoring.build_quote(d.get("bucket") or "WEAK", d["niche_query"], d.get("review_count") or 0)
    return render_template(
        "lead.html", d=d, quote=quote,
        wa_text=parts["whatsapp"], email_text=parts["email"], walk_text=parts["walk_in"],
    )


@app.route("/lead/<place_id>/mockup")
def lead_mockup(place_id: str):
    from .. import mockup

    with db.connect() as conn:
        row = db.full_lead(conn, place_id)
    if not row:
        abort(404)
    return mockup.render_mock_html(row)


@app.route("/pitch/<place_id>.md")
def pitch_raw(place_id: str):
    with db.connect() as conn:
        row = db.full_lead(conn, place_id)
    if not row:
        abort(404)
    return app.response_class(pitch_mod.build_markdown(row), mimetype="text/markdown")


# --------------------------------------------------------------------------- #
# Actions (run pipeline stages)
# --------------------------------------------------------------------------- #
def _run_job(stage: str, fn):
    def worker():
        _JOB.update(running=True, stage=stage, done=False, line="starting…", log=[])
        try:
            fn()
            _JOB["line"] = "complete"
        except Exception as exc:  # noqa: BLE001
            _JOB["line"] = f"error: {exc}"
            _JOB["log"].append(str(exc))
        finally:
            _JOB.update(running=False, done=True)

    threading.Thread(target=worker, daemon=True).start()


@app.route("/run/<stage>", methods=["POST"])
def run_stage(stage: str):
    if _JOB["running"]:
        return jsonify({"error": "a job is already running"}), 409

    def log(msg):
        _JOB["line"] = msg
        _JOB["log"].append(msg)

    if stage == "seed":
        from .. import seed as seed_mod

        _run_job("seed", lambda: log(f"seeded {seed_mod.seed()['seeded']} demo leads"))
    elif stage == "search":
        niches = request.form.getlist("niches") or ["all"]
        areas = request.form.getlist("areas") or ["dubai"]
        nn = list(NICHES) if "all" in niches else niches
        aa = []
        for a in areas:
            aa.extend(AREA_GROUPS.get(a, [a]))
        maxq = request.form.get("max_queries", type=int)

        def do_search():
            res = places.run_search(nn, list(dict.fromkeys(aa)), maxq,
                                    on_progress=lambda i, t, c, f: log(f"[{i}/{t}] {c.niche}@{c.area}: {f}"))
            log(f"new places {res['new_places']}, spend ${res['estimated_spend_usd']}")

        _run_job("search", do_search)
    elif stage == "audit":
        limit = request.form.get("limit", type=int)
        _run_job("audit", lambda: log(str(site_audit.run_audit(
            limit, on_progress=lambda i, t, p, r: log(f"[{i}/{t}] {p['name'][:30]} → {r.bucket}"))["buckets"])))
    elif stage == "score":
        _run_job("score", lambda: log(str(scoring.run_scoring()["tiers"])))
    elif stage == "pitch":
        _run_job("pitch", lambda: log(f"wrote {pitch_mod.run_pitch(tier='A')['written']} packs"))
    elif stage == "export":
        _run_job("export", lambda: log(export.run_export(tier="A")["out"]))
    else:
        return jsonify({"error": f"unknown stage {stage}"}), 400
    return redirect(url_for("dashboard"))


@app.route("/job")
def job_status():
    return jsonify(_JOB)


def main():
    db.init_db()
    port = int(os.environ.get("SITEGAP_PORT", "5001"))
    app.run(host="0.0.0.0", port=port, debug=bool(os.environ.get("SITEGAP_DEBUG")))


if __name__ == "__main__":
    main()
