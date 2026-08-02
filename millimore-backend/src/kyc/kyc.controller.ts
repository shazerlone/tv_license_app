import { Body, Controller, Get, Headers, Post, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiExcludeEndpoint, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { KycService } from './kyc.service';

@ApiTags('kyc')
@Controller('kyc')
export class KycController {
  constructor(private readonly kyc: KycService) {}

  @Post('start')
  @ApiBearerAuth('bearer')
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Begin identity verification (returns SDK token)' })
  start(@CurrentUser() user: AuthUser) {
    return this.kyc.start(user.userId);
  }

  @Get()
  @ApiBearerAuth('bearer')
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'My KYC status' })
  status(@CurrentUser() user: AuthUser) {
    return this.kyc.status(user.userId);
  }

  @Post('webhook')
  @ApiExcludeEndpoint() // provider → server callback, not for app/docs consumers
  webhook(
    @Headers() headers: Record<string, string>,
    @Req() req: Request & { rawBody?: Buffer },
    @Body() body: unknown,
  ) {
    const raw = req.rawBody ? req.rawBody.toString('utf8') : JSON.stringify(body ?? {});
    return this.kyc.handleWebhook(headers, raw);
  }
}
