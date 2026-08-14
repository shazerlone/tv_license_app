import { Controller, Get } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { SkipThrottle } from '@nestjs/throttler';

@ApiTags('system')
@Controller('health')
@SkipThrottle() // liveness probe is hit continuously by the load balancer
export class HealthController {
  @Get()
  @ApiOperation({ summary: 'Liveness probe' })
  health() {
    return { status: 'ok', service: 'millimore-backend', ts: new Date().toISOString() };
  }
}
