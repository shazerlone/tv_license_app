import { Injectable, Logger, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger('PrismaService');

  async onModuleInit() {
    // Tolerate a missing DB at boot (e.g. when generating the OpenAPI spec):
    // Prisma connects lazily on first query anyway.
    try {
      await this.$connect();
    } catch (err) {
      this.logger.warn(
        `Database not reachable at startup (${(err as Error).message}). ` +
          'Will retry on first query.',
      );
    }
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
