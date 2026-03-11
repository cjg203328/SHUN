import { IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateFriendRequestDto {
  @IsString()
  targetUserId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  message?: string;
}

