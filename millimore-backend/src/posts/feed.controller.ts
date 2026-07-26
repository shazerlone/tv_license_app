import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { PostsService } from './posts.service';
import { PostDto } from './dto/post.dto';

/** Feed-style reads that don't live under /posts (contract §4.4, §4.5). */
@ApiTags('feed')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller()
export class FeedController {
  constructor(private readonly posts: PostsService) {}

  @Get('feed')
  @ApiOperation({ summary: 'Posts from traders I subscribe to (contract §4.5)' })
  @ApiOkResponse({ type: [PostDto] })
  feed(@CurrentUser() u: AuthUser): Promise<PostDto[]> {
    return this.posts.feed(u.userId);
  }

  @Get('saved')
  @ApiOperation({ summary: 'Posts I saved (contract §4.5)' })
  @ApiOkResponse({ type: [PostDto] })
  saved(@CurrentUser() u: AuthUser): Promise<PostDto[]> {
    return this.posts.saved(u.userId);
  }

  @Get('traders/:id/posts')
  @ApiOperation({ summary: "A trader's posts (contract §4.4)" })
  @ApiOkResponse({ type: [PostDto] })
  traderPosts(@CurrentUser() u: AuthUser, @Param('id') id: string): Promise<PostDto[]> {
    return this.posts.listByTrader(id, u.userId);
  }
}
