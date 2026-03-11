import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Query,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ok } from '../../../common/dto/api-response.dto';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { AuthGuard } from '../../../common/guards/auth.guard';
import { TokenUser } from '../../auth/domain/token-user';
import { ChatService } from '../application/chat.service';
import { CreateDirectThreadDto } from '../dto/create-direct-thread.dto';
import { MarkReadDto } from '../dto/mark-read.dto';
import { SendImageMessageDto } from '../dto/send-image-message.dto';
import { SendTextMessageDto } from '../dto/send-text-message.dto';
import { UploadChatImageDto } from '../dto/upload-chat-image.dto';

@Controller()
@UseGuards(AuthGuard)
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Get('threads')
  async listThreads(@CurrentUser() actor: TokenUser) {
    return ok(await this.chatService.listThreads(actor));
  }

  @Post('threads/direct')
  async createDirectThread(
    @CurrentUser() actor: TokenUser,
    @Body() dto: CreateDirectThreadDto,
  ) {
    return ok(await this.chatService.createDirectThread(actor, dto.targetUserId));
  }

  @Get('threads/:threadId/messages')
  async listMessages(
    @CurrentUser() actor: TokenUser,
    @Param('threadId') threadId: string,
  ) {
    return ok(await this.chatService.listMessages(actor, threadId));
  }

  @Post('threads/:threadId/messages/text')
  async sendTextMessage(
    @CurrentUser() actor: TokenUser,
    @Param('threadId') threadId: string,
    @Body() dto: SendTextMessageDto,
  ) {
    return ok(
      await this.chatService.sendTextMessage(
        actor,
        threadId,
        dto.content,
        dto.clientMsgId,
      ),
    );
  }

  @Post('threads/:threadId/messages/image')
  async sendImageMessage(
    @CurrentUser() actor: TokenUser,
    @Param('threadId') threadId: string,
    @Body() dto: SendImageMessageDto,
  ) {
    return ok(
      await this.chatService.sendImageMessage(
        actor,
        threadId,
        dto.imageKey,
        dto.burnAfterReading ?? false,
        dto.burnSeconds,
        dto.clientMsgId,
      ),
    );
  }

  @Post('threads/:threadId/messages/image/upload-token')
  async createImageUploadToken(
    @CurrentUser() actor: TokenUser,
    @Param('threadId') threadId: string,
  ) {
    return ok(await this.chatService.createImageUploadToken(actor, threadId));
  }

  @Post('threads/:threadId/messages/image/upload')
  @UseInterceptors(FileInterceptor('file'))
  async uploadChatImage(
    @CurrentUser() actor: TokenUser,
    @Param('threadId') threadId: string,
    @Body() dto: UploadChatImageDto,
    @UploadedFile() file?: { buffer: Buffer; mimetype?: string },
  ) {
    return ok(await this.chatService.uploadChatImage(actor, threadId, dto, file));
  }

  @Post('threads/:threadId/read')
  async markRead(
    @CurrentUser() actor: TokenUser,
    @Param('threadId') threadId: string,
    @Body() dto: MarkReadDto,
  ) {
    await this.chatService.markThreadRead(actor, threadId, dto.lastReadMessageId);
    return ok({ read: true });
  }

  @Delete('threads/:threadId')
  async deleteThread(
    @CurrentUser() actor: TokenUser,
    @Param('threadId') threadId: string,
  ) {
    await this.chatService.deleteThread(actor, threadId);
    return ok({ deleted: true });
  }

  @Post('messages/:messageId/recall')
  async recallMessage(
    @CurrentUser() actor: TokenUser,
    @Param('messageId') messageId: string,
    @Query('threadId') _threadId?: string,
  ) {
    await this.chatService.recallMessage(actor, messageId);
    return ok({ recalled: true });
  }
}
