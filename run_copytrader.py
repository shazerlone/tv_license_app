"""Launcher for the CopyTrader Pro desktop app.

Run:  python run_copytrader.py
This is also the entry point used by the PyInstaller build (see build_exe.py).
"""
from copytrader_app.main import main

if __name__ == "__main__":
    main()
