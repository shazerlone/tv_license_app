import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { ReferralsService } from './referrals.service';
import { ApplyReferralDto, ReferralMeDto, ReferredUserDto } from './dto/referral.dto';

@ApiTags('referrals')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller('referrals')
export class ReferralsController {
  constructor(private readonly referrals: ReferralsService) {}

  @Get('me')
  @ApiOperation({ summary: 'My referral dashboard (code, link, earnings)' })
  @ApiOkResponse({ type: ReferralMeDto })
  mine(@CurrentUser() user: AuthUser): Promise<ReferralMeDto> {
    return this.referrals.mine(user.userId);
  }

  @Get()
  @ApiOperation({ summary: 'People I referred + what I earned from each' })
  @ApiOkResponse({ type: [ReferredUserDto] })
  list(@CurrentUser() user: AuthUser): Promise<ReferredUserDto[]> {
    return this.referrals.listReferred(user.userId);
  }

  @Post('apply')
  @ApiOperation({ summary: 'Attach a referral code to my account (once)' })
  apply(@CurrentUser() user: AuthUser, @Body() dto: ApplyReferralDto) {
    return this.referrals.apply(user.userId, dto.code);
  }
}
