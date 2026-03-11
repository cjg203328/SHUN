import { IsString, MinLength } from 'class-validator';

export class SearchUserDto {
  @IsString()
  @MinLength(4)
  uid!: string;
}

