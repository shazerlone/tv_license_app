import { Global, Injectable, Logger, Module, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

/**
 * Redis pub/sub + leader-lock — the layer that makes the API safe to run as
 * MANY instances behind a load balancer (AWS ECS/Fargate autoscaling).
 *
 * - Realtime events (RealtimeBus) publish here so a user's socket on ANY
 *   instance receives them.
 * - The price engine elects a single leader (via a lock) to generate ticks and
 *   publishes them so every instance shows identical prices.
 *
 * If REDIS_URL is unset the whole thing no-ops and the app runs single-instance
 * (local dev / a single Fargate task) exactly as before.
 */
@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger('RedisService');
  private readonly url?: string;
  private pub?: Redis;
  private sub?: Redis;
  private readonly handlers = new Map<string, (msg: string) => void>();

  constructor(config: ConfigService) {
    this.url = config.get<string>('REDIS_URL') || undefined;
  }

  get enabled(): boolean {
    return !!this.pub;
  }

  onModuleInit() {
    if (!this.url) {
      this.logger.log('REDIS_URL not set — running single-instance (no cross-node fan-out).');
      return;
    }
    const opts = { maxRetriesPerRequest: null as null, lazyConnect: false };
    this.pub = new Redis(this.url, opts);
    this.sub = new Redis(this.url, opts);
    this.pub.on('error', (e) => this.logger.warn(`redis pub: ${e.message}`));
    this.sub.on('error', (e) => this.logger.warn(`redis sub: ${e.message}`));
    this.sub.on('message', (channel, msg) => this.handlers.get(channel)?.(msg));
    this.logger.log('Redis connected — multi-instance pub/sub enabled.');
  }

  async publish(channel: string, payload: unknown): Promise<void> {
    if (this.pub) await this.pub.publish(channel, JSON.stringify(payload));
  }

  async get(key: string): Promise<string | null> {
    return this.pub ? this.pub.get(key) : null;
  }

  async set(key: string, value: string): Promise<void> {
    if (this.pub) await this.pub.set(key, value);
  }

  async subscribe(channel: string, handler: (parsed: any) => void): Promise<void> {
    if (!this.sub) return;
    this.handlers.set(channel, (msg) => {
      try {
        handler(JSON.parse(msg));
      } catch {
        /* ignore malformed */
      }
    });
    await this.sub.subscribe(channel);
  }

  /**
   * Cooperative leader lock. Returns true if this instance holds `key` for the
   * next `ttlMs`. The current holder refreshes it; others acquire only if free.
   * No Redis → always leader (single instance).
   */
  async acquireLeader(key: string, id: string, ttlMs: number): Promise<boolean> {
    if (!this.pub) return true;
    const current = await this.pub.get(key);
    if (current === id) {
      await this.pub.pexpire(key, ttlMs);
      return true;
    }
    const ok = await this.pub.set(key, id, 'PX', ttlMs, 'NX');
    return ok === 'OK';
  }

  onModuleDestroy() {
    this.pub?.quit().catch(() => undefined);
    this.sub?.quit().catch(() => undefined);
  }
}

@Global()
@Module({
  providers: [RedisService],
  exports: [RedisService],
})
export class RedisModule {}
