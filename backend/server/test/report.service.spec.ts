import { ReportService } from '../src/modules/report/application/report.service';
import { TokenUser } from '../src/modules/auth/domain/token-user';
import {
  ReportCategory,
  ReportTargetType,
} from '../src/modules/report/dto/create-report.dto';

function actor(userId: string): TokenUser {
  return {
    userId,
    uid: `SN_${userId}`,
    phone: `1380000${userId.padStart(4, '0')}`,
  };
}

describe('ReportService', () => {
  it('returns accepted for first valid report and duplicate for repeated target', async () => {
    const service = new ReportService();
    const reporter = actor('1001');

    const first = await service.createReport(reporter, {
      targetType: ReportTargetType.User,
      targetId: 'u_target_1',
      category: ReportCategory.Spam,
      detail: 'first report',
    });
    const second = await service.createReport(reporter, {
      targetType: ReportTargetType.User,
      targetId: 'u_target_1',
      category: ReportCategory.Spam,
      detail: 'duplicate report',
    });

    expect(first.status).toBe('accepted');
    expect(first.reportId).toBeTruthy();
    expect(second).toEqual({
      reportId: null,
      status: 'duplicate',
    });
  });

  it('returns ignored_self when reporting current user', async () => {
    const service = new ReportService();
    const reporter = actor('1002');

    const result = await service.createReport(reporter, {
      targetType: ReportTargetType.User,
      targetId: reporter.userId,
      category: ReportCategory.Other,
      detail: 'self report',
    });

    expect(result).toEqual({
      reportId: null,
      status: 'ignored_self',
    });
  });

  it('returns rate_limited after hourly threshold is exceeded', async () => {
    const service = new ReportService();
    const reporter = actor('1003');

    for (var index = 0; index < 10; index += 1) {
      const result = await service.createReport(reporter, {
        targetType: ReportTargetType.Message,
        targetId: `m_target_${index}`,
        category: ReportCategory.Spam,
        detail: `report ${index}`,
      });
      expect(result.status).toBe('accepted');
    }

    const limited = await service.createReport(reporter, {
      targetType: ReportTargetType.Message,
      targetId: 'm_target_11',
      category: ReportCategory.Spam,
      detail: 'rate limited report',
    });

    expect(limited).toEqual({
      reportId: null,
      status: 'rate_limited',
    });
  });
});
