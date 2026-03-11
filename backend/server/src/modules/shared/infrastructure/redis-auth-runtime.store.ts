import Redis from 'ioredis';
import { AuthRuntimeStore } from '../ports/auth-runtime-store.port';
import { AuthSessionEntity, OtpSessionEntity } from '../domain/entities';

const OTP_PREFIX = 'otp:';
const ACCESS_PREFIX = 'atk:';
const REFRESH_PREFIX = 'rtk:';

export class RedisAuthRuntimeStore implements AuthRuntimeStore {
  private readonly redis: Redis;
  private readonly sessionTtlSeconds: number;

  constructor() {
    this.redis = new Redis({
      host: process.env.REDIS_HOST ?? '127.0.0.1',
      port: Number(process.env.REDIS_PORT ?? 6379),
      lazyConnect: false,
      maxRetriesPerRequest: 2,
    });
    this.sessionTtlSeconds = Number(process.env.SESSION_TTL_SECONDS ?? 604800);
  }

  async saveOtp(session: OtpSessionEntity): Promise<void> {
    const ttl = Math.max(1, Math.floor((session.expiresAt - Date.now()) / 1000));
    await this.redis.set(
      `${OTP_PREFIX}${session.requestId}`,
      JSON.stringify(session),
      'EX',
      ttl,
    );
  }

  async getOtp(requestId: string): Promise<OtpSessionEntity | null> {
    const raw = await this.redis.get(`${OTP_PREFIX}${requestId}`);
    return raw ? (JSON.parse(raw) as OtpSessionEntity) : null;
  }

  async deleteOtp(requestId: string): Promise<void> {
    await this.redis.del(`${OTP_PREFIX}${requestId}`);
  }

  async saveAuthSession(session: AuthSessionEntity): Promise<void> {
    const payload = JSON.stringify(session);
    await this.redis.set(
      `${ACCESS_PREFIX}${session.accessToken}`,
      payload,
      'EX',
      this.sessionTtlSeconds,
    );
    await this.redis.set(
      `${REFRESH_PREFIX}${session.refreshToken}`,
      payload,
      'EX',
      this.sessionTtlSeconds,
    );
  }

  async getByAccessToken(accessToken: string): Promise<AuthSessionEntity | null> {
    const raw = await this.redis.get(`${ACCESS_PREFIX}${accessToken}`);
    return raw ? (JSON.parse(raw) as AuthSessionEntity) : null;
  }

  async getByRefreshToken(refreshToken: string): Promise<AuthSessionEntity | null> {
    const raw = await this.redis.get(`${REFRESH_PREFIX}${refreshToken}`);
    return raw ? (JSON.parse(raw) as AuthSessionEntity) : null;
  }

  async deleteByAccessToken(accessToken: string): Promise<void> {
    const session = await this.getByAccessToken(accessToken);
    if (!session) return;
    await this.redis.del(
      `${ACCESS_PREFIX}${session.accessToken}`,
      `${REFRESH_PREFIX}${session.refreshToken}`,
    );
  }

  async deleteByRefreshToken(refreshToken: string): Promise<void> {
    const session = await this.getByRefreshToken(refreshToken);
    if (!session) return;
    await this.redis.del(
      `${ACCESS_PREFIX}${session.accessToken}`,
      `${REFRESH_PREFIX}${session.refreshToken}`,
    );
  }
}

