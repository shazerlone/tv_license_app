import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsString, MaxLength, MinLength } from 'class-validator';

/** POST /auth/password/forgot */
export class ForgotPasswordDto {
  @ApiProperty({ example: 'trader@millimore.app' })
  @IsEmail()
  email: string;
}

/** POST /auth/password/reset */
export class ResetPasswordDto {
  @ApiProperty({ description: 'The token from the reset email.' })
  @IsString()
  @MinLength(1)
  token: string;

  @ApiProperty({ example: 'new-strong-password', writeOnly: true, minLength: 8 })
  @IsString()
  @MinLength(8)
  @MaxLength(200)
  newPassword: string;
}

/** POST /auth/password/change (authenticated) */
export class ChangePasswordDto {
  @ApiProperty({ writeOnly: true })
  @IsString()
  @MinLength(1)
  currentPassword: string;

  @ApiProperty({ example: 'new-strong-password', writeOnly: true, minLength: 8 })
  @IsString()
  @MinLength(8)
  @MaxLength(200)
  newPassword: string;
}

/** Generic ok response; forgot always returns ok to avoid account enumeration. */
export class ForgotPasswordResponseDto {
  @ApiProperty({ example: true }) ok: boolean;
  @ApiProperty({
    required: false,
    nullable: true,
    description: 'Dev-only: the reset token, surfaced when MAIL_PROVIDER=console (never in production).',
  })
  devToken?: string;
}
