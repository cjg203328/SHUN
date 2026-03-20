import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sunliao/config/app_env.dart';
import 'package:sunliao/providers/auth_provider.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/friend_provider.dart';
import 'package:sunliao/providers/match_provider.dart';
import 'package:sunliao/providers/notification_center_provider.dart';
import 'package:sunliao/providers/profile_provider.dart';
import 'package:sunliao/providers/settings_provider.dart';
import 'package:sunliao/screens/main_screen.dart';
import 'package:sunliao/screens/settings_screen.dart';
import 'package:sunliao/services/image_upload_service.dart';

import '../helpers/test_bootstrap.dart';

final List<int> _kTransparentImageBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Z0isAAAAASUVORK5CYII=',
);

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _TestHttpClient();
  }
}

class _TestHttpClient implements HttpClient {
  @override
  bool autoUncompress = false;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _TestHttpRequest(url);
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _TestHttpRequest(url);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class _TestHttpRequest implements HttpClientRequest {
  _TestHttpRequest(this.uri);

  @override
  final Uri uri;

  @override
  final HttpHeaders headers = _TestHttpHeaders();

  @override
  Future<HttpClientResponse> close() async {
    return _TestHttpResponse();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class _TestHttpResponse extends Stream<List<int>>
    implements HttpClientResponse {
  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => _kTransparentImageBytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_kTransparentImageBytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class _TestHttpHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

void main() {
  setUp(() async {
    await initTestAppStorage();
    HttpOverrides.global = _TestHttpOverrides();
  });

  tearDown(() {
    HttpOverrides.global = null;
  });

  Widget buildApp({
    String initialLocation = '/main',
    AuthProvider? authProvider,
  }) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/main',
          builder: (context, state) {
            final index =
                int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
            return MainScreen(initialIndex: index);
          },
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    );

    return MultiProvider(
      providers: [
        if (authProvider != null)
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider)
        else
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider<NotificationCenterProvider>.value(
          value: NotificationCenterProvider.instance,
        ),
        ChangeNotifierProvider(create: (_) => MatchProvider()),
        ChangeNotifierProvider(
          create: (_) => ChatProvider(
            enableRealtime: false,
            enableRemoteHydration: false,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => FriendProvider(enableRemoteHydration: false),
        ),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(enableRemoteHydration: false),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('main screen should render core content on default size',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('main-tab-stack')), findsOneWidget);
    expect(find.byKey(const Key('messages-tab-title')), findsOneWidget);
    expect(find.byKey(const Key('match-guide-card')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('main screen should show lightweight sync hint after login entry',
      (tester) async {
    await tester.pumpWidget(buildApp(initialLocation: '/main?entry=login'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('main-entry-sync-hint')), findsOneWidget);
    expect(find.byKey(const Key('main-entry-sync-spinner')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const Key('main-entry-sync-hint')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'main screen should also show lightweight sync hint from auth entry state',
      (tester) async {
    final authProvider = AuthProvider();
    addTearDown(authProvider.dispose);
    authProvider.debugPrimePendingEntryHintSource('login');

    await tester.pumpWidget(
      buildApp(
        initialLocation: '/main',
        authProvider: authProvider,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('main-entry-sync-hint')), findsOneWidget);
    expect(find.byKey(const Key('main-entry-sync-spinner')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const Key('main-entry-sync-hint')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('main screen should show messages tab from route query',
      (tester) async {
    await tester.pumpWidget(buildApp(initialLocation: '/main?tab=1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('messages-tab-title')), findsNothing);
    expect(find.byKey(const Key('match-guide-card')), findsOneWidget);
  });

  testWidgets(
      'main screen should keep profile quick actions visible on compact size',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildApp(initialLocation: '/main?tab=3'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
        find.byKey(const Key('profile-compact-identity-card')), findsOneWidget);
    expect(find.byKey(const Key('profile-stats-card')), findsOneWidget);
    expect(find.byKey(const Key('profile-quick-actions-card')), findsOneWidget);
    expect(find.byKey(const Key('profile-quick-actions-badge')), findsNothing);
    expect(find.byKey(const Key('profile-readiness-chip')), findsOneWidget);
    expect(
        find.byKey(const Key('profile-completion-checklist')), findsOneWidget);
    expect(find.byKey(const Key('profile-avatar-edit-pill')), findsOneWidget);
    expect(find.byKey(const Key('profile-check-background')), findsOneWidget);
    expect(find.byKey(const Key('profile-check-signature')), findsOneWidget);
    expect(find.byKey(const Key('profile-check-status')), findsOneWidget);
    expect(find.byKey(const Key('profile-quick-avatar')), findsOneWidget);
    expect(find.byKey(const Key('profile-quick-status')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('profile-quick-avatar')),
        matching: find.text('补头像'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('profile-quick-status')),
        matching: find.text('改状态'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('profile-quick-background-mode')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('profile-quick-background-mode')),
        matching: find.text('补背景'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('profile-quick-settings')), findsOneWidget);
    final quickStatusRect =
        tester.getRect(find.byKey(const Key('profile-quick-status')));
    final quickAvatarRect =
        tester.getRect(find.byKey(const Key('profile-quick-avatar')));
    final quickBackgroundRect =
        tester.getRect(find.byKey(const Key('profile-quick-background-mode')));
    final checklistRect =
        tester.getRect(find.byKey(const Key('profile-completion-checklist')));
    final settingsRect =
        tester.getRect(find.byKey(const Key('profile-quick-settings')));
    expect(quickStatusRect.top, lessThan(checklistRect.top));
    expect(quickAvatarRect.width, greaterThanOrEqualTo(88));
    expect(quickStatusRect.height, greaterThanOrEqualTo(34));
    expect(quickStatusRect.width, greaterThanOrEqualTo(88));
    expect(quickBackgroundRect.width, greaterThanOrEqualTo(88));
    expect(settingsRect.height, greaterThanOrEqualTo(34));
    expect(settingsRect.width, greaterThanOrEqualTo(84));
    expect(find.text('更多设置'), findsOneWidget);
    final quickActionsRect =
        tester.getRect(find.byKey(const Key('profile-quick-actions-card')));
    expect(quickActionsRect.bottom, lessThanOrEqualTo(640));
    final scrollableState = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('profile-main-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollableState.position.maxScrollExtent, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'profile compact media affordances should stay lightweight with background',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await ImageUploadService.saveBackgroundReference(
      'background/mock_compact_profile.png',
    );

    await tester.pumpWidget(buildApp(initialLocation: '/main?tab=3'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('profile-quick-avatar')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('profile-quick-background-mode')),
        matching: find.text('背景管理'),
      ),
      findsOneWidget,
    );
    expect(
        find.byKey(const Key('profile-background-edit-pill')), findsOneWidget);

    final avatarBadgeRect =
        tester.getRect(find.byKey(const Key('profile-avatar-edit-pill')));
    final backgroundBadgeRect =
        tester.getRect(find.byKey(const Key('profile-background-edit-pill')));

    expect(avatarBadgeRect.width, lessThanOrEqualTo(30));
    expect(avatarBadgeRect.height, lessThanOrEqualTo(30));
    expect(backgroundBadgeRect.width, lessThanOrEqualTo(32));
    expect(backgroundBadgeRect.height, lessThanOrEqualTo(32));
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile fullscreen background should show grouped quick rail',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await ImageUploadService.saveBackgroundReference(
      'background/mock_fullscreen_profile.png',
    );

    await tester.pumpWidget(buildApp(initialLocation: '/main?tab=3'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final mainContext = tester.element(find.byType(MainScreen));
    await Provider.of<ProfileProvider>(mainContext, listen: false)
        .updatePortraitFullscreenBackground(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('profile-quick-actions-card')), findsNothing);
    expect(find.byKey(const Key('profile-fullscreen-action-rail')),
        findsOneWidget);
    expect(
      find.byKey(const Key('profile-fullscreen-background-action')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('profile-fullscreen-settings-action')),
      findsOneWidget,
    );
    expect(find.text('背景'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);

    final railRect =
        tester.getRect(find.byKey(const Key('profile-fullscreen-action-rail')));
    final backgroundActionRect = tester.getRect(
      find.byKey(const Key('profile-fullscreen-background-action')),
    );
    final settingsActionRect = tester.getRect(
      find.byKey(const Key('profile-fullscreen-settings-action')),
    );

    expect(railRect.right, lessThanOrEqualTo(390));
    expect(backgroundActionRect.height, greaterThanOrEqualTo(40));
    expect(backgroundActionRect.width, greaterThanOrEqualTo(74));
    expect(settingsActionRect.height, greaterThanOrEqualTo(40));
    expect(settingsActionRect.width, greaterThanOrEqualTo(74));
    expect(backgroundActionRect.bottom, lessThan(settingsActionRect.top));

    await tester.tap(
      find.byKey(const Key('profile-fullscreen-background-action')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const Key('profile-background-management-sheet')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'profile compact avatar management sheet should show current media state',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildApp(initialLocation: '/main?tab=3'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('profile-quick-avatar')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const Key('profile-avatar-management-sheet')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('profile-avatar-management-preview')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
              find.byKey(const Key('profile-avatar-management-status')))
          .data,
      '当前还在使用默认头像',
    );
    expect(
      tester
          .widget<Text>(
              find.byKey(const Key('profile-avatar-management-badge')))
          .data,
      '待补充',
    );
    expect(find.text('补一个头像'), findsOneWidget);
    expect(
      find.byKey(const Key('profile-avatar-delete-action')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'profile background management sheet should restore default background',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await ImageUploadService.saveBackgroundReference(
      'background/mock_profile_management.png',
    );

    await tester.pumpWidget(buildApp(initialLocation: '/main?tab=3'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(
      find.byKey(const Key('profile-quick-background-mode')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const Key('profile-background-management-sheet')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('profile-background-management-status')),
          )
          .data,
      '当前背景已经生效',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('profile-background-management-badge')),
          )
          .data,
      '首屏展示中',
    );
    expect(find.text('重新上传背景'), findsOneWidget);
    expect(find.text('调整背景模式'), findsOneWidget);
    expect(find.byKey(const Key('profile-background-delete-action')),
        findsOneWidget);

    await tester.tap(
      find.byKey(const Key('profile-background-delete-action')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('app-dialog-confirm')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(await ImageUploadService.getBackgroundPath(), isNull);
    expect(
        find.byKey(const Key('profile-inline-feedback-card')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('profile-inline-feedback-title')))
          .data,
      '背景已恢复默认',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('profile-inline-feedback-badge')))
          .data,
      '已清空',
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('profile-quick-background-mode')),
        matching: find.text('补背景'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'profile checklist should jump directly to editors on compact size',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildApp(initialLocation: '/main?tab=3'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('profile-check-signature')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('profile-signature-sheet')), findsOneWidget);
    expect(
        find.byKey(const Key('profile-editor-preview-card')), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-editor-cancel')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(const Key('profile-check-status')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('profile-status-sheet')), findsOneWidget);
    expect(
        find.byKey(const Key('profile-status-current-card')), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-status-option-0')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('profile tab should show inline feedback after signature update',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildApp(initialLocation: '/main?tab=3'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester
        .ensureVisible(find.byKey(const Key('profile-priority-signature')));
    await tester.tap(find.byKey(const Key('profile-priority-signature')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(
      find.byKey(const Key('profile-editor-input')),
      '今晚想听点新鲜故事',
    );
    await tester.tap(find.byKey(const Key('profile-editor-save')));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('profile-inline-feedback-card')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('profile-inline-feedback-title')))
          .data,
      '签名已经更新',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('profile-inline-feedback-badge')))
          .data,
      '展示已刷新',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('profile-inline-feedback-description')),
          )
          .data,
      contains('新的签名已经写回当前资料卡'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile tab should open premium-style editor sheets',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildApp(initialLocation: '/main?tab=3'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('profile-priority-signature')), findsOneWidget);
    expect(find.byKey(const Key('profile-priority-status')), findsOneWidget);
    expect(
        find.byKey(const Key('profile-priority-background')), findsOneWidget);

    await tester
        .ensureVisible(find.byKey(const Key('profile-priority-signature')));
    await tester.tap(find.byKey(const Key('profile-priority-signature')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('profile-signature-sheet')), findsOneWidget);
    expect(
        find.byKey(const Key('profile-editor-preview-card')), findsOneWidget);
    expect(find.byKey(const Key('profile-editor-input')), findsOneWidget);
    expect(find.byKey(const Key('profile-editor-save')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('profile-editor-preview-card')),
        matching: find.text('默认'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('profile-editor-cancel')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('profile-signature-sheet')), findsNothing);

    await tester
        .ensureVisible(find.byKey(const Key('profile-priority-status')));
    await tester.tap(find.byKey(const Key('profile-priority-status')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('profile-status-sheet')), findsOneWidget);
    expect(
        find.byKey(const Key('profile-status-current-card')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('profile-status-current-value')))
          .data,
      '想找人聊聊',
    );

    await tester.tap(find.byKey(const Key('profile-status-option-0')));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'profile tab should keep priority actions focused on unfinished items',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildApp(initialLocation: '/main?tab=3'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('profile-priority-status')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('profile-check-status')),
        matching: find.text('去完善'),
      ),
      findsOneWidget,
    );

    await tester
        .ensureVisible(find.byKey(const Key('profile-priority-status')));
    await tester.tap(find.byKey(const Key('profile-priority-status')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('profile-status-sheet')), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-status-option-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-priority-status')), findsNothing);
    expect(find.byKey(const Key('profile-priority-signature')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('profile-check-status')),
        matching: find.text('可微调'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'profile tab should resolve remote media references after returning from settings',
    (tester) async {
      tester.view.physicalSize = const Size(430, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildApp(initialLocation: '/main?tab=3'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final profileScrollableFinder = find.descendant(
        of: find.byKey(const Key('profile-main-scroll')),
        matching: find.byType(Scrollable),
      );
      final profileScrollableState =
          tester.state<ScrollableState>(profileScrollableFinder);
      expect(profileScrollableState.position.maxScrollExtent, greaterThan(0));

      final quickSettingsButton =
          find.byKey(const Key('profile-quick-settings'));
      await tester.ensureVisible(quickSettingsButton);
      await tester.tap(quickSettingsButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);

      await ImageUploadService.saveAvatarReference('avatar/mock_uploaded.png');
      await ImageUploadService.saveBackgroundReference(
        'background/mock_uploaded.png',
      );

      final simulatedReturnOffset =
          profileScrollableState.position.maxScrollExtent > 120
              ? 120.0
              : profileScrollableState.position.maxScrollExtent / 2;
      expect(simulatedReturnOffset, greaterThan(0));
      profileScrollableState.position.jumpTo(simulatedReturnOffset);
      await tester.pump();
      expect(profileScrollableState.position.pixels, greaterThan(0));

      final settingsContext = tester.element(find.byType(SettingsScreen));
      GoRouter.of(settingsContext).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(
        find.byKey(const Key('profile-identity-sync-badge')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('profile-identity-sync-label')))
            .data,
        '首页同步中',
      );
      expect(
        find.byKey(const Key('profile-identity-sync-progress-icon')),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 320));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const Key('profile-settings-sync-hint')), findsOneWidget);
      expect(
        find.byKey(const Key('profile-identity-sync-badge')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('profile-identity-sync-label')))
            .data,
        '首页已同步',
      );
      expect(
        find.byKey(const Key('profile-identity-sync-complete-icon')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
                find.byKey(const Key('profile-inline-feedback-title')))
            .data,
        '头像和背景已同步到首页',
      );
      expect(
        tester
            .widget<Text>(
                find.byKey(const Key('profile-inline-feedback-badge')))
            .data,
        '展示已刷新',
      );
      expect(find.byKey(const Key('profile-avatar-media')), findsOneWidget);
      expect(
          find.byKey(const Key('profile-background-surface')), findsOneWidget);
      expect(
        find.byKey(const Key('profile-background-edit-pill')),
        findsOneWidget,
      );
      final refreshedScrollableState =
          tester.state<ScrollableState>(profileScrollableFinder);
      expect(refreshedScrollableState.position.pixels, lessThanOrEqualTo(8));

      final avatarImage = tester.widget<Image>(
        find.byKey(const Key('profile-avatar-media')),
      );
      expect(avatarImage.image, isA<NetworkImage>());
      expect(
        (avatarImage.image as NetworkImage).url,
        AppEnv.resolveMediaUrl('avatar/mock_uploaded.png'),
      );

      final backgroundSurface = tester.widget<Container>(
        find.byKey(const Key('profile-background-surface')),
      );
      final backgroundDecoration =
          backgroundSurface.decoration as BoxDecoration?;
      final backgroundImage = backgroundDecoration?.image?.image;

      expect(backgroundImage, isA<NetworkImage>());
      expect(
        (backgroundImage as NetworkImage).url,
        AppEnv.resolveMediaUrl('background/mock_uploaded.png'),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
