import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsString, ValidateNested } from 'class-validator';
import { VerificationDto } from '../../auth/dto/register.dto';

/** GET /creator/status response (contract §4.2). */
export class CreatorStatusDto {
  @ApiProperty({ enum: ['none', 'pending', 'approved', 'rejected', 'suspended'] })
  creatorStatus: string;

  @ApiPropertyOptional({ nullable: true, description: 'Present when rejected/suspended.' })
  reason?: string | null;
}

/** POST /creator/apply body (contract §4.2). */
export class ApplyCreatorDto {
  @ApiProperty({ example: 'Forex' })
  @IsString()
  market: string;

  @ApiProperty({ example: 'MetaTrader 5' })
  @IsString()
  platform: string;

  @ApiProperty({ type: VerificationDto })
  @ValidateNested()
  @Type(() => VerificationDto)
  verification: VerificationDto;
}
