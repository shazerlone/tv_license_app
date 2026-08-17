import { Module } from '@nestjs/common';
import { PostsService } from './posts.service';
import { PostsController } from './posts.controller';
import { FeedController } from './feed.controller';
import { DiscoverController } from './discover.controller';
import { TradersModule } from '../traders/traders.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [TradersModule, NotificationsModule],
  providers: [PostsService],
  controllers: [PostsController, FeedController, DiscoverController],
  exports: [PostsService],
})
export class PostsModule {}
