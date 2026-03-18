import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { ok } from '../../../common/dto/api-response.dto';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { AuthGuard } from '../../../common/guards/auth.guard';
import { TokenUser } from '../../auth/domain/token-user';
import { ReportService } from '../application/report.service';
import { CreateReportDto } from '../dto/create-report.dto';

@ApiTags('report')
@Controller('report')
@UseGuards(AuthGuard)
export class ReportController {
  constructor(private readonly reportService: ReportService) {}

  @Post()
  async createReport(
    @CurrentUser() actor: TokenUser,
    @Body() dto: CreateReportDto,
  ) {
    return ok(await this.reportService.createReport(actor, dto));
  }
}
