import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, PostType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { TradersService } from '../traders/traders.service';
import { genId } from '../common/ids';
import { PostDto, CommentDto, CreatePostDto, LikesDto } from './dto/post.dto';
import { ReelDto } from '../traders/dto/trader.dto';
import { seedFromString } from '../common/rng';

/** Prisma include that carries everything needed to serialize a Post for a user. */
function postInclude(userId: string) {
  return {
    trader: true,
    _count: { select: { likes: true, comments: true } },
    likes: { where: { userId }, select: { userId: true } },
    saves: { where: { userId }, select: { userId: true } },
  } satisfies Prisma.PostInclude;
}
type PostWithMeta = Prisma.PostGetPayload<{ include: ReturnType<typeof postInclude> }>;

@Injectable()
export class PostsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly traders: TradersService,
  ) {}

  toDto(p: PostWithMeta): PostDto {
    return {
      id: p.id,
      trader: this.traders.toDto(p.trader),
      type: p.type,
      content: p.content,
      pair: p.pair,
      title: p.title,
      points: p.points,
      likes: p._count.likes,
      comments: p._count.comments,
      createdAt: p.createdAt.toISOString(),
      isLiked: p.likes.length > 0,
      saved: p.saves.length > 0,
    };
  }

  async listByTrader(traderId: string, userId: string): Promise<PostDto[]> {
    await this.traders.getEntityOrThrow(traderId);
    const posts = await this.prisma.post.findMany({
      where: { traderId },
      orderBy: { createdAt: 'desc' },
      include: postInclude(userId),
    });
    return posts.map((p) => this.toDto(p));
  }

  async feed(userId: string): Promise<PostDto[]> {
    const subs = await this.prisma.subscription.findMany({
      where: { userId },
      select: { traderId: true },
    });
    const traderIds = subs.map((s) => s.traderId);
    if (traderIds.length === 0) return [];
    const posts = await this.prisma.post.findMany({
      where: { traderId: { in: traderIds } },
      orderBy: { createdAt: 'desc' },
      include: postInclude(userId),
      take: 100,
    });
    return posts.map((p) => this.toDto(p));
  }

  async saved(userId: string): Promise<PostDto[]> {
    const rows = await this.prisma.postSave.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      include: { post: { include: postInclude(userId) } },
    });
    return rows.map((r) => this.toDto(r.post));
  }

  async like(userId: string, postId: string): Promise<LikesDto> {
    await this.getPostOrThrow(postId);
    await this.prisma.postLike.upsert({
      where: { userId_postId: { userId, postId } },
      update: {},
      create: { userId, postId },
    });
    return { likes: await this.prisma.postLike.count({ where: { postId } }) };
  }

  async unlike(userId: string, postId: string): Promise<LikesDto> {
    await this.getPostOrThrow(postId);
    await this.prisma.postLike.deleteMany({ where: { userId, postId } });
    return { likes: await this.prisma.postLike.count({ where: { postId } }) };
  }

  async save(userId: string, postId: string): Promise<void> {
    await this.getPostOrThrow(postId);
    await this.prisma.postSave.upsert({
      where: { userId_postId: { userId, postId } },
      update: {},
      create: { userId, postId },
    });
  }

  async unsave(userId: string, postId: string): Promise<void> {
    await this.prisma.postSave.deleteMany({ where: { userId, postId } });
  }

  async comments(postId: string, userId: string): Promise<CommentDto[]> {
    await this.getPostOrThrow(postId);
    const rows = await this.prisma.comment.findMany({
      where: { postId },
      orderBy: { createdAt: 'asc' },
      include: { user: { select: { id: true, name: true, username: true } } },
    });
    return rows.map((c) => ({
      id: c.id,
      author: c.user.name,
      username: c.user.username,
      text: c.text,
      createdAt: c.createdAt.toISOString(),
      byMe: c.userId === userId,
    }));
  }

  async addComment(userId: string, postId: string, text: string): Promise<CommentDto> {
    await this.getPostOrThrow(postId);
    const c = await this.prisma.comment.create({
      data: { id: genId('c'), postId, userId, text },
      include: { user: { select: { id: true, name: true, username: true } } },
    });
    return {
      id: c.id,
      author: c.user.name,
      username: c.user.username,
      text: c.text,
      createdAt: c.createdAt.toISOString(),
      byMe: true,
    };
  }

  /** Discover reels — a mixed live/trade/lesson feed (contract §4.4). */
  async reels(userId: string): Promise<ReelDto[]> {
    const [live, contentPosts] = await Promise.all([
      this.prisma.trader.findMany({ where: { isLive: true }, orderBy: { copiers: 'desc' } }),
      this.prisma.post.findMany({
        where: { type: { in: ['trade', 'lesson'] } },
        orderBy: { createdAt: 'desc' },
        include: postInclude(userId),
        take: 20,
      }),
    ]);

    const reels: ReelDto[] = [];
    for (const t of live) {
      reels.push({
        kind: 'live',
        trader: this.traders.toDto(t),
        viewers: 40 + (seedFromString(`${t.id}:viewers`) % 4000),
      });
    }
    for (const p of contentPosts) {
      const dto = this.toDto(p);
      reels.push({
        kind: p.type === 'lesson' ? 'lesson' : 'trade',
        trader: dto.trader,
        post: dto,
        title: p.title,
        points: p.points,
      });
    }
    return reels;
  }

  /** Compose a post (contract §4.6). Ensures the author has a trader profile. */
  async compose(userId: string, dto: CreatePostDto): Promise<PostDto> {
    const trader = await this.traders.ensureForUser(userId);
    const post = await this.prisma.post.create({
      data: {
        id: genId('p'),
        traderId: trader.id,
        type: dto.type as PostType,
        content: dto.content,
        pair: dto.pair,
        title: dto.title,
        points: dto.points ?? [],
      },
      include: postInclude(userId),
    });
    return this.toDto(post);
  }

  private async getPostOrThrow(postId: string) {
    const p = await this.prisma.post.findUnique({ where: { id: postId }, select: { id: true } });
    if (!p) throw new NotFoundException({ code: 'post_not_found', message: 'Post not found' });
    return p;
  }
}
