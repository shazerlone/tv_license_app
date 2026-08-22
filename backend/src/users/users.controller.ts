import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Patch, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags, ApiOkResponse } from '@nestjs/swagger';
import { IsString, Length } from 'class-validator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { UsersService } from './users.service';
import { EmailVerificationService } from './email-verification.service';
import { UpdateMeDto } from './dto/update-me.dto';
import { UserEnvelopeDto } from './dto/user.dto';

class VerifyEmailDto {
  @IsString()
  @Length(4, 8)
  code: string;
}

@ApiTags('users')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller()
export class UsersController {
  constructor(
    private readonly users: UsersService,
    private readonly emailVerification: EmailVerificationService,
  ) {}

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

  @Post('me/email/send-code')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Email a verification code to the current email (resend)' })
  sendEmailCode(@CurrentUser() auth: AuthUser) {
    return this.emailVerification.sendCode(auth.userId);
  }

  @Post('me/email/verify')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Confirm the email verification code → marks email verified' })
  verifyEmail(@CurrentUser() auth: AuthUser, @Body() dto: VerifyEmailDto) {
    return this.emailVerification.verify(auth.userId, dto.code);
  }

  @Delete('me')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Permanently delete the authenticated account (frees email/phone).' })
  async deleteMe(@CurrentUser() auth: AuthUser): Promise<void> {
    await this.users.deleteMe(auth.userId);
  }
}
