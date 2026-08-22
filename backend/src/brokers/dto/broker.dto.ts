import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, Length } from 'class-validator';

/** Contract §3 `Broker`. */
export class BrokerDto {
  @ApiProperty({ example: 'century' }) id: string;
  @ApiProperty({ example: 'Century' }) name: string;
  @ApiProperty({ example: 'centuryfinancial.ae' }) domain: string;
  @ApiPropertyOptional({ nullable: true }) logoUrl: string | null;
  @ApiProperty({ example: true }) recommended: boolean;
}

/** GET /brokers?country= query. */
export class BrokerQueryDto {
  @ApiPropertyOptional({ example: 'IN', description: 'ISO alpha-2 country filter.' })
  @IsOptional()
  @IsString()
  @Length(2, 2)
  country?: string;
}
