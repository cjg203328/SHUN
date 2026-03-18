import { IsEnum, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export enum ReportTargetType {
  User = 'user',
  Message = 'message',
}

export enum ReportCategory {
  Spam = 'spam',
  Harassment = 'harassment',
  InappropriateContent = 'inappropriate_content',
  Fraud = 'fraud',
  HateSpeech = 'hate_speech',
  Underage = 'underage',
  Other = 'other',
}

export class CreateReportDto {
  @IsEnum(ReportTargetType)
  targetType!: ReportTargetType;

  @IsString()
  @IsNotEmpty()
  @MaxLength(128)
  targetId!: string;

  @IsEnum(ReportCategory)
  category!: ReportCategory;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  detail?: string;
}
