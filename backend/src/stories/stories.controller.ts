import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { StoriesService } from './stories.service';
import { CreateStoryDto, StoryDto, StoryGroupDto } from './dto/story.dto';

@ApiTags('stories')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller('stories')
export class StoriesController {
  constructor(private readonly stories: StoriesService) {}

  @Post()
  @ApiOperation({ summary: 'Post a 24h story (image/video, or a live recap card)' })
  @ApiOkResponse({ type: StoryDto })
  create(@CurrentUser() u: AuthUser, @Body() dto: CreateStoryDto): Promise<StoryDto> {
    return this.stories.create(u.userId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'Active stories from people I follow (+ my own), grouped by creator' })
  @ApiOkResponse({ type: [StoryGroupDto] })
  feed(@CurrentUser() u: AuthUser): Promise<StoryGroupDto[]> {
    return this.stories.feed(u.userId);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get a single story' })
  @ApiOkResponse({ type: StoryDto })
  getOne(@CurrentUser() u: AuthUser, @Param('id') id: string): Promise<StoryDto> {
    return this.stories.getOne(id, u.userId);
  }

  @Post(':id/view')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Mark a story viewed (idempotent)' })
  view(@CurrentUser() u: AuthUser, @Param('id') id: string) {
    return this.stories.view(id, u.userId);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Delete your own story' })
  remove(@CurrentUser() u: AuthUser, @Param('id') id: string) {
    return this.stories.remove(id, u.userId);
  }
}
