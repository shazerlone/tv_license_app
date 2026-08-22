import { ApiProperty } from '@nestjs/swagger';

/** GET /admin/metrics (contract §6) — real, live platform aggregates. */
export class AdminMetricsDto {
  @ApiProperty({ example: 128, description: 'Distinct users active in the last 24h.' })
  dau: number;
  @ApiProperty({ example: 940, description: 'Distinct users active in the last 30d.' })
  mau: number;
  @ApiProperty({ example: 3, description: 'Broadcasts currently live.' }) liveNow: number;
  @ApiProperty({ example: 12, description: 'Broadcasts started today (UTC).' })
  streamsToday: number;
  @ApiProperty({ example: 1543 }) totalUsers: number;
  @ApiProperty({ example: 87, description: 'Approved creators.' }) creators: number;
  @ApiProperty({ example: 250000, description: 'All-time copy allocation volume.' })
  gmv: number;
  @ApiProperty({ example: 82000, description: 'Currently active copy volume.' })
  copyVolume: number;
  @ApiProperty({ example: 310000, description: 'Total confirmed deposits.' })
  depositsTotal: number;
  @ApiProperty({ example: 74000, description: 'Sum of all user wallet balances (liabilities).' })
  walletLiabilities: number;
  @ApiProperty({ example: 5820, description: "Millimore's booked revenue (fee share)." })
  platformRevenue: number;
  @ApiProperty({ example: 4 }) pendingPayouts: number;
  @ApiProperty({ example: 1250.5 }) pendingPayoutAmount: number;
  @ApiProperty({ example: 0 }) errors24h: number;
  @ApiProperty({ example: 86400, description: 'Process uptime in seconds.' })
  uptime: number;
}
