import { Global, Injectable, Module, OnModuleInit } from '@nestjs/common';
import { EventEmitter } from 'events';
import { RedisService } from '../redis/redis.service';

const CH_USER = 'rt:user';
const CH_BROADCAST = 'rt:broadcast';
const CH_CHANNEL = 'rt:channel';

/**
 * Decouples event producers (copy engine, broadcasts, notifications) from the
 * WebSocket gateway. Producers call `emitUser` / `emitBroadcast`; the gateway
 * subscribes to the local `user` / `broadcast` events.
 *
 * With Redis enabled, emits are published to Redis so EVERY instance re-emits
 * locally and fans out to its own sockets — a user connected to any instance
 * receives the event. Without Redis it's a plain in-process emitter.
 */
@Injectable()
export class RealtimeBus extends EventEmitter implements OnModuleInit {
  constructor(private readonly redis: RedisService) {
    super();
  }

  async onModuleInit() {
    if (!this.redis.enabled) return;
    await this.redis.subscribe(CH_USER, ({ userId, payload }) =>
      super.emit('user', { userId, payload }),
    );
    await this.redis.subscribe(CH_BROADCAST, ({ broadcastId, payload }) =>
      super.emit('broadcast', { broadcastId, payload }),
    );
    await this.redis.subscribe(CH_CHANNEL, ({ channel, payload }) =>
      super.emit('channel', { channel, payload }),
    );
  }

  emitUser(userId: string, payload: unknown) {
    if (this.redis.enabled) void this.redis.publish(CH_USER, { userId, payload });
    else super.emit('user', { userId, payload });
  }

  emitBroadcast(broadcastId: string, payload: unknown) {
    if (this.redis.enabled) void this.redis.publish(CH_BROADCAST, { broadcastId, payload });
    else super.emit('broadcast', { broadcastId, payload });
  }

  /** Fan out to subscribers of an exact channel name (e.g. `pair:XAU/USD`). */
  emitChannel(channel: string, payload: unknown) {
    if (this.redis.enabled) void this.redis.publish(CH_CHANNEL, { channel, payload });
    else super.emit('channel', { channel, payload });
  }
}

@Global()
@Module({
  providers: [RealtimeBus],
  exports: [RealtimeBus],
})
export class RealtimeBusModule {}
