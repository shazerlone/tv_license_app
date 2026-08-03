import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Delete,
  HttpCode,
  HttpStatus,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { PermissionsGuard } from '../common/rbac/permissions.guard';
import { RequirePermissions } from '../common/rbac/require-permissions.decorator';
import { permissionsFor } from '../common/rbac/permissions';
import { KycStatus } from '@prisma/client';
import { AdminService } from './admin.service';
import { AnalyticsService } from './analytics.service';
import { PayoutsService } from '../payouts/payouts.service';
import { DepositsService } from '../wallet/deposits.service';
import { TransactionsService } from '../wallet/transactions.service';
import { SettingsService } from '../settings/settings.service';
import { KycService } from '../kyc/kyc.service';
import { AuditService } from '../audit/audit.service';
import { ReferralsService } from '../referrals/referrals.service';
import { SupportService } from '../support/support.service';
import { AnnouncementsService } from '../support/announcements.service';
import { AdminReplyDto, UpdateTicketDto } from '../support/dto/support.dto';
import { CreateAnnouncementDto, UpdateAnnouncementDto } from '../support/dto/announcement.dto';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import {
  AdminUserDto,
  AdminUserPageDto,
  AdminUsersQueryDto,
  UpdateAdminUserDto,
  AdminUserDetailDto,
  AdjustBalanceDto,
} from './dto/admin-user.dto';
import { ApplicationDto, ApproveDto, RejectDto } from './dto/application.dto';
import { AdminMetricsDto } from './dto/metrics.dto';
import { UpdateSettingsDto, ReasonDto } from './dto/settings.dto';
import {
  AdminPayoutDto,
  AdminPayoutsQueryDto,
  PayoutDecisionDto,
} from '../payouts/dto/payout.dto';
import { Paginated } from '../common/dto/pagination.dto';

@ApiTags('admin')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
@Roles(Role.admin)
@Controller('admin')
export class AdminController {
  constructor(
    private readonly admin: AdminService,
    private readonly analytics: AnalyticsService,
    private readonly payouts: PayoutsService,
    private readonly deposits: DepositsService,
    private readonly transactions: TransactionsService,
    private readonly settings: SettingsService,
    private readonly kyc: KycService,
    private readonly audit: AuditService,
    private readonly referrals: ReferralsService,
    private readonly support: SupportService,
    private readonly announcements: AnnouncementsService,
  ) {}

  @Get('me/permissions')
  @ApiOperation({ summary: 'The signed-in admin’s role + permission set' })
  async myPermissions(@CurrentUser() user: AuthUser) {
    const me = await this.admin.getAdminRole(user.userId);
    return { adminRole: me ?? 'superadmin', permissions: permissionsFor(me) };
  }

  @Get('team')
  @RequirePermissions('admins.manage')
  @ApiOperation({ summary: 'Back-office team (admins) + their roles' })
  team() {
    return this.admin.listAdmins();
  }

  @Post('team/:id/role')
  @HttpCode(HttpStatus.OK)
  @RequirePermissions('admins.manage')
  @ApiOperation({ summary: 'Assign an admin role (superadmin|finance|compliance|support|analyst)' })
  async setRole(@Param('id') id: string, @Body() body: { adminRole: string | null }, @CurrentUser() user: AuthUser) {
    const res = await this.admin.setAdminRole(id, body.adminRole || null);
    await this.audit.record(user.userId, 'admin.role.set', 'user', id, { adminRole: body.adminRole });
    return res;
  }

  @Get('referrals')
  @RequirePermissions('referrals.read')
  @ApiOperation({ summary: 'Top referrers by affiliate earnings' })
  topReferrers() {
    return this.referrals.adminTopReferrers();
  }

  // ── support (helpdesk) ─────────────────────────────────────────────
  @Get('support/tickets')
  @ApiOperation({ summary: 'Support tickets, filter by status' })
  @RequirePermissions('support.write')
  supportList(@Query('status') status?: string) {
    return this.support.adminList(status);
  }

  @Get('support/tickets/:id')
  @ApiOperation({ summary: 'Ticket thread incl. internal notes' })
  @RequirePermissions('support.write')
  supportGet(@Param('id') id: string) {
    return this.support.adminGet(id);
  }

  @Post('support/tickets/:id/messages')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Reply to a ticket (set internal:true for a private note)' })
  @RequirePermissions('support.write')
  supportReply(@Param('id') id: string, @Body() dto: AdminReplyDto, @CurrentUser() user: AuthUser) {
    return this.support.adminReply(id, user.userId, dto);
  }

  @Patch('support/tickets/:id')
  @ApiOperation({ summary: 'Update ticket status / priority' })
  @RequirePermissions('support.write')
  supportUpdate(@Param('id') id: string, @Body() dto: UpdateTicketDto) {
    return this.support.adminUpdate(id, dto);
  }

