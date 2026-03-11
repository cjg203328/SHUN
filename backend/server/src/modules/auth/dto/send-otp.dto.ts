import { IsString, Matches } from 'class-validator';

export class SendOtpDto {
  @IsString()
  @Matches(/^\d{11}$/, { message: 'phone must be 11 digits' })
  phone!: string;
}

