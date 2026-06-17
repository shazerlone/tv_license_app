"""Build a standalone Windows .exe for CopyTrader Pro.

Run this ON WINDOWS (PyInstaller produces an executable for the OS it runs on):

    pip install -r copytrader_app/requirements.txt
    python build_exe.py

Output: dist/CopyTraderPro.exe  (single-file, windowed — no console).

Notes
-----
* customtkinter ships data files (themes) that must be bundled; this script
  collects them automatically via --collect-all customtkinter.
* For a custom icon, drop an `app.ico` next to this file; it will be used.
"""
from __future__ import annotations

import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def main() -> int:
    args = [
        sys.executable, "-m", "PyInstaller",
        "--noconfirm",
        "--clean",
        "--onefile",
        "--windowed",
        "--name", "CopyTraderPro",
        "--collect-all", "customtkinter",
    ]
    icon = os.path.join(HERE, "app.ico")
    if os.path.exists(icon):
        args += ["--icon", icon]
    args.append(os.path.join(HERE, "run_copytrader.py"))

    print("Running:", " ".join(args))
    return subprocess.call(args)


if __name__ == "__main__":
    raise SystemExit(main())
