import { Inject, Injectable } from '@nestjs/common';
import { BusinessError, ErrorCode } from '../../../common/errors/error-codes';
import { TokenUser } from '../../auth/domain/token-user';
import { UpdateSettingsDto } from '../dto/update-settings.dto';
import { USER_SETTINGS_STORE } from '../../shared/tokens';
import { UserSettingsStore } from '../../shared/ports/user-settings-store.port';

@Injectable()
export class SettingsService {
  constructor(
    @Inject(USER_SETTINGS_STORE)
    private readonly store: UserSettingsStore,
  ) {}

  async getCurrentSettings(actor: TokenUser) {
    const settings = await this.store.getSettingsByUserId(actor.userId);
    if (!settings) {
      throw new BusinessError(ErrorCode.UserNotFound, 404, 'Settings not found');
    }
    return settings;
  }

  async updateSettings(actor: TokenUser, payload: UpdateSettingsDto) {
    const current = await this.getCurrentSettings(actor);
    const portraitFullscreenBackground =
      payload.portraitFullscreenBackground ?? current.portraitFullscreenBackground;

    const next = {
      ...current,
      invisibleMode: payload.invisibleMode ?? current.invisibleMode,
      notificationEnabled:
        payload.notificationEnabled ?? current.notificationEnabled,
      vibrationEnabled: payload.vibrationEnabled ?? current.vibrationEnabled,
      dayThemeEnabled: payload.dayThemeEnabled ?? current.dayThemeEnabled,
      portraitFullscreenBackground,
      transparentHomepage: portraitFullscreenBackground
        ? payload.transparentHomepage ?? current.transparentHomepage
        : false,
      updatedAt: new Date().toISOString(),
    };
    await this.store.saveSettings(next);
    return next;
  }
}
