import { Body, Controller, Headers, Post, Req, RawBodyRequest } from '@nestjs/common';
import type { Request } from 'express';
import { ApiExcludeController } from '@nestjs/swagger';
import { DepositsService } from './deposits.service';

/**
 * Public crypto-processor webhook (IPN). Not behind JwtAuthGuard — the processor
 * authenticates via the signature over the raw body (verified in the service /
 * provider). Point your processor's webhook at POST /v1/webhooks/deposits/crypto.
 */
@ApiExcludeController()
@Controller('webhooks/deposits')
export class DepositsWebhookController {
  constructor(private readonly deposits: DepositsService) {}

  @Post('crypto')
  crypto(
    @Req() req: RawBodyRequest<Request>,
    @Headers() headers: Record<string, string | undefined>,
    @Body() body: { depositId?: string; txRef?: string },
  ): Promise<{ ok: true; status?: string }> {
    const raw = req.rawBody?.toString('utf8') ?? JSON.stringify(body ?? {});
    return this.deposits.confirmViaWebhook(raw, headers ?? {}, body ?? {});
  }

  // Address-based processor (Tatum Gas Pump, etc.): a deposit landed on a
  // per-user address → verify + credit the owner's wallet.
  @Post('chain')
  chain(
    @Req() req: RawBodyRequest<Request>,
    @Headers() headers: Record<string, string | undefined>,
    @Body() body: unknown,
  ): Promise<{ ok: true; credited: boolean }> {
    const raw = req.rawBody?.toString('utf8') ?? JSON.stringify(body ?? {});
    return this.deposits.handleChainWebhook(raw, headers ?? {});
  }
}
