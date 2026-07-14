#!/usr/bin/env python3
"""One-command launcher for Sitegap.

    python run.py

Starts the web dashboard and opens it in your browser automatically. From
there every stage (search, audit, score, pitch) is a button — no other
commands needed. Reads your Google key from the local .env file.
"""

from __future__ import annotations

import os
import sys
import threading
import time
import webbrowser


def _open_browser(url: str) -> None:
    time.sleep(1.5)  # give Flask a moment to bind the port
    try:
        webbrowser.open(url)
    except Exception:
        pass


def main() -> None:
    try:
        from sitegap import config, db
        from sitegap.web.app import app
    except ModuleNotFoundError:
        sys.exit(
            "Missing dependencies. Run this first:\n"
            "    pip install -r sitegap/requirements.txt"
        )

    db.init_db()
    port = int(os.environ.get("SITEGAP_PORT", "5001"))
    url = f"http://127.0.0.1:{port}"

    print("=" * 60)
    print("  Sitegap — Lead Finder → Quotation → Pitch Pack")
    print("=" * 60)
    if config.PLACES_API_KEY:
        print("  ✓ Google API key loaded from .env")
        print("    On the dashboard, click '① Search grid' to pull real leads.")
    else:
        print("  ⚠ No API key found in .env — demo mode.")
        print("    Add your key to .env, or click 'Seed demo data' in the UI.")
    print(f"\n  Opening {url} in your browser…")
    print("  (Leave this window open. Press Ctrl+C here to stop.)")
    print("=" * 60)

    threading.Thread(target=_open_browser, args=(url,), daemon=True).start()
    app.run(host="127.0.0.1", port=port)


if __name__ == "__main__":
    main()
