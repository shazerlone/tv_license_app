import { BadRequestException, ForbiddenException, Injectable, Logger } from '@nestjs/common';
import { KycStatus, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { DepositsService } from '../wallet/deposits.service';
import { NotificationsService } from '../notifications/notifications.service';
import { SweepService } from '../wallet/crypto/sweep.service';
import { CryptoAddressService } from '../wallet/crypto/crypto-address.service';
import { DepositNetwork } from '../wallet/crypto/address-provider';

const TEST_USER_ID = 'u_setup_deposit_test';

/**
 * ONE-TIME master-wallet generator. Locked behind WALLET_SETUP_TOKEN (unset =
 * fully disabled) so it can only run during setup and is turned off afterwards.
 * Calls Tatum to generate a wallet and returns { mnemonic, xpub } ONCE — the
 * mnemonic is NEVER logged or stored. Runs on the deployed server (which can
 * reach Tatum); paste the xpub into env and save the mnemonic OFFLINE.
 */
@Injectable()
export class SetupService {
  private readonly logger = new Logger('SetupService');

  constructor(
    private readonly prisma: PrismaService,
    private readonly deposits: DepositsService,
    private readonly sweep: SweepService,
    private readonly notifications: NotificationsService,
  ) {}

  /** Browser-openable push diagnostic (token-gated). With no userId it tests the
   *  most-recently registered device (i.e. the last phone that opened the app). */
  async pushTest(token: string, userId?: string) {
    this.assertSetup(token);
    let uid = userId?.trim();
    if (!uid) {
      const dev = await this.prisma.device.findFirst({ orderBy: { createdAt: 'desc' }, select: { userId: true } });
      if (!dev) {
        return { note: 'No devices registered by ANY user yet — the app must POST /v1/devices with its FCM token after the user grants notification permission. That is almost certainly why push is silent.' };
      }
      uid = dev.userId;
    }
    return { userId: uid, ...(await this.notifications.testPush(uid)) };
  }

  private assertSetup(token: string) {
    const setupToken = process.env.WALLET_SETUP_TOKEN?.trim();
    if (!setupToken) throw new ForbiddenException({ code: 'setup_disabled', message: 'Set WALLET_SETUP_TOKEN to enable setup endpoints.' });
    if (!token || token !== setupToken) throw new ForbiddenException({ code: 'bad_setup_token', message: 'Invalid setup token.' });
  }

  async generateWallet(chain: string, token: string): Promise<{ chain: string; xpub: string; mnemonic: string; warning: string }> {
    this.assertSetup(token);
    const c = (chain ?? '').toLowerCase();
    if (c !== 'ethereum' && c !== 'tron') {
      throw new BadRequestException({ code: 'bad_chain', message: 'chain must be "ethereum" or "tron".' });
    }
    const apiKey = process.env.TATUM_API_KEY?.trim();
    if (!apiKey) {
      throw new BadRequestException({ code: 'no_tatum_key', message: 'TATUM_API_KEY is not set.' });
    }

    const res = await fetch(`https://api.tatum.io/v3/${c}/wallet`, { headers: { 'x-api-key': apiKey } });
    const json = (await res.json().catch(() => ({}))) as { mnemonic?: string; xpub?: string; message?: string };
    if (!res.ok || !json.xpub || !json.mnemonic) {
      throw new BadRequestException({ code: 'tatum_error', message: `Tatum wallet generation failed: ${res.status} ${json.message ?? ''}`.trim() });
    }
    this.logger.log(`Generated ${c} master wallet (xpub ${json.xpub.slice(0, 12)}…) — mnemonic returned to caller, not stored`);
    return {
      chain: c,
      xpub: json.xpub,
      mnemonic: json.mnemonic,
      warning: 'SAVE the mnemonic OFFLINE now (it controls all funds). Put ONLY the xpub in env. Then unset WALLET_SETUP_TOKEN and redeploy.',
    };
  }

  /**
   * Diagnostic: mint a real deposit address on each configured network via the
   * live provider (proves the API key + xpubs + derivation work) without needing
   * a KYC user, app, or coins. Locked behind WALLET_SETUP_TOKEN. Returns per-
   * network address or a per-network error so failures are easy to read.
   */
  async testAddresses(token: string): Promise<{ provider: string; results: Record<string, string> }> {
    this.assertSetup(token);
    const svc = new CryptoAddressService();
    if (!svc.enabled) throw new BadRequestException({ code: 'provider_disabled', message: 'No address provider configured (CRYPTO_ADDRESS_PROVIDER).' });

    const results: Record<string, string> = {};
    for (const network of svc.networks as DepositNetwork[]) {
      try {
        const gen = await svc.createAddress('setup-test-user', network, 999_000 + Math.floor(Math.random() * 999));
        results[network] = gen.address;
      } catch (e) {
        results[network] = `ERROR: ${(e as Error).message.split('\n')[0]}`;
      }
    }
    return { provider: svc.name, results };
  }

  /** Set up a dedicated KYC-verified test user and persist their real deposit
   *  addresses (subscribed to webhooks). Send testnet USDT to one, then poll
   *  testDepositStatus to watch it credit. */
  async testDepositSetup(token: string) {
    this.assertSetup(token);
    await this.prisma.user.upsert({
      where: { id: TEST_USER_ID },
      update: { kycStatus: KycStatus.verified },
      create: { id: TEST_USER_ID, name: 'Deposit Test', username: 'deposit_test', role: Role.follower, kycStatus: KycStatus.verified },
    });
    await this.prisma.wallet.upsert({
      where: { userId: TEST_USER_ID },
      update: {},
      create: { id: 'w_setup_deposit_test', userId: TEST_USER_ID, balance: 0, currency: 'USD' },
    });
    const addresses = await this.deposits.myAddresses(TEST_USER_ID); // persists + subscribes
    const w = await this.prisma.wallet.findUnique({ where: { userId: TEST_USER_ID }, select: { balance: true } });
    return {
      userId: TEST_USER_ID,
      walletBalance: w?.balance ?? 0,
      addresses,
      next: 'Send a small amount of testnet USDT to one of these addresses, then open /v1/setup/test-deposit/status?token=… to watch it credit.',
    };
  }

  /** Poll the test user's balance + recent deposits after sending testnet funds. */
  async testDepositStatus(token: string) {
    this.assertSetup(token);
    const w = await this.prisma.wallet.findUnique({ where: { userId: TEST_USER_ID }, select: { balance: true } });
    const deposits = await this.prisma.deposit.findMany({
      where: { userId: TEST_USER_ID },
      orderBy: { createdAt: 'desc' },
      take: 10,
      select: { amount: true, status: true, asset: true, payCurrency: true, txRef: true, createdAt: true },
    });
    return { userId: TEST_USER_ID, walletBalance: w?.balance ?? 0, deposits };
  }

  /** Inspect the last few raw deposit webhooks Tatum sent (testnet debugging). */
  lastWebhooks(token: string) {
    this.assertSetup(token);
    return { recent: this.deposits.recentChainWebhooks() };
  }

  /** Scan the test user's addresses for on-chain USDT deposits and credit them. */
  async rescan(token: string) {
    this.assertSetup(token);
    const results = await this.deposits.rescan(TEST_USER_ID);
    const w = await this.prisma.wallet.findUnique({ where: { userId: TEST_USER_ID }, select: { balance: true } });
    return { userId: TEST_USER_ID, walletBalance: w?.balance ?? 0, results };
  }

  /** Manually sweep the test user's deposit addresses to the master wallet. Returns
   *  the raw provider responses so the Gas Pump / KMS field shapes can be locked
   *  down on testnet before mainnet. No-op unless sweep is fully configured. */
  async sweepTest(token: string) {
    this.assertSetup(token);
    const results = await this.sweep.sweepUser(TEST_USER_ID);
    return {
      userId: TEST_USER_ID,
      enabled: this.sweep.enabled,
      config: {
        sweepEnabled: process.env.SWEEP_ENABLED === 'true',
        addressMode: process.env.CRYPTO_ADDRESS_MODE ?? 'hd',
        kmsSignatureIdSet: !!(process.env.TATUM_KMS_SIGNATURE_ID ?? '').trim(),
        gpMasterSet: !!(process.env.TATUM_GP_MASTER ?? process.env.TATUM_GP_MASTER_TRON ?? '').trim(),
      },
      results,
    };
  }

  /**
   * Ask Tatum directly what it has registered + attempt a fresh subscription,
   * returning the RAW responses so we can see exactly why webhooks aren't firing
   * (bad URL, unsupported chain name, testnet mismatch, etc.).
   */
  async tatumDebug(token: string) {
    this.assertSetup(token);
    const key = process.env.TATUM_API_KEY?.trim();
    const base = (process.env.PUBLIC_BASE_URL ?? '').trim().replace(/\/+$/, '');
    const webhookUrl = base ? `${base}/v1/webhooks/deposits/chain` : null;
    const hmac = process.env.TATUM_HMAC_SECRET?.trim() || '';
    const out: Record<string, unknown> = {
      config: { publicBaseUrl: base || null, webhookUrl, network: process.env.TATUM_NETWORK || 'per-key', hmacSet: !!hmac },
    };
    if (!key) return { ...out, error: 'TATUM_API_KEY not set' };

    // What does Tatum currently have?
    try {
      const r = await fetch('https://api.tatum.io/v4/subscription?pageSize=50', { headers: { 'x-api-key': key } });
      out.existingSubscriptions = { status: r.status, body: await r.json().catch(() => null) };
    } catch (e) {
      out.existingSubscriptions = { error: (e as Error).message };
    }

    // (Re)subscribe ALL of the test user's addresses so any network's faucet works.
    const testnet = (process.env.TATUM_NETWORK ?? 'testnet').toLowerCase() !== 'mainnet';
    const subChain: Record<string, string> = testnet
      ? { tron: 'tron-testnet', bsc: 'bsc-testnet', ethereum: 'ethereum-sepolia' }
      : { tron: 'tron-mainnet', bsc: 'bsc-mainnet', ethereum: 'ethereum-mainnet' };
    const addrs = await this.prisma.depositAddress.findMany({ where: { userId: TEST_USER_ID } });
    const subs: Record<string, unknown> = {};
    for (const a of addrs) {
      if (!webhookUrl) { subs[a.network] = { skipped: 'no PUBLIC_BASE_URL' }; continue; }
      try {
        const r = await fetch('https://api.tatum.io/v4/subscription', {
          method: 'POST',
          headers: { 'x-api-key': key, 'content-type': 'application/json' },
          body: JSON.stringify({ type: 'ADDRESS_EVENT', attr: { address: a.address, chain: subChain[a.network], url: webhookUrl } }),
        });
        subs[a.network] = { status: r.status, address: a.address, body: await r.json().catch(() => null) };
      } catch (e) {
        subs[a.network] = { error: (e as Error).message };
      }
    }
    out.subscriptions = subs;
    return out;
  }
}
