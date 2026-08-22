import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { SupportMessage, SupportTicket, TicketPriority, TicketStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { genId } from '../common/ids';
import {
  AdminReplyDto,
  CreateTicketDto,
  TicketDetailDto,
  TicketDto,
  UpdateTicketDto,
} from './dto/support.dto';

@Injectable()
export class SupportService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  private toTicketDto(t: SupportTicket & { messages?: SupportMessage[] }): TicketDto {
    return {
      id: t.id,
      subject: t.subject,
      category: t.category,
      priority: t.priority,
      status: t.status,
      createdAt: t.createdAt.toISOString(),
      lastMessageAt: t.lastMessageAt.toISOString(),
    };
  }

  private toMessageDto(m: SupportMessage) {
    return {
      id: m.id,
      authorRole: m.authorRole,
      body: m.body,
      internal: m.internal,
      createdAt: m.createdAt.toISOString(),
    };
  }

  // ── user ───────────────────────────────────────────────────────────
  async create(userId: string, dto: CreateTicketDto): Promise<TicketDto> {
    const id = genId('tkt');
    const ticket = await this.prisma.supportTicket.create({
      data: {
        id,
        userId,
        subject: dto.subject,
        category: dto.category ?? 'general',
        priority: (dto.priority as TicketPriority) ?? TicketPriority.normal,
        messages: {
          create: { id: genId('tmsg'), authorId: userId, authorRole: 'user', body: dto.message },
        },
      },
    });
    return this.toTicketDto(ticket);
  }

  async listMine(userId: string): Promise<TicketDto[]> {
    const rows = await this.prisma.supportTicket.findMany({
      where: { userId },
      orderBy: { lastMessageAt: 'desc' },
      take: 100,
    });
    return rows.map((t) => this.toTicketDto(t));
  }

  async getMine(userId: string, ticketId: string): Promise<TicketDetailDto> {
    const ticket = await this.prisma.supportTicket.findUnique({
      where: { id: ticketId },
      include: { messages: { where: { internal: false }, orderBy: { createdAt: 'asc' } } },
    });
    if (!ticket) throw new NotFoundException({ code: 'ticket_not_found', message: 'Ticket not found' });
    if (ticket.userId !== userId) throw new ForbiddenException({ code: 'forbidden', message: 'Not your ticket' });
    return { ...this.toTicketDto(ticket), messages: ticket.messages.map((m) => this.toMessageDto(m)) };
  }

  async reply(userId: string, ticketId: string, body: string): Promise<TicketDetailDto> {
    const ticket = await this.prisma.supportTicket.findUnique({ where: { id: ticketId } });
    if (!ticket) throw new NotFoundException({ code: 'ticket_not_found', message: 'Ticket not found' });
    if (ticket.userId !== userId) throw new ForbiddenException({ code: 'forbidden', message: 'Not your ticket' });
    await this.prisma.supportMessage.create({
      data: { id: genId('tmsg'), ticketId, authorId: userId, authorRole: 'user', body },
    });
    await this.prisma.supportTicket.update({
      where: { id: ticketId },
      // A user reply reopens a resolved/pending ticket.
      data: { lastMessageAt: new Date(), status: ticket.status === TicketStatus.closed ? TicketStatus.closed : TicketStatus.open },
    });
    return this.getMine(userId, ticketId);
  }

  // ── admin ──────────────────────────────────────────────────────────
  async adminList(status?: string) {
    const rows = await this.prisma.supportTicket.findMany({
      where: status ? { status: status as TicketStatus } : {},
      orderBy: [{ lastMessageAt: 'desc' }],
      take: 100,
      include: { user: { select: { id: true, name: true, username: true, email: true } } },
    });
    return rows.map((t) => ({ ...this.toTicketDto(t), user: t.user }));
  }

  async adminGet(ticketId: string) {
    const ticket = await this.prisma.supportTicket.findUnique({
      where: { id: ticketId },
      include: {
        messages: { orderBy: { createdAt: 'asc' } }, // includes internal notes
        user: { select: { id: true, name: true, username: true, email: true } },
      },
    });
    if (!ticket) throw new NotFoundException({ code: 'ticket_not_found', message: 'Ticket not found' });
    return { ...this.toTicketDto(ticket), user: ticket.user, messages: ticket.messages.map((m) => this.toMessageDto(m)) };
  }

  async adminReply(ticketId: string, adminId: string, dto: AdminReplyDto) {
    const ticket = await this.prisma.supportTicket.findUnique({ where: { id: ticketId } });
    if (!ticket) throw new NotFoundException({ code: 'ticket_not_found', message: 'Ticket not found' });
    const internal = !!dto.internal;
    await this.prisma.supportMessage.create({
      data: { id: genId('tmsg'), ticketId, authorId: adminId, authorRole: 'admin', body: dto.body, internal },
    });
    await this.prisma.supportTicket.update({
      where: { id: ticketId },
      // A public reply moves the ticket to "pending" (awaiting the user).
      data: { lastMessageAt: new Date(), ...(internal ? {} : { status: TicketStatus.pending }) },
    });
    if (!internal) {
      await this.notifications.pushEvent(ticket.userId, 'support.reply', 'Support replied', {
        body: dto.body.slice(0, 120),
        data: { ticketId },
      });
    }
    return this.adminGet(ticketId);
  }

  async adminUpdate(ticketId: string, dto: UpdateTicketDto) {
    await this.prisma.supportTicket.update({
      where: { id: ticketId },
      data: { status: dto.status as TicketStatus | undefined, priority: dto.priority as any },
    });
    return this.adminGet(ticketId);
  }
}
