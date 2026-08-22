import { Body, Controller, Get, Headers, Post, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiExcludeEndpoint, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { KycService } from './kyc.service';
import { KycStartResponseDto, KycStatusResponseDto, KycSubmitDto } from './dto/kyc.dto';

@ApiTags('kyc')
@Controller('kyc')
export class KycController {
  constructor(private readonly kyc: KycService) {}

  @Post('start')
  @ApiBearerAuth('bearer')
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Begin identity verification (returns SDK token)' })
  @ApiOkResponse({ type: KycStartResponseDto })
  start(@CurrentUser() user: AuthUser): Promise<KycStartResponseDto> {
    return this.kyc.start(user.userId);
  }

  @Post('submit')
  @ApiBearerAuth('bearer')
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Submit a manual verification (details + document images)' })
  @ApiOkResponse({ type: KycStatusResponseDto })
  submit(@CurrentUser() user: AuthUser, @Body() dto: KycSubmitDto) {
    return this.kyc.submitManual(user.userId, { ...dto });
  }

  @Get()
  @ApiBearerAuth('bearer')
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'My KYC status' })
  @ApiOkResponse({ type: KycStatusResponseDto })
  status(@CurrentUser() user: AuthUser): Promise<KycStatusResponseDto> {
    return this.kyc.status(user.userId) as Promise<KycStatusResponseDto>;
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
