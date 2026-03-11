import { UserEntity, UserSettingsEntity } from '../domain/entities';
import { UserSettingsStore } from '../ports/user-settings-store.port';

export class InMemoryUserSettingsStore implements UserSettingsStore {
  private readonly usersById = new Map<string, UserEntity>();
  private readonly usersByPhone = new Map<string, string>();
  private readonly usersByUid = new Map<string, string>();
  private readonly userSettings = new Map<string, UserSettingsEntity>();

  async saveUser(user: UserEntity): Promise<void> {
    this.usersById.set(user.userId, user);
    this.usersByPhone.set(user.phone, user.userId);
    this.usersByUid.set(user.uid.toUpperCase(), user.userId);
  }

  async getUserById(userId: string): Promise<UserEntity | null> {
    return this.usersById.get(userId) ?? null;
  }

  async getUserByPhone(phone: string): Promise<UserEntity | null> {
    const userId = this.usersByPhone.get(phone);
    return userId ? (this.usersById.get(userId) ?? null) : null;
  }

  async getUserByUid(uid: string): Promise<UserEntity | null> {
    const userId = this.usersByUid.get(uid.toUpperCase());
    return userId ? (this.usersById.get(userId) ?? null) : null;
  }

  async saveSettings(settings: UserSettingsEntity): Promise<void> {
    this.userSettings.set(settings.userId, settings);
  }

  async getSettingsByUserId(userId: string): Promise<UserSettingsEntity | null> {
    return this.userSettings.get(userId) ?? null;
  }
}

