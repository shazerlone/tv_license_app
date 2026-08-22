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

/** POST /kyc/submit — manual verification funnel (details + document images). */
export class KycSubmitDto {
  @ApiProperty({ example: 'Priya Sharma' }) fullName: string;
  @ApiProperty({ example: '1996-04-12', description: 'YYYY-MM-DD' }) dob: string;
  @ApiProperty({ example: 'IN', description: 'ISO country of the document' }) country: string;
  @ApiProperty({ enum: ['passport', 'id_card', 'drivers_license'] }) docType: string;
  @ApiProperty({ example: 'X1234567' }) docNumber: string;
  @ApiProperty({ description: 'Hosted URL of the document front image' }) frontUrl: string;
  @ApiPropertyOptional({ nullable: true, description: 'Back image (id_card / license)' }) backUrl?: string;
  @ApiProperty({ description: 'Hosted URL of the selfie image' }) selfieUrl: string;
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
