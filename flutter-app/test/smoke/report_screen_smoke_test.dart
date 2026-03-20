import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/screens/report_screen.dart';

import '../helpers/test_bootstrap.dart';

Widget _buildHarness({
  required ReportSubmitCallback onSubmitReport,
}) {
  return MaterialApp(
    home: _ReportSmokeLauncher(onSubmitReport: onSubmitReport),
  );
}

class _ReportSmokeLauncher extends StatefulWidget {
  const _ReportSmokeLauncher({
    required this.onSubmitReport,
  });

  final ReportSubmitCallback onSubmitReport;

  @override
  State<_ReportSmokeLauncher> createState() => _ReportSmokeLauncherState();
}

class _ReportSmokeLauncherState extends State<_ReportSmokeLauncher> {
  bool _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) {
      return;
    }
    _opened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReportScreen(
            targetId: 'u_report_target',
            targetType: ReportTargetType.user,
            targetName: '阿青',
            onSubmitReport: widget.onSubmitReport,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text('report-home'));
  }
}

Future<void> _selectSpamCategory(WidgetTester tester) async {
  final spamCategory = find.byKey(const Key('report-category-spam'));
  expect(spamCategory, findsOneWidget);
  await tester.ensureVisible(spamCategory);
  await tester.tap(spamCategory, warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 220));
}

void main() {
  setUp(() async {
    await initTestAppStorage();
  });

  testWidgets('report screen should require category before submit',
      (tester) async {
    await tester.pumpWidget(
      _buildHarness(
        onSubmitReport: ({
          required targetType,
          required targetId,
          required categoryId,
          detail,
        }) async {
          return const ReportSubmissionResult(
            status: ReportSubmissionStatus.accepted,
            reportId: 'report_unused',
          );
        },
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));

    await tester.tap(find.byKey(const Key('report-submit-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('请选择举报类型'), findsWidgets);
    expect(find.byType(ReportScreen), findsOneWidget);
  });

  testWidgets('report screen should close after accepted submission',
      (tester) async {
    await tester.pumpWidget(
      _buildHarness(
        onSubmitReport: ({
          required targetType,
          required targetId,
          required categoryId,
          detail,
        }) async {
          expect(targetType, ReportTargetType.user);
          expect(targetId, 'u_report_target');
          expect(categoryId, 'spam');
          return const ReportSubmissionResult(
            status: ReportSubmissionStatus.accepted,
            reportId: 'report_accepted_1',
          );
        },
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));

    await _selectSpamCategory(tester);
    await tester.tap(find.byKey(const Key('report-submit-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));

    expect(find.text('举报已提交，我们会尽快处理'), findsWidgets);
    expect(find.text('report-home'), findsOneWidget);
    expect(find.byType(ReportScreen), findsNothing);
  });

  testWidgets('report screen should merge duplicate submission feedback',
      (tester) async {
    await tester.pumpWidget(
      _buildHarness(
        onSubmitReport: ({
          required targetType,
          required targetId,
          required categoryId,
          detail,
        }) async {
          return const ReportSubmissionResult(
            status: ReportSubmissionStatus.duplicate,
          );
        },
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));

    await _selectSpamCategory(tester);
    await tester.tap(find.byKey(const Key('report-submit-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));

    expect(find.text('今天已提交过该举报，我们会合并处理'), findsWidgets);
    expect(find.text('report-home'), findsOneWidget);
    expect(find.byType(ReportScreen), findsNothing);
  });

  testWidgets('report screen should keep page visible on rate limit',
      (tester) async {
    await tester.pumpWidget(
      _buildHarness(
        onSubmitReport: ({
          required targetType,
          required targetId,
          required categoryId,
          detail,
        }) async {
          return const ReportSubmissionResult(
            status: ReportSubmissionStatus.rateLimited,
          );
        },
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));

    await _selectSpamCategory(tester);
    await tester.tap(find.byKey(const Key('report-submit-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));

    expect(find.text('提交过于频繁，请稍后再试'), findsOneWidget);
    expect(find.byType(ReportScreen), findsOneWidget);
    expect(find.text('report-home'), findsNothing);
  });

  testWidgets('report screen should keep page visible for self report',
      (tester) async {
    await tester.pumpWidget(
      _buildHarness(
        onSubmitReport: ({
          required targetType,
          required targetId,
          required categoryId,
          detail,
        }) async {
          return const ReportSubmissionResult(
            status: ReportSubmissionStatus.ignoredSelf,
          );
        },
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));

    await _selectSpamCategory(tester);
    await tester.tap(find.byKey(const Key('report-submit-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));

    expect(find.text('不能举报自己'), findsOneWidget);
    expect(find.byType(ReportScreen), findsOneWidget);
    expect(find.text('report-home'), findsNothing);
  });
}
