"""Best-effort discovery of MT5 terminals that are ALREADY running but were not
launched by this agent (e.g. the operator opened them by hand).

Everything here is wrapped so a failure can never break the heartbeat — worst
case it returns fewer (or zero) discovered terminals.
"""
from __future__ import annotations

import glob
import logging
import os
import re

import psutil

log = logging.getLogger("agent.discovery")

# MT5 journal lines look like:  '12345678': login on Broker-ServerName  /  authorized on ...
_LOGIN_RE = re.compile(r"'(\d{4,})'\s*:\s*(?:login|authorized|connected)", re.I)
_SERVER_RE = re.compile(r"(?:on|to)\s+([A-Za-z0-9][\w\-.]{2,})", re.I)


def discover(managed_pids: set[int]) -> list[dict]:
    """Return a list of discovered (unmanaged) terminals with best-effort login."""
    out: list[dict] = []
    try:
        for p in psutil.process_iter(["pid", "name"]):
            name = (p.info.get("name") or "").lower()
            if "terminal" not in name:            # terminal64.exe / terminal.exe
                continue
            if p.info["pid"] in managed_pids:      # skip ones we launched
                continue
            try:
                out.append(_probe(p))
            except Exception as exc:               # noqa: BLE001 - never fail discovery
                log.debug("probe failed for pid=%s: %s", p.info.get("pid"), exc)
    except Exception as exc:                       # noqa: BLE001
        log.warning("discovery scan failed: %s", exc)
    return out


def _probe(p: psutil.Process) -> dict:
    pid = p.pid
    data_dir = _data_dir(p)
    login, server = _login_from_logs(data_dir) if data_dir else (None, None)
    cpu = ram = None
    try:
        with p.oneshot():
            cpu = round(p.cpu_percent(None), 2)
            ram = int(p.memory_info().rss / (1024 * 1024))
    except psutil.Error:
        pass
    return {
        "login": login or f"unknown-{pid}",
        "broker_server": server or "unknown",
        "os_pid": pid,
        "cpu_pct": cpu,
        "ram_mb": ram,
        "data_dir": data_dir,
    }


def _data_dir(p: psutil.Process) -> str | None:
    """Locate the terminal's data directory (portable = next to exe, else the
    %APPDATA%\\MetaQuotes\\Terminal\\<hash> folder inferred from open files)."""
    try:
        exe = p.exe()
        near = os.path.dirname(exe)
        if os.path.isdir(os.path.join(near, "logs")):   # portable install
            return near
    except psutil.Error:
        pass
    try:
        for f in p.open_files():
            m = re.search(r"(.*[\\/]Terminal[\\/][0-9A-Fa-f]{16,})", f.path)
            if m:
                return m.group(1)
    except psutil.Error:
        pass
    return None


def _login_from_logs(data_dir: str) -> tuple[str | None, str | None]:
    try:
        logs = sorted(glob.glob(os.path.join(data_dir, "logs", "*.log")), reverse=True)
        for lf in logs[:2]:                         # newest one or two log files
            text = _read_text(lf)
            m = _LOGIN_RE.search(text)
            if m:
                login = m.group(1)
                sm = _SERVER_RE.search(text[m.start():m.start() + 200])
                return login, (sm.group(1) if sm else None)
    except Exception:                               # noqa: BLE001
        pass
    return None, None


def _read_text(path: str) -> str:
    for enc in ("utf-16", "utf-8", "latin-1"):
        try:
            with open(path, encoding=enc, errors="ignore") as f:
                return f.read()
        except (OSError, UnicodeError):
            continue
    return ""
