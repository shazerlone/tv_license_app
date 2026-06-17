"""Live MetaTrader 4 client (file bridge).

MT4 has no official API, so trading goes through an Expert Advisor that runs
inside each MT4 terminal: ``ea/CopyTraderBridge.mq4``. The EA and this client
exchange JSON files inside the terminal's ``MQL4/Files`` folder:

  * ``ct_status.json``           - EA writes account info + open orders (live)
  * ``ct_cmd_<id>.json``         - this client writes a command (OPEN/CLOSE)
  * ``ct_res_<id>.json``         - EA writes the command result, deletes the cmd

The account's ``mt4_files_path`` must point at that ``MQL4/Files`` folder
(see README for how to find it via "Open Data Folder" in MT4).
"""
from __future__ import annotations

import json
import os
import time
import uuid

from .clients import BrokerClient
from .types import AccountInfo, CloseResult, OpenResult, OrderRequest, Position, Side

STATUS_FILE = "ct_status.json"
STATUS_MAX_AGE = 10.0   # seconds; older => terminal considered offline
CMD_TIMEOUT = 8.0       # seconds to wait for the EA to answer a command


class Mt4Client(BrokerClient):
    def __init__(self, account):
        self.account = account
        self.files_dir = getattr(account, "mt4_files_path", "") or os.path.join(
            account.terminal_path or "", "MQL4", "Files"
        )
        self._ok = False

    # -- helpers ------------------------------------------------------------ #
    def _status(self) -> dict | None:
        path = os.path.join(self.files_dir, STATUS_FILE)
        try:
            if time.time() - os.path.getmtime(path) > STATUS_MAX_AGE:
                return None  # stale -> EA not running / terminal closed
            with open(path, "r", encoding="utf-8") as fh:
                return json.load(fh)
        except (OSError, ValueError):
            return None

    def _run_command(self, payload: dict) -> dict:
        cmd_id = uuid.uuid4().hex[:12]
        cmd_path = os.path.join(self.files_dir, f"ct_cmd_{cmd_id}.json")
        res_path = os.path.join(self.files_dir, f"ct_res_{cmd_id}.json")
        try:
            with open(cmd_path, "w", encoding="utf-8") as fh:
                json.dump(payload, fh)
        except OSError as exc:
            return {"ok": False, "error": f"cannot write command: {exc}"}

        deadline = time.time() + CMD_TIMEOUT
        while time.time() < deadline:
            if os.path.exists(res_path):
                try:
                    with open(res_path, "r", encoding="utf-8") as fh:
                        result = json.load(fh)
                    os.remove(res_path)
                    return result
                except (OSError, ValueError):
                    break
            time.sleep(0.1)
        # timed out: clean up our command file if the EA never consumed it
        try:
            os.remove(cmd_path)
        except OSError:
            pass
        return {"ok": False, "error": "EA did not respond (timeout)"}

    # -- BrokerClient ------------------------------------------------------- #
    def connect(self) -> bool:
        self._ok = self._status() is not None
        return self._ok

    def disconnect(self) -> None:
        self._ok = False

    def is_connected(self) -> bool:
        return self._status() is not None

    def account_info(self) -> AccountInfo:
        st = self._status() or {}
        return AccountInfo(
            login=str(st.get("login", self.account.login)),
            balance=float(st.get("balance", 0.0)),
            equity=float(st.get("equity", 0.0)),
            currency=st.get("currency", "USD"),
            leverage=int(st.get("leverage", 0)),
        )

    def positions(self) -> list[Position]:
        st = self._status() or {}
        out = []
        for o in st.get("orders", []):
            try:
                side = Side.BUY if str(o.get("type")).upper() == "BUY" else Side.SELL
                out.append(Position(
                    ticket=int(o["ticket"]), symbol=str(o["symbol"]), side=side,
                    volume=float(o["lots"]), price_open=float(o.get("open_price", 0.0)),
                    sl=float(o.get("sl", 0.0)), tp=float(o.get("tp", 0.0)),
                    comment=str(o.get("comment", "")),
                ))
            except (KeyError, ValueError, TypeError):
                continue
        return out

    def symbols(self) -> list[str]:
        st = self._status() or {}
        return list(st.get("symbols", []))

    def open_market(self, req: OrderRequest) -> OpenResult:
        res = self._run_command({
            "action": "OPEN", "symbol": req.symbol, "side": req.side.value,
            "volume": req.volume, "sl": req.sl, "tp": req.tp,
            "comment": req.comment,
        })
        if res.get("ok"):
            return OpenResult(ok=True, ticket=int(res.get("ticket", 0)))
        return OpenResult(ok=False, error=res.get("error", "open failed"))

    def close(self, ticket: int, volume: float = 0.0) -> CloseResult:
        res = self._run_command({"action": "CLOSE", "ticket": ticket, "volume": volume})
        return CloseResult(ok=bool(res.get("ok")), error=res.get("error", ""))
