import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import { AppModule } from './app.module';
import { buildOpenApiConfig } from './openapi';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';

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
  app.enableCors({
    origin: origins.length ? origins : true,
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

  // Swagger / OpenAPI generated from the same decorators the routes use.
  const document = SwaggerModule.createDocument(app, buildOpenApiConfig().build());
  SwaggerModule.setup(`${apiPrefix}/docs`, app, document);

  const port = Number(config.get<string>('PORT', '3000'));
  await app.listen(port);
  new Logger('Bootstrap').log(
    `Millimore API on http://localhost:${port}/${apiPrefix}  (docs: /${apiPrefix}/docs)`,
  );
}
bootstrap();
