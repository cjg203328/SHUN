import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { TokenUser } from '../../modules/auth/domain/token-user';

export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): TokenUser => {
    const request = ctx.switchToHttp().getRequest<{ user: TokenUser }>();
    return request.user;
  },
);

