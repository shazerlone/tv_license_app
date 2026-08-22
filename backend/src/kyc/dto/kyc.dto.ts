import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

/** GET /kyc — the user's current verification status. */
export class KycStatusResponseDto {
  @ApiProperty({ enum: ['none', 'pending', 'verified', 'rejected'] })
  kycStatus: string;
  @ApiPropertyOptional({ nullable: true, example: 'sumsub' })
  provider: string | null;
  @ApiPropertyOptional({ nullable: true })
  reason: string | null;
}

/** POST /kyc/start — SDK handoff for the provider flow. */
export class KycStartResponseDto {
  @ApiProperty({ example: 'sumsub' }) provider: string;
  @ApiProperty({ example: 'appl_abc123' }) applicantId: string;
  @ApiProperty({ example: '_act-sbx-…', description: 'Short-lived SDK token.' })
  accessToken: string;
  @ApiPropertyOptional({ example: false, description: 'true when no provider is configured (manual review).' })
  manual?: boolean;
}
