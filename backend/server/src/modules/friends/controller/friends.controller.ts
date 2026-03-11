import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ok } from '../../../common/dto/api-response.dto';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { AuthGuard } from '../../../common/guards/auth.guard';
import { TokenUser } from '../../auth/domain/token-user';
import { FriendsService } from '../application/friends.service';
import { CreateFriendRequestDto } from '../dto/create-friend-request.dto';

@Controller('friends')
@UseGuards(AuthGuard)
export class FriendsController {
  constructor(private readonly friendsService: FriendsService) {}

  @Get()
  async listFriends(@CurrentUser() actor: TokenUser) {
    return ok(await this.friendsService.listFriends(actor));
  }

  @Get('requests/pending')
  async listPendingRequests(@CurrentUser() actor: TokenUser) {
    return ok(await this.friendsService.listPendingRequests(actor));
  }

  @Post('requests')
  async createRequest(
    @CurrentUser() actor: TokenUser,
    @Body() dto: CreateFriendRequestDto,
  ) {
    return ok(
      await this.friendsService.createRequest(
        actor,
        dto.targetUserId,
        dto.message,
      ),
    );
  }

  @Post('requests/:requestId/accept')
  async acceptRequest(
    @CurrentUser() actor: TokenUser,
    @Param('requestId') requestId: string,
  ) {
    return ok(await this.friendsService.acceptRequest(actor, requestId));
  }

  @Post('requests/:requestId/reject')
  async rejectRequest(
    @CurrentUser() actor: TokenUser,
    @Param('requestId') requestId: string,
  ) {
    await this.friendsService.rejectRequest(actor, requestId);
    return ok({ rejected: true });
  }

  @Post(':userId/block')
  async blockUser(
    @CurrentUser() actor: TokenUser,
    @Param('userId') userId: string,
  ) {
    await this.friendsService.blockUser(actor, userId);
    return ok({ blocked: true });
  }

  @Delete(':userId/block')
  async unblockUser(
    @CurrentUser() actor: TokenUser,
    @Param('userId') userId: string,
  ) {
    await this.friendsService.unblockUser(actor, userId);
    return ok({ blocked: false });
  }
}

