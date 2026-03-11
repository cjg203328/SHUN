import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { FriendsService } from './application/friends.service';
import { FriendsController } from './controller/friends.controller';
import { SocialUsersController } from './controller/social-users.controller';

@Module({
  imports: [AuthModule],
  controllers: [FriendsController, SocialUsersController],
  providers: [FriendsService],
  exports: [FriendsService],
})
export class FriendsModule {}

