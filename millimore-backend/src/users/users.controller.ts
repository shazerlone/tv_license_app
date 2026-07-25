import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags, ApiOkResponse } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { UsersService } from './users.service';
import { UpdateMeDto } from './dto/update-me.dto';
import { UserEnvelopeDto } from './dto/user.dto';

@ApiTags('users')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller()
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get('me')
  @ApiOperation({ summary: 'Get the authenticated user (contract §4.1 GET /me)' })
  @ApiOkResponse({ type: UserEnvelopeDto })
  async me(@CurrentUser() auth: AuthUser): Promise<UserEnvelopeDto> {
    const user = await this.users.findByIdOrThrow(auth.userId);
    return { user: this.users.toDto(user) };
  }

  @Patch('me')
  @ApiOperation({ summary: 'Update the authenticated user (contract §4.1 PATCH /me)' })
  @ApiOkResponse({ type: UserEnvelopeDto })
  async updateMe(
    @CurrentUser() auth: AuthUser,
    @Body() dto: UpdateMeDto,
  ): Promise<UserEnvelopeDto> {
    const user = await this.users.updateMe(auth.userId, dto);
    return { user: this.users.toDto(user) };
  }
}
