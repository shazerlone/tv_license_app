import { Global, Injectable, Module } from '@nestjs/common';
import { EventEmitter } from 'events';

/**
 * Decouples event producers (copy engine, broadcasts, notifications) from the
 * WebSocket gateway. Services call `emitUser` / `emitBroadcast`; the gateway
 * subscribes and fans out to sockets. Swap this for Redis pub/sub to go
 * multi-instance without touching producers (see ARCHITECTURE.md).
 */
@Injectable()
export class RealtimeBus extends EventEmitter {
  /** Deliver `payload` (e.g. { ch:'user', type, data }) to a specific user. */
  emitUser(userId: string, payload: unknown) {
    this.emit('user', { userId, payload });
  }

  /** Deliver to everyone watching a broadcast channel. */
  emitBroadcast(broadcastId: string, payload: unknown) {
    this.emit('broadcast', { broadcastId, payload });
  }
}

@Global()
@Module({
  providers: [RealtimeBus],
  exports: [RealtimeBus],
})
export class RealtimeBusModule {}
