import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CryptoAddressService } from './crypto-address.service';
import { DepositNetwork } from './address-provider';
import { genId } from '../../common/ids';

/**
 * Consolidates ("sweeps") credited USDT off users' per-user deposit addresses into
 * the master wallet. Non-custodial: the actual signing is delegated to Tatum KMS
 * via the provider (a signatureId) — no private key ever touches this server.
 *
 * Gated OFF by default (SWEEP_ENABLED). Even when enabled it is a no-op unless the
 * provider reports canSweep (Gas Pump address mode + KMS signatureId configured).
 * Sweeps are event-driven (fire right after a deposit credits) and idempotent: a
 * per-address in-flight guard plus the on-chain balance check mean a double trigger
 * can't double-send.
 */
@Injectable()
export class SweepService {
  private readonly logger = new Logger('SweepService');

  constructor(
    private readonly prisma: PrismaService,
    private readonly addresses: CryptoAddressService,
  ) {}

  get enabled(): boolean {
    return process.env.SWEEP_ENABLED === 'true' && this.addresses.canSweep;
  }

  private minUsdt(): number {
    const n = Number(process.env.SWEEP_MIN_USDT ?? 1);
    return Number.isFinite(n) && n > 0 ? n : 1;
  }

  /** Fire-and-forget auto-sweep after a deposit is credited. Never throws into the
   *  caller (deposit crediting must not fail because a sweep failed). */
  triggerAfterDeposit(userId: string, network: DepositNetwork, address: string): void {
    if (!this.enabled) return;
    void this.sweepAddress(userId, network, address).catch((e) =>
      this.logger.warn(`auto-sweep failed for ${network} ${address}: ${String(e)}`),
    );
  }

  /** Sweep every configured deposit address of a user that holds ≥ min USDT. */
  async sweepUser(userId: string): Promise<Array<Record<string, unknown>>> {
    const rows = await this.prisma.depositAddress.findMany({ where: { userId } });
    const out: Array<Record<string, unknown>> = [];
    for (const a of rows) {
      out.push(await this.sweepAddress(userId, a.network as DepositNetwork, a.address));
    }
    return out;
  }

  /** Sweep a single address. Idempotent: skips when a sweep is already in flight
   *  for this address or the balance is below the threshold. */
  async sweepAddress(userId: string, network: DepositNetwork, address: string): Promise<Record<string, unknown>> {
    if (!this.enabled) return { network, address, status: 'skipped', reason: 'sweep disabled' };

    const row = await this.prisma.depositAddress.findFirst({ where: { network, address } });
    const index = row?.derivationIndex ?? 0;

    const inFlight = await this.prisma.sweep.findFirst({ where: { network, fromAddress: address, status: { in: ['pending', 'broadcast'] } } });
    if (inFlight) return { network, address, status: 'skipped', reason: 'sweep in flight', sweepId: inFlight.id };

    const { balance } = await this.addresses.usdtBalance(address, network);
    if (balance < this.minUsdt()) return { network, address, status: 'skipped', reason: `balance ${balance} < min ${this.minUsdt()}`, balance };

    const rec = await this.prisma.sweep.create({
      data: {
        id: genId('swp'),
        userId,
        network,
        fromAddress: address,
        toAddress: (process.env[`TATUM_GP_MASTER_${network.toUpperCase()}`] ?? process.env.TATUM_GP_MASTER ?? '').trim(),
        asset: 'USDT',
        amount: balance,
        status: 'pending',
      },
    });

    const res = await this.addresses.sweep(address, network, index);
    await this.prisma.sweep.update({
      where: { id: rec.id },
      data: {
        status: res.status === 'broadcast' ? 'broadcast' : 'failed',
        txRef: res.txRef,
        error: res.status === 'broadcast' ? null : (res.reason ?? 'sweep failed'),
      },
    });
    return { network, address, status: res.status, reason: res.reason, txRef: res.txRef, balance, sweepId: rec.id, raw: res.raw };
  }
}
