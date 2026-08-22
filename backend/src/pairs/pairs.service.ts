import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeBus } from '../realtime/realtime.bus';
import { genId } from '../common/ids';

export interface PairChatDto {
  author: string;
  text: string;
  createdAt: string;
}

/**
 * Per-pair public chat (contract §pairs) — the Exness/eToro-style chat under a
 * symbol's chart. Messages persist and fan out live over the WS `pair:{symbol}`
 * channel (same `{ ch, type, data }` envelope as broadcast chat).
 */
@Injectable()
export class PairsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly bus: RealtimeBus,
  ) {}

  /** Normalize the URL symbol to canonical form (e.g. decodes XAU%2FUSD). */
  private normalize(symbol: string): string {
    return decodeURIComponent(symbol).toUpperCase().trim();
  }

  async list(symbol: string, limit = 100): Promise<PairChatDto[]> {
    const rows = await this.prisma.pairChat.findMany({
      where: { symbol: this.normalize(symbol) },
      orderBy: { createdAt: 'asc' },
      take: Math.min(200, Math.max(1, limit)),
    });
    return rows.map((r) => ({ author: r.author, text: r.text, createdAt: r.createdAt.toISOString() }));
  }

  async send(userId: string, symbol: string, text: string): Promise<PairChatDto> {
    const sym = this.normalize(symbol);
    const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { name: true, username: true } });
    const author = user?.username ?? user?.name ?? 'user';
    const row = await this.prisma.pairChat.create({
      data: { id: genId('pc'), symbol: sym, userId, author, text },
    });
    const dto: PairChatDto = { author, text: row.text, createdAt: row.createdAt.toISOString() };
    this.bus.emitChannel(`pair:${sym}`, { ch: `pair:${sym}`, type: 'chat', data: dto });
    return dto;
  }
}
