import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { BrokersService } from './brokers.service';
import { BrokerDto, BrokerQueryDto } from './dto/broker.dto';

@ApiTags('brokers')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller('brokers')
export class BrokersController {
  constructor(private readonly brokers: BrokersService) {}

  @Get()
  @ApiOperation({ summary: 'List brokers, country-gated (contract §4.3)' })
  @ApiOkResponse({ type: [BrokerDto] })
  list(@Query() q: BrokerQueryDto): Promise<BrokerDto[]> {
    return this.brokers.list(q.country);
  }
}
