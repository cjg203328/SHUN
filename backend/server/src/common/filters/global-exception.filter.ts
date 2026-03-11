import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { BusinessError, ErrorCode } from '../errors/error-codes';

@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    if (exception instanceof BusinessError) {
      response.status(exception.status).json({
        code: exception.code,
        message: exception.message,
        detail: exception.detail,
        path: request.url,
      });
      return;
    }

    if (exception instanceof HttpException) {
      response.status(exception.getStatus()).json({
        code: ErrorCode.InvalidInput,
        message: exception.message,
        path: request.url,
      });
      return;
    }

    response.status(HttpStatus.INTERNAL_SERVER_ERROR).json({
      code: ErrorCode.InternalError,
      message: 'Internal server error',
      path: request.url,
    });
  }
}

