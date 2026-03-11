import { IsOptional, IsString, MaxLength } from 'class-validator';

export class SendTextMessageDto {
  @IsString()
  @MaxLength(500)
  content!: string;

  @IsOptional()
  @IsString()
  clientMsgId?: string;
}

