import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

/** Contract §3 `User`. Serialized public shape — never includes credentials. */
export class UserDto {
  @ApiProperty({ example: 'u_123' }) id: string;
  @ApiProperty({ example: 'Marcus Sterling' }) name: string;
  @ApiProperty({ example: 'marcussterling' }) username: string;
  @ApiPropertyOptional({ example: 'marcus@x.com', nullable: true }) email: string | null;
  @ApiPropertyOptional({ example: '+91 90000 00000', nullable: true }) phone: string | null;
  @ApiPropertyOptional({ nullable: true }) photoUrl: string | null;
  @ApiProperty({ enum: ['follower', 'creator', 'admin'] }) role: string;
  @ApiProperty({ enum: ['none', 'pending', 'approved', 'rejected', 'suspended'] })
  creatorStatus: string;
  @ApiPropertyOptional({ example: 'IN', nullable: true }) residenceIso: string | null;
  @ApiPropertyOptional({ example: 'India', nullable: true }) residenceCountry: string | null;
  @ApiPropertyOptional({ example: 'Forex', nullable: true }) market: string | null;
  @ApiPropertyOptional({ example: 'MetaTrader 5', nullable: true }) platform: string | null;
  @ApiPropertyOptional({ nullable: true }) addressLine?: string | null;
  @ApiPropertyOptional({ nullable: true }) city?: string | null;
  @ApiPropertyOptional({ nullable: true }) postalCode?: string | null;
  @ApiProperty({ example: 100, description: 'Default leverage.' }) leverage: number;
  @ApiProperty({ enum: ['none', 'pending', 'verified', 'rejected'], description: 'KYC status.' })
  kycStatus: string;
  @ApiProperty({ example: false, description: 'Whether 2FA is enabled.' }) twofaEnabled: boolean;
  @ApiProperty({ example: '2026-01-01T00:00:00Z' }) createdAt: string;
}

/** Response envelope for endpoints that return a single user: { user }. */
export class UserEnvelopeDto {
  @ApiProperty({ type: UserDto }) user: UserDto;
}
