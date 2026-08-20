import { Controller, Get } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { SkipThrottle } from '@nestjs/throttler';

@ApiTags('system')
@Controller('health')
@SkipThrottle() // liveness probe is hit continuously by the load balancer
export class HealthController {
  @Get()
  @ApiOperation({ summary: 'Liveness probe + safety-mode readout (verifies what is actually deployed)' })
  health() {
    return {
      status: 'ok',
      service: 'millimore-backend',
      ts: new Date().toISOString(),
      // Safety flags so you can confirm the running image's config remotely.
      // depositAutoConfirm MUST be false in production.
      safety: {
        depositAutoConfirm: process.env.DEPOSIT_AUTO_CONFIRM === 'true',
        seedDemo: process.env.SEED_DEMO === 'true',
        cryptoProvider: (process.env.CRYPTO_DEPOSIT_PROVIDER ?? '').trim() || 'none',
      },
      // Deposit-funnel readiness so a monitor can verify the gate without auth.
      // addressProvider !== "none" means GET /deposits/addresses will issue
      // addresses to KYC-verified users (else it returns deposits_unavailable).
      deposits: this.depositStatus(),
      // Auto-sweep (consolidation) readout. "active" only when fully wired:
      // enabled flag + Gas Pump address mode + a KMS signatureId (non-custodial).
      sweep: this.sweepStatus(),
      // Which optional integrations are configured on THIS running server, so you
      // can see what's live vs still-missing without reading the env. Booleans/
      // labels only — never secrets.
      integrations: this.integrationsStatus(),
    };
  }

  private integrationsStatus() {
    const has = (k: string) => !!(process.env[k] ?? '').trim();
    const socialLogin = [
      has('GOOGLE_OAUTH_CLIENT_ID') && 'google',
      has('APPLE_CLIENT_ID') && 'apple',
      has('FACEBOOK_APP_ID') && 'facebook',
    ].filter(Boolean);
    const marketProvider = (process.env.MARKET_DATA_PROVIDER ?? '').trim().toLowerCase();
    return {
      // Live video ingest — falls back to a mock live-input without these.
      streaming: has('CLOUDFLARE_STREAM_TOKEN') && has('CLOUDFLARE_ACCOUNT_ID') ? 'cloudflare' : 'mock',
      // Mobile push (FCM HTTP v1). NOTE: real gate is the service account, not the
      // legacy FCM_SERVER_KEY. WS in-app events work regardless.
      push: has('FCM_SERVICE_ACCOUNT_JSON') || has('FCM_SERVICE_ACCOUNT_B64'),
      // Transactional email (password reset). 'console' = logs only, doesn't send.
      mail: (process.env.MAIL_PROVIDER ?? 'console').toLowerCase() !== 'console',
      // SMS OTP login. 'console' = codes only logged (dev), no real SMS.
      otp: (process.env.OTP_PROVIDER ?? 'console').toLowerCase() !== 'console' && has('OTP_PROVIDER_KEY'),
      // Upload storage: S3 when a bucket is set, else Postgres fallback.
      storage: has('STORAGE_BUCKET') && has('STORAGE_REGION') ? 's3' : 'db',
      // Market prices.
      marketData: marketProvider && (has('TWELVE_DATA_API_KEY') || has('FINNHUB_API_KEY')) ? marketProvider : 'none',
      socialLogin,
      youtube: has('YOUTUBE_OAUTH_CLIENT_ID'),
    };
  }

  private sweepStatus() {
    const enabled = process.env.SWEEP_ENABLED === 'true';
    const addressMode = (process.env.CRYPTO_ADDRESS_MODE ?? 'hd').toLowerCase();
    const kms = !!(process.env.TATUM_KMS_SIGNATURE_ID ?? '').trim();
    const master = !!(process.env.TATUM_GP_MASTER ?? process.env.TATUM_GP_MASTER_TRON ?? '').trim();
    const active = enabled && addressMode === 'gaspump' && kms && master;
    const mode = (process.env.SWEEP_MODE ?? 'batch').toLowerCase() === 'instant' ? 'instant' : 'batch';
    return { active, enabled, mode, addressMode, kmsSignatureId: kms, gpMaster: master };
  }

  private depositStatus() {
    const ap = (process.env.CRYPTO_ADDRESS_PROVIDER ?? '').trim().toLowerCase();
    const isProd = process.env.NODE_ENV === 'production';
    let addressProvider = 'none';
    if (ap === 'tatum' && process.env.TATUM_API_KEY) addressProvider = 'tatum';
    else if (ap === 'mock' && !isProd) addressProvider = 'mock';
    const live = addressProvider !== 'none';
    return {
      addressProvider,
      networks: live ? ['tron', 'ethereum', 'bsc'] : [],
      gate: live ? 'ready' : 'coming_soon',
    };
  }
}
