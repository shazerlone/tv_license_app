"""Trade copier engine (runs inside the agent, in its own thread).

It reuses the terminals the manager already runs — no new terminals, no EAs.
For each participating terminal it drives a lightweight `mt5_connector.py`
subprocess (one MT5 IPC connection each). A master's positions are polled
tightly; new/closed positions are mapped + lot-sized and executed on each
same-VPS slave. Cross-VPS slaves are skipped for now (network relay is a later
phase). Every failure is contained so it never crashes the agent.
"""
from __future__ import annotations

import json
import logging
import subprocess
import sys
import threading
import time

log = logging.getLogger("agent.copier")


class Connector:
    """Owns one mt5_connector.py subprocess and does strict request/response."""

    def __init__(self, login: str, argv: list[str]):
        self.login = login
        self.ready = False
        self.error: str | None = None
        self.lock = threading.Lock()
        self._id = 0
        self.proc = subprocess.Popen(
            argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            text=True, bufsize=1,
        )
        threading.Thread(target=self._await_ready, daemon=True).start()

    def _await_ready(self):
        try:
            line = self.proc.stdout.readline()
            d = json.loads(line) if line else {}
        except Exception:
            d = {}
        if d.get("ok"):
            self.ready = True
        else:
            self.error = d.get("fatal") or "connector failed to start"
            log.warning("Connector %s not ready: %s", self.login, self.error)

    def alive(self) -> bool:
        return self.proc.poll() is None

    def call(self, cmd: str, **kw) -> dict:
        if not self.alive():
            return {"ok": False, "error": "connector dead"}
        with self.lock:
            self._id += 1
            req = {"id": self._id, "cmd": cmd, **kw}
            try:
                self.proc.stdin.write(json.dumps(req) + "\n")
                self.proc.stdin.flush()
                line = self.proc.stdout.readline()
                return json.loads(line) if line else {"ok": False, "error": "no response"}
            except Exception as exc:
                return {"ok": False, "error": str(exc)}

    def stop(self):
        try:
            self.proc.terminate()
        except Exception:
            pass


