import {
  CallHandler,
  ExecutionContext,
  Injectable,
  Logger,
  NestInterceptor,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { Observable } from 'rxjs';
import { finalize } from 'rxjs/operators';

@Injectable()
export class RequestLoggingInterceptor implements NestInterceptor {
  private readonly logger = new Logger(RequestLoggingInterceptor.name);

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const httpContext = context.switchToHttp();
    const request = httpContext.getRequest<{
      method: string;
      originalUrl: string;
      headers: Record<string, string | string[] | undefined>;
      requestId?: string;
    }>();
    const response = httpContext.getResponse<{
      statusCode: number;
      setHeader: (name: string, value: string) => void;
    }>();

    const startedAt = Date.now();
    const requestIdHeader = request.headers['x-request-id'];
    const requestId =
      (Array.isArray(requestIdHeader) ? requestIdHeader[0] : requestIdHeader) ??
      randomUUID();

    request.requestId = requestId;
    response.setHeader('x-request-id', requestId);

    return next.handle().pipe(
      finalize(() => {
        const durationMs = Date.now() - startedAt;
        this.logger.log(
          `${request.method} ${request.originalUrl} ${response.statusCode} ${durationMs}ms request_id=${requestId}`,
        );
      }),
    );
  }
}

