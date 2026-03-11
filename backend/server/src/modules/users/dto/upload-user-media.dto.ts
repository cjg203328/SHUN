import { IsString } from 'class-validator';

export class UploadUserMediaDto {
  @IsString()
  uploadToken!: string;

  @IsString()
  objectKey!: string;
}
