import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  HttpCode,
  HttpStatus,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { AdminService } from './admin.service';
import { PayoutsService } from '../payouts/payouts.service';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import {
  AdminUserDto,
  AdminUserPageDto,
  AdminUsersQueryDto,
  UpdateAdminUserDto,
} from './dto/admin-user.dto';
import { ApplicationDto, ApproveDto, RejectDto } from './dto/application.dto';
import { AdminMetricsDto } from './dto/metrics.dto';
import {
  AdminPayoutDto,
  AdminPayoutsQueryDto,
  PayoutDecisionDto,
} from '../payouts/dto/payout.dto';
import { Paginated } from '../common/dto/pagination.dto';

@ApiTags('admin')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.admin)
@Controller('admin')
export class AdminController {
  constructor(
    private readonly admin: AdminService,
    private readonly payouts: PayoutsService,
  ) {}

  @Get('metrics')
  @ApiOperation({ summary: 'Live platform metrics (contract §6)' })
  @ApiOkResponse({ type: AdminMetricsDto })
  metrics(): Promise<AdminMetricsDto> {
    return this.admin.metrics();
  }

  @Get('users')
  @ApiOperation({ summary: 'List users, paginated + filtered (contract §6)' })
  @ApiOkResponse({ type: AdminUserPageDto })
  listUsers(@Query() q: AdminUsersQueryDto): Promise<AdminUserPageDto> {
    return this.admin.listUsers(q);
  }

  @Patch('users/:id')
  @ApiOperation({ summary: 'Update a user: role / banned / creatorStatus (contract §6)' })
  @ApiOkResponse({ type: AdminUserDto })
  updateUser(
    @Param('id') id: string,
    @Body() dto: UpdateAdminUserDto,
  ): Promise<AdminUserDto> {
    return this.admin.updateUser(id, dto);
  }

  @Get('creators/pending')
  @ApiOperation({ summary: 'Creator verification queue (contract §6)' })
  @ApiOkResponse({ type: [ApplicationDto] })
  pending(): Promise<ApplicationDto[]> {
    return this.admin.pendingCreators();
  }

  @Post('creators/:id/approve')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Approve a creator application (contract §6)' })
  @ApiOkResponse({ type: ApplicationDto })
  approve(@Param('id') id: string, @Body() dto: ApproveDto): Promise<ApplicationDto> {
    return this.admin.approveCreator(id, dto.note);
  }

  @Post('creators/:id/reject')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Reject a creator application (contract §6)' })
  @ApiOkResponse({ type: ApplicationDto })
  reject(@Param('id') id: string, @Body() dto: RejectDto): Promise<ApplicationDto> {
    return this.admin.rejectCreator(id, dto.reason);
  }

  // ── payouts / withdrawals (contract §6) ────────────────────────────
  @Get('payouts')
  @ApiOperation({ summary: 'Withdrawal requests, paginated + filterable (contract §6)' })
  adminPayouts(@Query() q: AdminPayoutsQueryDto): Promise<Paginated<AdminPayoutDto>> {
    return this.payouts.adminList(q);
  }

  @Post('payouts/:id/approve')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Approve a withdrawal (contract §6)' })
  @ApiOkResponse({ type: AdminPayoutDto })
  approvePayout(
    @Param('id') id: string,
    @Body() dto: PayoutDecisionDto,
    @CurrentUser() user: AuthUser,
  ): Promise<AdminPayoutDto> {
    return this.payouts.approve(id, user.userId, dto.reason);
  }

  @Post('payouts/:id/reject')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Reject a withdrawal — refunds the held funds (contract §6)' })
  @ApiOkResponse({ type: AdminPayoutDto })
  rejectPayout(
    @Param('id') id: string,
    @Body() dto: PayoutDecisionDto,
    @CurrentUser() user: AuthUser,
  ): Promise<AdminPayoutDto> {
    return this.payouts.reject(id, user.userId, dto.reason ?? 'Rejected');
  }
}
