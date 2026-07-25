import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsString, MinLength } from 'class-validator';

/** POST /auth/login */
export class LoginDto {
  @ApiProperty({ example: 'trader@millimore.app' })
  @IsEmail()
  email: string;

  @ApiProperty({ example: 'password', writeOnly: true })
  @IsString()
  @MinLength(1)
  password: string;
}

/** POST /auth/social/apple */
export class AppleSocialDto {
  @ApiProperty({ description: 'Apple identity token (JWT).' })
  @IsString()
  identityToken: string;
}

/** POST /auth/social/google */
export class GoogleSocialDto {
  @ApiProperty({ description: 'Google ID token (JWT).' })
  @IsString()
  idToken: string;
}
