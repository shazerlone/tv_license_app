"""MT5 Windows Agent — supervisor / reconciliation loop.

Run:  python agent.py --config C:\\mt5agent\\config.yaml
Or install as a Windows service with install-service.ps1 (NSSM).

Each tick the agent:
  1. Pulls DESIRED state from Laravel (which accounts should run here + action).
  2. Reconciles: launches missing terminals (respecting resource limits),
     restarts dead ones via the watchdog, stops de-assigned ones.
  3. Samples host + per-terminal CPU/RAM and pushes a heartbeat.
  4. Flushes buffered events (at-least-once, survives restarts).
"""
from __future__ import annotations

import argparse
import json
import logging
import os
import signal
import time
import uuid
from datetime import datetime, timezone
from logging.handlers import RotatingFileHandler

import yaml

import discovery
import metrics
from api_client import ApiClient
from mt5_installer import Mt5Installer
from mt5_manager import Instance, Mt5Manager
from watchdog import Watchdog

log = logging.getLogger("agent")


def utcnow_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


class Agent:
    def __init__(self, cfg: dict):
        self.cfg = cfg
        self.running = True

        self.api = ApiClient(
            cfg["api"]["base_url"], cfg["api"]["token"],
            verify_tls=cfg["api"].get("ca_bundle") or cfg["api"].get("verify_tls", True),
            timeout=cfg["api"].get("timeout_seconds", 20),
        )
        mt5c = cfg["mt5"]
        self.mt5 = Mt5Manager(
            mt5c["terminal_exe"], mt5c["data_root"],
            startup_grace=mt5c.get("startup_grace", 25),
            warm_count=mt5c.get("warm_count", 1),
        )
        self.auto_install = mt5c.get("auto_install", True)
        self.installer = Mt5Installer(
            mt5c["terminal_exe"],
            download_dir=mt5c.get("download_dir", os.path.join(mt5c["data_root"], "_installer")),
            installer_url=mt5c.get("installer_url"),
            installer_urls=mt5c.get("installer_urls"),
            install_timeout=mt5c.get("install_timeout", 300),
        )
        wd = cfg["watchdog"]
        self.watchdog = Watchdog(
            wd.get("restart_base_seconds", 5), wd.get("restart_max_seconds", 300),
            wd.get("max_restarts_per_hour", 6),
        )
        self.limits = cfg["limits"]
        self.reconcile_interval = cfg["poll"]["assignments_interval"]
        self.heartbeat_interval = cfg["poll"]["heartbeat_interval"]

        # account_id -> Instance
        self.instances: dict[int, Instance] = {}
        # account_id -> restart_count (reported to control plane)
        self.restart_counts: dict[int, int] = {}
        # durable event buffer
        self.event_file = os.path.join(os.path.dirname(cfg["logging"]["file"]), "events.buffer.json")
        self.events: list[dict] = self._load_events()

        self._last_reconcile = 0.0
        self._last_heartbeat = 0.0

    # ── event buffer (at-least-once) ─────────────────────────────────────────
    def _load_events(self) -> list[dict]:
        try:
            with open(self.event_file, encoding="utf-8") as f:
                return json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            return []

    def _persist_events(self) -> None:
        try:
            with open(self.event_file, "w", encoding="utf-8") as f:
                json.dump(self.events, f)
        except OSError:
            log.exception("Failed to persist event buffer")

    def emit(self, type_: str, severity: str, message: str,
             account_id: int | None = None, context: dict | None = None) -> None:
        self.events.append({
            "event_uid": str(uuid.uuid4()),
            "trading_account_id": account_id,
            "type": type_,
            "severity": severity,
            "message": message,
            "context": context or {},
            "occurred_at": utcnow_iso(),
        })
        self._persist_events()

    def flush_events(self) -> None:
        if not self.events:
            return
        try:
            accepted = set(self.api.send_events(self.events[:200]))
            if accepted:
                self.events = [e for e in self.events if e["event_uid"] not in accepted]
                self._persist_events()
        except Exception as exc:  # keep buffered, retry next tick
            log.warning("Event flush failed, will retry: %s", exc)

    # ── reconciliation ───────────────────────────────────────────────────────
    def reconcile(self) -> None:
        data = self.api.get_assignments()
        assignments = {a["account_id"]: a for a in data.get("assignments", [])}

        # 1. Stop terminals for accounts no longer assigned or explicitly stopped.
        for account_id in list(self.instances):
            a = assignments.get(account_id)
            if a is None or a["action"] == "stop":
                self._teardown(account_id, reason="unassigned" if a is None else "stop")

        # 2. Apply desired action for each assignment.
        for account_id, a in assignments.items():
            action = a["action"]
            if action == "stop":
                continue
            if action == "restart":
                self._restart(account_id, a, operator=True)
            else:  # run
                self._ensure_running(account_id, a)

    def _ensure_running(self, account_id: int, a: dict) -> None:
        inst = self.instances.get(account_id)

        if inst is None:
            # Re-adopt a terminal that survived an agent restart.
            pid = self.mt5.adopt_running(str(a["login"]))
            if pid:
                inst = Instance(account_id=account_id, login=str(a["login"]),
                                server=a["broker_server"],
                                data_dir=self.mt5.instance_dir(str(a["login"])),
                                pid=pid, started_at=time.time())
                self.instances[account_id] = inst
                metrics.prime_cpu(pid)
                return
            self._launch_new(account_id, a)
            return

        if not self.mt5.is_alive(inst):
            self._restart(account_id, a, operator=False)

    def _launch_new(self, account_id: int, a: dict) -> None:
        """Launch a brand-new terminal, gated by the resource guard."""
        if self.watchdog.is_tripped(account_id):
            return  # crash-looping; wait for human / breaker reset
        ok, why = self._has_resource_headroom()
        if not ok:
            log.warning("Deferring launch of account %s — %s", account_id, why)
            self.emit("resource_limit", "warning",
                      f"Deferred launch: {why}", account_id, self._host_snapshot())
            return
        inst = self.mt5.launch(account_id, a["login"], a["password"], a["broker_server"])
        self.instances[account_id] = inst
        metrics.prime_cpu(inst.pid)
        self.emit("started", "info", f"Terminal launched (pid={inst.pid})", account_id)

    def _restart(self, account_id: int, a: dict, *, operator: bool) -> None:
        may, reason = (True, "operator") if operator else self.watchdog.should_restart(account_id)
        if not may:
            if reason == "circuit_breaker_open":
                self.emit("crashed", "critical",
                          "Restart suppressed — circuit breaker open", account_id)
            return

        old = self.instances.get(account_id)
        if old:
            self.mt5.stop(old)
        # respect resource guard on restart too
        ok, why = self._has_resource_headroom()
        if not ok:
            log.warning("Deferring restart of account %s — %s", account_id, why)
            return

        inst = self.mt5.launch(account_id, a["login"], a["password"], a["broker_server"])
        self.instances[account_id] = inst
        metrics.prime_cpu(inst.pid)
        self.restart_counts[account_id] = self.restart_counts.get(account_id, 0) + 1
        self.watchdog.record_restart(account_id)
        self.emit("restarted", "warning",
                  f"Terminal restarted ({'operator' if operator else 'watchdog'})",
                  account_id, {"pid": inst.pid, "restart_count": self.restart_counts[account_id]})

    def _teardown(self, account_id: int, reason: str) -> None:
        inst = self.instances.pop(account_id, None)
        if inst:
            self.mt5.stop(inst)
            self.emit("stopped", "info", f"Terminal stopped ({reason})", account_id)
        self.watchdog.forget(account_id)
        self.restart_counts.pop(account_id, None)

    # ── resource-aware guard (Phase 6) ───────────────────────────────────────
    def _host_snapshot(self) -> dict:
        return metrics.host_metrics()

    def _has_resource_headroom(self) -> tuple[bool, str]:
        h = metrics.host_metrics()
        if h["cpu_pct"] >= self.limits["cpu_soft_limit_pct"]:
            return False, f"cpu {h['cpu_pct']}% >= {self.limits['cpu_soft_limit_pct']}%"
        if h["ram_used_mb"] >= self.limits["ram_soft_limit_mb"]:
            return False, f"ram {h['ram_used_mb']}MB >= {self.limits['ram_soft_limit_mb']}MB"
        free = h["ram_total_mb"] - h["ram_used_mb"]
        if free <= self.limits["ram_headroom_mb"]:
            return False, f"only {free}MB free (< {self.limits['ram_headroom_mb']}MB headroom)"
        return True, "ok"

    # ── heartbeat ────────────────────────────────────────────────────────────
    def heartbeat(self) -> None:
        terminals = []
        for account_id, inst in list(self.instances.items()):
            alive = self.mt5.is_alive(inst)
            pm = metrics.process_metrics(inst.pid) if alive else None
            if alive and pm:
                self.watchdog.record_healthy(account_id)  # reset backoff when up
                status = "running"      # 'connected' is inferred server-side once broker link confirmed
            else:
                status = "crashed"
            terminals.append({
                "account_id": account_id,
                "status": status,
                "os_pid": inst.pid,
                "cpu_pct": pm["cpu_pct"] if pm else None,
                "ram_mb": pm["ram_mb"] if pm else None,
                "mt5_connected": alive,   # refine with MetaTrader5 pkg if you attach it
                "restart_count": self.restart_counts.get(account_id, 0),
                "instance_key": inst.login,
                "data_dir": inst.data_dir,
            })

        # Discover MT5 terminals running on this box that we didn't launch.
        managed_pids = {i.pid for i in self.instances.values() if i.pid}
        discovered = []
        if self.cfg.get("discovery", {}).get("enabled", True):
            discovered = discovery.discover(managed_pids)

        payload = {
            "host": metrics.host_metrics(),
            "agent_version": self.cfg.get("agent_version", "1.0.0"),
            "terminals": terminals,
            "discovered": discovered,
        }
        self.api.send_heartbeat(payload)

    # ── main loop ────────────────────────────────────────────────────────────
    def bootstrap(self) -> None:
        """Self-provision MT5 on a bare VPS, then warm the spare pool so the
        first account launches instantly. Runs once at startup."""
        if not self.auto_install:
            return
        try:
            if not self.installer.base_installed():
                self.emit("agent_started", "info", "No MT5 found — auto-installing")
                resolved = self.installer.ensure_base_install()
                self.mt5.set_base_exe(resolved)
                self.emit("started", "info", f"MT5 installed at {resolved}")
            else:
                self.mt5.set_base_exe(self.installer.terminal_exe)
            # Pre-provision the warm spare(s) in the background.
            self.mt5.refill_pool_async()
        except Exception as exc:
            log.exception("MT5 bootstrap failed: %s", exc)
            self.emit("agent_error", "error", f"MT5 auto-install failed: {exc}")

    def run(self) -> None:
        signal.signal(signal.SIGTERM, self._stop)
        signal.signal(signal.SIGINT, self._stop)
        log.info("Agent starting — %d instance(s) adopted on boot", len(self.instances))
        self.emit("agent_started", "info", "Agent process started")
        self.bootstrap()

        while self.running:
            now = time.time()
            try:
                if now - self._last_reconcile >= self.reconcile_interval:
                    self.reconcile()
                    self._last_reconcile = now
                if now - self._last_heartbeat >= self.heartbeat_interval:
                    self.heartbeat()
                    self._last_heartbeat = now
                self.flush_events()
            except PermissionError as exc:
                log.error("Fatal auth error: %s", exc)
                time.sleep(30)
            except Exception as exc:
                log.exception("Loop error: %s", exc)
                self.emit("agent_error", "error", str(exc))
            time.sleep(1)

        log.info("Agent stopping — leaving terminals running")
        self.flush_events()

    def _stop(self, *_):
        # NOTE: we deliberately leave terminals running on agent stop so an
        # agent update/restart does not disconnect live accounts. They are
        # re-adopted on next start.
        self.running = False


def setup_logging(cfg: dict) -> None:
    os.makedirs(os.path.dirname(cfg["file"]), exist_ok=True)
    handler = RotatingFileHandler(
        cfg["file"], maxBytes=cfg.get("max_bytes", 10_485_760),
        backupCount=cfg.get("backups", 5), encoding="utf-8",
    )
    logging.basicConfig(
        level=getattr(logging, cfg.get("level", "INFO")),
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
        handlers=[handler, logging.StreamHandler()],
    )


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", default="config.yaml")
    args = ap.parse_args()

    with open(args.config, encoding="utf-8") as f:
        cfg = yaml.safe_load(f)

    setup_logging(cfg["logging"])
    Agent(cfg).run()


if __name__ == "__main__":
    main()
