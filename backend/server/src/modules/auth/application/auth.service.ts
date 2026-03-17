import { Inject, Injectable } from '@nestjs/common';
import { createHmac, randomUUID } from 'crypto';
import { BusinessError, ErrorCode } from '../../../common/errors/error-codes';
import { TokenUser } from '../domain/token-user';
import { UserEntity, UserSettingsEntity } from '../../shared/domain/entities';
import { AUTH_RUNTIME_STORE, USER_SETTINGS_STORE } from '../../shared/tokens';
import { UserSettingsStore } from '../../shared/ports/user-settings-store.port';
import { AuthRuntimeStore } from '../../shared/ports/auth-runtime-store.port';

// Lightweight HS256 JWT — avoids @nestjs/jwt dependency
const JWT_SECRET = process.env.JWT_SECRET ?? 'dev-secret-change-in-production';
const ACCESS_TOKEN_TTL_S = 60 * 60 * 2;   // 2h
const REFRESH_TOKEN_TTL_S = 60 * 60 * 24 * 30; // 30d

function b64url(s: string): string {
  return Buffer.from(s).toString('base64url');
}

function signJwt(
  payload: Record<string, unknown>,
  expiresInSeconds: number,
): string {
  const header = b64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const body = b64url(
    JSON.stringify({ ...payload, iat: Math.floor(Date.now() / 1000), exp: Math.floor(Date.now() / 1000) + expiresInSeconds }),
  );
  const sig = createHmac('sha256', JWT_SECRET)
    .update(`${header}.${body}`)
    .digest('base64url');
  return `${header}.${body}.${sig}`;
}

function verifyJwt(token: string): Record<string, unknown> | null {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const [header, body, sig] = parts;
    const expected = createHmac('sha256', JWT_SECRET)
      .update(`${header}.${body}`)
      .digest('base64url');
    if (sig !== expected) return null;
    const payload = JSON.parse(Buffer.from(body, 'base64url').toString()) as Record<string, unknown>;
    if (typeof payload.exp === 'number' && Date.now() / 1000 > payload.exp) return null;
    return payload;
  } catch {
    return null;
  }
}

export interface AuthResult {
  accessToken: string;
  refreshToken: string;
  user: TokenUser;
}

const OTP_RATE_LIMIT_MS = 60_000;      // 60s between sends per phone
const OTP_MAX_ATTEMPTS = 5;            // max verify failures before lock
const OTP_LOCK_MS = 10 * 60_000;       // 10min lock after max failures

@Injectable()
export class AuthService {
  // phone -> last send timestamp
  private readonly otpSendTimes = new Map<string, number>();
  // requestId -> consecutive failure count
  private readonly otpFailCounts = new Map<string, number>();
  // phone -> locked-until timestamp
  private readonly otpLockUntil = new Map<string, number>();

  constructor(
    @Inject(USER_SETTINGS_STORE)
    private readonly userStore: UserSettingsStore,
    @Inject(AUTH_RUNTIME_STORE)
    private readonly runtimeStore: AuthRuntimeStore,
  ) {}

  async sendOtp(phone: string): Promise<{ requestId: string; expireSeconds: number }> {
    // Rate limit: one OTP send per phone per 60s
    const lastSent = this.otpSendTimes.get(phone) ?? 0;
    const cooldownRemaining = OTP_RATE_LIMIT_MS - (Date.now() - lastSent);
    if (cooldownRemaining > 0) {
      throw new BusinessError(
        ErrorCode.AuthOtpInvalid,
        429,
        `请等待 ${Math.ceil(cooldownRemaining / 1000)} 秒后再重试`,
      );
    }
    this.otpSendTimes.set(phone, Date.now());
    const requestId = `otp_${randomUUID()}`;
    // TODO: integrate real SMS provider; for now use env override or fixed dev code
    const code = process.env.OTP_OVERRIDE ??
      Math.floor(100000 + Math.random() * 900000).toString();
    const expireSeconds = 120;
    // Log code in dev; never log in production
    if (process.env.NODE_ENV !== 'production') {
      console.log(`[OTP] ${phone} → ${code}`);
    }
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
    // Check phone-level lock from too many failures
    const lockedUntil = this.otpLockUntil.get(phone) ?? 0;
    if (Date.now() < lockedUntil) {
      const waitSecs = Math.ceil((lockedUntil - Date.now()) / 1000);
      throw new BusinessError(
        ErrorCode.AuthOtpInvalid,
        429,
        `验证失败次数过多，请 ${waitSecs} 秒后重试`,
      );
    }

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
      const fails = (this.otpFailCounts.get(requestId) ?? 0) + 1;
      this.otpFailCounts.set(requestId, fails);
      if (fails >= OTP_MAX_ATTEMPTS) {
        this.otpLockUntil.set(phone, Date.now() + OTP_LOCK_MS);
        await this.runtimeStore.deleteOtp(requestId);
        this.otpFailCounts.delete(requestId);
        throw new BusinessError(
          ErrorCode.AuthOtpInvalid,
          429,
          '验证失败次数过多，账号已临时锁定 10 分钟',
        );
      }
      throw new BusinessError(ErrorCode.AuthOtpInvalid, 400, 'OTP is incorrect');
    }
    // Success: clear fail counter
    this.otpFailCounts.delete(requestId);

    await this.runtimeStore.deleteOtp(requestId);
    const user = await this.ensureUser(phone);
    const jti = randomUUID();
    const accessToken = signJwt(
      { sub: user.userId, uid: user.uid, jti, type: 'access' },
      ACCESS_TOKEN_TTL_S,
    );
    const refreshToken = signJwt(
      { sub: user.userId, jti: randomUUID(), type: 'refresh' },
      REFRESH_TOKEN_TTL_S,
    );

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
    const nextAccess = signJwt(
      { sub: session.userId, jti: randomUUID(), type: 'access' },
      ACCESS_TOKEN_TTL_S,
    );
    const nextRefresh = signJwt(
      { sub: session.userId, jti: randomUUID(), type: 'refresh' },
      REFRESH_TOKEN_TTL_S,
    );
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

  async deleteAccount(actor: TokenUser, accessToken: string): Promise<void> {
    // Invalidate all sessions for this user
    await this.runtimeStore.deleteByAccessToken(accessToken);
    // Mark user as deleted (soft delete — set phone to tombstone so slot is released)
    const user = await this.userStore.getUserById(actor.userId);
    if (user) {
      await this.userStore.saveUser({
        ...user,
        phone: `deleted:${user.userId}`,
        nickname: '已注销用户',
        signature: '',
      });
    }
  }

  async validateAccessToken(accessToken: string): Promise<TokenUser | null> {
    // Fast-fail: verify JWT signature and expiry before hitting the store
    const payload = verifyJwt(accessToken);
    if (!payload || payload['type'] !== 'access') return null;
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
