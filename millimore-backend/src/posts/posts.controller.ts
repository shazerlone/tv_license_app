import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiCreatedResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { PostsService } from './posts.service';
import {
  PostDto,
  CommentDto,
  CreatePostDto,
  CreateCommentDto,
  LikesDto,
} from './dto/post.dto';

@ApiTags('posts')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller('posts')
export class PostsController {
  constructor(private readonly posts: PostsService) {}

  @Post()
  @ApiOperation({ summary: 'Compose a post (contract §4.6)' })
  @ApiCreatedResponse({ type: PostDto })
  compose(@CurrentUser() u: AuthUser, @Body() dto: CreatePostDto): Promise<PostDto> {
    return this.posts.compose(u.userId, dto);
  }

  @Post(':id/like')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Like a post (contract §4.5)' })
  @ApiOkResponse({ type: LikesDto })
  like(@CurrentUser() u: AuthUser, @Param('id') id: string): Promise<LikesDto> {
    return this.posts.like(u.userId, id);
  }

  @Delete(':id/like')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Unlike a post (contract §4.5)' })
  @ApiOkResponse({ type: LikesDto })
  unlike(@CurrentUser() u: AuthUser, @Param('id') id: string): Promise<LikesDto> {
    return this.posts.unlike(u.userId, id);
  }

  @Post(':id/save')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Save a post (contract §4.5)' })
  async save(@CurrentUser() u: AuthUser, @Param('id') id: string): Promise<void> {
    await this.posts.save(u.userId, id);
  }

  @Delete(':id/save')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Unsave a post (contract §4.5)' })
  async unsave(@CurrentUser() u: AuthUser, @Param('id') id: string): Promise<void> {
    await this.posts.unsave(u.userId, id);
  }

  @Get(':id/comments')
  @ApiOperation({ summary: 'List comments on a post (contract §4.5)' })
  @ApiOkResponse({ type: [CommentDto] })
  comments(@CurrentUser() u: AuthUser, @Param('id') id: string): Promise<CommentDto[]> {
    return this.posts.comments(id, u.userId);
  }

  @Post(':id/comments')
  @ApiOperation({ summary: 'Add a comment (contract §4.5)' })
  @ApiCreatedResponse({ type: CommentDto })
  addComment(
    @CurrentUser() u: AuthUser,
    @Param('id') id: string,
    @Body() dto: CreateCommentDto,
  ): Promise<CommentDto> {
    return this.posts.addComment(u.userId, id, dto.text);
  }
}
