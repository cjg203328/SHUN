import { Pool, QueryResult } from 'pg';
import { UserEntity, UserSettingsEntity } from '../domain/entities';
import { UserSettingsStore } from '../ports/user-settings-store.port';

type UserRow = {
  id: string;
  uid: string;
  phone: string;
  nickname: string;
  avatar_url: string | null;
  background_url: string | null;
  signature: string;
  status: string;
  created_at: Date;
  updated_at: Date;
};

type SettingsRow = {
  user_id: string;
  invisible_mode: boolean;
  notification_enabled: boolean;
  vibration_enabled: boolean;
  day_theme_enabled: boolean;
  transparent_homepage: boolean;
  portrait_fullscreen_background: boolean;
  updated_at: Date;
};

export class PostgresUserSettingsStore implements UserSettingsStore {
  private readonly pool: Pool;

  constructor() {
    this.pool = new Pool({
      host: process.env.DB_HOST ?? '127.0.0.1',
      port: Number(process.env.DB_PORT ?? 5432),
      database: process.env.DB_NAME ?? 'sunliao',
      user: process.env.DB_USER ?? 'sunliao',
      password: process.env.DB_PASSWORD ?? 'sunliao_dev',
      max: 10,
    });
  }

  async saveUser(user: UserEntity): Promise<void> {
    await this.pool.query(
      `
      INSERT INTO users (
        id, uid, phone, nickname, avatar_url, background_url, signature, status, created_at, updated_at
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
      ON CONFLICT (id) DO UPDATE SET
        uid = EXCLUDED.uid,
        phone = EXCLUDED.phone,
        nickname = EXCLUDED.nickname,
        avatar_url = EXCLUDED.avatar_url,
        background_url = EXCLUDED.background_url,
        signature = EXCLUDED.signature,
        status = EXCLUDED.status,
        updated_at = EXCLUDED.updated_at
      `,
      [
        user.userId,
        user.uid,
        user.phone,
        user.nickname,
        user.avatarUrl ?? null,
        user.backgroundUrl ?? null,
        user.signature,
        user.status,
        user.createdAt,
        user.updatedAt,
      ],
    );
  }

  async getUserById(userId: string): Promise<UserEntity | null> {
    const result = await this.pool.query<UserRow>(
      'SELECT * FROM users WHERE id = $1 LIMIT 1',
      [userId],
    );
    return this.mapUserRow(result);
  }

  async getUserByPhone(phone: string): Promise<UserEntity | null> {
    const result = await this.pool.query<UserRow>(
      'SELECT * FROM users WHERE phone = $1 LIMIT 1',
      [phone],
    );
    return this.mapUserRow(result);
  }

  async getUserByUid(uid: string): Promise<UserEntity | null> {
    const result = await this.pool.query<UserRow>(
      'SELECT * FROM users WHERE uid = $1 LIMIT 1',
      [uid.toUpperCase()],
    );
    return this.mapUserRow(result);
  }

  async saveSettings(settings: UserSettingsEntity): Promise<void> {
    await this.pool.query(
      `
      INSERT INTO user_settings (
        user_id,
        invisible_mode,
        notification_enabled,
        vibration_enabled,
        day_theme_enabled,
        transparent_homepage,
        portrait_fullscreen_background,
        updated_at
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
      ON CONFLICT (user_id) DO UPDATE SET
        invisible_mode = EXCLUDED.invisible_mode,
        notification_enabled = EXCLUDED.notification_enabled,
        vibration_enabled = EXCLUDED.vibration_enabled,
        day_theme_enabled = EXCLUDED.day_theme_enabled,
        transparent_homepage = EXCLUDED.transparent_homepage,
        portrait_fullscreen_background = EXCLUDED.portrait_fullscreen_background,
        updated_at = EXCLUDED.updated_at
      `,
      [
        settings.userId,
        settings.invisibleMode,
        settings.notificationEnabled,
        settings.vibrationEnabled,
        settings.dayThemeEnabled,
        settings.transparentHomepage,
        settings.portraitFullscreenBackground,
        settings.updatedAt,
      ],
    );
  }

  async getSettingsByUserId(userId: string): Promise<UserSettingsEntity | null> {
    const result = await this.pool.query<SettingsRow>(
      'SELECT * FROM user_settings WHERE user_id = $1 LIMIT 1',
      [userId],
    );
    if (!result.rowCount) return null;
    const row = result.rows[0];
    return {
      userId: row.user_id,
      invisibleMode: row.invisible_mode,
      notificationEnabled: row.notification_enabled,
      vibrationEnabled: row.vibration_enabled,
      dayThemeEnabled: row.day_theme_enabled,
      transparentHomepage: row.transparent_homepage,
      portraitFullscreenBackground: row.portrait_fullscreen_background,
      updatedAt: row.updated_at.toISOString(),
    };
  }

  private mapUserRow(result: QueryResult<UserRow>): UserEntity | null {
    if (!result.rowCount) return null;
    const row = result.rows[0];
    return {
      userId: row.id,
      uid: row.uid,
      phone: row.phone,
      nickname: row.nickname,
      avatarUrl: row.avatar_url ?? undefined,
      backgroundUrl: row.background_url ?? undefined,
      signature: row.signature,
      status: row.status,
      createdAt: row.created_at.toISOString(),
      updatedAt: row.updated_at.toISOString(),
    };
  }
}
