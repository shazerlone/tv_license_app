import { Injectable, Logger, OnApplicationBootstrap, OnModuleDestroy } from '@nestjs/common';
import { SweepService } from './sweep.service';

/**
 * Runs the batched consolidation sweep on an interval (default 15 min). Self-
 * contained (no scheduler dependency) and horizontally safe: multiple instances
 * may tick, but the partial unique index on Sweep makes a double-sweep impossible,
 * so at worst instances do a little redundant balance-reading. Inert unless sweep
 * is fully configured (SweepService.enabled).
 */
@Injectable()
export class SweepScheduler implements OnApplicationBootstrap, OnModuleDestroy {
  private readonly logger = new Logger('SweepScheduler');
  private timer?: NodeJS.Timeout;
  private running = false;

  constructor(private readonly sweep: SweepService) {}

  private intervalMs(): number {
    const n = Number(process.env.SWEEP_BATCH_INTERVAL_MS ?? 15 * 60_000);
    return Number.isFinite(n) && n >= 30_000 ? n : 15 * 60_000; // floor 30s
  }

  onApplicationBootstrap(): void {
    if (process.env.SWEEP_ENABLED !== 'true' || this.sweep.mode !== 'batch') return;
    const ms = this.intervalMs();
    // Small random initial delay so instances don't all fire on the same tick.
    const jitter = Math.floor(Math.random() * Math.min(ms, 30_000));
    this.timer = setInterval(() => void this.tick(), ms);
    setTimeout(() => void this.tick(), jitter);
    this.logger.log(`batch sweep scheduler armed (every ${Math.round(ms / 1000)}s)`);
  }

  private async tick(): Promise<void> {
    if (this.running || !this.sweep.enabled) return;
    this.running = true;
    try {
      const r = await this.sweep.sweepBatch();
      if (r.swept > 0) this.logger.log(`batch sweep: ${r.swept}/${r.scanned} address(es) swept`);
    } catch (e) {
      this.logger.warn(`batch sweep tick failed: ${String(e)}`);
    } finally {
      this.running = false;
    }
  }

  onModuleDestroy(): void {
    if (this.timer) clearInterval(this.timer);
  }
}
