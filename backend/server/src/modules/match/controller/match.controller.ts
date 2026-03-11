import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { ok } from '../../../common/dto/api-response.dto';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { AuthGuard } from '../../../common/guards/auth.guard';
import { TokenUser } from '../../auth/domain/token-user';
import { MatchService } from '../application/match.service';
import { StartMatchDto } from '../dto/start-match.dto';

@Controller('match')
@UseGuards(AuthGuard)
export class MatchController {
  constructor(private readonly matchService: MatchService) {}

  @Get('quota')
  async getQuota(@CurrentUser() actor: TokenUser) {
    return ok(await this.matchService.getQuota(actor));
  }

  @Post('start')
  async startMatch(@CurrentUser() actor: TokenUser, @Body() dto: StartMatchDto) {
    return ok(await this.matchService.startMatch(actor, dto.excludeUserIds ?? []));
  }

  @Post('cancel')
  async cancelMatch(@CurrentUser() actor: TokenUser) {
    return ok(await this.matchService.cancelMatch(actor));
  }
}
