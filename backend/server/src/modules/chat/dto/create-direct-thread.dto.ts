import { IsString } from 'class-validator';

export class CreateDirectThreadDto {
  @IsString()
  targetUserId!: string;
}

