import { Inject, Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { BusinessError, ErrorCode } from '../../../common/errors/error-codes';
import { TokenUser } from '../domain/token-user';
import { UserEntity, UserSettingsEntity } from '../../shared/domain/entities';
import { AUTH_RUNTIME_STORE, USER_SETTINGS_STORE } from '../../shared/tokens';
import { UserSettingsStore } from '../../shared/ports/user-settings-store.port';
import { AuthRuntimeStore } from '../../shared/ports/auth-runtime-store.port';

export interface AuthResult {
  accessToken: string;
  refreshToken: string;
  user: TokenUser;
}

@Injectable()
export class AuthService {
  constructor(
    @Inject(USER_SETTINGS_STORE)
    private readonly userStore: UserSettingsStore,
    @Inject(AUTH_RUNTIME_STORE)
    private readonly runtimeStore: AuthRuntimeStore,
  ) {}

  async sendOtp(phone: string): Promise<{ requestId: string; expireSeconds: number }> {
    const requestId = `otp_${randomUUID()}`;
    const code = '123456';
    const expireSeconds = 60;
    await this.runtimeStore.saveOtp({
      requestId,
      phone,
      code,
      expiresAt: Date.now() + expireSeconds * 1000,
    });
    return { requestId, expireSeconds };
  }

  async verifyOtp(
    phone: string,
    code: string,
    requestId: string,
    deviceId: string,
  ): Promise<AuthResult> {
    const session = await this.runtimeStore.getOtp(requestId);
    if (!session || session.phone !== phone) {
      throw new BusinessError(
        ErrorCode.AuthOtpInvalid,
        400,
        'Invalid otp request',
      );
    }
    if (Date.now() > session.expiresAt) {
      throw new BusinessError(ErrorCode.AuthOtpExpired, 400, 'OTP expired');
    }
    if (session.code !== code) {
      throw new BusinessError(ErrorCode.AuthOtpInvalid, 400, 'OTP is incorrect');
    }

    await this.runtimeStore.deleteOtp(requestId);
    const user = await this.ensureUser(phone);
    const accessToken = `atk_${randomUUID()}`;
    const refreshToken = `rtk_${randomUUID()}`;

    await this.runtimeStore.saveAuthSession({
      accessToken,
      refreshToken,
      userId: user.userId,
      deviceId,
      createdAt: Date.now(),
    });

    return {
      accessToken,
      refreshToken,
      user: {
        userId: user.userId,
        uid: user.uid,
        phone: user.phone,
      },
    };
  }

  async refreshToken(
    refreshToken: string,
  ): Promise<{ accessToken: string; refreshToken: string }> {
    const session = await this.runtimeStore.getByRefreshToken(refreshToken);
    if (!session) {
      throw new BusinessError(
        ErrorCode.AuthTokenInvalid,
        401,
        'Invalid refresh token',
      );
    }

    await this.runtimeStore.deleteByRefreshToken(refreshToken);
    const nextAccess = `atk_${randomUUID()}`;
    const nextRefresh = `rtk_${randomUUID()}`;
    await this.runtimeStore.saveAuthSession({
      accessToken: nextAccess,
      refreshToken: nextRefresh,
      userId: session.userId,
      deviceId: session.deviceId,
      createdAt: Date.now(),
    });

    return { accessToken: nextAccess, refreshToken: nextRefresh };
  }

  async logout(accessToken: string): Promise<void> {
    await this.runtimeStore.deleteByAccessToken(accessToken);
  }

  async validateAccessToken(accessToken: string): Promise<TokenUser | null> {
    const session = await this.runtimeStore.getByAccessToken(accessToken);
    if (!session) return null;
    const user = await this.userStore.getUserById(session.userId);
    if (!user) return null;
    return { userId: user.userId, uid: user.uid, phone: user.phone };
  }

  private async ensureUser(phone: string): Promise<UserEntity> {
    const existing = await this.userStore.getUserByPhone(phone);
    if (existing) {
      return existing;
    }

    const now = new Date().toISOString();
    const user: UserEntity = {
      userId: randomUUID(),
      uid: this.generateUid(phone),
      phone,
      nickname: '神秘人',
      signature: '这个人很神秘，什么都没留下',
      status: '想找人聊聊',
      createdAt: now,
      updatedAt: now,
    };
    await this.userStore.saveUser(user);

    const settings: UserSettingsEntity = {
      userId: user.userId,
      invisibleMode: false,
      notificationEnabled: true,
      vibrationEnabled: true,
      dayThemeEnabled: false,
      transparentHomepage: false,
      portraitFullscreenBackground: false,
      updatedAt: now,
    };
    await this.userStore.saveSettings(settings);
    return user;
  }

  private generateUid(phone: string): string {
    let hash = 0;
    for (const codeUnit of phone.split('').map((c) => c.charCodeAt(0))) {
      hash = (hash * 131 + codeUnit) & 0x7fffffff;
    }
    const base = hash.toString(36).toUpperCase().padStart(6, '0');
    const tail = phone.slice(-4);
    return `SN${base.slice(-6)}${tail}`;
  }
}
