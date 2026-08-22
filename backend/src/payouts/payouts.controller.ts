import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { PayoutsService } from './payouts.service';
import { PayoutDto, RequestPayoutDto } from './dto/payout.dto';

/** Creator-facing payout endpoints (contract §5b). Admin side lives in /admin. */
@ApiTags('creator')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller('creator/payouts')
export class PayoutsController {
  constructor(private readonly payouts: PayoutsService) {}

  @Get()
  @ApiOperation({ summary: 'My payout requests, newest first (contract §5b)' })
  @ApiOkResponse({ type: [PayoutDto] })
  listMine(@CurrentUser() user: AuthUser): Promise<PayoutDto[]> {
    return this.payouts.listMine(user.userId);
  }

  @Post()
  @ApiOperation({ summary: 'Request a withdrawal against available balance (contract §5b)' })
  @ApiOkResponse({ type: PayoutDto })
  request(
    @CurrentUser() user: AuthUser,
    @Body() dto: RequestPayoutDto,
  ): Promise<PayoutDto> {
    return this.payouts.request(user.userId, dto);
  }
}
