import { IsString, Matches } from 'class-validator';

export class VerifyOtpDto {
  @IsString()
  @Matches(/^\d{11}$/, { message: 'phone must be 11 digits' })
  phone!: string;

  @IsString()
  @Matches(/^\d{6}$/, { message: 'code must be 6 digits' })
  code!: string;

  @IsString()
  requestId!: string;

  @IsString()
  deviceId!: string;
}

