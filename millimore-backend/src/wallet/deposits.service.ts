import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Deposit, DepositStatus, LedgerType } from '@prisma/client';
import { randomBytes } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { WalletService } from './wallet.service';
import { genId } from '../common/ids';
import { CreateDepositDto, DepositDto, DepositMethodDto } from './dto/deposit.dto';

/**
 * Deposits into the Millimore wallet. Crypto is the only live method now; others
 * are advertised as "coming soon". In test mode (DEPOSIT_AUTO_CONFIRM=true)
 * deposits confirm and credit the wallet immediately; in production a crypto
 * webhook calls `confirm()` exactly once when funds actually arrive.
 */
@Injectable()
export class DepositsService {
  private readonly autoConfirm: boolean;

  constructor(
    private readonly prisma: PrismaService,
    private readonly wallet: WalletService,
    config: ConfigService,
  ) {
    // Default ON for now (test mode). Set DEPOSIT_AUTO_CONFIRM=false for prod.
    this.autoConfirm = config.get<string>('DEPOSIT_AUTO_CONFIRM', 'true') !== 'false';
  }

  methods(): DepositMethodDto[] {
    return [
      {
        id: 'crypto',
        label: 'Crypto (USDT / BTC)',
        active: true,
        assets: ['USDT', 'BTC', 'ETH'],
      },
      { id: 'metatrader', label: 'MetaTrader transfer', active: false, comingSoon: true },
      { id: 'card', label: 'Debit / Credit card', active: false, comingSoon: true },
      { id: 'bank', label: 'Bank transfer', active: false, comingSoon: true },
    ];
  }

  private toDto(d: Deposit): DepositDto {
    return {
      id: d.id,
      amount: d.amount,
      currency: d.currency,
      method: d.method,
      asset: d.asset,
      address: d.address,
      status: d.status,
      createdAt: d.createdAt.toISOString(),
      confirmedAt: d.confirmedAt?.toISOString() ?? null,
    };
  }

  /** A placeholder deposit address (a real crypto processor issues these). */
  private mockAddress(asset: string): string {
    const prefix = asset === 'BTC' ? 'bc1' : '0x';
    return `${prefix}${randomBytes(18).toString('hex')}`;
  }

  async create(userId: string, dto: CreateDepositDto): Promise<DepositDto> {
    const method = dto.method ?? 'crypto';
    if (method !== 'crypto') {
      throw new BadRequestException({
        code: 'method_unavailable',
        message: 'Only crypto deposits are available right now. Other methods are coming soon.',
      });
    }
    const asset = dto.asset ?? 'USDT';
    const deposit = await this.prisma.deposit.create({
      data: {
        id: genId('dep'),
        userId,
        amount: Math.round(dto.amount * 100) / 100,
        currency: 'USD',
        method,
        asset,
        address: this.mockAddress(asset),
        status: DepositStatus.pending,
      },
    });

    if (this.autoConfirm) {
      return this.confirm(deposit.id, `test-${deposit.id}`);
    }
    return this.toDto(deposit);
  }

  /**
   * Confirm a pending deposit and credit the wallet — idempotent: a deposit is
   * only ever credited once (webhook retries are safe).
   */
  async confirm(depositId: string, txRef?: string): Promise<DepositDto> {
    const deposit = await this.prisma.deposit.findUnique({ where: { id: depositId } });
    if (!deposit) {
      throw new NotFoundException({ code: 'deposit_not_found', message: 'Deposit not found' });
    }
    if (deposit.status === DepositStatus.confirmed) return this.toDto(deposit);

    const updated = await this.prisma.$transaction(async (tx) => {
      const d = await tx.deposit.update({
        where: { id: deposit.id },
        data: { status: DepositStatus.confirmed, txRef: txRef ?? deposit.txRef, confirmedAt: new Date() },
      });
      await this.wallet.post({
        userId: d.userId,
        type: LedgerType.deposit,
        amount: d.amount,
        refId: d.id,
        note: `Deposit ${d.asset ?? d.method}`,
        tx,
      });
      return d;
    });
    return this.toDto(updated);
  }

  async listMine(userId: string): Promise<DepositDto[]> {
    const rows = await this.prisma.deposit.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    return rows.map((d) => this.toDto(d));
  }
}
