import { IsBoolean, IsOptional } from 'class-validator';

export class UpdateSettingsDto {
  @IsOptional()
  @IsBoolean()
  invisibleMode?: boolean;

  @IsOptional()
  @IsBoolean()
  notificationEnabled?: boolean;

  @IsOptional()
  @IsBoolean()
  vibrationEnabled?: boolean;

  @IsOptional()
  @IsBoolean()
  dayThemeEnabled?: boolean;

  @IsOptional()
  @IsBoolean()
  transparentHomepage?: boolean;

  @IsOptional()
  @IsBoolean()
  portraitFullscreenBackground?: boolean;
}

