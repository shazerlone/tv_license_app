"""Host and per-process resource sampling via psutil."""
from __future__ import annotations

import psutil


def host_metrics() -> dict:
    """Snapshot of the whole VPS."""
    vm = psutil.virtual_memory()
    try:
        disk = psutil.disk_usage("C:\\")
        disk_free_mb = int(disk.free / (1024 * 1024))
    except Exception:
        disk_free_mb = None

    # psutil.getloadavg() exists on Windows in recent psutil (emulated).
    try:
        load1 = round(psutil.getloadavg()[0], 2)
    except (AttributeError, OSError):
        load1 = None

    return {
        "cpu_pct": round(psutil.cpu_percent(interval=0.5), 2),
        "ram_used_mb": int((vm.total - vm.available) / (1024 * 1024)),
        "ram_total_mb": int(vm.total / (1024 * 1024)),
        "cpu_cores": psutil.cpu_count(logical=True),
        "disk_free_mb": disk_free_mb,
        "load_avg": load1,
    }


def process_metrics(pid: int) -> dict | None:
    """CPU% (of a single core baseline) and RAM for one PID, or None if gone."""
    try:
        p = psutil.Process(pid)
        with p.oneshot():
            if not p.is_running() or p.status() == psutil.STATUS_ZOMBIE:
                return None
            # cpu_percent needs two reads; the agent primes it once at launch.
            cpu = p.cpu_percent(interval=None)
            rss_mb = int(p.memory_info().rss / (1024 * 1024))
        return {"cpu_pct": round(cpu, 2), "ram_mb": rss_mb}
    except (psutil.NoSuchProcess, psutil.AccessDenied):
        return None


def prime_cpu(pid: int) -> None:
    """First cpu_percent() call returns 0.0; call it once so later reads are real."""
    try:
        psutil.Process(pid).cpu_percent(interval=None)
    except psutil.Error:
        pass
