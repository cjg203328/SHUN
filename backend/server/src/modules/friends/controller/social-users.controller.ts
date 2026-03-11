import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ok } from '../../../common/dto/api-response.dto';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { AuthGuard } from '../../../common/guards/auth.guard';
import { TokenUser } from '../../auth/domain/token-user';
import { FriendsService } from '../application/friends.service';
import { SearchUserDto } from '../dto/search-user.dto';

@Controller('users')
@UseGuards(AuthGuard)
export class SocialUsersController {
  constructor(private readonly friendsService: FriendsService) {}

  @Get('search')
  async searchUser(@CurrentUser() actor: TokenUser, @Query() query: SearchUserDto) {
    return ok(await this.friendsService.searchByUid(actor, query.uid));
  }

  @Get('blocked')
  async listBlocked(@CurrentUser() actor: TokenUser) {
    return ok(await this.friendsService.listBlocked(actor));
  }
}

