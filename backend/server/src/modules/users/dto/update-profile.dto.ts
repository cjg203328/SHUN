import { IsOptional, IsString, MaxLength } from 'class-validator';

export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @MaxLength(32)
  nickname?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  signature?: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  status?: string;
}

