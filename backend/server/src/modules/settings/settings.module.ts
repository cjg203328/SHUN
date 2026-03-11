import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { SettingsService } from './application/settings.service';
import { SettingsController } from './controller/settings.controller';

@Module({
  imports: [AuthModule],
  controllers: [SettingsController],
  providers: [SettingsService],
})
export class SettingsModule {}

