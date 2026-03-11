import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { FriendsModule } from '../friends/friends.module';
import { MatchService } from './application/match.service';
import { MatchController } from './controller/match.controller';

@Module({
  imports: [AuthModule, FriendsModule],
  controllers: [MatchController],
  providers: [MatchService],
})
export class MatchModule {}

