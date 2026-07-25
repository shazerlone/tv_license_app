import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString } from 'class-validator';
import { UserDto } from '../../users/dto/user.dto';

/** POST /auth/otp/request */
export class OtpRequestDto {
  @ApiProperty({ example: '+91 90000 00000' })
  @IsString()
  phone: string;
}

export class OtpRequestResponseDto {
  @ApiProperty({ example: 'otp_9f8a...' }) requestId: string;
  @ApiPropertyOptional({
    description: 'Present only in dev/console OTP mode to ease app integration.',
    example: '123456',
  })
  devCode?: string;
}

/** POST /auth/otp/verify */
export class OtpVerifyDto {
  @ApiProperty({ example: 'otp_9f8a...' })
  @IsString()
  requestId: string;

  @ApiProperty({ example: '123456' })
  @IsString()
  code: string;
}

/** Standard auth response: { token, user }. */
export class AuthResponseDto {
  @ApiProperty({ example: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...' }) token: string;
  @ApiProperty({ type: UserDto }) user: UserDto;
}
