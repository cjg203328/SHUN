import { AuthSessionEntity, OtpSessionEntity } from '../domain/entities';
import { AuthRuntimeStore } from '../ports/auth-runtime-store.port';

export class InMemoryAuthRuntimeStore implements AuthRuntimeStore {
  private readonly otpSessions = new Map<string, OtpSessionEntity>();
  private readonly accessSessions = new Map<string, AuthSessionEntity>();
  private readonly refreshSessions = new Map<string, AuthSessionEntity>();

  async saveOtp(session: OtpSessionEntity): Promise<void> {
    this.otpSessions.set(session.requestId, session);
  }

  async getOtp(requestId: string): Promise<OtpSessionEntity | null> {
    return this.otpSessions.get(requestId) ?? null;
  }

  async deleteOtp(requestId: string): Promise<void> {
    this.otpSessions.delete(requestId);
  }

  async saveAuthSession(session: AuthSessionEntity): Promise<void> {
    this.accessSessions.set(session.accessToken, session);
    this.refreshSessions.set(session.refreshToken, session);
  }

  async getByAccessToken(accessToken: string): Promise<AuthSessionEntity | null> {
    return this.accessSessions.get(accessToken) ?? null;
  }

  async getByRefreshToken(refreshToken: string): Promise<AuthSessionEntity | null> {
    return this.refreshSessions.get(refreshToken) ?? null;
  }

  async deleteByAccessToken(accessToken: string): Promise<void> {
    const session = this.accessSessions.get(accessToken);
    if (!session) return;
    this.refreshSessions.delete(session.refreshToken);
    this.accessSessions.delete(accessToken);
  }

  async deleteByRefreshToken(refreshToken: string): Promise<void> {
    const session = this.refreshSessions.get(refreshToken);
    if (!session) return;
    this.accessSessions.delete(session.accessToken);
    this.refreshSessions.delete(refreshToken);
  }
}

