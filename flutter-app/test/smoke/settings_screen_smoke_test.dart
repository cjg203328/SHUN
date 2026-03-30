import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sunliao/models/app_notification.dart';
import 'package:sunliao/providers/auth_provider.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/friend_provider.dart';
import 'package:sunliao/providers/notification_center_provider.dart';
import 'package:sunliao/providers/settings_provider.dart';
import 'package:sunliao/repositories/app_data_repository.dart';
import 'package:sunliao/screens/notification_center_screen.dart';
import 'package:sunliao/screens/settings_screen.dart';
import 'package:sunliao/services/image_upload_service.dart';
import 'package:sunliao/services/media_upload_service.dart';
import 'package:sunliao/services/push_notification_service.dart';
import 'package:sunliao/services/storage_service.dart';
import 'package:sunliao/widgets/chat_delivery_debug_sheet.dart';
import 'package:sunliao/config/app_env.dart';

import '../helpers/test_bootstrap.dart';

class _TestPushNotificationService implements PushNotificationService {
  _TestPushNotificationService({
    required PushRuntimeState initialState,
    this.refreshedState,
  }) : _state = initialState;

  PushRuntimeState _state;
  final PushRuntimeState? refreshedState;

  @override
  PushRuntimeState get state => _state;

  @override
  Future<void> clearSession() async {}

  @override
  Future<void> initialize({required bool notificationsEnabled}) async {}

  @override
  Future<void> refreshPermissionState() async {
    _state = refreshedState ?? _state;
  }

  @override
  Future<void> syncSettings({required bool notificationsEnabled}) async {
    _state = PushRuntimeState(
      notificationsEnabled: notificationsEnabled,
      permissionGranted: _state.permissionGranted,
      deviceToken: notificationsEnabled ? _state.deviceToken : null,
      lastSyncedAt: _state.lastSyncedAt,
    );
  }

  @override
  void debugSetState(PushRuntimeState state) {
    _state = state;
  }
}

class _FakeMediaUploadService extends MediaUploadService {
  _FakeMediaUploadService({
    this.avatarResult,
    this.backgroundResult,
  });

  final String? avatarResult;
  final String? backgroundResult;

  @override
  Future<String> uploadUserMedia(String type, File imageFile) async {
    if (type == 'avatar') {
      return avatarResult ?? imageFile.path;
    }
    if (type == 'background') {
      return backgroundResult ?? imageFile.path;
    }
    return imageFile.path;
  }

  @override
  Future<UserMediaUploadResult> uploadUserMediaWithStatus(
    String type,
    File imageFile,
  ) async {
    final mediaRef = await uploadUserMedia(type, imageFile);
    final remoteSucceeded = mediaRef != imageFile.path;
    return UserMediaUploadResult(
      mediaRef: mediaRef,
      remoteAttempted: remoteSucceeded,
      remoteSucceeded: remoteSucceeded,
    );
  }
}

