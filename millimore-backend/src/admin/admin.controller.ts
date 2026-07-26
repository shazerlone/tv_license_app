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
import {
  AdminUserDto,
  AdminUserPageDto,
  AdminUsersQueryDto,
  UpdateAdminUserDto,
} from './dto/admin-user.dto';
import { ApplicationDto, ApproveDto, RejectDto } from './dto/application.dto';

@ApiTags('admin')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.admin)
@Controller('admin')
export class AdminController {
  constructor(private readonly admin: AdminService) {}

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
}
