import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { PostsService } from './posts.service';
import { ReelDto } from '../traders/dto/trader.dto';

@ApiTags('discover')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller('discover')
export class DiscoverController {
  constructor(private readonly posts: PostsService) {}

  @Get('reels')
  @ApiOperation({ summary: 'Mixed live/trade/lesson reels feed (contract §4.4)' })
  @ApiOkResponse({ type: [ReelDto] })
  reels(@CurrentUser() u: AuthUser): Promise<ReelDto[]> {
    return this.posts.reels(u.userId);
  }
}
