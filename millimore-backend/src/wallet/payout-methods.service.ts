import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PayoutMethod } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CryptoService } from '../common/crypto/crypto.service';
import { genId } from '../common/ids';
import { CreatePayoutMethodDto, PayoutMethodDto } from './dto/payout-method.dto';

/**
 * Saved withdrawal destinations. Sensitive details (crypto address, bank
 * account) are AES-256-GCM encrypted at rest and never returned — responses
 * carry only a `masked` hint, exactly like broker credentials.
 */
@Injectable()
export class PayoutMethodsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly crypto: CryptoService,
  ) {}

  private toDto(m: PayoutMethod): PayoutMethodDto {
    return {
      id: m.id,
      type: m.type,
      label: m.label,
      masked: m.masked,
      createdAt: m.createdAt.toISOString(),
    };
  }

  private tail(s?: string): string {
    const v = (s ?? '').replace(/\s+/g, '');
    return v ? `••••${v.slice(-4)}` : '••••';
  }

  async list(userId: string): Promise<PayoutMethodDto[]> {
    const rows = await this.prisma.payoutMethod.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
    return rows.map((m) => this.toDto(m));
  }

  async create(userId: string, dto: CreatePayoutMethodDto): Promise<PayoutMethodDto> {
    let details: Record<string, string>;
    let masked: string;
    if (dto.type === 'crypto') {
      if (!dto.address) {
        throw new BadRequestException({ code: 'address_required', message: 'Crypto address is required.' });
      }
      details = { asset: dto.asset ?? 'USDT', address: dto.address };
      masked = `${dto.asset ?? 'Crypto'} ${this.tail(dto.address)}`;
    } else {
      const acct = dto.accountNumber || dto.iban;
      if (!acct) {
        throw new BadRequestException({ code: 'account_required', message: 'Bank account number or IBAN is required.' });
      }
      details = {
        bankName: dto.bankName ?? '',
        accountNumber: dto.accountNumber ?? '',
        iban: dto.iban ?? '',
      };
      masked = `${dto.bankName ?? 'Bank'} ${this.tail(acct)}`;
    }
    const row = await this.prisma.payoutMethod.create({
      data: {
        id: genId('pm'),
        userId,
        type: dto.type,
        label: dto.label,
        detailsEnc: this.crypto.encrypt(JSON.stringify(details)),
        masked,
      },
    });
    return this.toDto(row);
  }

  async remove(userId: string, id: string): Promise<void> {
    const m = await this.prisma.payoutMethod.findFirst({ where: { id, userId } });
    if (!m) throw new NotFoundException({ code: 'method_not_found', message: 'Payout method not found' });
    await this.prisma.payoutMethod.delete({ where: { id } });
  }

  /** Internal: whether a method belongs to a user (used to gate withdrawals). */
  async ownsMethod(userId: string, id: string): Promise<boolean> {
    const m = await this.prisma.payoutMethod.findFirst({ where: { id, userId }, select: { id: true } });
    return !!m;
  }

  /** The method's type ("crypto" | "bank"), or null if not owned. */
  async typeOf(userId: string, id: string): Promise<string | null> {
    const m = await this.prisma.payoutMethod.findFirst({ where: { id, userId }, select: { type: true } });
    return m?.type ?? null;
  }

  async count(userId: string): Promise<number> {
    return this.prisma.payoutMethod.count({ where: { userId } });
  }
}
