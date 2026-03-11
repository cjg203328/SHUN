import { INestApplication, ValidationPipe } from '@nestjs/common';
import type { NestExpressApplication } from '@nestjs/platform-express';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { mkdirSync } from 'fs';
import { resolve } from 'path';
import { GlobalExceptionFilter } from './common/filters/global-exception.filter';
import { RequestLoggingInterceptor } from './common/interceptors/request-logging.interceptor';

export function configureApp(app: INestApplication): void {
  app.setGlobalPrefix('api/v1');
  app.enableCors();
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
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
