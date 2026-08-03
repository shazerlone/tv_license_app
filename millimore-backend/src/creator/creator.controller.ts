import { Body, Controller, Get, Patch, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { CreatorService } from './creator.service';
import {
  CreatorStatusDto,
  ApplyCreatorDto,
  CreatorStatsDto,
  CreatorEarningsDto,
  SetCommissionDto,
  CommissionDto,
} from './dto/creator.dto';
import { UserDto } from '../users/dto/user.dto';

@ApiTags('creator')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller('creator')
export class CreatorController {
  constructor(private readonly creator: CreatorService) {}

  @Get('status')
  @ApiOperation({ summary: 'Get my creator verification status (contract §4.2)' })
  @ApiOkResponse({ type: CreatorStatusDto })
  status(@CurrentUser() user: AuthUser): Promise<CreatorStatusDto> {
    return this.creator.getStatus(user.userId);
  }

  @Get('stats')
  @ApiOperation({ summary: 'Creator dashboard stats (contract §5b)' })
  @ApiOkResponse({ type: CreatorStatsDto })
  stats(@CurrentUser() user: AuthUser): Promise<CreatorStatsDto> {
    return this.creator.stats(user.userId);
  }

  @Get('followers')
  @ApiOperation({ summary: 'Users who follow me (contract §5b)' })
  @ApiOkResponse({ type: [UserDto] })
  followers(@CurrentUser() user: AuthUser): Promise<UserDto[]> {
    return this.creator.followers(user.userId);
  }

  @Get('earnings')
  @ApiOperation({ summary: 'Creator earnings & payouts (contract §5b)' })
  @ApiOkResponse({ type: CreatorEarningsDto })
  earnings(@CurrentUser() user: AuthUser): Promise<CreatorEarningsDto> {
    return this.creator.earnings(user.userId);
  }

  @Get('commission')
  @ApiOperation({ summary: 'My current performance-fee % charged to copiers' })
  @ApiOkResponse({ type: CommissionDto })
  getCommission(@CurrentUser() user: AuthUser): Promise<CommissionDto> {
    return this.creator.getCommission(user.userId);
  }

  @Patch('commission')
  @ApiOperation({ summary: 'Set my performance-fee % charged to copiers (1–30)' })
  @ApiOkResponse({ type: CommissionDto })
  setCommission(
    @CurrentUser() user: AuthUser,
    @Body() dto: SetCommissionDto,
  ): Promise<CommissionDto> {
    return this.creator.setCommission(user.userId, dto.percent);
  }

  @Post('apply')
  @ApiOperation({ summary: 'Apply for creator verification (contract §4.2)' })
  @ApiOkResponse({ type: CreatorStatusDto })
  apply(
    @CurrentUser() user: AuthUser,
    @Body() dto: ApplyCreatorDto,
  ): Promise<CreatorStatusDto> {
    return this.creator.apply(user.userId, dto);
  }
}
