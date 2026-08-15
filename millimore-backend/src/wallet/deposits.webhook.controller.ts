import { Body, Controller, Headers, Post, Req, RawBodyRequest } from '@nestjs/common';
import type { Request } from 'express';
import { ApiExcludeController } from '@nestjs/swagger';
import { DepositsService } from './deposits.service';

/**
 * Public crypto-processor webhook. Not behind JwtAuthGuard — the processor
 * authenticates via the HMAC signature over the raw body (verified in the
 * service against CRYPTO_WEBHOOK_SECRET). Point your provider's webhook here.
 */
@ApiExcludeController()
@Controller('webhooks/deposits')
export class DepositsWebhookController {
  constructor(private readonly deposits: DepositsService) {}

  @Post('crypto')
  crypto(
    @Req() req: RawBodyRequest<Request>,
    @Headers('x-signature') signature: string | undefined,
    @Body() body: { depositId?: string; txRef?: string },
  ): Promise<{ ok: true }> {
    const raw = req.rawBody?.toString('utf8') ?? JSON.stringify(body ?? {});
    return this.deposits.confirmViaWebhook(raw, signature, body ?? {});
  }
}
