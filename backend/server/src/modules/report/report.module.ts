import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { ReportService } from './application/report.service';
import { ReportController } from './controller/report.controller';

@Module({
  imports: [AuthModule],
  controllers: [ReportController],
  providers: [ReportService],
})
export class ReportModule {}