  // ── announcements ──────────────────────────────────────────────────
  @Get('announcements')
  @ApiOperation({ summary: 'All announcements (with read counts)' })
  announcementsList() {
    return this.announcements.adminList();
  }

  @Post('announcements')
  @ApiOperation({ summary: 'Create an announcement' })
  @RequirePermissions('announcements.write')
  async announcementsCreate(@Body() dto: CreateAnnouncementDto, @CurrentUser() user: AuthUser) {
    const res = await this.announcements.create(dto, user.userId);
    await this.audit.record(user.userId, 'announcement.create', 'announcement', res.id, { title: dto.title });
    return res;
  }

  @Patch('announcements/:id')
  @ApiOperation({ summary: 'Update an announcement' })
  @RequirePermissions('announcements.write')
  announcementsUpdate(@Param('id') id: string, @Body() dto: UpdateAnnouncementDto) {
    return this.announcements.update(id, dto);
  }

  @Delete('announcements/:id')
  @ApiOperation({ summary: 'Delete an announcement' })
  @RequirePermissions('announcements.write')
  announcementsRemove(@Param('id') id: string) {
    return this.announcements.remove(id);
  }

  @Get('metrics')
  @ApiOperation({ summary: 'Live platform metrics (contract §6)' })
  @ApiOkResponse({ type: AdminMetricsDto })
  metrics(): Promise<AdminMetricsDto> {
    return this.admin.metrics();
  }

  @Get('analytics')
  @ApiOperation({ summary: 'Business analytics — daily series, totals, top traders' })
  @RequirePermissions('analytics.read')
  analyticsOverview(@Query('days') days?: string) {
    return this.analytics.overview(days ? Number(days) : 30);
  }

  @Get('users')
  @ApiOperation({ summary: 'List users, paginated + filtered (contract §6)' })
  @RequirePermissions('users.read')
  @ApiOkResponse({ type: AdminUserPageDto })
  listUsers(@Query() q: AdminUsersQueryDto): Promise<AdminUserPageDto> {
    return this.admin.listUsers(q);
  }

  @Get('users/:id')
  @ApiOperation({ summary: 'User 360 — profile, wallet, stats, recent ledger' })
  @RequirePermissions('users.read')
  @ApiOkResponse({ type: AdminUserDetailDto })
  userDetail(@Param('id') id: string) {
    return this.admin.userDetail(id);
  }

  @Patch('users/:id')
  @ApiOperation({ summary: 'Update a user: role / banned / frozen / note / creatorStatus' })
  @RequirePermissions('users.write')
  @ApiOkResponse({ type: AdminUserDto })
  async updateUser(
    @Param('id') id: string,
    @Body() dto: UpdateAdminUserDto,
    @CurrentUser() user: AuthUser,
  ): Promise<AdminUserDto> {
    const res = await this.admin.updateUser(id, dto);
    await this.audit.record(user.userId, 'user.update', 'user', id, { ...dto });
    return res;
  }

