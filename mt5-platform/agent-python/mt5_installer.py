"""Automatic MetaTrader 5 acquisition for a bare Windows VPS.

The operator's VPS may have NO MetaTrader installed. This module downloads the
MT5 setup and installs it silently the first time it's needed, so the whole
"add account on the web → terminal appears" flow requires zero manual MT5 setup.

Broker note
-----------
`mt5setup.exe /auto` installs the terminal silently. The generic MetaQuotes
build can connect to many brokers' servers by name; some brokers require their
own build. Configure a per-broker installer URL in config.yaml
(`mt5.installer_urls`) when a broker needs its branded terminal; otherwise the
default MetaQuotes URL is used.
"""
from __future__ import annotations

import glob
import logging
import os
import subprocess
import time

import requests

log = logging.getLogger("agent.installer")

DEFAULT_INSTALLER_URL = "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"


class Mt5Installer:
    def __init__(self, terminal_exe: str, download_dir: str,
                 installer_url: str | None = None,
                 installer_urls: dict[str, str] | None = None,
                 install_timeout: int = 300):
        self.terminal_exe = terminal_exe
        self.download_dir = download_dir
        self.installer_url = installer_url or DEFAULT_INSTALLER_URL
        self.installer_urls = installer_urls or {}   # broker_server -> url
        self.install_timeout = install_timeout
        os.makedirs(download_dir, exist_ok=True)

    def base_installed(self) -> bool:
        return os.path.isfile(self.terminal_exe)

    def ensure_base_install(self, broker_server: str | None = None) -> str:
        """Guarantee a base MT5 install exists; download + silent-install if not.

        Returns the resolved path to the base terminal64.exe.
        """
        if self.base_installed():
            return self.terminal_exe

        url = self.installer_urls.get(broker_server or "", self.installer_url)
        setup_path = os.path.join(self.download_dir, "mt5setup.exe")

        if not os.path.isfile(setup_path):
            self._download(url, setup_path)
        else:
            log.info("Reusing cached installer %s", setup_path)

        self._silent_install(setup_path)

        resolved = self._resolve_terminal_exe()
        if not resolved:
            raise RuntimeError("MT5 silent install finished but terminal64.exe not found")
        self.terminal_exe = resolved
        log.info("MT5 base install ready at %s", resolved)
        return resolved

    # ── internals ────────────────────────────────────────────────────────────
    def _download(self, url: str, dest: str) -> None:
        log.info("Downloading MT5 installer from %s", url)
        with requests.get(url, stream=True, timeout=120) as r:
            r.raise_for_status()
            tmp = dest + ".part"
            with open(tmp, "wb") as f:
                for chunk in r.iter_content(chunk_size=1 << 16):
                    f.write(chunk)
            os.replace(tmp, dest)
        log.info("Installer saved to %s (%d bytes)", dest, os.path.getsize(dest))

    def _silent_install(self, setup_path: str) -> None:
        log.info("Running silent MT5 install (%s /auto)", setup_path)
        # /auto = unattended install to the default Program Files location.
        subprocess.run([setup_path, "/auto"], check=False)
        # Setup returns before the terminal folder is fully populated; poll.
        deadline = time.time() + self.install_timeout
        while time.time() < deadline:
            if self._resolve_terminal_exe():
                return
            time.sleep(3)
        log.warning("Timed out waiting for terminal64.exe after install")

    def _resolve_terminal_exe(self) -> str | None:
        """Find terminal64.exe at the configured path, else search Program Files."""
        if os.path.isfile(self.terminal_exe):
            return self.terminal_exe
        for root in (os.environ.get("ProgramFiles", r"C:\Program Files"),
                     os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")):
            if not root:
                continue
            hits = glob.glob(os.path.join(root, "*MetaTrader*", "terminal64.exe")) \
                + glob.glob(os.path.join(root, "*MT5*", "terminal64.exe"))
            if hits:
                return hits[0]
        return None
