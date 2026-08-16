import { BadRequestException, ForbiddenException, Injectable, Logger } from '@nestjs/common';
import { CryptoAddressService } from '../wallet/crypto/crypto-address.service';
import { DepositNetwork } from '../wallet/crypto/address-provider';

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

  async generateWallet(chain: string, token: string): Promise<{ chain: string; xpub: string; mnemonic: string; warning: string }> {
    const setupToken = process.env.WALLET_SETUP_TOKEN?.trim();
    if (!setupToken) {
      throw new ForbiddenException({ code: 'setup_disabled', message: 'Wallet setup is disabled. Set WALLET_SETUP_TOKEN to enable it temporarily.' });
    }
    if (!token || token !== setupToken) {
      throw new ForbiddenException({ code: 'bad_setup_token', message: 'Invalid setup token.' });
    }
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
    const setupToken = process.env.WALLET_SETUP_TOKEN?.trim();
    if (!setupToken) throw new ForbiddenException({ code: 'setup_disabled', message: 'Set WALLET_SETUP_TOKEN to enable this test.' });
    if (!token || token !== setupToken) throw new ForbiddenException({ code: 'bad_setup_token', message: 'Invalid setup token.' });

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
}
