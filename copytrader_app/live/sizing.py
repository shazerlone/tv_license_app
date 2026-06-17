"""Pure lot-sizing logic — no broker dependencies, fully unit-tested.

Given a master trade and a slave's settings, compute the volume the slave
should trade. Kept pure so the maths can be verified without MetaTrader.
"""
from __future__ import annotations

from ..models import LotMode


def compute_slave_volume(
    *,
    lot_mode: LotMode,
    lot_value: float,
    master_volume: float,
    master_balance: float = 0.0,
    slave_balance: float = 0.0,
    master_equity: float = 0.0,
    slave_equity: float = 0.0,
    max_lot: float = 0.0,
    volume_step: float = 0.01,
    min_lot: float = 0.01,
) -> float:
    """Return the slave volume, rounded to the broker's volume step and clamped.

    * MULTIPLIER     -> master_volume * lot_value
    * FIXED          -> lot_value
    * BALANCE_RATIO  -> master_volume * (slave_balance / master_balance) * lot_value
    * EQUITY_RATIO   -> master_volume * (slave_equity / master_equity) * lot_value
    """
    if lot_mode is LotMode.FIXED:
        raw = lot_value
    elif lot_mode is LotMode.MULTIPLIER:
        raw = master_volume * lot_value
    elif lot_mode is LotMode.BALANCE_RATIO:
        ratio = (slave_balance / master_balance) if master_balance > 0 else 0.0
        raw = master_volume * ratio * lot_value
    elif lot_mode is LotMode.EQUITY_RATIO:
        ratio = (slave_equity / master_equity) if master_equity > 0 else 0.0
        raw = master_volume * ratio * lot_value
    else:  # pragma: no cover - exhaustive
        raw = master_volume

    if raw <= 0:
        return 0.0

    # snap down to the nearest valid volume step (e.g. 0.01)
    if volume_step > 0:
        steps = int(round(raw / volume_step))
        raw = steps * volume_step

    raw = round(raw, 8)
    if raw < min_lot:
        raw = min_lot
    if max_lot and raw > max_lot:
        raw = max_lot
    return round(raw, 8)
