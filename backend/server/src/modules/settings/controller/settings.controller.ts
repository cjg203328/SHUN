import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { ok } from '../../../common/dto/api-response.dto';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { AuthGuard } from '../../../common/guards/auth.guard';
import { TokenUser } from '../../auth/domain/token-user';
import { SettingsService } from '../application/settings.service';
import { UpdateSettingsDto } from '../dto/update-settings.dto';

@Controller('settings')
@UseGuards(AuthGuard)
export class SettingsController {
  constructor(private readonly settingsService: SettingsService) {}

  @Get('me')
  async getMe(@CurrentUser() user: TokenUser) {
    return ok(await this.settingsService.getCurrentSettings(user));
  }

  @Patch('me')
  async patchMe(@CurrentUser() user: TokenUser, @Body() dto: UpdateSettingsDto) {
    return ok(await this.settingsService.updateSettings(user, dto));
  }
}
