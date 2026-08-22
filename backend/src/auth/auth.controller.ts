import {
  Body,
  Controller,
  Post,
  HttpCode,
  HttpStatus,
  UseGuards,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiOkResponse,
  ApiCreatedResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { RegisterFollowerDto, RegisterCreatorDto } from './dto/register.dto';
import {
  OtpRequestDto,
  OtpRequestResponseDto,
  OtpVerifyDto,
  AuthResponseDto,
} from './dto/otp.dto';
import { LoginDto, AppleSocialDto, GoogleSocialDto, FirebaseSignInDto } from './dto/login.dto';
import {
  ForgotPasswordDto,
  ForgotPasswordResponseDto,
  ResetPasswordDto,
  ChangePasswordDto,
} from './dto/password.dto';

// Sensitive auth endpoints get a tighter rate limit than the global default.
const AUTH_THROTTLE = { default: { limit: 10, ttl: 60_000 } };

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('register/follower')
  @ApiOperation({ summary: 'Register a follower (contract §4.1)' })
  @ApiCreatedResponse({ type: AuthResponseDto })
  registerFollower(@Body() dto: RegisterFollowerDto): Promise<AuthResponseDto> {
    return this.auth.registerFollower(dto);
  }

  @Post('register/creator')
  @ApiOperation({
    summary: 'Register a creator; opens a pending verification application (contract §4.1)',
  })
  @ApiCreatedResponse({ type: AuthResponseDto })
  registerCreator(@Body() dto: RegisterCreatorDto): Promise<AuthResponseDto> {
    return this.auth.registerCreator(dto);
  }

  @Post('otp/request')
  @HttpCode(HttpStatus.OK)
  @Throttle(AUTH_THROTTLE)
  @ApiOperation({ summary: 'Request an OTP for a phone number (contract §4.1)' })
  @ApiOkResponse({ type: OtpRequestResponseDto })
  otpRequest(@Body() dto: OtpRequestDto): Promise<OtpRequestResponseDto> {
    return this.auth.otpRequest(dto.phone);
  }

  @Post('otp/verify')
  @HttpCode(HttpStatus.OK)
  @Throttle(AUTH_THROTTLE)
  @ApiOperation({ summary: 'Verify an OTP and sign in (contract §4.1)' })
  @ApiOkResponse({ type: AuthResponseDto })
  otpVerify(@Body() dto: OtpVerifyDto): Promise<AuthResponseDto> {
    return this.auth.otpVerify(dto.requestId, dto.code);
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  @Throttle(AUTH_THROTTLE)
  @ApiOperation({ summary: 'Email + password login (contract §4.1)' })
  @ApiOkResponse({ type: AuthResponseDto })
  login(@Body() dto: LoginDto): Promise<AuthResponseDto> {
    return this.auth.login(dto.email, dto.password, dto.twofaCode);
  }

  @Post('password/forgot')
  @HttpCode(HttpStatus.OK)
  @Throttle(AUTH_THROTTLE)
  @ApiOperation({ summary: 'Start a password reset; emails a token (contract §4.1)' })
  @ApiOkResponse({ type: ForgotPasswordResponseDto })
  forgotPassword(@Body() dto: ForgotPasswordDto): Promise<ForgotPasswordResponseDto> {
    return this.auth.forgotPassword(dto.email);
  }

  @Post('password/reset')
  @HttpCode(HttpStatus.OK)
  @Throttle(AUTH_THROTTLE)
  @ApiOperation({ summary: 'Complete a password reset with the emailed token (contract §4.1)' })
  @ApiOkResponse({ schema: { example: { ok: true } } })
  resetPassword(@Body() dto: ResetPasswordDto): Promise<{ ok: true }> {
    return this.auth.resetPassword(dto.token, dto.newPassword);
  }

  @Post('password/change')
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('bearer')
  @ApiOperation({ summary: 'Change password for the logged-in user (contract §4.1)' })
  @ApiOkResponse({ schema: { example: { ok: true } } })
  changePassword(@CurrentUser() u: AuthUser, @Body() dto: ChangePasswordDto): Promise<{ ok: true }> {
    return this.auth.changePassword(u.userId, dto.currentPassword, dto.newPassword);
  }

  @Post('social/apple')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Sign in with Apple (contract §4.1)' })
  @ApiOkResponse({ type: AuthResponseDto })
  apple(@Body() dto: AppleSocialDto): Promise<AuthResponseDto> {
    return this.auth.socialApple(dto.identityToken);
  }

  @Post('social/google')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Sign in with Google (contract §4.1)' })
  @ApiOkResponse({ type: AuthResponseDto })
  google(@Body() dto: GoogleSocialDto): Promise<AuthResponseDto> {
    return this.auth.socialGoogle(dto.idToken);
  }

  @Post('firebase')
  @HttpCode(HttpStatus.OK)
  @Throttle(AUTH_THROTTLE)
  @ApiOperation({ summary: 'Exchange a Firebase Phone Auth ID token for a session (SMS OTP, no DLT)' })
  @ApiOkResponse({ type: AuthResponseDto })
  firebase(@Body() dto: FirebaseSignInDto): Promise<AuthResponseDto> {
    return this.auth.firebaseSignIn(dto.idToken);
  }

  @Post('logout')
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('bearer')
  @ApiOperation({
    summary: 'Log out (contract §4.1). Stateless JWT — client discards the token.',
  })
  logout(): { ok: true } {
    // JWTs are stateless; a token blacklist/rotation store is added with Redis
    // in a later milestone. For now the client drops the token.
    return { ok: true };
  }
}
