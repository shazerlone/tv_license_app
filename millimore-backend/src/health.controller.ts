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
    };
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
