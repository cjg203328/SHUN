import { AuthSessionEntity, OtpSessionEntity } from '../domain/entities';

export interface AuthRuntimeStore {
  saveOtp(session: OtpSessionEntity): Promise<void>;
  getOtp(requestId: string): Promise<OtpSessionEntity | null>;
  deleteOtp(requestId: string): Promise<void>;

  saveAuthSession(session: AuthSessionEntity): Promise<void>;
  getByAccessToken(accessToken: string): Promise<AuthSessionEntity | null>;
  getByRefreshToken(refreshToken: string): Promise<AuthSessionEntity | null>;
  deleteByAccessToken(accessToken: string): Promise<void>;
  deleteByRefreshToken(refreshToken: string): Promise<void>;
}

