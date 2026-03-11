import {
  Body,
  Controller,
  Get,
  Patch,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ok } from '../../../common/dto/api-response.dto';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { AuthGuard } from '../../../common/guards/auth.guard';
import { TokenUser } from '../../auth/domain/token-user';
import { UsersService } from '../application/users.service';
import { UpdateProfileDto } from '../dto/update-profile.dto';
import { UploadUserMediaDto } from '../dto/upload-user-media.dto';

@Controller('users')
@UseGuards(AuthGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  async getMe(@CurrentUser() user: TokenUser) {
    return ok(await this.usersService.getCurrentUser(user));
  }

  @Patch('me')
  async patchMe(@CurrentUser() user: TokenUser, @Body() dto: UpdateProfileDto) {
    return ok(await this.usersService.updateProfile(user, dto));
  }

  @Post('me/avatar/upload-token')
  async createAvatarUploadToken(@CurrentUser() user: TokenUser) {
    return ok(await this.usersService.createUploadToken(user, 'avatar'));
  }

  @Post('me/background/upload-token')
  async createBackgroundUploadToken(@CurrentUser() user: TokenUser) {
    return ok(await this.usersService.createUploadToken(user, 'background'));
  }

  @Post('me/avatar/upload')
  @UseInterceptors(FileInterceptor('file'))
  async uploadAvatar(
    @CurrentUser() user: TokenUser,
    @Body() dto: UploadUserMediaDto,
    @UploadedFile() file?: { buffer: Buffer; mimetype?: string },
  ) {
    return ok(await this.usersService.uploadMedia(user, 'avatar', dto, file));
  }

  @Post('me/background/upload')
  @UseInterceptors(FileInterceptor('file'))
  async uploadBackground(
    @CurrentUser() user: TokenUser,
    @Body() dto: UploadUserMediaDto,
    @UploadedFile() file?: { buffer: Buffer; mimetype?: string },
  ) {
    return ok(await this.usersService.uploadMedia(user, 'background', dto, file));
  }
}
