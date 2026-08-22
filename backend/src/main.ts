import { NestFactory } from '@nestjs/core';
import type { NestExpressApplication } from '@nestjs/platform-express';
import { ValidationPipe, Logger } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { buildOpenApiConfig } from './openapi';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { RealtimeGateway } from './realtime/realtime.gateway';

async function bootstrap() {
  // rawBody:true captures the unparsed body so the KYC (Sumsub) webhook can
  // verify the payload signature; JSON parsing still works as normal.
  const app = await NestFactory.create<NestExpressApplication>(AppModule, { bufferLogs: false, rawBody: true });
  const config = app.get(ConfigService);

  // Base64 image uploads (POST /uploads) can be several MB — the default ~100KB
  // body limit would 413 real photos before the handler's own 8MB check runs.
  // Raise JSON + urlencoded limits to comfortably cover an 8MB file base64-encoded
  // (~10.7MB) plus overhead. Env override via BODY_LIMIT (e.g. "16mb").
  const bodyLimit = config.get<string>('BODY_LIMIT', '12mb');
  app.useBodyParser('json', { limit: bodyLimit });
  app.useBodyParser('urlencoded', { limit: bodyLimit, extended: true });

  // Behind an ALB/CloudFront, trust the proxy so req.ip is the real client (used
  // by the rate limiter) and secure-cookie/redirect logic is correct.
  app.getHttpAdapter().getInstance().set('trust proxy', 1);

  // Security headers. Keep CSP off here — the API serves JSON, and the admin SPA
  // it also hosts sets its own; enabling a strict CSP would break the SPA/Swagger.
  app.use(helmet({ contentSecurityPolicy: false, crossOriginEmbedderPolicy: false }));

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
