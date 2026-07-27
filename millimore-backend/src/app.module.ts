import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ServeStaticModule } from '@nestjs/serve-static';
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
    CopyModule,
    RealtimeModule,
    ...staticModules,
  ],
  controllers: [HealthController],
})
export class AppModule {}
