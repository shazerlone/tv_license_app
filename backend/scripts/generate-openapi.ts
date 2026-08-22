/**
 * Generates a static OpenAPI/Swagger spec (openapi.json) from the live Nest
 * decorators — no server needs to be running. Keeps the published spec in sync
 * with the code, which is in turn kept in sync with docs/BACKEND_CONTRACT.md.
 *
 * Run: npm run openapi:gen
 */
import { NestFactory } from '@nestjs/core';
import { SwaggerModule } from '@nestjs/swagger';
import { writeFileSync } from 'fs';
import { join } from 'path';
import { AppModule } from '../src/app.module';
import { buildOpenApiConfig } from '../src/openapi';

async function generate() {
  const app = await NestFactory.create(AppModule, { logger: false });
  app.setGlobalPrefix('v1');
  const document = SwaggerModule.createDocument(app, buildOpenApiConfig().build());
  const out = join(process.cwd(), 'openapi.json');
  writeFileSync(out, JSON.stringify(document, null, 2));
  await app.close();
  // eslint-disable-next-line no-console
  console.log(`OpenAPI spec written to ${out}`);
}

generate().catch((e) => {
  // eslint-disable-next-line no-console
  console.error(e);
  process.exit(1);
});
