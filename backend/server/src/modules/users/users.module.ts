import { Module } from '@nestjs/common';
import { UsersController } from './controller/users.controller';
import { UsersService } from './application/users.service';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [AuthModule],
  controllers: [UsersController],
  providers: [UsersService],
})
export class UsersModule {}

