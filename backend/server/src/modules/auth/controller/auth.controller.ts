import { Body, Controller, Headers, Post } from '@nestjs/common';
import { ok } from '../../../common/dto/api-response.dto';
import { AuthService } from '../application/auth.service';
import { LogoutDto } from '../dto/logout.dto';
import { RefreshTokenDto } from '../dto/refresh-token.dto';
import { SendOtpDto } from '../dto/send-otp.dto';
import { VerifyOtpDto } from '../dto/verify-otp.dto';
import { BusinessError, ErrorCode } from '../../../common/errors/error-codes';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('otp/send')
  async sendOtp(@Body() dto: SendOtpDto) {
    const result = await this.authService.sendOtp(dto.phone);
    return ok({
      requestId: result.requestId,
      expireSeconds: result.expireSeconds,
    });
  }

  @Post('otp/verify')
  async verifyOtp(@Body() dto: VerifyOtpDto) {
    const result = await this.authService.verifyOtp(
      dto.phone,
      dto.code,
      dto.requestId,
      dto.deviceId,
    );
    return ok(result);
  }

  @Post('refresh')
  async refresh(@Body() dto: RefreshTokenDto) {
    const result = await this.authService.refreshToken(dto.refreshToken);
    return ok(result);
  }

  @Post('logout')
  async logout(
    @Headers('authorization') authHeader: string,
    @Body() _dto: LogoutDto,
  ) {
    const token = authHeader?.startsWith('Bearer ')
      ? authHeader.substring('Bearer '.length)
      : '';
    if (!token) {
      throw new BusinessError(
        ErrorCode.AuthTokenInvalid,
        401,
        'Missing access token',
      );
    }
    await this.authService.logout(token);
    return ok({ loggedOut: true });
  }
}
