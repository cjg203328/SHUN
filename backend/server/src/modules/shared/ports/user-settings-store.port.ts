import { UserEntity, UserSettingsEntity } from '../domain/entities';

export interface UserSettingsStore {
  saveUser(user: UserEntity): Promise<void>;
  getUserById(userId: string): Promise<UserEntity | null>;
  getUserByPhone(phone: string): Promise<UserEntity | null>;
  getUserByUid(uid: string): Promise<UserEntity | null>;

  saveSettings(settings: UserSettingsEntity): Promise<void>;
  getSettingsByUserId(userId: string): Promise<UserSettingsEntity | null>;
}

