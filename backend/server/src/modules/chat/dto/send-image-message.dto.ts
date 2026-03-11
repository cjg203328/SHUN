import { IsBoolean, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class SendImageMessageDto {
  @IsString()
  imageKey!: string;

  @IsOptional()
  @IsBoolean()
  burnAfterReading?: boolean;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(10)
  burnSeconds?: number;

  @IsOptional()
  @IsString()
  clientMsgId?: string;
}

