import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, MinLength } from 'class-validator';

/** Verification details surfaced to admins — NEVER includes investorPassword. */
export class ApplicationVerificationDto {
  @ApiProperty({ example: 'MetaTrader 5' }) platform: string;
  @ApiPropertyOptional({ nullable: true }) server: string | null;
  @ApiPropertyOptional({ nullable: true }) account: string | null;
  @ApiPropertyOptional({ nullable: true }) statementUrl: string | null;
  @ApiProperty({ description: 'Whether an investor password was provided.' })
  hasInvestorPassword: boolean;
}

/** Applicant summary embedded in a queue item. */
export class ApplicationUserDto {
  @ApiProperty() id: string;
  @ApiProperty() name: string;
  @ApiProperty() username: string;
  @ApiPropertyOptional({ nullable: true }) email: string | null;
  @ApiPropertyOptional({ nullable: true }) phone: string | null;
  @ApiPropertyOptional({ nullable: true }) photoUrl: string | null;
  @ApiPropertyOptional({ nullable: true }) residenceCountry: string | null;
}

/** A creator verification application (contract §6 GET /admin/creators/pending). */
export class ApplicationDto {
  @ApiProperty({ example: 'capp_1' }) id: string;
  @ApiProperty({ example: 'u_1' }) userId: string;
  @ApiProperty({ type: ApplicationUserDto }) user: ApplicationUserDto;
  @ApiProperty({ enum: ['none', 'pending', 'approved', 'rejected', 'suspended'] })
  status: string;
  @ApiProperty({ example: 'Forex' }) market: string;
  @ApiProperty({ example: 'MetaTrader 5' }) platform: string;
  @ApiProperty({ type: ApplicationVerificationDto }) verification: ApplicationVerificationDto;
  @ApiPropertyOptional({ nullable: true }) reviewerNote: string | null;
  @ApiPropertyOptional({ nullable: true }) rejectReason: string | null;
  @ApiProperty() createdAt: string;
}

/** POST /admin/creators/{id}/approve body. */
export class ApproveDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  note?: string;
}

/** POST /admin/creators/{id}/reject body. */
export class RejectDto {
  @ApiProperty()
  @IsString()
  @MinLength(1)
  reason: string;
}
