"""Launch, isolate, and stop MetaTrader 5 terminals — one per trading account.

Isolation strategy
------------------
Each account gets its OWN copy of the MT5 installation under
``data_root\\<login>\\`` and is launched in **portable mode** with a generated
``start.ini`` that carries the auto-login credentials. Portable mode keeps every
terminal's data, logs, and config inside its own folder, so N terminals never
collide. The credential .ini is deleted right after a successful launch so the
plaintext password does not linger on disk.

This module knows nothing about the API — it only starts/stops OS processes and
reports what it sees. The supervisor (agent.py) drives it.
"""
from __future__ import annotations

import logging
import os
import shutil
import subprocess
import threading
import time
import uuid
from dataclasses import dataclass, field

import psutil

log = logging.getLogger("agent.mt5")

CREATE_NO_WINDOW = 0x08000000  # keep terminals off the interactive desktop


@dataclass
class Instance:
    account_id: int
    login: str
    server: str
    data_dir: str
    pid: int | None = None
    proc: subprocess.Popen | None = field(default=None, repr=False)
    started_at: float | None = None


class Mt5Manager:
    def __init__(self, terminal_exe: str, data_root: str, startup_grace: int = 25,
                 warm_count: int = 1):
        self.base_exe = terminal_exe
        self.base_dir = os.path.dirname(terminal_exe)
        self.data_root = data_root
        self.startup_grace = startup_grace
        self.warm_count = warm_count
        self.pool_dir = os.path.join(data_root, "_pool")
        self._pool_lock = threading.Lock()
        os.makedirs(data_root, exist_ok=True)
        os.makedirs(self.pool_dir, exist_ok=True)

    def set_base_exe(self, terminal_exe: str) -> None:
        """Point the manager at the base install the installer resolved."""
        self.base_exe = terminal_exe
        self.base_dir = os.path.dirname(terminal_exe)

    # ── paths ────────────────────────────────────────────────────────────────
    def instance_dir(self, login: str) -> str:
        return os.path.join(self.data_root, str(login))

    def instance_exe(self, login: str) -> str:
        return os.path.join(self.instance_dir(login), "terminal64.exe")

    # ── warm pool ────────────────────────────────────────────────────────────
    def _copy_install(self, target: str) -> None:
        """Copy the base MT5 install into `target` (robocopy on Windows)."""
        os.makedirs(target, exist_ok=True)
        try:
            subprocess.run(
                ["robocopy", self.base_dir, target, "/E", "/NFL", "/NDL", "/NJH", "/NJS", "/NP"],
                check=False, capture_output=True,
            )
        except FileNotFoundError:
            shutil.copytree(self.base_dir, target, dirs_exist_ok=True)

    def _pool_slots(self) -> list[str]:
        return [os.path.join(self.pool_dir, d) for d in os.listdir(self.pool_dir)
                if os.path.isfile(os.path.join(self.pool_dir, d, "terminal64.exe"))]

    def _claim_warm(self, login: str) -> bool:
        """Atomically hand a pre-built pool slot to this account (fast rename)."""
        with self._pool_lock:
            slots = self._pool_slots()
            if not slots:
                return False
            src = slots[0]
            try:
                os.rename(src, self.instance_dir(login))
                log.info("Claimed warm MT5 instance for %s", login)
                return True
            except OSError:
                return False

    def refill_pool_async(self) -> None:
        """Top the warm pool back up to `warm_count` in a background thread."""
        threading.Thread(target=self._refill_pool, daemon=True).start()

    def _refill_pool(self) -> None:
        if not os.path.isfile(self.base_exe):
            return  # base not installed yet; nothing to copy from
        while len(self._pool_slots()) < self.warm_count:
            slot = os.path.join(self.pool_dir, f"warm_{uuid.uuid4().hex[:8]}")
            log.info("Pre-provisioning warm MT5 instance %s", slot)
            self._copy_install(slot)

    # ── provisioning ─────────────────────────────────────────────────────────
    def ensure_installed(self, login: str) -> None:
        """Ensure this account has its own MT5 folder: claim a warm slot if one
        exists (instant), else copy the base install. Then refill the pool."""
        if os.path.isfile(self.instance_exe(login)):
            return
        log.info("Provisioning MT5 instance folder for %s", login)
        if not self._claim_warm(login):
            self._copy_install(self.instance_dir(login))
        self.refill_pool_async()

    def _write_login_ini(self, login: str, password: str, server: str) -> str:
        """Write the one-shot auto-login config MT5 reads at startup."""
        ini_path = os.path.join(self.instance_dir(login), "start.ini")
        # MT5 reads [Common] Login/Password/Server on launch with /config.
        content = (
            "[Common]\n"
            f"Login={login}\n"
            f"Password={password}\n"
            f"Server={server}\n"
            "ProxyEnable=0\n"
            "CertInstall=0\n"
            "NewsEnable=0\n"
        )
        # Write with restrictive perms; deleted right after launch.
        fd = os.open(ini_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w", encoding="utf-16") as f:  # MT5 ini is UTF-16
            f.write(content)
        return ini_path

    # ── lifecycle ────────────────────────────────────────────────────────────
    def launch(self, account_id: int, login: str, password: str, server: str) -> Instance:
        self.ensure_installed(login)
        ini = self._write_login_ini(login, password, server)
        exe = self.instance_exe(login)

        log.info("Launching terminal for account=%s login=%s", account_id, login)
        proc = subprocess.Popen(
            [exe, "/portable", f"/config:{ini}"],
            cwd=self.instance_dir(login),
            creationflags=CREATE_NO_WINDOW,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

        inst = Instance(
            account_id=account_id, login=str(login), server=server,
            data_dir=self.instance_dir(login), pid=proc.pid, proc=proc,
            started_at=time.time(),
        )

        # Give MT5 a moment to read the ini, then scrub the plaintext password.
        self._delayed_scrub(ini)
        return inst

    def _delayed_scrub(self, ini_path: str) -> None:
        # MT5 consumes the ini within a couple of seconds. Remove it best-effort.
        try:
            time.sleep(3)
            if os.path.exists(ini_path):
                os.remove(ini_path)
        except OSError:
            log.warning("Could not remove login ini %s (will retry next cycle)", ini_path)

    def is_alive(self, inst: Instance) -> bool:
        if inst.pid is None:
            return False
        try:
            p = psutil.Process(inst.pid)
            return p.is_running() and p.status() != psutil.STATUS_ZOMBIE \
                and p.name().lower().startswith("terminal")
        except psutil.NoSuchProcess:
            return False

    def stop(self, inst: Instance, timeout: int = 15) -> None:
        if inst.pid is None:
            return
        log.info("Stopping terminal account=%s pid=%s", inst.account_id, inst.pid)
        try:
            p = psutil.Process(inst.pid)
            p.terminate()
            try:
                p.wait(timeout=timeout)
            except psutil.TimeoutExpired:
                p.kill()
        except psutil.NoSuchProcess:
            pass
        inst.pid = None
        inst.proc = None

    def adopt_running(self, login: str) -> int | None:
        """After an agent restart, re-find a terminal already running for this login."""
        exe = os.path.normcase(self.instance_exe(login))
        for p in psutil.process_iter(["pid", "exe"]):
            try:
                if p.info["exe"] and os.path.normcase(p.info["exe"]) == exe:
                    return p.info["pid"]
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
        return None
