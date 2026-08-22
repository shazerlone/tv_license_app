import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { AuthUser } from '../common/decorators/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';

export interface JwtPayload {
  sub: string; // userId
  role: 'follower' | 'creator' | 'admin';
}

/** Only touch lastSeenAt at most this often per user (keeps writes cheap). */
const SEEN_THROTTLE_MS = 10 * 60 * 1000;

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  // Per-instance throttle so we don't write lastSeenAt on every request.
  private readonly lastTouch = new Map<string, number>();

  constructor(
    config: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.get<string>('JWT_SECRET', 'dev-secret'),
    });
  }

  async validate(payload: JwtPayload): Promise<AuthUser> {
    this.touchLastSeen(payload.sub);
    return { userId: payload.sub, role: payload.role };
  }

  /**
   * Record activity for DAU/MAU without adding a write to the hot path: throttled
   * in-memory per instance, fired-and-forgotten, and failure-tolerant.
   */
  private touchLastSeen(userId: string): void {
    const now = Date.now();
    const last = this.lastTouch.get(userId) ?? 0;
    if (now - last < SEEN_THROTTLE_MS) return;
    this.lastTouch.set(userId, now);
    void this.prisma.user
      .updateMany({ where: { id: userId }, data: { lastSeenAt: new Date() } })
      .catch(() => undefined);
  }
}