class CopierEngine:
    def __init__(self, api, connector_script: str, resolve_creds):
        self.api = api
        self.script = connector_script
        self.resolve = resolve_creds          # account_id -> (exe, login, password, server) | None
        self.connectors: dict[str, Connector] = {}
        self.groups: list[dict] = []
        self.master_pos: dict[str, dict] = {}  # master_login -> {ticket: pos}
        self.links: dict[tuple, int] = {}      # (copier_slave_id, master_ticket) -> slave_ticket
        self.events: list[dict] = []
        self.cfg_lock = threading.Lock()

    # ── config ──────────────────────────────────────────────────────────────
    def update_config(self, copiers: list[dict]):
        with self.cfg_lock:
            self.groups = copiers or []
            for cop in self.groups:
                for s in cop.get("slaves", []):
                    for ot in s.get("open_trades", []):
                        if ot.get("slave_ticket"):
                            self.links.setdefault((s["copier_slave_id"], ot["master_ticket"]),
                                                  ot["slave_ticket"])
        self._ensure_connectors()

    def _ensure_connectors(self):
        need: set[tuple[str, int]] = set()
        with self.cfg_lock:
            for cop in self.groups:
                m = cop["master"]
                need.add((m["login"], m["account_id"]))
                for s in cop.get("slaves", []):
                    if s.get("same_vps") and s.get("login"):
                        need.add((s["login"], s["account_id"]))
        for login, account_id in need:
            c = self.connectors.get(login)
            if c and c.alive():
                continue
            creds = None
            try:
                creds = self.resolve(account_id)
            except Exception as exc:
                log.debug("resolve creds failed for %s: %s", account_id, exc)
            if not creds:
                continue
            exe, lg, pw, srv = creds
            argv = [sys.executable, self.script, "--exe", exe, "--login", str(lg),
                    "--password", pw or "", "--server", srv or ""]
            try:
                self.connectors[login] = Connector(login, argv)
                log.info("Started copier connector for %s", login)
            except Exception as exc:
                log.warning("Could not start connector for %s: %s", login, exc)

    # ── main tick ───────────────────────────────────────────────────────────
    def tick(self):
        with self.cfg_lock:
            groups = list(self.groups)
        for cop in groups:
            try:
                self._process_master(cop)
            except Exception as exc:            # never break the loop
                log.warning("copier group error: %s", exc)
        self._flush_events()

    def _process_master(self, cop: dict):
        ml = cop["master"]["login"]
        conn = self.connectors.get(ml)
        if not conn or not conn.ready:
            return
        resp = conn.call("positions")
        if not resp.get("ok"):
            return
        cur = {p["ticket"]: p for p in resp.get("positions", [])}
        prev = self.master_pos.get(ml)

        if prev is None:
            # First time we see this master: baseline it.
            self.master_pos[ml] = cur
            if cop.get("copy_new_only", True):
                return                          # existing positions are NOT copied
            prev = {}

        for tk, p in cur.items():
            if tk not in prev:
                self._on_open(cop, p)
        for tk in list(prev.keys()):
            if tk not in cur:
                self._on_close(cop, tk)

        self.master_pos[ml] = cur

    def _on_open(self, cop: dict, pos: dict):
        for s in cop.get("slaves", []):
            if not s.get("same_vps"):
                continue
            key = (s["copier_slave_id"], pos["ticket"])
            if key in self.links:
                continue                        # already copied (dedup)
            slave_symbol = self._map_symbol(s, pos["symbol"])
            if not slave_symbol:
                continue                        # unmapped master symbol -> skip
            conn = self.connectors.get(s["login"])
            if not conn or not conn.ready:
                continue
            side = pos["side"]
            if s.get("reverse"):
                side = "sell" if side == "buy" else "buy"
            volume = self._size_lot(cop, s, pos)
            kw = {"symbol": slave_symbol, "side": side, "volume": volume,
                  "deviation": s.get("max_slippage_points", 20)}
            if s.get("copy_sl_tp"):
                if pos.get("sl"):
                    kw["sl"] = pos["sl"]
                if pos.get("tp"):
                    kw["tp"] = pos["tp"]
            r = conn.call("open", **kw)
            if r.get("ok"):
                self.links[key] = r["ticket"]
                self._event(s, pos, "open", slave_ticket=r["ticket"],
                            slave_symbol=slave_symbol, slave_volume=r.get("volume", volume), side=side)
                log.info("Copied OPEN %s#%s -> slave %s %s %.3f (ticket %s)",
                         pos["symbol"], pos["ticket"], s["login"], slave_symbol, volume, r["ticket"])
            else:
                self._event(s, pos, "error", slave_symbol=slave_symbol,
                            side=side, error=r.get("error"))
                log.warning("Copy OPEN failed -> %s: %s", s["login"], r.get("error"))

    def _on_close(self, cop: dict, master_ticket: int):
        for s in cop.get("slaves", []):
            key = (s["copier_slave_id"], master_ticket)
            slave_ticket = self.links.get(key)
            if not slave_ticket:
                continue
            conn = self.connectors.get(s["login"])
            if not conn or not conn.ready:
                continue
            r = conn.call("close", ticket=slave_ticket)
            if r.get("ok"):
                self.links.pop(key, None)
                self.events.append({
                    "copier_slave_id": s["copier_slave_id"], "master_ticket": master_ticket,
                    "slave_ticket": slave_ticket, "status": "closed",
                })
                log.info("Copied CLOSE master#%s -> slave %s ticket %s",
                         master_ticket, s["login"], slave_ticket)

    # ── helpers ─────────────────────────────────────────────────────────────
    def _map_symbol(self, s: dict, master_symbol: str) -> str | None:
        for mp in s.get("maps", []):
            if mp["from"].lower() == master_symbol.lower():
                return mp["to"]
        return None

    def _size_lot(self, cop: dict, s: dict, pos: dict) -> float:
        mode = s.get("lot_mode", "multiplier")
        mv = pos["volume"]
        if mode == "fixed" and s.get("fixed_lots"):
            v = float(s["fixed_lots"])
        elif mode == "balance":
            mb = self._balance(cop["master"]["login"])
            sb = self._balance(s["login"])
            ratio = (sb / mb) if (mb and sb and mb > 0) else 1.0
            v = mv * ratio * float(s.get("balance_multiplier") or 1.0)
        else:
            v = mv * float(s.get("lot_multiplier") or 1.0)
        if s.get("min_lot"):
            v = max(v, float(s["min_lot"]))
        if s.get("max_lot"):
            v = min(v, float(s["max_lot"]))
        return round(v, 3)

    def _balance(self, login: str):
        conn = self.connectors.get(login)
        if conn and conn.ready:
            r = conn.call("account")
            if r.get("ok"):
                return r["account"]["balance"]
        return None

    def _event(self, s, pos, status, **extra):
        self.events.append({
            "copier_slave_id": s["copier_slave_id"],
            "master_ticket": pos["ticket"],
            "master_symbol": pos["symbol"],
            "master_volume": pos["volume"],
            "status": status,
            **extra,
        })

    def _flush_events(self):
        if not self.events:
            return
        batch, self.events = self.events[:200], self.events[200:]
        try:
            self.api.send_copy_events(batch)
        except Exception as exc:
            self.events = batch + self.events   # retry next tick
            log.debug("copy-event flush failed: %s", exc)

    def stop(self):
        for c in self.connectors.values():
            c.stop()
