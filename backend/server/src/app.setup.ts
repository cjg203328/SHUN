import { INestApplication, ValidationPipe } from '@nestjs/common';
import type { NestExpressApplication } from '@nestjs/platform-express';
import helmet from 'helmet';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { mkdirSync } from 'fs';
import { resolve } from 'path';
import { GlobalExceptionFilter } from './common/filters/global-exception.filter';
import { RequestLoggingInterceptor } from './common/interceptors/request-logging.interceptor';

// Fail fast at startup if required secrets are missing
function assertRequiredEnv(): void {
  const appEnv = (process.env.APP_ENV ?? 'development').toLowerCase();
  if (appEnv === 'production') {
    const required = ['JWT_SECRET', 'DATABASE_URL'];
    const missing = required.filter((k) => !process.env[k]);
    if (missing.length > 0) {
      throw new Error(
        `[startup] Missing required env vars in production: ${missing.join(', ')}`,
      );
    }
    const secret = process.env.JWT_SECRET ?? '';
    if (secret.length < 32) {
      throw new Error(
        '[startup] JWT_SECRET must be at least 32 characters in production',
      );
    }
  } else if (!process.env.JWT_SECRET) {
    console.warn(
      '[startup] WARNING: JWT_SECRET not set — using insecure dev default. Never deploy without setting this.',
    );
  }
}

export function configureApp(app: INestApplication): void {
  assertRequiredEnv();

  app.use(helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' }, // allow /media/ static assets
  }));

  app.setGlobalPrefix('api/v1');

  const appEnv = (process.env.APP_ENV ?? 'development').toLowerCase();
  const allowedOrigins = process.env.ALLOWED_ORIGINS
    ? process.env.ALLOWED_ORIGINS.split(',')
    : ['http://localhost:3000', 'http://localhost:8080'];
  app.enableCors(
    appEnv === 'production'
      ? {
          origin: allowedOrigins,
          methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
          credentials: true,
        }
      : { origin: true, credentials: true },
  );

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
      stopAtFirstError: false,
    }),
  );
  app.useGlobalFilters(new GlobalExceptionFilter());
  app.useGlobalInterceptors(new RequestLoggingInterceptor());
  setupStaticMedia(app);
  setupOpenApi(app);
}

function setupStaticMedia(app: INestApplication): void {
  const mediaRoot = resolve(process.cwd(), 'storage', 'media');
  mkdirSync(mediaRoot, { recursive: true });
  (app as NestExpressApplication).useStaticAssets(mediaRoot, {
    prefix: '/media/',
  });
}

function setupOpenApi(app: INestApplication): void {
  const appEnv = (process.env.APP_ENV ?? 'development').toLowerCase();
  const isTest = appEnv === 'test';
  if (isTest) return;

  const builder = new DocumentBuilder()
    .setTitle('Sunliao Backend API')
    .setDescription('Sunliao app backend API docs')
    .setVersion('v1')
    .addBearerAuth()
    .build();

  const document = SwaggerModule.createDocument(app, builder);
  SwaggerModule.setup('api/docs', app, document);
}
