import {
  Injectable,
  BadRequestException,
  NotFoundException,
  Inject,
} from '@nestjs/common';
import { CopyConfig, CopyPosition, LedgerType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { PricesService } from '../market/prices.service';
import { NotificationsService } from '../notifications/notifications.service';
import { WalletService } from '../wallet/wallet.service';
import { SettlementService } from '../wallet/settlement.service';
import { SettingsService } from '../settings/settings.service';
import { MT_BRIDGE, MtBridge } from '../mt/mt.types';
import { genId } from '../common/ids';
import { round } from '../common/rng';
import {
  CopyConfigDto,
  CopyPositionDto,
  StartCopyDto,
  PortfolioSummaryDto,
} from './dto/copy.dto';

const PAIRS: Record<string, string[]> = {
  Forex: ['EUR/USD', 'GBP/USD', 'USD/JPY', 'AUD/USD'],
  Crypto: ['BTC/USD', 'ETH/USD', 'SOL/USD'],
  Gold: ['XAU/USD'],
  Indices: ['US30', 'NAS100', 'US500'],
};

@Injectable()
export class CopyService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly prices: PricesService,
    private readonly notifications: NotificationsService,
    private readonly wallet: WalletService,
    private readonly settlement: SettlementService,
    private readonly settings: SettingsService,
    @Inject(MT_BRIDGE) private readonly bridge: MtBridge,
  ) {}

  // ── live P/L helpers ────────────────────────────────────────────────
  /** Compute { pnlAmount, pnlPercent } for a position at a given price. */
  private pnlAt(p: { isBuy: boolean; entryPrice: number; lots: number }, price: number) {
    const dir = p.isBuy ? 1 : -1;
    const pnlPercent = round(((price - p.entryPrice) / p.entryPrice) * 100 * dir, 2);
    const pnlAmount = round(pnlPercent * p.lots * 100, 2);
    return { pnlAmount, pnlPercent };
  }

  toPositionDto(p: CopyPosition): CopyPositionDto {
    let pnlAmount = p.pnlAmount;
    let pnlPercent = p.pnlPercent;
    if (p.status === 'active') {
      const cur = this.prices.price(p.pair);
      if (cur != null) ({ pnlAmount, pnlPercent } = this.pnlAt(p, cur));
    }
    return {
      id: p.id,
      traderId: p.traderId,
      traderName: p.traderName,
      pair: p.pair,
      isBuy: p.isBuy,
      status: p.status,
      entryPrice: p.entryPrice,
      exitPrice: p.exitPrice,
      pnlAmount,
      pnlPercent,
      lots: p.lots,
      openedAt: p.openedAt.toISOString(),
      closedAt: p.closedAt ? p.closedAt.toISOString() : null,
      accountId: p.accountId,
    };
  }

  private toConfigDto(c: CopyConfig): CopyConfigDto {
    return {
      traderId: c.traderId,
      accountId: c.accountId,
      amount: c.amount,
      leverage: c.leverage,
      risk: c.risk,
      autoCopy: c.autoCopy,
      startedAt: c.startedAt.toISOString(),
    };
  }

  // ── start / stop ────────────────────────────────────────────────────
  async start(userId: string, traderId: string, dto: StartCopyDto): Promise<CopyConfigDto> {
    const trader = await this.prisma.trader.findUnique({ where: { id: traderId } });
    if (!trader) throw new NotFoundException({ code: 'trader_not_found', message: 'Trader not found' });

    // accountId is an optional broker hint now — funding is the in-app wallet.
    if (dto.accountId) {
      const account = await this.prisma.tradingAccount.findFirst({
        where: { id: dto.accountId, userId },
        select: { id: true },
      });
      if (!account) {
        throw new BadRequestException({ code: 'account_invalid', message: 'Unknown or unowned account' });
      }
    }
    const accountId = dto.accountId ?? 'wallet';

    // Resolve leverage: requested → user default → platform default, clamped to
    // the platform max (contract §12; wallet balance is the margin).
    const settings = await this.settings.get();
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { leverage: true },
    });
    const requested = dto.leverage ?? user?.leverage ?? settings.defaultLeverage;
    const leverage = Math.min(settings.maxLeverage, Math.max(1, Math.round(requested)));

    // Only allocate wallet capital on a fresh copy (or a re-start after stop),
    // not when merely updating an already-active config's settings.
    const existing = await this.prisma.copyConfig.findUnique({
      where: { userId_traderId: { userId, traderId } },
    });
    const isNewAllocation = !existing || !existing.active;
    if (isNewAllocation) {
      // Debits the wallet — throws insufficient_balance if the user hasn't
      // deposited enough. This is the "deposit first" flow.
      await this.wallet.post({
        userId,
        type: LedgerType.copy_allocate,
        amount: -dto.amount,
        refId: existing?.id,
        note: `Copy ${trader.name}`,
      });
    }

    const config = await this.prisma.copyConfig.upsert({
      where: { userId_traderId: { userId, traderId } },
      update: {
        accountId,
        amount: dto.amount,
        leverage,
        risk: dto.risk ?? 1.0,
        autoCopy: dto.autoCopy ?? true,
        active: true,
        stoppedAt: null,
      },
      create: {
        id: genId('cc'),
        userId,
        traderId,
        accountId,
        amount: dto.amount,
        leverage,
        risk: dto.risk ?? 1.0,
        autoCopy: dto.autoCopy ?? true,
      },
    });

    // Open a few positions mirroring the trader (synthetic until the broker
    // bridge is live) and route the net exposure to the corporate broker
    // account via the bridge (best-effort — never blocks the copy). Exposure is
    // margin × leverage.
    await this.openInitialPositions(userId, trader.id, trader.name, accountId, dto.amount, dto.risk ?? 1, leverage);
    void this.bridge
      .placeOrder({ accountRef: `corp:${trader.id}`, symbol: trader.category, side: 'buy', volume: dto.amount * leverage })
      .catch(() => undefined);
    return this.toConfigDto(config);
  }

  private async openInitialPositions(
    userId: string,
    traderId: string,
    traderName: string,
    accountId: string,
    amount: number,
    risk: number,
    leverage = 100,
  ) {
    // Don't duplicate if positions already open for this trader.
    const existing = await this.prisma.copyPosition.count({
      where: { userId, traderId, status: 'active' },
    });
    if (existing > 0) return;

    const trader = await this.prisma.trader.findUnique({ where: { id: traderId }, select: { category: true } });
    const pairs = PAIRS[trader?.category ?? 'Forex'] ?? PAIRS.Forex;
    const count = 2 + Math.floor(Math.random() * 2); // 2–3 positions
    // Exposure = margin × leverage. At leverage 100 this matches the prior
    // amount/5000 sizing, and scales linearly with leverage.
    const lotBase = round(Math.max(0.01, ((amount * leverage) / 500000) * risk), 2);

    for (let i = 0; i < count; i++) {
      const pair = pairs[Math.floor(Math.random() * pairs.length)];
      const entry = this.prices.price(pair);
      if (entry == null) continue;
      const isBuy = Math.random() > 0.45;
      await this.prisma.copyPosition.create({
        data: {
          id: genId('pos'),
          userId,
          traderId,
          traderName,
          accountId,
          pair,
          isBuy,
          entryPrice: entry,
          lots: round(lotBase * (0.6 + Math.random() * 0.8), 2),
        },
      });
      // Live event: a copied trader opened a position (contract §6a).
      await this.notifications.pushEvent(userId, 'trade.opened', `${traderName} opened ${pair}`, {
        data: { traderId, name: traderName, pair, isBuy, entryPrice: entry },
      });
    }
  }

  async stop(userId: string, traderId: string): Promise<void> {
    const trader = await this.prisma.trader.findUnique({
      where: { id: traderId },
      select: { id: true, userId: true, commissionPercent: true },
    });
    const config = await this.prisma.copyConfig.findUnique({
      where: { userId_traderId: { userId, traderId } },
    });
    const wasActive = !!config?.active;

    await this.prisma.copyConfig.updateMany({
      where: { userId, traderId },
      data: { active: false, stoppedAt: new Date() },
    });
    // Close any open positions at the current price, booking final P/L.
    const open = await this.prisma.copyPosition.findMany({
      where: { userId, traderId, status: 'active' },
    });
    let realizedPnl = 0;
    for (const p of open) {
      const cur = this.prices.price(p.pair) ?? p.entryPrice;
      const { pnlAmount, pnlPercent } = this.pnlAt(p, cur);
      realizedPnl += pnlAmount;
      await this.prisma.copyPosition.update({
        where: { id: p.id },
        data: { status: 'closed', exitPrice: cur, pnlAmount, pnlPercent, closedAt: new Date() },
      });
      // Live event: position closed with booked P/L (contract §6a).
      await this.notifications.pushEvent(userId, 'trade.closed', `${p.pair} closed ${pnlPercent}%`, {
        data: { traderId, pair: p.pair, pnlPercent, pnlAmount },
      });
    }

    // Settle the wallet: return principal, book P/L, split the performance fee
    // (copier keeps the profit, trader earns commission, Millimore its share).
    if (wasActive && config && trader) {
      const result = await this.settlement.settle({
        copierUserId: userId,
        trader: { id: trader.id, userId: trader.userId, commissionPercent: trader.commissionPercent },
        principal: config.amount,
        realizedPnl: round(realizedPnl, 2),
        refId: config.id,
      });
      await this.notifications.pushEvent(userId, 'copy.settled', 'Copy stopped & settled', {
        body: `You received $${result.netToCopier.toFixed(2)} back to your wallet.`,
        data: { traderId, netToCopier: result.netToCopier, fee: result.fee },
      });
    }
  }

  // ── reads ───────────────────────────────────────────────────────────
  async listConfigs(userId: string): Promise<CopyConfigDto[]> {
    const rows = await this.prisma.copyConfig.findMany({
      where: { userId, active: true },
      orderBy: { startedAt: 'desc' },
    });
    return rows.map((c) => this.toConfigDto(c));
  }

  async positions(userId: string, status?: 'active' | 'closed'): Promise<CopyPositionDto[]> {
    const rows = await this.prisma.copyPosition.findMany({
      where: { userId, ...(status ? { status } : {}) },
      orderBy: { openedAt: 'desc' },
    });
    return rows.map((p) => this.toPositionDto(p));
  }

  /** Active positions for a user (used by the WS portfolio stream). */
  activePositions(userId: string): Promise<CopyPosition[]> {
    return this.prisma.copyPosition.findMany({ where: { userId, status: 'active' } });
  }

  async portfolioSummary(userId: string): Promise<PortfolioSummaryDto> {
    const [positions, configs] = await Promise.all([
      this.prisma.copyPosition.findMany({ where: { userId } }),
      this.prisma.copyConfig.findMany({ where: { userId, active: true } }),
    ]);

    let openPnl = 0;
    let bookedProfit = 0;
    let bookedLoss = 0;
    let activeCount = 0;
    let closedCount = 0;

    for (const p of positions) {
      if (p.status === 'active') {
        activeCount++;
        const cur = this.prices.price(p.pair);
        openPnl += cur != null ? this.pnlAt(p, cur).pnlAmount : p.pnlAmount;
      } else {
        closedCount++;
        if (p.pnlAmount >= 0) bookedProfit += p.pnlAmount;
        else bookedLoss += p.pnlAmount;
      }
    }
    const invested = configs.reduce((s, c) => s + c.amount, 0);

    // Margin view: the wallet balance is the free margin; active copy
    // allocations are used margin; equity folds in open P/L.
    const freeMargin = await this.wallet.balance(userId);
    const usedMargin = round(invested, 2);
    const equity = round(freeMargin + usedMargin + openPnl, 2);
    const marginLevel = usedMargin > 0 ? round((equity / usedMargin) * 100, 2) : null;

    return {
      netPnl: round(openPnl + bookedProfit + bookedLoss, 2),
      openPnl: round(openPnl, 2),
      bookedProfit: round(bookedProfit, 2),
      bookedLoss: round(bookedLoss, 2),
      copyingCount: configs.length,
      activeCount,
      closedCount,
      invested: usedMargin,
      freeMargin: round(freeMargin, 2),
      usedMargin,
      equity,
      marginLevel,
    };
  }
}
