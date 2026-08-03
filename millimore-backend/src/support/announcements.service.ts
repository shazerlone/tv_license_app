import { Injectable, NotFoundException } from '@nestjs/common';
import { Announcement, AnnouncementAudience, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { genId } from '../common/ids';
import { CreateAnnouncementDto, UpdateAnnouncementDto } from './dto/announcement.dto';

@Injectable()
export class AnnouncementsService {
  constructor(private readonly prisma: PrismaService) {}

  private audienceWhere(role: string): Prisma.AnnouncementWhereInput {
    const audiences: AnnouncementAudience[] = [AnnouncementAudience.all];
    if (role === 'follower') audiences.push(AnnouncementAudience.followers);
    if (role === 'creator') audiences.push(AnnouncementAudience.creators);
    return { audience: { in: audiences } };
  }

  /** Active, in-window, audience-matched announcements + this user's read state. */
  async listForUser(userId: string, role: string) {
    const now = new Date();
    const rows = await this.prisma.announcement.findMany({
      where: {
        active: true,
        ...this.audienceWhere(role),
        AND: [
          { OR: [{ startsAt: null }, { startsAt: { lte: now } }] },
          { OR: [{ endsAt: null }, { endsAt: { gte: now } }] },
        ],
      },
      orderBy: { createdAt: 'desc' },
      take: 50,
      include: { reads: { where: { userId }, select: { id: true }, take: 1 } },
    });
    const items = rows.map((a) => ({
      id: a.id,
      title: a.title,
      body: a.body,
      requiredRead: a.requiredRead,
      createdAt: a.createdAt.toISOString(),
      read: a.reads.length > 0,
    }));
    return { items, unread: items.filter((i) => !i.read).length };
  }

  async markRead(userId: string, announcementId: string) {
    await this.prisma.announcementRead.upsert({
      where: { announcementId_userId: { announcementId, userId } },
      update: {},
      create: { id: genId('annr'), announcementId, userId },
    });
    return { ok: true };
  }

  // ── admin ──────────────────────────────────────────────────────────
  private toDto(a: Announcement & { _count?: { reads: number } }) {
    return {
      id: a.id,
      title: a.title,
      body: a.body,
      audience: a.audience,
      requiredRead: a.requiredRead,
      active: a.active,
      startsAt: a.startsAt?.toISOString() ?? null,
      endsAt: a.endsAt?.toISOString() ?? null,
      createdAt: a.createdAt.toISOString(),
      reads: a._count?.reads ?? 0,
    };
  }

  async adminList() {
    const rows = await this.prisma.announcement.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: { _count: { select: { reads: true } } },
    });
    return rows.map((a) => this.toDto(a));
  }

  async create(dto: CreateAnnouncementDto, adminId: string) {
    const a = await this.prisma.announcement.create({
      data: {
        id: genId('ann'),
        title: dto.title,
        body: dto.body,
        audience: (dto.audience as AnnouncementAudience) ?? AnnouncementAudience.all,
        requiredRead: dto.requiredRead ?? false,
        active: dto.active ?? true,
        startsAt: dto.startsAt ? new Date(dto.startsAt) : null,
        endsAt: dto.endsAt ? new Date(dto.endsAt) : null,
        createdBy: adminId,
      },
    });
    return this.toDto(a);
  }

  async update(id: string, dto: UpdateAnnouncementDto) {
    await this.getOrThrow(id);
    const a = await this.prisma.announcement.update({
      where: { id },
      data: {
        title: dto.title,
        body: dto.body,
        audience: dto.audience as AnnouncementAudience | undefined,
        requiredRead: dto.requiredRead,
        active: dto.active,
        startsAt: dto.startsAt !== undefined ? (dto.startsAt ? new Date(dto.startsAt) : null) : undefined,
        endsAt: dto.endsAt !== undefined ? (dto.endsAt ? new Date(dto.endsAt) : null) : undefined,
      },
      include: { _count: { select: { reads: true } } },
    });
    return this.toDto(a);
  }

  async remove(id: string) {
    await this.getOrThrow(id);
    await this.prisma.announcement.delete({ where: { id } });
    return { ok: true };
  }

  private async getOrThrow(id: string) {
    const a = await this.prisma.announcement.findUnique({ where: { id } });
    if (!a) throw new NotFoundException({ code: 'announcement_not_found', message: 'Announcement not found' });
    return a;
  }
}
