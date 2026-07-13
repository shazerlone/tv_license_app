"""Thin, resilient HTTP client for the Laravel Agent API.

All calls are authenticated with the per-VPS bearer token and go over HTTPS.
Network errors are retried with exponential backoff so a brief control-plane
blip never crashes the agent.
"""
from __future__ import annotations

import logging
import time
from typing import Any

import requests

log = logging.getLogger("agent.api")


class ApiClient:
    def __init__(self, base_url: str, token: str, *, verify_tls: bool | str = True,
                 timeout: int = 20, max_retries: int = 4):
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.max_retries = max_retries
        self.session = requests.Session()
        self.session.headers.update({
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        })
        self.session.verify = verify_tls

    # ── public endpoints ────────────────────────────────────────────────────
    def get_assignments(self) -> dict[str, Any]:
        """Desired state for this VPS (accounts + per-account action + creds)."""
        return self._request("GET", "/agent/assignments")

    def send_heartbeat(self, payload: dict[str, Any]) -> dict[str, Any]:
        """Push host + per-terminal metrics."""
        return self._request("POST", "/agent/heartbeat", json=payload)

    def send_events(self, events: list[dict[str, Any]]) -> list[str]:
        """Push buffered events; returns the list of accepted event_uids."""
        resp = self._request("POST", "/agent/events", json={"events": events})
        return resp.get("accepted", [])

    # ── internals ───────────────────────────────────────────────────────────
    def _request(self, method: str, path: str, **kwargs) -> dict[str, Any]:
        url = f"{self.base_url}{path}"
        delay = 2
        last_exc: Exception | None = None

        for attempt in range(1, self.max_retries + 1):
            try:
                r = self.session.request(method, url, timeout=self.timeout, **kwargs)
                if r.status_code == 401:
                    raise PermissionError("Agent token rejected (401) — check config.yaml")
                if r.status_code == 403:
                    raise PermissionError("Server disabled or forbidden (403)")
                if r.status_code >= 500:
                    raise requests.HTTPError(f"server {r.status_code}")
                r.raise_for_status()
                return r.json() if r.content else {}
            except PermissionError:
                raise  # not retryable — auth problem
            except (requests.ConnectionError, requests.Timeout, requests.HTTPError) as exc:
                last_exc = exc
                if attempt == self.max_retries:
                    break
                log.warning("API %s %s failed (attempt %d/%d): %s — retrying in %ds",
                            method, path, attempt, self.max_retries, exc, delay)
                time.sleep(delay)
                delay *= 2

        raise ConnectionError(f"API {method} {path} failed after {self.max_retries} attempts: {last_exc}")
