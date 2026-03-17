import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/friend_provider.dart';
import 'package:sunliao/providers/match_provider.dart';
import 'package:sunliao/services/match_service.dart';
import 'package:sunliao/models/models.dart';
import 'package:sunliao/utils/permission_manager.dart';
import 'package:sunliao/widgets/match_tab.dart';

import '../helpers/test_bootstrap.dart';

class _FakeMatchService extends MatchService {
  _FakeMatchService({required this.startMatchHandler});

  final Future<MatchStartAttempt> Function(List<String> excludedUserIds)
      startMatchHandler;

  @override
  Future<MatchStartAttempt> startMatch({
    required List<String> excludedUserIds,
  }) {
    return startMatchHandler(excludedUserIds);
  }
}

Widget _buildHost({
  required MatchProvider matchProvider,
  required ChatProvider chatProvider,
  required FriendProvider friendProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<MatchProvider>.value(value: matchProvider),
      ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
      ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
    ],
    child: const MaterialApp(home: MatchTab()),
  );
}

Future<void> _disposeHost(
  WidgetTester tester,
  MatchProvider matchProvider,
  ChatProvider chatProvider,
  FriendProvider friendProvider,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  matchProvider.dispose();
  chatProvider.dispose();
  friendProvider.dispose();
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  setUp(() async {
    await initTestAppStorage();
    PermissionManager.clearSessionCache();
    PermissionManager.setSessionLocationPermission(false);
  });

  tearDown(() {
    PermissionManager.clearSessionCache();
  });

  testWidgets(
      'match tab should show actionable failure guidance when match service is unavailable',
      (tester) async {
    tester.view.physicalSize = const Size(430, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final matchProvider = MatchProvider(
      matchService: _FakeMatchService(
        startMatchHandler: (_) async => const MatchStartAttempt.failure(
          errorCode: 'MATCH_UNAVAILABLE',
          errorMessage: 'Match service has no available candidates',
        ),
      ),
      allowMockFallback: false,
    );
    final chatProvider = ChatProvider(
      enableRealtime: false,
      enableRemoteHydration: false,
    );
    final friendProvider = FriendProvider(enableRemoteHydration: false);

    await tester.pumpWidget(
      _buildHost(
        matchProvider: matchProvider,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('match-guide-card')), findsOneWidget);
    expect(find.byKey(const Key('match-primary-action')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('match-primary-action')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('match-primary-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('当前环境还没有可用匹配对象，请先完成联调配置。'), findsWidgets);
    expect(find.textContaining('建议先检查当前服务环境是否可用'), findsOneWidget);
    expect(find.textContaining('准备好后可再次点击开始匹配'), findsOneWidget);

    await _disposeHost(
      tester,
      matchProvider,
      chatProvider,
      friendProvider,
    );
  });

  testWidgets('match tab should keep primary action visible on compact screens',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final matchProvider = MatchProvider(
      matchService: _FakeMatchService(
        startMatchHandler: (_) async => const MatchStartAttempt.failure(
          errorCode: 'MATCH_SESSION_MISSING',
          errorMessage: 'Session missing',
        ),
      ),
      allowMockFallback: false,
    );
    final chatProvider = ChatProvider(
      enableRealtime: false,
      enableRemoteHydration: false,
    );
    final friendProvider = FriendProvider(enableRemoteHydration: false);

    await tester.pumpWidget(
      _buildHost(
        matchProvider: matchProvider,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('match-status-chip')), findsOneWidget);
    expect(find.byKey(const Key('match-primary-action')), findsOneWidget);

    final buttonRect =
        tester.getRect(find.byKey(const Key('match-primary-action')));
    expect(buttonRect.bottom, lessThanOrEqualTo(640));

    await _disposeHost(
      tester,
      matchProvider,
      chatProvider,
      friendProvider,
    );
  });

  testWidgets('match tab should keep result actions visible on compact screens',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final matchProvider = MatchProvider(
      matchService: _FakeMatchService(
        startMatchHandler: (_) async => MatchStartAttempt.success(
          MatchResult(
            matchId: 'match-compact-success',
            threadId: 'thread-compact-success',
            user: User(
              id: 'u_match_compact',
              uid: 'SNF0A301',
              nickname: 'Compact Match',
              avatar: 'A',
              distance: '2km',
              status: 'ready to chat',
              isOnline: true,
              hasLocationPermission: true,
            ),
            remaining: 19,
            createdAt: DateTime(2026, 3, 18, 10),
            expiresAt: DateTime(2026, 3, 19, 10),
          ),
        ),
      ),
      allowMockFallback: false,
    );
    final chatProvider = ChatProvider(
      enableRealtime: false,
      enableRemoteHydration: false,
    );
    final friendProvider = FriendProvider(enableRemoteHydration: false);

    await tester.pumpWidget(
      _buildHost(
        matchProvider: matchProvider,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('match-primary-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const Key('match-result-card')), findsOneWidget);
    expect(find.byKey(const Key('match-result-actions')), findsOneWidget);

    final actionsRect =
        tester.getRect(find.byKey(const Key('match-result-actions')));
    expect(actionsRect.bottom, lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);

    await _disposeHost(
      tester,
      matchProvider,
      chatProvider,
      friendProvider,
    );
  });
}
