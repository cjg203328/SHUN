import { IsString } from 'class-validator';

export class UploadChatImageDto {
  @IsString()
  uploadToken!: string;

  @IsString()
  objectKey!: string;
}
