import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import { AppModule } from './app.module';
import { buildOpenApiConfig } from './openapi';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { RealtimeGateway } from './realtime/realtime.gateway';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { bufferLogs: false });
  const config = app.get(ConfigService);

  const apiPrefix = config.get<string>('API_PREFIX', 'v1');
  app.setGlobalPrefix(apiPrefix);

  const origins = config
    .get<string>('CORS_ORIGINS', '')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);
  // '*' (or empty) → reflect any origin. Reflecting is required alongside
  // credentials:true, since browsers reject a literal '*' with credentials.
  const allowAll = origins.length === 0 || origins.includes('*');
  app.enableCors({
    origin: allowAll ? true : origins,
    credentials: true,
  });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: false,
    }),
  );
  app.useGlobalFilters(new HttpExceptionFilter());

  // Clean shutdown on SIGTERM (ECS/Fargate rolling deploys, K8s) so Prisma and
  // Redis disconnect and in-flight requests drain.
  app.enableShutdownHooks();

  // Swagger / OpenAPI generated from the same decorators the routes use.
  const document = SwaggerModule.createDocument(app, buildOpenApiConfig().build());
  SwaggerModule.setup(`${apiPrefix}/docs`, app, document);

  // Attach the realtime WebSocket gateway to the same HTTP server (/v1/ws).
  app.get(RealtimeGateway).bind(app.getHttpServer());

  const port = Number(config.get<string>('PORT', '3000'));
  // Bind to 0.0.0.0 so the container is reachable on hosts like Render.
  await app.listen(port, '0.0.0.0');
  new Logger('Bootstrap').log(
    `Millimore API on http://localhost:${port}/${apiPrefix}  (docs: /${apiPrefix}/docs)`,
  );
}
bootstrap();
