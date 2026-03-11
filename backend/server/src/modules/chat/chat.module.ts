import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { FriendsModule } from '../friends/friends.module';
import { ChatService } from './application/chat.service';
import { ChatController } from './controller/chat.controller';
import { ChatGateway } from './gateway/chat.gateway';

@Module({
  imports: [AuthModule, FriendsModule],
  controllers: [ChatController],
  providers: [ChatService, ChatGateway],
  exports: [ChatService],
})
export class ChatModule {}
