import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { AuthService } from '../../modules/auth/application/auth.service';
import { BusinessError, ErrorCode } from '../errors/error-codes';

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(private readonly authService: AuthService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<{
      headers: Record<string, string | undefined>;
      user?: unknown;
    }>();

    const authHeader = request.headers.authorization ?? '';
    const token = authHeader.startsWith('Bearer ')
      ? authHeader.substring('Bearer '.length)
      : '';

    if (!token) {
      throw new BusinessError(
        ErrorCode.AuthTokenInvalid,
        401,
        'Missing access token',
      );
    }

    const user = await this.authService.validateAccessToken(token);
    if (!user) {
      throw new BusinessError(
        ErrorCode.AuthTokenInvalid,
        401,
        'Invalid access token',
      );
    }

    request.user = user;
    return true;
  }
}
