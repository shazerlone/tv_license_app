import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PlatformSettings } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

const SETTINGS_ID = 'platform';
const CACHE_TTL_MS = 15_000;

/**
 * Admin-editable platform settings (the Millimore fee, leverage cap, deposit /
 * withdrawal limits, method toggles). A single row, read on nearly every money
 * operation, so it's cached in-process for a few seconds and invalidated on
 * write. Env vars provide the first-run defaults.
 */
@Injectable()
export class SettingsService {
  private cache: { at: number; value: PlatformSettings } | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  private envNum(key: string, fallback: number): number {
    const n = Number(this.config.get<string>(key));
    return Number.isFinite(n) ? n : fallback;
  }

  /** The settings row, created with env-seeded defaults on first access. */
  async get(): Promise<PlatformSettings> {
    if (this.cache && Date.now() - this.cache.at < CACHE_TTL_MS) {
      return this.cache.value;
    }
    let row = await this.prisma.platformSettings.findUnique({ where: { id: SETTINGS_ID } });
    if (!row) {
      row = await this.prisma.platformSettings.create({
        data: {
          id: SETTINGS_ID,
          platformFeeShare: this.envNum('PLATFORM_FEE_SHARE', 0.3),
          maxLeverage: this.envNum('MAX_LEVERAGE', 500),
          defaultLeverage: this.envNum('DEFAULT_LEVERAGE', 100),
          depositAutoConfirm:
            this.config.get<string>('DEPOSIT_AUTO_CONFIRM', 'true') !== 'false',
        },
      });
    }
    this.cache = { at: Date.now(), value: row };
    return row;
  }

  async update(patch: Partial<PlatformSettings>): Promise<PlatformSettings> {
    // Never let a client move the primary key or timestamps.
    const { id: _id, updatedAt: _u, ...data } = patch as Record<string, unknown>;
    const row = await this.prisma.platformSettings.upsert({
      where: { id: SETTINGS_ID },
      update: data,
      create: { id: SETTINGS_ID, ...(data as object) },
    });
    this.cache = { at: Date.now(), value: row };
    return row;
  }

  /** Public subset the mobile app needs (no ops-only flags). */
  async publicConfig() {
    const s = await this.get();
    return {
      maxLeverage: s.maxLeverage,
      defaultLeverage: s.defaultLeverage,
      minDeposit: s.minDeposit,
      minWithdrawal: s.minWithdrawal,
      maxWithdrawalPerTx: s.maxWithdrawalPerTx,
      maxWithdrawalPerDay: s.maxWithdrawalPerDay,
      kycRequiredForWithdrawal: s.kycRequiredForWithdrawal,
      depositMethods: [
        { id: 'crypto', label: 'Crypto (USDT / BTC)', active: s.cryptoEnabled },
        { id: 'card', label: 'Debit / Credit card', active: s.cardEnabled, comingSoon: !s.cardEnabled },
        { id: 'bank', label: 'Bank transfer', active: s.bankEnabled, comingSoon: !s.bankEnabled },
        { id: 'metatrader', label: 'MetaTrader transfer', active: false, comingSoon: true },
      ],
      maintenanceMode: s.maintenanceMode,
    };
  }
}
