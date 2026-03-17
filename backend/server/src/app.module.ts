import { Module } from '@nestjs/common';
import { AuthModule } from './modules/auth/auth.module';
import { ChatModule } from './modules/chat/chat.module';
import { FriendsModule } from './modules/friends/friends.module';
import { MatchModule } from './modules/match/match.module';
import { ReportModule } from './modules/report/report.module';
import { SettingsModule } from './modules/settings/settings.module';
import { InfrastructureModule } from './modules/shared/infrastructure/infrastructure.module';
import { UsersModule } from './modules/users/users.module';

@Module({
  imports: [
    InfrastructureModule,
    AuthModule,
    UsersModule,
    SettingsModule,
    FriendsModule,
    MatchModule,
    ChatModule,
    ReportModule,
  ],
})
export class AppModule {}
