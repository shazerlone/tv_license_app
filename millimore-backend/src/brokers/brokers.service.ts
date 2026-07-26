import { Injectable } from '@nestjs/common';
import { Broker } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { BrokerDto } from './dto/broker.dto';

@Injectable()
export class BrokersService {
  constructor(private readonly prisma: PrismaService) {}

  toDto(b: Broker): BrokerDto {
    return {
      id: b.id,
      name: b.name,
      domain: b.domain,
      logoUrl: b.logoUrl,
      recommended: b.recommended,
    };
  }

  /**
   * Country-gated list (contract §4.3). A broker with an empty `countries`
   * list is available everywhere; otherwise it must include the country.
   */
  async list(country?: string): Promise<BrokerDto[]> {
    const iso = country?.toUpperCase();
    const brokers = await this.prisma.broker.findMany({
      where: iso ? { OR: [{ countries: { isEmpty: true } }, { countries: { has: iso } }] } : {},
      orderBy: [{ recommended: 'desc' }, { sortOrder: 'asc' }, { name: 'asc' }],
    });
    return brokers.map((b) => this.toDto(b));
  }
}
