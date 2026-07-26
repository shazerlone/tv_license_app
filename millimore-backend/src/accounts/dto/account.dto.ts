import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, MinLength } from 'class-validator';

/** Contract §3 `TradingAccount` — never includes the password. */
export class TradingAccountDto {
  @ApiProperty({ example: 'acc_1' }) id: string;
  @ApiProperty({ example: 'xm' }) brokerId: string;
  @ApiProperty({ example: 'XM' }) brokerName: string;
  @ApiProperty({ example: '50231487' }) accountNumber: string;
  @ApiProperty({ example: '••••1487' }) masked: string;
  @ApiProperty({ example: 'XM-Live3' }) server: string;
  @ApiProperty({ example: 'USD' }) currency: string;
  @ApiProperty({ example: 5000 }) balance: number;
  @ApiProperty({ enum: ['connected', 'pending', 'disconnected', 'error'] }) status: string;
  @ApiProperty({ example: '2026-07-01T00:00:00Z' }) connectedAt: string;
}

/** POST /accounts body (contract §4.3). `password` is write-only. */
export class ConnectAccountDto {
  @ApiProperty({ example: 'xm' })
  @IsString()
  brokerId: string;

  @ApiProperty({ example: '50231487' })
  @IsString()
  accountNumber: string;

  @ApiProperty({ example: 'XM-Live3' })
  @IsString()
  server: string;

  @ApiProperty({ example: 'investor-or-trade-password', writeOnly: true })
  @IsString()
  @MinLength(1)
  password: string;

  @ApiPropertyOptional({ example: 'USD' })
  @IsOptional()
  @IsString()
  currency?: string;
}

/** POST /accounts/{id}/password body (contract §4.3). */
export class ChangeAccountPasswordDto {
  @ApiProperty({ writeOnly: true })
  @IsString()
  current: string;

  @ApiProperty({ writeOnly: true })
  @IsString()
  @MinLength(1)
  next: string;
}
