import { Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { CreateReportDto } from '../dto/create-report.dto';
import { TokenUser } from '../../auth/domain/token-user';

export interface ReportRecord {
  id: string;
  reporterId: string;
  targetType: string;
  targetId: string;
  category: string;
  detail?: string;
  createdAt: number;
  status: 'pending' | 'reviewed' | 'dismissed';
}

const REPORT_DEDUP_MS = 24 * 60 * 60_000; // 24h dedup window per target
const REPORT_HOURLY_LIMIT = 10;           // max reports per user per hour
const REPORT_HOURLY_WINDOW_MS = 60 * 60_000;

@Injectable()
export class ReportService {
  // In-memory store — replace with DB persistence in P1
  private readonly reports = new Map<string, ReportRecord>();
  // "reporterId:targetType:targetId" -> timestamp of last report
  private readonly recentReports = new Map<string, number>();
  // reporterId -> list of timestamps in current hour window
  private readonly hourlyReportTimes = new Map<string, number[]>();

  async createReport(
    actor: TokenUser,
    dto: CreateReportDto,
  ): Promise<{ reportId: string }> {
    // Prevent self-reporting
    if (dto.targetType === 'user' && dto.targetId === actor.userId) {
      return { reportId: 'noop' };
    }

    // Hourly rate limit: max 10 reports per user per hour
    const now = Date.now();
    const hourlyTimes = (this.hourlyReportTimes.get(actor.userId) ?? []).filter(
      (t) => now - t < REPORT_HOURLY_WINDOW_MS,
    );
    if (hourlyTimes.length >= REPORT_HOURLY_LIMIT) {
      return { reportId: 'rate_limited' };
    }
    hourlyTimes.push(now);
    this.hourlyReportTimes.set(actor.userId, hourlyTimes);

    // Dedup: same reporter + target within 24h returns silently
    const dedupKey = `${actor.userId}:${dto.targetType}:${dto.targetId}`;
    const lastReport = this.recentReports.get(dedupKey) ?? 0;
    if (now - lastReport < REPORT_DEDUP_MS) {
      return { reportId: 'dedup' };
    }
    this.recentReports.set(dedupKey, now);

    const reportId = randomUUID();
    this.reports.set(reportId, {
      id: reportId,
      reporterId: actor.userId,
      targetType: dto.targetType,
      targetId: dto.targetId,
      category: dto.category,
      detail: dto.detail,
      createdAt: Date.now(),
      status: 'pending',
    });

    // TODO: trigger moderation pipeline / notify admin
    if (process.env.NODE_ENV !== 'production') {
      console.log(
        `[Report] ${actor.userId} reported ${dto.targetType}:${dto.targetId} for ${dto.category}`,
      );
    }

    return { reportId };
  }
}
