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
import 'package:sunliao/services/storage_service.dart';

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

  Future<void> pumpMainScreen(
    WidgetTester tester, {
    String initialLocation = '/main',
    AuthProvider? authProvider,
  }) async {
    await tester.pumpWidget(
      buildApp(
        initialLocation: initialLocation,
        authProvider: authProvider,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  List<String> collectTextValues(WidgetTester tester, Finder root) {
    return tester
        .widgetList<Text>(
          find.descendant(
            of: root,
            matching: find.byType(Text),
          ),
        )
        .map((widget) => widget.data)
        .whereType<String>()
        .toList();
  }

  testWidgets('main screen should render core content on default size',
      (tester) async {
    await pumpMainScreen(tester);

    expect(find.byKey(const Key('main-tab-stack')), findsOneWidget);
    expect(find.byKey(const Key('messages-tab-title')), findsOneWidget);
    expect(find.byKey(const Key('match-guide-card')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('main screen should show lightweight sync hint after login entry',
      (tester) async {
    await pumpMainScreen(tester, initialLocation: '/main?entry=login');

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

    await pumpMainScreen(
      tester,
      initialLocation: '/main',
      authProvider: authProvider,
    );

    expect(find.byKey(const Key('main-entry-sync-hint')), findsOneWidget);
    expect(find.byKey(const Key('main-entry-sync-spinner')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const Key('main-entry-sync-hint')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('main screen should show messages tab from route query',
      (tester) async {
    await pumpMainScreen(tester, initialLocation: '/main?tab=1');

    expect(find.byKey(const Key('messages-tab-title')), findsNothing);
    expect(find.byKey(const Key('match-guide-card')), findsNothing);
    expect(find.byKey(const Key('match-primary-action')), findsOneWidget);
  });

  testWidgets(
      'main screen should keep profile direct entry affordances visible on compact size',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpMainScreen(tester, initialLocation: '/main?tab=3');

    expect(
        find.byKey(const Key('profile-compact-identity-card')), findsOneWidget);
    expect(find.byKey(const Key('profile-stats-card')), findsOneWidget);
    expect(find.byKey(const Key('profile-quick-actions-card')), findsNothing);
    expect(find.byKey(const Key('profile-quick-actions-badge')), findsNothing);
    expect(find.byKey(const Key('profile-avatar-trigger')), findsOneWidget);
    expect(find.byKey(const Key('profile-avatar-edit-pill')), findsOneWidget);
    expect(find.byKey(const Key('profile-signature-trigger')), findsOneWidget);
    expect(find.byKey(const Key('profile-status-trigger')), findsOneWidget);
    expect(find.byKey(const Key('profile-header-settings-action')),
        findsOneWidget);
    expect(find.byKey(const Key('profile-background-surface')), findsOneWidget);
    expect(find.byKey(const Key('profile-background-edit-pill')), findsNothing);

    final avatarRect =
        tester.getRect(find.byKey(const Key('profile-avatar-trigger')));
    final signatureRect =
        tester.getRect(find.byKey(const Key('profile-signature-trigger')));
    final statusRect =
        tester.getRect(find.byKey(const Key('profile-status-trigger')));
    final settingsRect =
        tester.getRect(find.byKey(const Key('profile-header-settings-action')));

    expect(avatarRect.width, greaterThanOrEqualTo(64));
    expect(avatarRect.height, greaterThanOrEqualTo(64));
    expect(signatureRect.width, greaterThanOrEqualTo(180));
    expect(statusRect.height, greaterThanOrEqualTo(48));
    expect(statusRect.width, greaterThanOrEqualTo(220));
    expect(settingsRect.height, lessThanOrEqualTo(32));
    expect(settingsRect.width, lessThanOrEqualTo(32));
    expect(settingsRect.top, greaterThanOrEqualTo(0));

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

    await pumpMainScreen(tester, initialLocation: '/main?tab=3');

    expect(find.byKey(const Key('profile-avatar-trigger')), findsOneWidget);
    expect(find.byKey(const Key('profile-header-settings-action')),
        findsOneWidget);
    expect(
        find.byKey(const Key('profile-background-edit-pill')), findsOneWidget);

    final avatarBadgeRect =
        tester.getRect(find.byKey(const Key('profile-avatar-edit-pill')));
    final backgroundBadgeRect =
        tester.getRect(find.byKey(const Key('profile-background-edit-pill')));
    final settingsRect =
        tester.getRect(find.byKey(const Key('profile-header-settings-action')));

    expect(avatarBadgeRect.width, lessThanOrEqualTo(30));
    expect(avatarBadgeRect.height, lessThanOrEqualTo(30));
    expect(backgroundBadgeRect.width, lessThanOrEqualTo(32));
    expect(backgroundBadgeRect.height, lessThanOrEqualTo(32));
    expect(settingsRect.width, lessThanOrEqualTo(32));
    expect(settingsRect.height, lessThanOrEqualTo(32));
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

    await pumpMainScreen(tester, initialLocation: '/main?tab=3');

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

    await pumpMainScreen(tester, initialLocation: '/main?tab=3');

    await tester.tap(find.byKey(const Key('profile-avatar-trigger')));
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
      isNotEmpty,
    );
    expect(
      tester
          .widget<Text>(
              find.byKey(const Key('profile-avatar-management-badge')))
          .data,
      isNotEmpty,
    );
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

    await pumpMainScreen(tester, initialLocation: '/main?tab=3');

    await tester.tap(
      find.byKey(const Key('profile-background-edit-pill')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const Key('profile-background-management-sheet')),
      findsOneWidget,
    );
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
      isNotEmpty,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('profile-inline-feedback-badge')))
          .data,
      isNotEmpty,
    );
    expect(find.byKey(const Key('profile-background-edit-pill')), findsNothing);
    expect(find.byKey(const Key('profile-background-surface')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile background mode sheet should keep switch state in sync',
      (tester) async {
    await ImageUploadService.saveBackgroundReference(
      'background/mock_profile_mode.png',
    );

    await pumpMainScreen(tester, initialLocation: '/main?tab=3');

    await tester.tap(
      find.byKey(const Key('profile-background-edit-pill')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(
      find.byKey(const Key('profile-background-mode-action')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('profile-background-mode-sheet')),
      findsOneWidget,
    );

    Switch portraitSwitch = tester.widget<Switch>(
      find.byKey(const Key('profile-background-mode-portrait-switch')),
    );
    Switch transparentSwitch = tester.widget<Switch>(
      find.byKey(const Key('profile-background-mode-transparent-switch')),
    );

    expect(portraitSwitch.value, isFalse);
    expect(portraitSwitch.onChanged, isNotNull);
    expect(transparentSwitch.value, isFalse);
    expect(transparentSwitch.onChanged, isNull);

    await tester.tap(
      find.byKey(const Key('profile-background-mode-portrait-switch')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    portraitSwitch = tester.widget<Switch>(
      find.byKey(const Key('profile-background-mode-portrait-switch')),
    );
    transparentSwitch = tester.widget<Switch>(
      find.byKey(const Key('profile-background-mode-transparent-switch')),
    );

    expect(portraitSwitch.value, isTrue);
    expect(transparentSwitch.onChanged, isNotNull);

    await tester.tap(
      find.byKey(const Key('profile-background-mode-transparent-switch')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    transparentSwitch = tester.widget<Switch>(
      find.byKey(const Key('profile-background-mode-transparent-switch')),
    );
    expect(transparentSwitch.value, isTrue);

    await tester.tap(
      find.byKey(const Key('profile-background-mode-portrait-switch')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    portraitSwitch = tester.widget<Switch>(
      find.byKey(const Key('profile-background-mode-portrait-switch')),
    );
    transparentSwitch = tester.widget<Switch>(
      find.byKey(const Key('profile-background-mode-transparent-switch')),
    );

    expect(portraitSwitch.value, isFalse);
    expect(transparentSwitch.value, isFalse);
    expect(transparentSwitch.onChanged, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'profile direct entry affordances should jump directly to editors on compact size',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpMainScreen(tester, initialLocation: '/main?tab=3');

    await tester.tap(find.byKey(const Key('profile-signature-trigger')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('profile-signature-sheet')), findsOneWidget);
    expect(
        find.byKey(const Key('profile-editor-preview-card')), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-editor-cancel')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(const Key('profile-status-trigger')));
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

    await pumpMainScreen(tester, initialLocation: '/main?tab=3');

    await tester.tap(find.byKey(const Key('profile-signature-trigger')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(
      find.byKey(const Key('profile-editor-input')),
      'fresh signature',
    );
    await tester.tap(find.byKey(const Key('profile-editor-save')));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('profile-inline-feedback-card')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('profile-inline-feedback-title')))
          .data,
      isNotEmpty,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('profile-inline-feedback-badge')))
          .data,
      isNotEmpty,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('profile-inline-feedback-description')),
          )
          .data,
      isNotEmpty,
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

    await pumpMainScreen(tester, initialLocation: '/main?tab=3');

    expect(find.byKey(const Key('profile-signature-trigger')), findsOneWidget);
    expect(find.byKey(const Key('profile-status-trigger')), findsOneWidget);
    expect(find.byKey(const Key('profile-background-surface')), findsOneWidget);
    expect(find.byKey(const Key('profile-header-settings-action')),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-signature-trigger')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('profile-signature-sheet')), findsOneWidget);
    expect(
        find.byKey(const Key('profile-editor-preview-card')), findsOneWidget);
    expect(find.byKey(const Key('profile-editor-input')), findsOneWidget);
    expect(find.byKey(const Key('profile-editor-save')), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-editor-cancel')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('profile-signature-sheet')), findsNothing);

    await tester.tap(find.byKey(const Key('profile-status-trigger')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('profile-status-sheet')), findsOneWidget);
    expect(
        find.byKey(const Key('profile-status-current-card')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('profile-status-current-value')))
          .data,
      isNotEmpty,
    );

    await tester.tap(find.byKey(const Key('profile-status-option-0')));
    await tester.pumpAndSettle();
  });

  testWidgets('profile tab should keep direct status entry in sync',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpMainScreen(tester, initialLocation: '/main?tab=3');

    expect(find.byKey(const Key('profile-quick-actions-card')), findsNothing);
    expect(find.byKey(const Key('profile-status-trigger')), findsOneWidget);

    final initialStatusTexts = collectTextValues(
      tester,
      find.byKey(const Key('profile-status-trigger')),
    );
    expect(initialStatusTexts, isNotEmpty);

    await tester.tap(find.byKey(const Key('profile-status-trigger')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('profile-status-sheet')), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-status-option-1')));
    await tester.pumpAndSettle();

    final updatedStatusTexts = collectTextValues(
      tester,
      find.byKey(const Key('profile-status-trigger')),
    );

    expect(updatedStatusTexts, isNot(equals(initialStatusTexts)));
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

      await pumpMainScreen(tester, initialLocation: '/main?tab=3');

      final profileScrollableFinder = find.descendant(
        of: find.byKey(const Key('profile-main-scroll')),
        matching: find.byType(Scrollable),
      );
      final profileScrollableState =
          tester.state<ScrollableState>(profileScrollableFinder);
      expect(profileScrollableState.position.maxScrollExtent, greaterThan(0));

      final quickSettingsButton =
          find.byKey(const Key('profile-header-settings-action'));
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
        find.byKey(const Key('profile-identity-sync-complete-icon')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('profile-inline-feedback-title')),
            )
            .data,
        '头像和背景已同步',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('profile-inline-feedback-badge')),
            )
            .data,
        '已同步',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('profile-inline-feedback-description')),
            )
            .data,
        '当前首页已显示新的头像和背景。',
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

  testWidgets(
    'profile tab should show deferred settings sync copy for local-only media when remote refresh fails',
    (tester) async {
      final avatarFile = File(
        '${Directory.systemTemp.path}\\profile_settings_return_avatar_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      final backgroundFile = File(
        '${Directory.systemTemp.path}\\profile_settings_return_background_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await avatarFile.writeAsBytes(_kTransparentImageBytes);
      await backgroundFile.writeAsBytes(_kTransparentImageBytes);
      addTearDown(() async {
        if (await avatarFile.exists()) {
          await avatarFile.delete();
        }
        if (await backgroundFile.exists()) {
          await backgroundFile.delete();
        }
      });

      await StorageService.saveToken('remote-refresh-fail-token');
      await pumpMainScreen(tester, initialLocation: '/main?tab=3');

      final quickSettingsButton =
          find.byKey(const Key('profile-header-settings-action'));
      await tester.ensureVisible(quickSettingsButton);
      await tester.tap(quickSettingsButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);

      await ImageUploadService.saveAvatarReference(avatarFile.path);
      await ImageUploadService.saveBackgroundReference(backgroundFile.path);

      final settingsContext = tester.element(find.byType(SettingsScreen));
      GoRouter.of(settingsContext).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 320));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('profile-settings-sync-hint')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('profile-inline-feedback-title')),
            )
            .data,
        '头像和背景已保存在本机',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('profile-inline-feedback-badge')),
            )
            .data,
        '待联网同步',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('profile-inline-feedback-description')),
            )
            .data,
        '当前首页先显示新的头像和背景，联网后会继续同步到服务器。',
      );
    },
  );

  testWidgets(
    'profile tab should fallback cleanly when local media references are stale',
    (tester) async {
      final missingAvatarPath =
          '${Directory.systemTemp.path}\\missing_profile_avatar_${DateTime.now().microsecondsSinceEpoch}.png';
      final missingBackgroundPath =
          '${Directory.systemTemp.path}\\missing_profile_background_${DateTime.now().microsecondsSinceEpoch}.png';

      await ImageUploadService.saveAvatarReference(missingAvatarPath);
      await ImageUploadService.saveBackgroundReference(missingBackgroundPath);

      await pumpMainScreen(tester, initialLocation: '/main?tab=3');

      expect(find.byKey(const Key('profile-avatar-media')), findsNothing);

      final backgroundSurface = tester.widget<Container>(
        find.byKey(const Key('profile-background-surface')),
      );
      final backgroundDecoration =
          backgroundSurface.decoration as BoxDecoration?;
      expect(backgroundDecoration?.image, isNull);

      await tester.tap(find.byKey(const Key('profile-avatar-trigger')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byKey(const Key('profile-avatar-management-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('profile-avatar-management-image')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('profile-avatar-delete-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('app-dialog-cancel')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('profile-background-edit-pill')),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final backgroundThumbnail = tester.widget<Container>(
        find.byKey(const Key('profile-background-management-thumbnail')),
      );
      final backgroundThumbnailDecoration =
          backgroundThumbnail.decoration as BoxDecoration?;
      expect(backgroundThumbnailDecoration?.image, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile media management should show deferred sync copy for local-only media',
    (tester) async {
      final avatarFile = File(
        '${Directory.systemTemp.path}\\profile_local_avatar_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      final backgroundFile = File(
        '${Directory.systemTemp.path}\\profile_local_background_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await avatarFile.writeAsBytes(_kTransparentImageBytes);
      await backgroundFile.writeAsBytes(_kTransparentImageBytes);
      addTearDown(() async {
        if (await avatarFile.exists()) {
          await avatarFile.delete();
        }
        if (await backgroundFile.exists()) {
          await backgroundFile.delete();
        }
      });

      await ImageUploadService.saveAvatarReference(avatarFile.path);
      await ImageUploadService.saveBackgroundReference(backgroundFile.path);

      await pumpMainScreen(tester, initialLocation: '/main?tab=3');

      await tester.tap(find.byKey(const Key('profile-avatar-trigger')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('profile-avatar-management-status')),
            )
            .data,
        '头像已保存在本机',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('profile-avatar-management-badge')),
            )
            .data,
        '待联网同步',
      );
      expect(find.text('更换头像'), findsOneWidget);

      await tester.tap(find.byKey(const Key('profile-background-edit-pill')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('profile-background-management-status')),
            )
            .data,
        '背景已保存在本机',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('profile-background-management-badge')),
            )
            .data,
        '待联网同步',
      );
      expect(find.text('更换背景'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
