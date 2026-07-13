"""Restart policy for crashed terminals.

Tracks per-account restart history and answers one question for the supervisor:
"this terminal is down — may I restart it now?" It enforces exponential backoff
between restarts and a rolling-hour circuit breaker so a terminal that keeps
crashing (bad credentials, broker outage) stops thrashing the box and is
surfaced as ``errored`` for a human.
"""
from __future__ import annotations

import logging
import time
from collections import deque
from dataclasses import dataclass, field

log = logging.getLogger("agent.watchdog")


@dataclass
class _State:
    consecutive_failures: int = 0
    next_allowed_at: float = 0.0
    restart_times: deque = field(default_factory=deque)  # unix ts of recent restarts
    tripped: bool = False                                 # circuit breaker open


class Watchdog:
    def __init__(self, base_seconds: int = 5, max_seconds: int = 300,
                 max_restarts_per_hour: int = 6):
        self.base = base_seconds
        self.max = max_seconds
        self.max_per_hour = max_restarts_per_hour
        self._states: dict[int, _State] = {}

    def _state(self, account_id: int) -> _State:
        return self._states.setdefault(account_id, _State())

    def should_restart(self, account_id: int) -> tuple[bool, str]:
        """(may_restart, reason). Call when a terminal is found dead."""
        st = self._state(account_id)
        now = time.time()

        # Drop restarts older than an hour from the rolling window.
        cutoff = now - 3600
        while st.restart_times and st.restart_times[0] < cutoff:
            st.restart_times.popleft()

        if len(st.restart_times) >= self.max_per_hour:
            if not st.tripped:
                st.tripped = True
                log.error("Account %s circuit breaker OPEN (%d restarts/hour)",
                          account_id, len(st.restart_times))
            return False, "circuit_breaker_open"

        if now < st.next_allowed_at:
            return False, "backoff"

        return True, "ok"

    def record_restart(self, account_id: int) -> None:
        """Call right after a restart is issued."""
        st = self._state(account_id)
        now = time.time()
        st.consecutive_failures += 1
        st.restart_times.append(now)
        delay = min(self.max, self.base * (2 ** (st.consecutive_failures - 1)))
        st.next_allowed_at = now + delay
        log.warning("Account %s restarted (#%d); next restart allowed in %ds",
                    account_id, st.consecutive_failures, delay)

    def record_healthy(self, account_id: int) -> None:
        """Terminal is up and connected — reset the failure counters."""
        st = self._states.get(account_id)
        if st and (st.consecutive_failures or st.tripped):
            log.info("Account %s recovered — resetting watchdog state", account_id)
        self._states[account_id] = _State()

    def is_tripped(self, account_id: int) -> bool:
        return self._state(account_id).tripped

    def forget(self, account_id: int) -> None:
        self._states.pop(account_id, None)
