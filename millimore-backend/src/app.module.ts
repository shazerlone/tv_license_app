import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ServeStaticModule } from '@nestjs/serve-static';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { APP_GUARD } from '@nestjs/core';
import { existsSync } from 'fs';
import { join } from 'path';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { BrokersModule } from './brokers/brokers.module';
import { AccountsModule } from './accounts/accounts.module';
import { CreatorModule } from './creator/creator.module';
import { AdminModule } from './admin/admin.module';
import { TradersModule } from './traders/traders.module';
import { PostsModule } from './posts/posts.module';
import { SubscriptionsModule } from './subscriptions/subscriptions.module';
import { NotificationsModule } from './notifications/notifications.module';
import { MarketModule } from './market/market.module';
import { CopyModule } from './copy/copy.module';
import { RealtimeModule } from './realtime/realtime.module';
import { RealtimeBusModule } from './realtime/realtime.bus';
import { RedisModule } from './redis/redis.service';
import { UploadsModule } from './uploads/uploads.module';
import { BroadcastsModule } from './broadcasts/broadcasts.module';
import { MtModule } from './mt/mt.module';
import { WalletModule } from './wallet/wallet.module';
import { PayoutsModule } from './payouts/payouts.module';
import { SettingsModule } from './settings/settings.module';
import { AuditModule } from './audit/audit.module';
import { KycModule } from './kyc/kyc.module';
import { ReferralsModule } from './referrals/referrals.module';
import { SupportModule } from './support/support.module';
import { TwofaModule } from './twofa/twofa.module';
import { YoutubeModule } from './youtube/youtube.module';
import { PairsModule } from './pairs/pairs.module';
import { MailModule } from './mail/mail.module';
import { AlertsModule } from './alerts/alerts.module';
import { HealthController } from './health.controller';

// Single-origin: if the admin's static export exists (built into admin/out),
// serve it at `/` from this same service. The API lives under `/v1`, so the
// two never collide. In dev without a built admin, this is simply skipped.
const ADMIN_DIR = join(process.cwd(), 'admin', 'out');
const staticModules = existsSync(ADMIN_DIR)
  ? [
      ServeStaticModule.forRoot({
        rootPath: ADMIN_DIR,
        // Keep the API namespace off the static/SPA-fallback handler so unknown
        // /v1 routes return the JSON 404 envelope, not index.html.
        exclude: ['/v1', '/v1/(.*)'],
        serveStaticOptions: { index: 'index.html', extensions: ['html'] },
      }),
    ]
  : [];

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    // Global rate limit (per IP, per instance). Sensitive auth routes tighten
    // this further with @Throttle. Behind an ALB, main.ts sets 'trust proxy' so
    // the real client IP is used.
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 200 }]),
    RedisModule,
    RealtimeBusModule,
    PrismaModule,
    AuthModule,
    UsersModule,
    BrokersModule,
    AccountsModule,
    CreatorModule,
    AdminModule,
    TradersModule,
    PostsModule,
    SubscriptionsModule,
    NotificationsModule,
    MarketModule,
    SettingsModule,
    AuditModule,
    MtModule,
    WalletModule,
    PayoutsModule,
    KycModule,
    ReferralsModule,
    SupportModule,
    TwofaModule,
    YoutubeModule,
    PairsModule,
    MailModule,
    AlertsModule,
    CopyModule,
    RealtimeModule,
    UploadsModule,
    BroadcastsModule,
    ...staticModules,
  ],
  controllers: [HealthController],
  providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }],
})
export class AppModule {}
