"""Sitegap CLI. Every stage is idempotent and resumable.

    python -m sitegap.cli search --niches all --areas dubai
    python -m sitegap.cli audit  --limit 200
    python -m sitegap.cli score
    python -m sitegap.cli export --tier A --out outputs/leads_A.csv
    python -m sitegap.cli pitch  --tier A
    python -m sitegap.cli mockup --place-id XXXX
    python -m sitegap.cli seed          # populate demo data, no API key needed
    python -m sitegap.cli stats
"""

from __future__ import annotations

import argparse
import sys

from . import config, db, export, pitch, places, scoring, site_audit
from .config import AREA_GROUPS, AREAS, NICHES


def _resolve_niches(values: list[str]) -> list[str]:
    if not values or "all" in values:
        return list(NICHES.keys())
    bad = [v for v in values if v not in NICHES]
    if bad:
        sys.exit(f"Unknown niches: {', '.join(bad)}\nAvailable: {', '.join(NICHES)}")
    return values


def _resolve_areas(values: list[str]) -> list[str]:
    if not values:
        values = ["dubai"]
    out: list[str] = []
    for v in values:
        if v in AREA_GROUPS:
            out.extend(AREA_GROUPS[v])
        elif v in AREAS:
            out.append(v)
        else:
            sys.exit(f"Unknown area/group: {v}\nGroups: {', '.join(AREA_GROUPS)}")
    return list(dict.fromkeys(out))  # de-dupe, keep order


def cmd_search(args: argparse.Namespace) -> None:
    niches = _resolve_niches(args.niches)
    areas = _resolve_areas(args.areas)
    grid = places.build_grid(niches, areas)
    n = len(grid) if args.max_queries is None else min(args.max_queries, len(grid))
    print(f"Grid: {len(niches)} niches × {len(areas)} areas = {len(grid)} cells (running {n}).")
    print(f"Worst-case estimated spend: ${places.estimate_spend(n):.2f} "
          f"(≈ ${config.COST_PER_QUERY_USD}/query × up to {config.MAX_PAGES_PER_QUERY} pages).")
    if not config.PLACES_API_KEY:
        print("\n⚠  GOOGLE_PLACES_API_KEY is not set. Run `python -m sitegap.cli seed` "
              "for demo data, or export a key first.")
        return

    def prog(i, total, cell, found):
        print(f"  [{i}/{total}] {cell.niche} @ {cell.area}: {found} places", flush=True)

    res = places.run_search(niches, areas, args.max_queries, on_progress=prog)
    print(f"\nDone. New places: {res['new_places']} · live requests: {res['live_requests']} "
          f"· actual spend ≈ ${res['estimated_spend_usd']}")


def cmd_audit(args: argparse.Namespace) -> None:
    def prog(i, total, place, res):
        print(f"  [{i}/{total}] {place['name'][:40]:40} → {res.bucket}", flush=True)

    res = site_audit.run_audit(args.limit, on_progress=prog)
    print(f"\nAudited {res['audited']}. Buckets: {res['buckets']}")


def cmd_score(args: argparse.Namespace) -> None:
    res = scoring.run_scoring()
    print(f"Scored {res['scored']}. Tiers: {res['tiers']}")


def cmd_export(args: argparse.Namespace) -> None:
    res = export.run_export(tier=args.tier, out=args.out)
    print(f"Wrote {res['rows']} rows → {res['out']}")


def cmd_pitch(args: argparse.Namespace) -> None:
    res = pitch.run_pitch(tier=args.tier)
    print(f"Wrote {res['written']} pitch packs → {res['dir']}")


def cmd_mockup(args: argparse.Namespace) -> None:
    from . import mockup

    res = mockup.run_mockup(args.place_id)
    if "error" in res:
        sys.exit(res["error"])
    print(f"HTML mock: {res['html']}")
    print(f"Screenshot: {res['png'] or '(Playwright not installed — HTML only)'}")
    print(f"\nPrompt:\n{res['prompt']}")


def cmd_seed(args: argparse.Namespace) -> None:
    from . import seed as seed_mod

    res = seed_mod.seed(args.per_area)
    print(f"Seeded {res['seeded']} demo leads.")
    print(f"  Qualified {res['qualified']} · Audited {res['audited']} · Scored {res['scored']}")
    print(f"  Buckets {res['buckets']}\n  Tiers {res['tiers']}")


def cmd_stats(args: argparse.Namespace) -> None:
    db.init_db()
    with db.connect() as conn:
        s = db.funnel_stats(conn)
    print("Funnel:")
    print(f"  Places fetched : {s['total']}")
    print(f"  Qualified      : {s['qualified']}")
    print(f"  Audited        : {s['audited']}  {s['buckets']}")
    print(f"  Scored         : {s['scored']}  {s['tiers']}")
    print(f"  Cache entries  : {s['cache_entries']}")


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="sitegap", description="Lead Finder → Quotation → Pitch Pack")
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("search", help="Fan out the niche × area grid via Google Places")
    s.add_argument("--niches", nargs="+", default=["all"])
    s.add_argument("--areas", nargs="+", default=["dubai"])
    s.add_argument("--max-queries", type=int, default=None, help="Budget cap on grid cells")
    s.set_defaults(func=cmd_search)

    a = sub.add_parser("audit", help="Audit websites of qualified leads")
    a.add_argument("--limit", type=int, default=None)
    a.set_defaults(func=cmd_audit)

    sc = sub.add_parser("score", help="Compute opportunity score, tier and package")
    sc.set_defaults(func=cmd_score)

    e = sub.add_parser("export", help="Export ranked leads to CSV")
    e.add_argument("--tier", default=None, choices=["A", "B", "C"])
    e.add_argument("--out", default=None)
    e.set_defaults(func=cmd_export)

    pt = sub.add_parser("pitch", help="Generate pitch packs (markdown)")
    pt.add_argument("--tier", default="A", choices=["A", "B", "C"])
    pt.set_defaults(func=cmd_pitch)

    m = sub.add_parser("mockup", help="Generate a mock homepage + prompt for one lead")
    m.add_argument("--place-id", required=True)
    m.set_defaults(func=cmd_mockup)

    sd = sub.add_parser("seed", help="Populate demo leads (no API key needed)")
    sd.add_argument("--per-area", type=int, default=6)
    sd.set_defaults(func=cmd_seed)

    st = sub.add_parser("stats", help="Show funnel counts")
    st.set_defaults(func=cmd_stats)
    return p


def main(argv: list[str] | None = None) -> None:
    args = build_parser().parse_args(argv)
    args.func(args)


if __name__ == "__main__":
    main()
