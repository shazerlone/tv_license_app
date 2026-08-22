import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class ConfigDepositMethodDto {
  @ApiProperty({ example: 'crypto' }) id: string;
  @ApiProperty({ example: 'Crypto (USDT / BTC)' }) label: string;
  @ApiProperty({ example: true }) active: boolean;
  @ApiPropertyOptional({ example: false }) comingSoon?: boolean;
}

/** GET /config — public platform config the app reads on launch. */
export class PublicConfigDto {
  @ApiProperty({ example: 500 }) maxLeverage: number;
  @ApiProperty({ example: 100 }) defaultLeverage: number;
  @ApiProperty({ example: 10 }) minDeposit: number;
  @ApiProperty({ example: 10 }) minWithdrawal: number;
  @ApiProperty({ example: 25000 }) maxWithdrawalPerTx: number;
  @ApiProperty({ example: 50000 }) maxWithdrawalPerDay: number;
  @ApiProperty({ example: true }) kycRequiredForWithdrawal: boolean;
  @ApiProperty({ type: [ConfigDepositMethodDto] }) depositMethods: ConfigDepositMethodDto[];
  @ApiProperty({ example: false }) maintenanceMode: boolean;
}
