export interface UserEntity {
  userId: string;
  uid: string;
  phone: string;
  nickname: string;
  avatarUrl?: string;
  backgroundUrl?: string;
  signature: string;
  status: string;
  createdAt: string;
  updatedAt: string;
}

export interface UserSettingsEntity {
  userId: string;
  invisibleMode: boolean;
  notificationEnabled: boolean;
  vibrationEnabled: boolean;
  dayThemeEnabled: boolean;
  transparentHomepage: boolean;
  portraitFullscreenBackground: boolean;
  updatedAt: string;
}

export interface OtpSessionEntity {
  requestId: string;
  phone: string;
  code: string;
  expiresAt: number;
}

export interface AuthSessionEntity {
  accessToken: string;
  refreshToken: string;
  userId: string;
  deviceId: string;
  createdAt: number;
}