void main() {
  String? clipboardText;

  Future<void> revealInSettingsList(
    WidgetTester tester,
    Finder target, {
    double step = 220,
    int maxScrolls = 12,
    bool reverse = false,
  }) async {
    final scrollable = find.byType(Scrollable).first;
    for (var index = 0;
        index < maxScrolls && target.evaluate().isEmpty;
        index++) {
      await tester.drag(scrollable, Offset(0, reverse ? step : -step));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(target, findsOneWidget);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  setUp(() async {
    await initTestAppStorage();
    clipboardText = null;
    ImageUploadService.debugResetOverrides();
    await NotificationCenterProvider.instance.clearSession();
    PushNotificationService.instance.debugSetState(
      const PushRuntimeState(
        notificationsEnabled: true,
        permissionGranted: true,
        deviceToken: 'stub_push_test_device',
      ),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          final arguments = call.arguments;
          if (arguments is Map) {
            clipboardText = arguments['text']?.toString();
          }
          return null;
        case 'Clipboard.getData':
          return <String, dynamic>{'text': clipboardText};
      }
      return null;
    });
  });

  tearDown(() async {
    ImageUploadService.debugResetOverrides();
    PushNotificationService.instance.debugSetState(
      const PushRuntimeState(
        notificationsEnabled: true,
        permissionGranted: true,
        deviceToken: 'stub_push_test_device',
      ),
    );
    await NotificationCenterProvider.instance.clearSession();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets(
    'settings screen should filter delivery timeline by source and level',
    (tester) async {
      await AppDataRepository.instance.saveChatState(<String, dynamic>{
        'threads': <String, dynamic>{},
        'messages': <String, dynamic>{},
        'lastMessageTime': <String, dynamic>{},
        'recalledMessageIds': <String, dynamic>{},
        'deletedThreads': <String, dynamic>{},
        'deliveryStats': <String, dynamic>{
          'counters': <String, int>{
            'image_reselect_required': 1,
            'image_failed': 1,
            'retries_succeeded': 1,
            'text_succeeded': 1,
          },
          'recentEvents': <Map<String, dynamic>>[
            <String, dynamic>{
              'code': 'retries_succeeded',
              'label': '重试成功，已送达',
              'tagLabel': '重试',
              'timestamp': DateTime.now()
                  .subtract(const Duration(minutes: 1))
                  .toIso8601String(),
              'isError': false,
            },
            <String, dynamic>{
              'code': 'image_failed',
              'label': '图片发送失败',
              'tagLabel': '图片',
              'timestamp': DateTime.now()
                  .subtract(const Duration(minutes: 3))
                  .toIso8601String(),
              'isError': true,
            },
            <String, dynamic>{
              'code': 'image_reselect_required',
              'label': '原图失效，需重选图片',
              'tagLabel': '图片',
              'timestamp': DateTime.now()
                  .subtract(const Duration(minutes: 2))
                  .toIso8601String(),
              'isError': true,
            },
            <String, dynamic>{
              'code': 'text_succeeded',
              'label': '文本发送成功',
              'tagLabel': '文本',
              'timestamp': DateTime.now().toIso8601String(),
              'isError': false,
            },
          ],
        },
      });

      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      await StorageService.saveLocalPassword('123456');
      final authProvider = AuthProvider();
      await authProvider.updatePhone('13800138000');
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(enableRemoteHydration: false);
      await settingsProvider.applyExperiencePreset(
        SettingsExperiencePreset.responsive,
      );
      addTearDown(chatProvider.dispose);
      addTearDown(authProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000);
      await tester.pump();
      await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000);
      await tester.pump(const Duration(milliseconds: 300));
      showChatDeliveryStatsDebugSheet(
        tester.element(find.byType(SettingsScreen)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('发送反馈统计'), findsOneWidget);
      expect(find.text('最近发送轨迹'), findsOneWidget);
      expect(find.text('全部 · 4'), findsOneWidget);
      expect(find.text('失败 · 2'), findsOneWidget);
      expect(find.text('重试 · 1'), findsOneWidget);
      expect(find.text('图片 · 2'), findsOneWidget);
      expect(find.text('全部级别 · 4'), findsOneWidget);
      expect(find.text('成功恢复 · 1'), findsOneWidget);
      expect(find.text('失败阻断 · 1'), findsOneWidget);
      expect(find.text('需要重选 · 1'), findsOneWidget);
      expect(find.text('最新优先'), findsOneWidget);
      expect(find.text('异常优先'), findsOneWidget);
      expect(find.text('完整轨迹'), findsOneWidget);
      expect(find.text('最近异常'), findsOneWidget);
      expect(find.text('恢复'), findsOneWidget);
      expect(find.text('阻断'), findsOneWidget);
      expect(find.text('重选'), findsOneWidget);
      expect(find.text('常规'), findsOneWidget);
      expect(find.text('诊断结论'), findsOneWidget);
      expect(find.text('优先处理：图片需重选'), findsOneWidget);
      expect(find.text('原图已失效，需要重选。'), findsOneWidget);
      expect(find.text('重新选图后再发送'), findsOneWidget);
      expect(find.text('建议重选图片'), findsOneWidget);

      final latestTextY = tester.getTopLeft(find.text('文本发送成功')).dy;
      final latestReselectY = tester.getTopLeft(find.text('原图失效，需重选图片')).dy;
      expect(latestTextY, lessThan(latestReselectY));

      await tester.ensureVisible(find.text('最近异常'));
      await tester.tap(find.text('最近异常'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('图片链路'), findsOneWidget);
      expect(find.text('重试链路'), findsOneWidget);
      expect(find.text('待处理'), findsOneWidget);
      expect(find.text('已恢复'), findsOneWidget);
      expect(find.text('优先处理'), findsOneWidget);
      expect(find.text('2步'), findsOneWidget);
      expect(find.textContaining('状态：需重新选图'), findsOneWidget);
      expect(find.textContaining('状态：已恢复送达'), findsOneWidget);
      expect(find.text('异常集中在图片链路，共2步。'), findsOneWidget);
      expect(find.text('已恢复送达，无需处理'), findsOneWidget);
      expect(find.text('文本发送成功'), findsNothing);
      expect(find.text('优先处理：图片链路需重新选图'), findsOneWidget);
      expect(find.text('重新选图后再发送'), findsOneWidget);
      expect(find.text('建议重选图片'), findsWidgets);

      final pendingGroupY = tester.getTopLeft(find.text('图片链路')).dy;
      final resolvedGroupY = tester.getTopLeft(find.text('重试链路')).dy;
      expect(pendingGroupY, lessThan(resolvedGroupY));

      await tester.tap(
        find.byKey(const ValueKey<String>('chat-delivery-copy-summary')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(clipboardText, contains('发送反馈统计'));
      expect(clipboardText, contains('诊断结论'));
      expect(clipboardText, contains('优先处理：图片链路需重新选图'));
      expect(clipboardText, contains('建议：建议重选图片'));
      expect(clipboardText, contains('状态：原图已失效，需要重选。'));
      expect(clipboardText, contains('异常集中在图片链路，共2步。'));
      expect(clipboardText, contains('当前筛选：全部 / 全部级别 / 最新优先 / 最近异常'));
      expect(clipboardText, contains('图片链路｜2步｜需重新选图'));
      expect(clipboardText, contains('重试链路｜1步｜已恢复送达'));

      await tester.ensureVisible(find.text('完整轨迹'));
      await tester.tap(find.text('完整轨迹'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('图片链路'), findsNothing);
      expect(find.text('重试链路'), findsNothing);
      expect(find.text('文本发送成功'), findsOneWidget);

      await tester.ensureVisible(find.text('成功恢复 · 1'));
      await tester.tap(find.text('成功恢复 · 1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('重试成功，已送达'), findsOneWidget);
      expect(find.text('图片发送失败'), findsNothing);
      expect(find.text('原图失效，需重选图片'), findsNothing);

      await tester.ensureVisible(find.text('图片 · 2'));
      await tester.tap(find.text('图片 · 2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('当前筛选下暂无成功恢复轨迹'), findsWidgets);

      await tester.ensureVisible(find.text('需要重选 · 1'));
      await tester.tap(find.text('需要重选 · 1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('原图失效，需重选图片'), findsOneWidget);
      expect(find.text('图片发送失败'), findsNothing);

      await tester.ensureVisible(find.text('全部级别 · 4'));
      await tester.tap(find.text('全部级别 · 4'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.ensureVisible(find.text('全部 · 4'));
      await tester.tap(find.text('全部 · 4'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.ensureVisible(find.text('异常优先'));
      await tester.tap(find.text('异常优先'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final anomalyTextY = tester.getTopLeft(find.text('文本发送成功')).dy;
      final anomalyReselectY = tester.getTopLeft(find.text('原图失效，需重选图片')).dy;
      expect(anomalyReselectY, lessThan(anomalyTextY));

      await tester.ensureVisible(find.text('最近异常'));
      await tester.tap(find.text('最近异常'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('文本发送成功'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('chat-delivery-clear-stats')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('暂无发送反馈统计'), findsOneWidget);
      expect(find.text('暂无最近发送轨迹'), findsOneWidget);
      expect(find.text('全部 · 0'), findsOneWidget);
      expect(find.text('全部级别 · 0'), findsOneWidget);
    },
  );

  testWidgets(
    'settings screen should show specific blocked reason for retry failures',
    (tester) async {
      await AppDataRepository.instance.saveChatState(<String, dynamic>{
        'threads': <String, dynamic>{},
        'messages': <String, dynamic>{},
        'lastMessageTime': <String, dynamic>{},
        'recalledMessageIds': <String, dynamic>{},
        'deletedThreads': <String, dynamic>{},
        'deliveryStats': <String, dynamic>{
          'counters': <String, int>{
            'retries_failed': 1,
            'image_failed': 1,
          },
          'recentEvents': <Map<String, dynamic>>[
            <String, dynamic>{
              'code': 'retries_failed',
              'label': '重试失败',
              'tagLabel': '重试',
              'timestamp': DateTime.now().toIso8601String(),
              'isError': true,
            },
            <String, dynamic>{
              'code': 'image_failed',
              'label': '图片发送失败',
              'tagLabel': '图片',
              'timestamp': DateTime.now()
                  .subtract(const Duration(minutes: 2))
                  .toIso8601String(),
              'isError': true,
            },
          ],
        },
      });

      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final authProvider = AuthProvider();
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(enableRemoteHydration: false);
      addTearDown(chatProvider.dispose);
      addTearDown(authProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000);
      await tester.pump();
      await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000);
      await tester.pump(const Duration(milliseconds: 300));
      showChatDeliveryStatsDebugSheet(
        tester.element(find.byType(SettingsScreen)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('诊断结论'), findsOneWidget);
      expect(find.text('建议检查网络'), findsOneWidget);
      expect(find.text('最近一次重试仍未送达。'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('chat-delivery-copy-summary')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(clipboardText, contains('建议：建议检查网络'));
      expect(clipboardText, contains('状态：最近一次重试仍未送达。'));
    },
  );

  testWidgets(
    'settings screen should expose overview focus and quick actions',
    (tester) async {
      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final authProvider = AuthProvider();
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(enableRemoteHydration: false);
      addTearDown(chatProvider.dispose);
      addTearDown(authProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('settings-overview-focus-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-device-status-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-device-status-notification')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-device-status-presence')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-device-status-vibration')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-overview-phone-action')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-overview-uid-action')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-overview-notification-action')),
        findsOneWidget,
      );
      await revealInSettingsList(
        tester,
        find.byKey(const Key('settings-experience-preset-card')),
      );
      expect(
        find.byKey(const Key('settings-experience-preset-card')),
        findsOneWidget,
      );
      expect(
          find.byKey(const Key('settings-preset-responsive')), findsOneWidget);
      expect(find.byKey(const Key('settings-preset-balanced')), findsOneWidget);
      expect(
        find.byKey(const Key('settings-preset-quiet-observe')),
        findsOneWidget,
      );
      final avatarManagementFinder = find.byKey(
        const Key('settings-avatar-management-item'),
      );
      await revealInSettingsList(
        tester,
        avatarManagementFinder,
        reverse: true,
      );
      expect(
        find.descendant(
          of: avatarManagementFinder,
          matching: find.text('待补充'),
        ),
        findsOneWidget,
      );
      await tester.tap(avatarManagementFinder, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('settings-avatar-management-preview')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('settings-avatar-sheet')), findsOneWidget);
      expect(
        find.byKey(const Key('settings-avatar-sheet-preview')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-avatar-replace-action')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('settings-avatar-sheet-status')))
            .data,
        '正在使用默认头像',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('settings-avatar-sheet-badge')))
            .data,
        '待补充',
      );
      expect(find.text('上传头像'), findsOneWidget);
    },
  );

  testWidgets(
    'settings screen should translate toggle states into readable badges',
    (tester) async {
      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final authProvider = AuthProvider();
      await authProvider.updatePhone('13800138000');
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(enableRemoteHydration: false);
      await settingsProvider.updateInvisibleMode(true);
      await settingsProvider.updateNotificationEnabled(false);
      await settingsProvider.updateVibrationEnabled(false);
      addTearDown(chatProvider.dispose);
      addTearDown(authProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.descendant(
          of: find.byKey(const Key('settings-overview-focus-card')),
          matching: find.text('消息提醒当前已收起'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('settings-overview-focus-card')),
          matching: find.text('提醒已收起'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('settings-device-status-notification')),
          matching: find.text('提醒已收起'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('settings-device-status-presence')),
          matching: find.text('展示已收起'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('settings-device-status-vibration')),
          matching: find.text('提醒已收起'),
        ),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-invisible-mode-item')),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final invisibleBadgeText = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('settings-invisible-mode-badge')),
              matching: find.byType(Text),
            ),
          )
          .single
          .data;

      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-notification-item')),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final notificationBadgeText = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('settings-notification-badge')),
              matching: find.byType(Text),
            ),
          )
          .single
          .data;

      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-vibration-item')),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final vibrationBadgeText = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('settings-vibration-badge')),
              matching: find.byType(Text),
            ),
          )
          .single
          .data;

      expect(invisibleBadgeText, '展示已收起');
      expect(notificationBadgeText, '提醒已收起');
      expect(vibrationBadgeText, '提醒已收起');
    },
  );

  testWidgets(
    'settings screen should show inline feedback for toggle actions',
    (tester) async {
      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final authProvider = AuthProvider();
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(enableRemoteHydration: false);
      addTearDown(chatProvider.dispose);
      addTearDown(authProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final invisibleSwitch = find.descendant(
        of: find.byKey(const Key('settings-invisible-mode-item')),
        matching: find.byType(Switch),
      );
      await tester.scrollUntilVisible(
        invisibleSwitch,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(invisibleSwitch, warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-inline-feedback-card')),
        -120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(settingsProvider.invisibleMode, isTrue);
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-title')),
            )
            .data,
        '\u5c55\u793a\u5df2\u5207\u5230\u9690\u8eab',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-badge')),
            )
            .data,
        '\u5c55\u793a\u5df2\u6536\u8d77',
      );

      final notificationSwitch = find.descendant(
        of: find.byKey(const Key('settings-notification-item')),
        matching: find.byType(Switch),
      );
      await tester.scrollUntilVisible(
        notificationSwitch,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(notificationSwitch, warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-inline-feedback-card')),
        -120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(settingsProvider.notificationEnabled, isFalse);
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-title')),
            )
            .data,
        '\u901a\u77e5\u5df2\u5207\u5230\u9759\u9ed8',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-badge')),
            )
            .data,
        '\u63d0\u9192\u5df2\u6536\u8d77',
      );

      final vibrationSwitch = find.descendant(
        of: find.byKey(const Key('settings-vibration-item')),
        matching: find.byType(Switch),
      );
      await tester.scrollUntilVisible(
        vibrationSwitch,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(vibrationSwitch, warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-inline-feedback-card')),
        -120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(settingsProvider.vibrationEnabled, isFalse);
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-title')),
            )
            .data,
        '\u9707\u52a8\u63d0\u9192\u5df2\u7ecf\u6536\u8d77',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-badge')),
            )
            .data,
        '\u63d0\u9192\u5df2\u6536\u8d77',
      );

      await tester.pump(const Duration(milliseconds: 2600));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('settings-inline-feedback-card')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'settings screen should apply experience preset from device mode card',
    (tester) async {
      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final authProvider = AuthProvider();
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(enableRemoteHydration: false);
      addTearDown(chatProvider.dispose);
      addTearDown(authProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final quietObservePreset = find.byKey(
        const Key('settings-preset-quiet-observe'),
      );
      await revealInSettingsList(tester, quietObservePreset);
      await tester.tap(quietObservePreset, warnIfMissed: false);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(settingsProvider.invisibleMode, isTrue);
      expect(settingsProvider.notificationEnabled, isFalse);
      expect(settingsProvider.vibrationEnabled, isFalse);
      expect(
        settingsProvider.activeExperiencePreset,
        SettingsExperiencePreset.quietObserve,
      );

      final currentBadgeText = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(
                const Key('settings-experience-preset-current-badge'),
              ),
              matching: find.byType(Text),
            ),
          )
          .single
          .data;

      expect(currentBadgeText, '展示已收起');
      expect(
        find.byKey(const Key('settings-inline-feedback-card')),
        findsOneWidget,
      );
      expect(find.text('体验预设已切到安静观察'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-badge')),
            )
            .data,
        '\u5c55\u793a\u5df2\u6536\u8d77',
      );
      await revealInSettingsList(
        tester,
        find.byKey(const Key('settings-invisible-mode-item')),
        reverse: true,
      );
      expect(
        find.byKey(const Key('settings-invisible-mode-badge')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-notification-badge')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'settings screen should ignore tapping active experience preset in device mode card',
    (tester) async {
      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final authProvider = AuthProvider();
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(enableRemoteHydration: false);
      addTearDown(chatProvider.dispose);
      addTearDown(authProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        settingsProvider.activeExperiencePreset,
        SettingsExperiencePreset.responsive,
      );

      final responsivePreset = find.byKey(
        const Key('settings-preset-responsive'),
      );
      await revealInSettingsList(tester, responsivePreset);
      await tester.tap(responsivePreset, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        settingsProvider.activeExperiencePreset,
        SettingsExperiencePreset.responsive,
      );
      expect(
        find.byKey(const Key('settings-inline-feedback-card')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'settings screen should surface missing system notification permission',
    (tester) async {
      PushNotificationService.instance.debugSetState(
        const PushRuntimeState(
          notificationsEnabled: true,
          permissionGranted: false,
        ),
      );
      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final authProvider = AuthProvider();
      await authProvider.updatePhone('13800138000');
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(enableRemoteHydration: false);
      addTearDown(chatProvider.dispose);
      addTearDown(authProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('系统通知未打开'), findsOneWidget);
      expect(
        find.byKey(const Key('settings-notification-runtime-card')),
        findsOneWidget,
      );

      final runtimeBadgeText = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('settings-notification-runtime-badge')),
              matching: find.byType(Text),
            ),
          )
          .single
          .data;

      expect(runtimeBadgeText, '待授权');
      expect(
        find.byKey(const Key('settings-notification-runtime-action')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-notification-center-action')),
        findsOneWidget,
      );
      expect(find.text('去系统设置'), findsWidgets);
    },
  );

  testWidgets(
    'settings screen should surface syncing notification channel in overview focus',
    (tester) async {
      PushNotificationService.instance.debugSetState(
        const PushRuntimeState(
          notificationsEnabled: true,
          permissionGranted: true,
        ),
      );
      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final authProvider = AuthProvider();
      await authProvider.updatePhone('13800138000');
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(enableRemoteHydration: false);
      addTearDown(chatProvider.dispose);
      addTearDown(authProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('通知通道正在同步'), findsOneWidget);
      final runtimeBadgeText = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('settings-notification-runtime-badge')),
              matching: find.byType(Text),
            ),
          )
          .single
          .data;

      expect(runtimeBadgeText, '通道同步中');
      expect(find.text('刷新状态'), findsWidgets);
    },
  );

  testWidgets(
    'settings screen should open notification center from notification runtime card',
    (tester) async {
      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final authProvider = AuthProvider();
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(enableRemoteHydration: false);
      await settingsProvider.updateNotificationEnabled(false);

      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (context, state) => MultiProvider(
              providers: [
                ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
                ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
                ChangeNotifierProvider<FriendProvider>.value(
                  value: friendProvider,
                ),
                ChangeNotifierProvider<NotificationCenterProvider>.value(
                  value: NotificationCenterProvider.instance,
                ),
                ChangeNotifierProvider<SettingsProvider>.value(
                  value: settingsProvider,
                ),
              ],
              child: const SettingsScreen(),
            ),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => MultiProvider(
              providers: [
                ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
                ChangeNotifierProvider<NotificationCenterProvider>.value(
                  value: NotificationCenterProvider.instance,
                ),
              ],
              child: NotificationCenterScreen(
                initialFilter: NotificationCenterSourceFilter.fromQuery(
                  state.uri.queryParameters['source'],
                ),
              ),
            ),
          ),
        ],
      );

      addTearDown(chatProvider.dispose);
      addTearDown(authProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('settings-notification-runtime-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-notification-center-action')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const Key('settings-notification-center-action')),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        router.push('/notifications');
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pumpAndSettle();

      expect(find.byType(NotificationCenterScreen), findsOneWidget);
    },
  );

  testWidgets(
    'settings screen should summarize unread notification center items in runtime card',
    (tester) async {
      await StorageService.saveNotificationCenterState(
        jsonEncode([
          AppNotification(
            id: 'settings-summary-read',
            type: AppNotificationType.friendAccepted,
            title: '小满',
            body: '已通过你的好友申请',
            createdAt: DateTime.parse('2026-03-17T08:00:00.000'),
            userId: 'u_settings_summary_read',
            sourceKey: 'friend-accepted:u_settings_summary_read',
          ).toJson(),
          AppNotification(
            id: 'settings-summary-unread-older',
            type: AppNotificationType.system,
            title: '系统提醒',
            body: '今晚有新的活动推荐',
            createdAt: DateTime.parse('2026-03-17T08:30:00.000'),
            userId: 'system',
            sourceKey: 'system:settings-summary-unread-older',
          ).toJson(),
          AppNotification(
            id: 'settings-summary-unread-latest',
            type: AppNotificationType.message,
            title: '阿青',
            body: '周末一起喝咖啡吗？',
            createdAt: DateTime.parse('2099-03-17T09:00:00.000'),
            threadId: 'th_settings_summary',
            userId: 'u_settings_summary_latest',
            sourceKey: 'chat-message:th_settings_summary:msg-1',
          ).toJson(),
        ]),
      );
      await NotificationCenterProvider.instance.reloadFromStorage();
      await AppDataRepository.instance.saveNotificationEnabled(false);

      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final authProvider = AuthProvider();
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(enableRemoteHydration: false);
      addTearDown(chatProvider.dispose);
      addTearDown(authProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
            ChangeNotifierProvider<NotificationCenterProvider>.value(
              value: NotificationCenterProvider.instance,
            ),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('settings-notification-runtime-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-notification-center-summary-card')),
        findsOneWidget,
      );
      final unreadCount = NotificationCenterProvider.instance.unreadCount;
      expect(unreadCount, greaterThan(0));
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const Key('settings-notification-center-summary-title'),
              ),
            )
            .data,
        '还有 $unreadCount 条未读提醒',
      );
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(
                  const Key('settings-notification-center-summary-badge'),
                ),
                matching: find.byType(Text),
              ),
            )
            .data,
        '未读 $unreadCount',
      );
      final summaryDescription = tester
          .widget<Text>(
            find.byKey(
              const Key('settings-notification-center-summary-description'),
            ),
          )
          .data;
      expect(summaryDescription, contains('阿青'));
      expect(summaryDescription, contains('咖啡'));
      expect(
        find.byKey(const Key('settings-notification-center-source-overview')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('settings-notification-center-source-message'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('settings-notification-center-source-friend'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('settings-notification-center-source-system'),
        ),
        findsOneWidget,
      );
      expect(find.text('消息 1'), findsOneWidget);
      expect(find.text('好友 1'), findsOneWidget);
      expect(find.text('系统 1'), findsOneWidget);
    },
  );

  testWidgets(
    'settings screen should open notification center with source filter from summary chip',
    (tester) async {
      await StorageService.saveNotificationCenterState(
        jsonEncode([
          AppNotification(
            id: 'settings-filter-friend',
            type: AppNotificationType.friendAccepted,
            title: '小满',
            body: '已通过你的好友申请',
            createdAt: DateTime.parse('2026-03-17T08:00:00.000'),
            userId: 'u_settings_filter_friend',
            sourceKey: 'friend-accepted:u_settings_filter_friend',
          ).toJson(),
          AppNotification(
            id: 'settings-filter-system',
            type: AppNotificationType.system,
            title: '系统提醒',
            body: '今晚有新的活动推荐',
            createdAt: DateTime.parse('2026-03-17T08:30:00.000'),
            userId: 'system',
            sourceKey: 'system:settings-filter-system',
          ).toJson(),
          AppNotification(
            id: 'settings-filter-message',
            type: AppNotificationType.message,
            title: '阿青',
            body: '周末一起喝咖啡吗？',
            createdAt: DateTime.parse('2099-03-17T09:00:00.000'),
            threadId: 'th_settings_filter',
            userId: 'u_settings_filter_message',
            sourceKey: 'chat-message:th_settings_filter:msg-1',
          ).toJson(),
        ]),
      );
      await NotificationCenterProvider.instance.reloadFromStorage();
      await AppDataRepository.instance.saveNotificationEnabled(false);

      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final authProvider = AuthProvider();
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(enableRemoteHydration: false);
      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (context, state) => MultiProvider(
              providers: [
                ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
                ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
                ChangeNotifierProvider<FriendProvider>.value(
                  value: friendProvider,
                ),
                ChangeNotifierProvider<NotificationCenterProvider>.value(
                  value: NotificationCenterProvider.instance,
                ),
                ChangeNotifierProvider<SettingsProvider>.value(
                  value: settingsProvider,
                ),
              ],
              child: const SettingsScreen(),
            ),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => MultiProvider(
              providers: [
                ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
                ChangeNotifierProvider<NotificationCenterProvider>.value(
                  value: NotificationCenterProvider.instance,
                ),
                ChangeNotifierProvider<SettingsProvider>.value(
                  value: settingsProvider,
                ),
              ],
              child: NotificationCenterScreen(
                initialFilter: NotificationCenterSourceFilter.fromQuery(
                  state.uri.queryParameters['source'],
                ),
              ),
            ),
          ),
        ],
      );

      addTearDown(chatProvider.dispose);
      addTearDown(authProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final friendSourceChip = find.byKey(
        const Key('settings-notification-center-source-friend'),
      );
      expect(friendSourceChip, findsOneWidget);
      await tester.ensureVisible(friendSourceChip);
      tester.widget<InkWell>(friendSourceChip).onTap!.call();
      await tester.pumpAndSettle();

      expect(find.byType(NotificationCenterScreen), findsOneWidget);
      expect(
        find.byKey(const Key('notification-center-filter-friend')),
        findsOneWidget,
      );
      expect(find.text('小满'), findsOneWidget);
      expect(find.text('阿青'), findsNothing);
      expect(find.text('系统提醒'), findsNothing);
    },
  );

  testWidgets(
    'settings screen should copy uid from overview action with inline feedback',
    (tester) async {
      await AppDataRepository.instance.saveAuthState(
        phone: '13800138000',
        token: 'stub_token',
        uid: 'SNTEST2026',
      );

      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final authProvider = AuthProvider();
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(enableRemoteHydration: false);
      addTearDown(chatProvider.dispose);
      addTearDown(authProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(authProvider.uid, 'SNTEST2026');

      final uidAction = find.byKey(const Key('settings-overview-uid-action'));
      expect(uidAction, findsOneWidget);
      await tester.ensureVisible(uidAction);
      await tester.pumpAndSettle();
      await tester.tap(uidAction, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(clipboardText, 'SNTEST2026');
      expect(
        find.byKey(const Key('settings-inline-feedback-card')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-title')),
            )
            .data,
        '\u0055\u0049\u0044 \u5df2\u590d\u5236',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-badge')),
            )
            .data,
        '\u53ef\u590d\u5236',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-description')),
            )
            .data,
        contains('UID'),
      );
    },
  );

  testWidgets(
    'settings screen should show inline feedback when uid is not ready',
    (tester) async {
      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final authProvider = AuthProvider();
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(enableRemoteHydration: false);
      addTearDown(chatProvider.dispose);
      addTearDown(authProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(authProvider.uid, isNull);
      final uidAction = find.byKey(const Key('settings-overview-uid-action'));
      expect(uidAction, findsOneWidget);
      await tester.ensureVisible(uidAction);
      await tester.pumpAndSettle();
      await tester.tap(uidAction, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(clipboardText, isNull);
      expect(
        find.byKey(const Key('settings-inline-feedback-card')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-title')),
            )
            .data,
        '\u0055\u0049\u0044 \u8fd8\u672a\u5c31\u7eea',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-badge')),
            )
            .data,
        '\u751f\u6210\u4e2d',
      );
    },
  );

  testWidgets(
    'settings screen should show inline feedback after opening notification system settings',
    (tester) async {
      PushNotificationService.instance.debugSetState(
        const PushRuntimeState(
          notificationsEnabled: true,
          permissionGranted: false,
        ),
      );

      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final authProvider = AuthProvider();
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(enableRemoteHydration: false);
      addTearDown(chatProvider.dispose);
      addTearDown(authProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final runtimeAction = find.byKey(
        const Key('settings-notification-runtime-action'),
      );
      await tester.ensureVisible(runtimeAction);
      await tester.pumpAndSettle();
      await tester.tap(runtimeAction, warnIfMissed: false);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('settings-inline-feedback-card')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-title')),
            )
            .data,
        '\u5df2\u6253\u5f00\u7cfb\u7edf\u8bbe\u7f6e',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-badge')),
            )
            .data,
        '\u7b49\u5f85\u8fd4\u56de',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-description')),
            )
            .data,
        contains('\u8fd4\u56de\u5e94\u7528'),
      );
      expect(
        find.byKey(const Key('settings-notification-runtime-card')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'settings screen should auto refresh notification permission after returning from system settings',
    (tester) async {
      final pushNotificationService = _TestPushNotificationService(
        initialState: const PushRuntimeState(
          notificationsEnabled: true,
          permissionGranted: false,
        ),
        refreshedState: const PushRuntimeState(
          notificationsEnabled: true,
          permissionGranted: true,
          deviceToken: 'stub_resumed_ready_device_token',
        ),
      );

      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final authProvider = AuthProvider();
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(
        pushNotificationService: pushNotificationService,
        enableRemoteHydration: false,
      );
      addTearDown(chatProvider.dispose);
      addTearDown(authProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(settingsProvider.pushRuntimeState.deviceToken, isNull);

      final runtimeAction = find.byKey(
        const Key('settings-notification-runtime-action'),
      );
      await tester.ensureVisible(runtimeAction);
      await tester.pumpAndSettle();
      await tester.tap(runtimeAction, warnIfMissed: false);
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(settingsProvider.pushRuntimeState.deviceToken, isNotNull);
      expect(
        find.byKey(const Key('settings-notification-runtime-card')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('settings-inline-feedback-card')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-title')),
            )
            .data,
        '\u901a\u77e5\u5df2\u7ecf\u6062\u590d\u5728\u7ebf',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-badge')),
            )
            .data,
        '\u901a\u9053\u5df2\u5c31\u7eea',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-description')),
            )
            .data,
        contains('\u7cfb\u7edf\u901a\u77e5\u6743\u9650\u5df2\u6062\u590d'),
      );
    },
  );

  testWidgets(
    'settings screen should avoid duplicate recovery feedback when notification permission is unchanged after returning from system settings',
    (tester) async {
      final pushNotificationService = _TestPushNotificationService(
        initialState: const PushRuntimeState(
          notificationsEnabled: true,
          permissionGranted: false,
        ),
        refreshedState: const PushRuntimeState(
          notificationsEnabled: true,
          permissionGranted: false,
        ),
      );

      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final authProvider = AuthProvider();
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(
        pushNotificationService: pushNotificationService,
        enableRemoteHydration: false,
      );
      addTearDown(chatProvider.dispose);
      addTearDown(authProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final runtimeAction = find.byKey(
        const Key('settings-notification-runtime-action'),
      );
      await tester.ensureVisible(runtimeAction);
      await tester.pumpAndSettle();
      await tester.tap(runtimeAction, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-title')),
            )
            .data,
        '已打开系统设置',
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(settingsProvider.pushRuntimeState.deviceToken, isNull);
      expect(
        find.byKey(const Key('settings-notification-runtime-card')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-title')),
            )
            .data,
        '已打开系统设置',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-badge')),
            )
            .data,
        '等待返回',
      );
    },
  );

  testWidgets(
    'settings screen should refresh notification runtime state into ready feedback',
    (tester) async {
      final pushNotificationService = _TestPushNotificationService(
        initialState: const PushRuntimeState(
          notificationsEnabled: true,
          permissionGranted: true,
        ),
        refreshedState: const PushRuntimeState(
          notificationsEnabled: true,
          permissionGranted: true,
          deviceToken: 'stub_ready_device_token',
        ),
      );

      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final authProvider = AuthProvider();
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(
        pushNotificationService: pushNotificationService,
        enableRemoteHydration: false,
      );
      addTearDown(chatProvider.dispose);
      addTearDown(authProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(settingsProvider.pushRuntimeState.deviceToken, isNull);
      expect(
        find.byKey(const Key('settings-notification-runtime-card')),
        findsOneWidget,
      );

      final runtimeAction = find.byKey(
        const Key('settings-notification-runtime-action'),
      );
      expect(runtimeAction, findsOneWidget);
      await tester.ensureVisible(runtimeAction);
      await tester.pumpAndSettle();
      await tester.tap(runtimeAction, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(settingsProvider.pushRuntimeState.deviceToken, isNotNull);
      expect(
        find.byKey(const Key('settings-notification-runtime-card')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('settings-inline-feedback-card')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-title')),
            )
            .data,
        '\u901a\u77e5\u5df2\u7ecf\u6062\u590d\u5728\u7ebf',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-badge')),
            )
            .data,
        '\u901a\u9053\u5df2\u5c31\u7eea',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-description')),
            )
            .data,
        contains('\u90fd\u5df2\u5c31\u7eea'),
      );
    },
  );

  testWidgets(
    'settings screen should manage blocked users with sheet summary and empty state',
    (tester) async {
      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final authProvider = AuthProvider();
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(enableRemoteHydration: false);
      final blockedUser = friendProvider.searchUserByUid('SNF0A101');
      expect(blockedUser, isNotNull);
      friendProvider.addFriendDirect(blockedUser!);
      await friendProvider.blockUser(blockedUser.id);

      addTearDown(chatProvider.dispose);
      addTearDown(authProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final blockedUsersFinder = find.byKey(
        const Key('settings-blocked-users-item'),
      );
      await tester.scrollUntilVisible(
        blockedUsersFinder,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(blockedUsersFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-blocked-sheet')), findsOneWidget);
      expect(
        find.byKey(const Key('settings-blocked-summary-card')),
        findsOneWidget,
      );
      expect(
          find.byKey(const Key('settings-blocked-count-chip')), findsOneWidget);
      expect(find.text('1 人'), findsOneWidget);
      expect(
        find.byKey(
          ValueKey<String>('settings-blocked-row-${blockedUser.id}'),
        ),
        findsOneWidget,
      );
      expect(find.text(blockedUser.nickname), findsOneWidget);

      await tester.tap(
        find.byKey(
          ValueKey<String>('settings-blocked-restore-${blockedUser.id}'),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(friendProvider.isBlocked(blockedUser.id), isFalse);
      expect(
        find.byKey(const Key('settings-blocked-sheet')),
        findsNothing,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-inline-feedback-card')),
        -120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('settings-inline-feedback-card')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-title')),
            )
            .data,
        '\u5df2\u89e3\u9664\u62c9\u9ed1',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-badge')),
            )
            .data,
        '\u5173\u7cfb\u5df2\u6062\u590d',
      );

      await tester.scrollUntilVisible(
        blockedUsersFinder,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(blockedUsersFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-blocked-sheet')), findsOneWidget);
      expect(
        find.byKey(
          ValueKey<String>('settings-blocked-row-${blockedUser.id}'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const Key('settings-blocked-empty-state')),
        findsOneWidget,
      );
      expect(find.text('0 人'), findsOneWidget);
    },
  );
  testWidgets(
    'settings screen should restore avatar and background defaults with inline feedback',
    (tester) async {
      await ImageUploadService.saveAvatarReference('avatar/mock_remote.png');
      await ImageUploadService.saveBackgroundReference(
        'background/mock_remote.png',
      );

      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final authProvider = AuthProvider();
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(enableRemoteHydration: false);
      addTearDown(chatProvider.dispose);
      addTearDown(authProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final avatarManagementItem = find.byKey(
        const Key('settings-avatar-management-item'),
      );
      await tester.scrollUntilVisible(
        avatarManagementItem,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: avatarManagementItem,
          matching: find.text('已同步'),
        ),
        findsOneWidget,
      );
      await tester.tap(avatarManagementItem, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('settings-avatar-management-preview')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('settings-avatar-sheet')), findsOneWidget);
      expect(
        find.byKey(const Key('settings-avatar-sheet-preview')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-avatar-delete-action')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('settings-avatar-sheet-status')))
            .data,
        '头像已同步',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('settings-avatar-sheet-badge')))
            .data,
        '展示中',
      );
      expect(find.text('更换头像'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('settings-avatar-delete-action')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, '\u786e\u5b9a'),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-inline-feedback-card')),
        -120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(await ImageUploadService.getAvatarPath(), isNull);
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-title')),
            )
            .data,
        '\u5934\u50cf\u5df2\u6062\u590d\u9ed8\u8ba4',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-badge')),
            )
            .data,
        '\u5df2\u6e05\u7a7a',
      );

      final backgroundManagementItem = find.byKey(
        const Key('settings-background-management-item'),
      );
      await tester.scrollUntilVisible(
        backgroundManagementItem,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: backgroundManagementItem,
          matching: find.text('首屏已生效'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-background-management-preview')),
        findsOneWidget,
      );
      await tester.tap(backgroundManagementItem, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('settings-background-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-background-sheet-preview')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-background-delete-action')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-background-sheet-status')),
            )
            .data,
        '背景已生效',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-background-sheet-badge')),
            )
            .data,
        '首屏展示中',
      );
      expect(find.text('更换背景'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('settings-background-delete-action')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, '\u786e\u5b9a'),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-inline-feedback-card')),
        -120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(await ImageUploadService.getBackgroundPath(), isNull);
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-title')),
            )
            .data,
        '\u80cc\u666f\u5df2\u6062\u590d\u9ed8\u8ba4',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-badge')),
            )
            .data,
        '\u5df2\u6e05\u7a7a',
      );
    },
  );

  testWidgets(
    'settings screen should show inline feedback after avatar and background update succeeds',
    (tester) async {
      ImageUploadService.debugAvatarPickOverride = (_) async {
        return File('avatar/mock_local_pick.jpg');
      };
      ImageUploadService.debugBackgroundPickOverride = (_) async {
        return File('background/mock_local_pick.jpg');
      };

      final mediaUploadService = _FakeMediaUploadService(
        avatarResult: AppEnv.resolveMediaUrl('avatar/mock_uploaded.png'),
        backgroundResult:
            AppEnv.resolveMediaUrl('background/mock_uploaded.png'),
      );

      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final authProvider = AuthProvider();
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(enableRemoteHydration: false);
      addTearDown(chatProvider.dispose);
      addTearDown(authProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: MaterialApp(
            home: SettingsScreen(mediaUploadService: mediaUploadService),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final avatarManagementItem = find.byKey(
        const Key('settings-avatar-management-item'),
      );
      await tester.scrollUntilVisible(
        avatarManagementItem,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(avatarManagementItem, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('上传头像'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('settings-avatar-replace-action')),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.fling(find.byType(ListView), const Offset(0, 1800), 3000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('settings-inline-feedback-card')),
        findsOneWidget,
      );

      expect(
        await ImageUploadService.getAvatarPath(),
        AppEnv.resolveMediaUrl('avatar/mock_uploaded.png'),
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-title')),
            )
            .data,
        '\u5934\u50cf\u5df2\u7ecf\u66f4\u65b0',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-badge')),
            )
            .data,
        '\u8d44\u6599\u5df2\u5237\u65b0',
      );
      await tester.scrollUntilVisible(
        avatarManagementItem,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: avatarManagementItem,
          matching: find.text('已同步'),
        ),
        findsOneWidget,
      );

      final backgroundManagementItem = find.byKey(
        const Key('settings-background-management-item'),
      );
      await tester.scrollUntilVisible(
        backgroundManagementItem,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(backgroundManagementItem, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('上传背景'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('settings-background-replace-action')),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.fling(find.byType(ListView), const Offset(0, 1800), 3000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('settings-inline-feedback-card')),
        findsOneWidget,
      );

      expect(
        await ImageUploadService.getBackgroundPath(),
        AppEnv.resolveMediaUrl('background/mock_uploaded.png'),
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-title')),
            )
            .data,
        '\u80cc\u666f\u5df2\u7ecf\u66f4\u65b0',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-badge')),
            )
            .data,
        '\u6c1b\u56f4\u5df2\u5237\u65b0',
      );
      await tester.scrollUntilVisible(
        backgroundManagementItem,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: backgroundManagementItem,
          matching: find.text('首屏已生效'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'settings screen should open account security sheets',
    (tester) async {
      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final authProvider = AuthProvider();
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(enableRemoteHydration: false);
      addTearDown(chatProvider.dispose);
      addTearDown(authProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final overviewPhoneAction = find.byKey(
        const Key('settings-overview-phone-action'),
      );
      await tester.scrollUntilVisible(
        overviewPhoneAction,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(overviewPhoneAction, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-phone-sheet')), findsOneWidget);
      expect(find.byKey(const Key('settings-phone-hint-card')), findsOneWidget);
      expect(find.byKey(const Key('settings-phone-input')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('settings-phone-input')),
        '13900139000',
      );
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('settings-phone-save')))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const Key('settings-phone-save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-phone-sheet')), findsNothing);
      expect(authProvider.phone, '13900139000');
      expect(
        find.byKey(const Key('settings-inline-feedback-card')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
                find.byKey(const Key('settings-inline-feedback-title')))
            .data,
        '\u624b\u673a\u53f7\u5df2\u7ecf\u66f4\u65b0',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-badge')),
            )
            .data,
        '\u8d26\u53f7\u5df2\u5237\u65b0',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-description')),
            )
            .data,
        contains(
            '\u65b0\u624b\u673a\u53f7\u5df2\u540c\u6b65\u5230\u8d26\u53f7\u8d44\u6599'),
      );

      final passwordItem = find.byKey(const Key('settings-password-item'));
      await tester.scrollUntilVisible(
        passwordItem,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(passwordItem, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-password-sheet')), findsOneWidget);
      expect(
        find.byKey(const Key('settings-password-hint-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-password-old-input')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-password-new-input')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-password-confirm-input')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('settings-password-old-input')),
        '123456',
      );
      await tester.enterText(
        find.byKey(const Key('settings-password-new-input')),
        '654321',
      );
      await tester.enterText(
        find.byKey(const Key('settings-password-confirm-input')),
        '654321',
      );
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('settings-password-save')))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const Key('settings-password-save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-password-sheet')), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-overview-focus-card')),
        -120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('settings-inline-feedback-card')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
                find.byKey(const Key('settings-inline-feedback-title')))
            .data,
        '\u5bc6\u7801\u5df2\u7ecf\u66f4\u65b0',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-badge')),
            )
            .data,
        '\u5b89\u5168\u5df2\u5237\u65b0',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-inline-feedback-description')),
            )
            .data,
        contains('\u65b0\u5bc6\u7801\u5df2\u4fdd\u5b58'),
      );
    },
  );

  testWidgets(
    'settings screen should keep account sheets open until inputs are valid',
    (tester) async {
      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final authProvider = AuthProvider();
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(enableRemoteHydration: false);
      await StorageService.saveLocalPassword('123456');
      addTearDown(chatProvider.dispose);
      addTearDown(authProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final overviewPhoneAction = find.byKey(
        const Key('settings-overview-phone-action'),
      );
      await tester.scrollUntilVisible(
        overviewPhoneAction,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(overviewPhoneAction, warnIfMissed: false);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('settings-phone-input')),
        '12345',
      );
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('settings-phone-save')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('settings-phone-save')));
      await tester.pump();

      expect(authProvider.phone, isNull);
      expect(find.byKey(const Key('settings-phone-sheet')), findsOneWidget);
      expect(
        find.byKey(const Key('settings-phone-validation-card')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('settings-phone-validation-card')),
          matching: find.text('还需要完整的 11 位手机号'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-inline-feedback-card')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('settings-phone-cancel')));
      await tester.pumpAndSettle();

      final passwordItem = find.byKey(const Key('settings-password-item'));
      await tester.scrollUntilVisible(
        passwordItem,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(passwordItem, warnIfMissed: false);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('settings-password-old-input')),
        '111111',
      );
      await tester.enterText(
        find.byKey(const Key('settings-password-new-input')),
        '654321',
      );
      await tester.enterText(
        find.byKey(const Key('settings-password-confirm-input')),
        '654321',
      );
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('settings-password-save')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('settings-password-save')));
      await tester.pump();

      expect(StorageService.getLocalPassword(), '123456');
      expect(find.byKey(const Key('settings-password-sheet')), findsOneWidget);
      expect(
        find.byKey(const Key('settings-password-validation-card')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('settings-password-validation-card')),
          matching: find.text('旧密码还未校验通过'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-inline-feedback-card')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'settings screen should keep overview actions visible on compact size',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final authProvider = AuthProvider();
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(enableRemoteHydration: false);
      addTearDown(chatProvider.dispose);
      addTearDown(authProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final notificationAction = find.byKey(
        const Key('settings-overview-notification-action'),
      );
      final phoneAction = find.byKey(
        const Key('settings-overview-phone-action'),
      );
      await tester.scrollUntilVisible(
        notificationAction,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        phoneAction,
        findsOneWidget,
      );
      expect(
        notificationAction,
        findsOneWidget,
      );
      final actionRect = tester.getRect(notificationAction);
      final responsivePreset = find.byKey(
        const Key('settings-preset-responsive'),
      );
      await revealInSettingsList(tester, responsivePreset);
      final balancedPreset = find.byKey(
        const Key('settings-preset-balanced'),
      );
      expect(responsivePreset, findsOneWidget);
      expect(balancedPreset, findsOneWidget);
      final quietObservePreset = find.byKey(
        const Key('settings-preset-quiet-observe'),
      );
      expect(quietObservePreset, findsOneWidget);
      expect(tester.takeException(), isNull);

      final responsiveRect = tester.getRect(responsivePreset);
      final balancedRect = tester.getRect(balancedPreset);
      final quietObserveRect = tester.getRect(quietObservePreset);
      expect(responsiveRect.width, lessThanOrEqualTo(148.5));
      expect(balancedRect.width, lessThanOrEqualTo(148.5));
      expect(responsiveRect.height, lessThanOrEqualTo(60));
      expect(balancedRect.height, lessThanOrEqualTo(60));
      expect(quietObserveRect.height, lessThanOrEqualTo(60));

      expect(actionRect.width, greaterThanOrEqualTo(220));
      expect(actionRect.bottom, lessThanOrEqualTo(640));

      final deleteAccountCard = find.byKey(
        const Key('settings-delete-account-card'),
      );
      await tester.scrollUntilVisible(
        deleteAccountCard,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('settings-account-actions-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-logout-card')),
        findsOneWidget,
      );
      expect(deleteAccountCard, findsOneWidget);

      final deleteCardRect = tester.getRect(deleteAccountCard);
      expect(deleteCardRect.width, greaterThanOrEqualTo(280));
      expect(deleteCardRect.bottom, lessThanOrEqualTo(640));
    },
  );

  testWidgets(
    'settings screen should keep overview and toggles stable on tight size',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final authProvider = AuthProvider();
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(enableRemoteHydration: false);
      addTearDown(chatProvider.dispose);
      addTearDown(authProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final phoneAction = find.byKey(
        const Key('settings-overview-phone-action'),
      );
      await tester.scrollUntilVisible(
        phoneAction,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final phoneActionRect = tester.getRect(phoneAction);
      final presetResponsive = find.byKey(
        const Key('settings-preset-responsive'),
      );

      await revealInSettingsList(tester, presetResponsive, step: 160);

      expect(presetResponsive, findsOneWidget);
      expect(tester.takeException(), isNull);

      final presetRect = tester.getRect(presetResponsive);

      expect(phoneActionRect.width, greaterThanOrEqualTo(240));
      expect(presetRect.width, greaterThanOrEqualTo(240));
      expect(presetRect.height, lessThanOrEqualTo(60));
    },
  );
}