  @Post('users/:id/adjust')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Manually credit/debit a user wallet (audited)' })
  @RequirePermissions('wallet.adjust')
  async adjustBalance(
    @Param('id') id: string,
    @Body() dto: AdjustBalanceDto,
    @CurrentUser() user: AuthUser,
  ) {
    const res = await this.admin.adjustBalance(id, dto.amount, dto.reason, user.userId);
    await this.audit.record(user.userId, 'wallet.adjust', 'user', id, { amount: dto.amount, reason: dto.reason });
    return res;
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
  @RequirePermissions('creators.approve')
  @ApiOkResponse({ type: ApplicationDto })
  approve(@Param('id') id: string, @Body() dto: ApproveDto): Promise<ApplicationDto> {
    return this.admin.approveCreator(id, dto.note);
  }

  @Post('creators/:id/reject')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Reject a creator application (contract §6)' })
  @RequirePermissions('creators.approve')
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
  @RequirePermissions('payouts.approve')
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
  @RequirePermissions('payouts.approve')
  @ApiOkResponse({ type: AdminPayoutDto })
  rejectPayout(
    @Param('id') id: string,
    @Body() dto: PayoutDecisionDto,
    @CurrentUser() user: AuthUser,
  ): Promise<AdminPayoutDto> {
    return this.payouts.reject(id, user.userId, dto.reason ?? 'Rejected');
  }

  @Post('payouts/:id/flag')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Flag / unflag a withdrawal for risk review' })
  @RequirePermissions('payouts.approve')
  async flagPayout(
    @Param('id') id: string,
    @Body() dto: { flagged?: boolean; reason?: string },
    @CurrentUser() user: AuthUser,
  ): Promise<AdminPayoutDto> {
    const flagged = dto.flagged !== false;
    const res = await this.payouts.setFlag(id, flagged, dto.reason);
    await this.audit.record(user.userId, flagged ? 'payout.flag' : 'payout.unflag', 'payout', id, { reason: dto.reason });
    return res;
  }

  // ── settings (contract §12) ────────────────────────────────────────
  @Get('settings')
  @ApiOperation({ summary: 'Platform settings (fee, limits, leverage, methods)' })
  getSettings() {
    return this.settings.get();
  }

  @Patch('settings')
  @ApiOperation({ summary: 'Update platform settings (contract §12)' })
  @RequirePermissions('settings.write')
  async updateSettings(@Body() dto: UpdateSettingsDto, @CurrentUser() user: AuthUser) {
    const res = await this.settings.update(dto);
    await this.audit.record(user.userId, 'settings.update', 'settings', 'platform', { ...dto });
    return res;
  }

  // ── transactions (deposits + withdrawals) ──────────────────────────
  @Get('transactions')
  @ApiOperation({ summary: 'Money-ops feed: deposits + withdrawals, filterable' })
  adminTransactions(
    @Query('kind') kind?: 'deposit' | 'withdrawal',
    @Query('status') status?: string,
    @Query('flagged') flagged?: string,
    @Query('limit') limit?: string,
    @Query('cursor') cursor?: string,
  ) {
    return this.transactions.adminList({
      kind,
      status,
      flagged: flagged === undefined ? undefined : flagged === 'true',
      limit: limit ? Number(limit) : undefined,
      cursor,
    });
  }

  // ── deposits ops ───────────────────────────────────────────────────
  @Post('deposits/:id/approve')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Approve a pending deposit → credit the wallet' })
  @RequirePermissions('payouts.approve')
  async approveDeposit(@Param('id') id: string, @CurrentUser() user: AuthUser) {
    const res = await this.deposits.adminApprove(id, user.userId);
    await this.audit.record(user.userId, 'deposit.approve', 'deposit', id);
    return res;
  }

  @Post('deposits/:id/reject')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Reject a deposit' })
  @RequirePermissions('payouts.approve')
  async rejectDeposit(@Param('id') id: string, @Body() dto: ReasonDto, @CurrentUser() user: AuthUser) {
    const res = await this.deposits.adminReject(id, user.userId, dto.reason ?? 'Rejected');
    await this.audit.record(user.userId, 'deposit.reject', 'deposit', id, { reason: dto.reason });
    return res;
  }

  @Post('deposits/:id/flag')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Flag / unflag a deposit for risk review' })
  @RequirePermissions('payouts.approve')
  async flagDeposit(
    @Param('id') id: string,
    @Body() dto: { flagged?: boolean; reason?: string },
    @CurrentUser() user: AuthUser,
  ) {
    const flagged = dto.flagged !== false;
    const res = await this.deposits.setFlag(id, flagged, dto.reason);
    await this.audit.record(user.userId, flagged ? 'deposit.flag' : 'deposit.unflag', 'deposit', id, { reason: dto.reason });
    return res;
  }

  // ── KYC ────────────────────────────────────────────────────────────
  @Get('kyc')
  @ApiOperation({ summary: 'KYC submissions, filter by status' })
  @RequirePermissions('kyc.decide')
  kycList(@Query('status') status?: string, @Query('limit') limit?: string, @Query('cursor') cursor?: string) {
    return this.kyc.adminList({ status, limit: limit ? Number(limit) : undefined, cursor });
  }

  @Post('kyc/:userId/verify')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Manually mark a user KYC-verified' })
  @RequirePermissions('kyc.decide')
  async verifyKyc(@Param('userId') userId: string, @CurrentUser() user: AuthUser) {
    await this.kyc.setStatus(userId, KycStatus.verified);
    await this.audit.record(user.userId, 'kyc.verify', 'kyc', userId);
    return { ok: true };
  }

  @Post('kyc/:userId/reject')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Reject a user KYC with a reason' })
  @RequirePermissions('kyc.decide')
  async rejectKyc(@Param('userId') userId: string, @Body() dto: ReasonDto, @CurrentUser() user: AuthUser) {
    await this.kyc.setStatus(userId, KycStatus.rejected, dto.reason ?? 'Rejected');
    await this.audit.record(user.userId, 'kyc.reject', 'kyc', userId, { reason: dto.reason });
    return { ok: true };
  }

  // ── audit trail ────────────────────────────────────────────────────
  @Get('audit')
  @ApiOperation({ summary: 'Admin action audit log (contract §12)' })
  @RequirePermissions('audit.read')
  auditLog(@Query('targetType') targetType?: string, @Query('limit') limit?: string, @Query('cursor') cursor?: string) {
    return this.audit.list({ targetType, limit: limit ? Number(limit) : undefined, cursor });
  }
}
