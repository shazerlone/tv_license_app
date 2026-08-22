import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { genId } from '../common/ids';
import { CreateStoryDto, StoryDto, StoryGroupDto } from './dto/story.dto';

const STORY_TTL_MS = 24 * 60 * 60 * 1000; // 24h

/** Story fields + just enough of `views` to compute `viewed`. */
type StoryWithViews = Omit<Prisma.StoryGetPayload<object>, never> & { views: { userId: string }[] };

@Injectable()
export class StoriesService {
  constructor(private readonly prisma: PrismaService) {}

  private toDto(s: StoryWithViews, viewerId: string): StoryDto {
    return {
      id: s.id,
      userId: s.userId,
      mediaUrl: s.mediaUrl,
      mediaType: s.mediaType,
      caption: s.caption,
      kind: s.kind,
      broadcastId: s.broadcastId,
      viewed: s.views.some((v) => v.userId === viewerId),
      createdAt: s.createdAt.toISOString(),
      expiresAt: s.expiresAt.toISOString(),
    };
  }

  /** Post a 24h story. `kind=recap` must reference one of the caller's broadcasts. */
  async create(userId: string, dto: CreateStoryDto): Promise<StoryDto> {
    const kind = dto.kind ?? 'normal';
    if (kind === 'recap') {
      if (!dto.broadcastId) throw new BadRequestException({ code: 'broadcast_required', message: 'A recap story needs broadcastId.' });
      const b = await this.prisma.broadcast.findUnique({ where: { id: dto.broadcastId }, select: { creatorId: true } });
      if (!b) throw new NotFoundException({ code: 'broadcast_not_found', message: 'Broadcast not found' });
      if (b.creatorId !== userId) throw new ForbiddenException({ code: 'not_your_broadcast', message: 'You can only recap your own broadcast.' });
    }
    const s = await this.prisma.story.create({
      data: {
        id: genId('st'),
        userId,
        mediaUrl: dto.mediaUrl,
        mediaType: dto.mediaType ?? 'image',
        caption: dto.caption ?? null,
        kind,
        broadcastId: kind === 'recap' ? dto.broadcastId : null,
        expiresAt: new Date(Date.now() + STORY_TTL_MS),
      },
      include: { views: true },
    });
    return this.toDto(s, userId);
  }

  /** Active (non-expired) stories from creators the user follows + their own,
   *  grouped by author. Groups ordered by most recent story; unseen groups first. */
  async feed(userId: string): Promise<StoryGroupDto[]> {
    const subs = await this.prisma.subscription.findMany({
      where: { userId },
      select: { trader: { select: { userId: true } } },
    });
    const authorIds = [...new Set([userId, ...subs.map((s) => s.trader.userId).filter((v): v is string => !!v)])];

    const stories = await this.prisma.story.findMany({
      where: { userId: { in: authorIds }, expiresAt: { gt: new Date() } },
      orderBy: { createdAt: 'asc' },
      include: {
        views: { where: { userId }, select: { userId: true } },
        user: { select: { id: true, name: true, username: true, photoUrl: true } },
      },
    });

    const groups = new Map<string, StoryGroupDto>();
    for (const s of stories) {
      let g = groups.get(s.userId);
      if (!g) {
        g = { user: { id: s.user.id, name: s.user.name, username: s.user.username, photoUrl: s.user.photoUrl }, stories: [], hasUnseen: false };
        groups.set(s.userId, g);
      }
      const viewed = s.views.length > 0;
      g.stories.push(this.toDto(s, userId));
      if (!viewed) g.hasUnseen = true;
    }
    // Own group first, then unseen groups, then by newest story.
    return [...groups.values()].sort((a, b) => {
      if (a.user.id === userId) return -1;
      if (b.user.id === userId) return 1;
      if (a.hasUnseen !== b.hasUnseen) return a.hasUnseen ? -1 : 1;
      const at = a.stories[a.stories.length - 1]?.createdAt ?? '';
      const bt = b.stories[b.stories.length - 1]?.createdAt ?? '';
      return bt.localeCompare(at);
    });
  }

  /** Active stories for one specific author, grouped (for their profile ring).
   *  Returns null when they have no active stories. */
  async userGroup(targetUserId: string, viewerId: string): Promise<StoryGroupDto | null> {
    const stories = await this.prisma.story.findMany({
      where: { userId: targetUserId, expiresAt: { gt: new Date() } },
      orderBy: { createdAt: 'asc' },
      include: {
        views: { where: { userId: viewerId }, select: { userId: true } },
        user: { select: { id: true, name: true, username: true, photoUrl: true } },
      },
    });
    if (stories.length === 0) return null;
    const g: StoryGroupDto = {
      user: {
        id: stories[0].user.id,
        name: stories[0].user.name,
        username: stories[0].user.username,
        photoUrl: stories[0].user.photoUrl,
      },
      stories: [],
      hasUnseen: false,
    };
    for (const s of stories) {
      g.stories.push(this.toDto(s, viewerId));
      if (s.views.length === 0) g.hasUnseen = true;
    }
    return g;
  }

  /** Same as userGroup but keyed by a trader id (resolves trader → user). */
  async traderGroup(traderId: string, viewerId: string): Promise<StoryGroupDto | null> {
    const t = await this.prisma.trader.findUnique({ where: { id: traderId }, select: { userId: true } });
    if (!t?.userId) return null;
    return this.userGroup(t.userId, viewerId);
  }

  async getOne(id: string, userId: string): Promise<StoryDto> {
    const s = await this.prisma.story.findUnique({ where: { id }, include: { views: true } });
    if (!s || s.expiresAt.getTime() < Date.now()) throw new NotFoundException({ code: 'story_not_found', message: 'Story not found or expired' });
    return this.toDto(s, userId);
  }

  /** Record a view (idempotent). Returns the running view count. */
  async view(id: string, userId: string): Promise<{ ok: true; views: number }> {
    const s = await this.prisma.story.findUnique({ where: { id }, select: { id: true } });
    if (!s) throw new NotFoundException({ code: 'story_not_found', message: 'Story not found' });
    await this.prisma.storyView.upsert({
      where: { storyId_userId: { storyId: id, userId } },
      update: {},
      create: { storyId: id, userId },
    });
    const views = await this.prisma.storyView.count({ where: { storyId: id } });
    return { ok: true, views };
  }

  /** Delete your own story. */
  async remove(id: string, userId: string): Promise<{ ok: true }> {
    const s = await this.prisma.story.findUnique({ where: { id }, select: { userId: true } });
    if (!s) throw new NotFoundException({ code: 'story_not_found', message: 'Story not found' });
    if (s.userId !== userId) throw new ForbiddenException({ code: 'not_your_story', message: 'Not your story' });
    await this.prisma.story.delete({ where: { id } });
    return { ok: true };
  }
}
