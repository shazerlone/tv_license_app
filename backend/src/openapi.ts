import { DocumentBuilder } from '@nestjs/swagger';

/**
 * Shared OpenAPI metadata. Used both by the live /docs endpoint (main.ts) and
 * the static spec generator (scripts/generate-openapi.ts) so they never drift.
 */
export function buildOpenApiConfig(): DocumentBuilder {
  return new DocumentBuilder()
    .setTitle('Millimore API')
    .setDescription(
      'Backend API for the Millimore platform (mobile app + admin dashboard). ' +
        'Single source of truth: docs/BACKEND_CONTRACT.md',
    )
    .setVersion('1.0.0')
    .addServer('https://api.millimore.app/v1', 'Production')
    .addServer('http://localhost:3000/v1', 'Local')
    .addBearerAuth(
      { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
      'bearer',
    )
    .addTag('auth', 'Auth & onboarding (contract §4.1)')
    .addTag('users', 'Current user (contract §4.1)')
    .addTag('creator', 'Creator verification (contract §4.2)');
}
