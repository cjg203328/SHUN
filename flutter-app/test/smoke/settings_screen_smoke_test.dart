import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sunliao/providers/auth_provider.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/friend_provider.dart';
import 'package:sunliao/providers/settings_provider.dart';
import 'package:sunliao/repositories/app_data_repository.dart';
import 'package:sunliao/screens/settings_screen.dart';
import 'package:sunliao/services/push_notification_service.dart';

import '../helpers/test_bootstrap.dart';

void main() {
  String? clipboardText;

  setUp(() async {
    await initTestAppStorage();
    clipboardText = null;
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

  tearDown(() {
    PushNotificationService.instance.debugSetState(
      const PushRuntimeState(
        notificationsEnabled: true,
        permissionGranted: true,
        deviceToken: 'stub_push_test_device',
      ),
    );
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
      final authProvider = AuthProvider();
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
      await tester.longPress(
        find.byKey(const ValueKey<String>('settings-debug-version-trigger')),
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
      expect(find.text('当前诊断结论'), findsOneWidget);
      expect(find.text('最值得处理：图片需重新选择'), findsOneWidget);
      expect(find.text('处理状态说明：原图已失效，本次需要改为重新选图。'), findsOneWidget);
      expect(find.text('处理建议：原图已失效，建议重新选择图片后再发送。'), findsOneWidget);
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
      expect(find.textContaining('最新状态：需重新选图'), findsOneWidget);
      expect(find.textContaining('最新状态：已恢复送达'), findsOneWidget);
      expect(find.text('建议：重新选择图片后再发送'), findsOneWidget);
      expect(find.text('建议：已恢复送达，无需处理'), findsOneWidget);
      expect(find.text('文本发送成功'), findsNothing);
      expect(find.text('最值得处理：图片链路需重新选图'), findsOneWidget);
      expect(find.text('处理建议：重新选择图片后再发送'), findsOneWidget);
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
      expect(clipboardText, contains('当前结论'));
      expect(clipboardText, contains('最值得处理：图片链路需重新选图'));
      expect(clipboardText, contains('处理状态：建议重选图片'));
      expect(clipboardText, contains('处理状态说明：原图已失效，本次需要改为重新选图。'));
      expect(clipboardText, contains('处理建议：重新选择图片后再发送'));
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
      await tester.longPress(
        find.byKey(const ValueKey<String>('settings-debug-version-trigger')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('当前诊断结论'), findsOneWidget);
      expect(find.text('建议检查网络'), findsOneWidget);
      expect(find.text('处理状态说明：最近一次重试仍未送达，优先排查网络波动。'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('chat-delivery-copy-summary')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(clipboardText, contains('处理状态：建议检查网络'));
      expect(clipboardText, contains('处理状态说明：最近一次重试仍未送达，优先排查网络波动。'));
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
        find.byKey(const Key('settings-experience-preset-card')),
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
      await tester.scrollUntilVisible(
        avatarManagementFinder,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(avatarManagementFinder, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-avatar-sheet')), findsOneWidget);
      expect(
        find.byKey(const Key('settings-avatar-replace-action')),
        findsOneWidget,
      );
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

      expect(invisibleBadgeText, '低曝光');
      expect(notificationBadgeText, '易漏消息');
      expect(vibrationBadgeText, '更安静');
    },
  );

  testWidgets(
    'settings screen should apply experience preset from overview card',
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
      await tester.ensureVisible(quietObservePreset);
      await tester.pumpAndSettle();
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

      expect(currentBadgeText, '安静观察');
      expect(
        find.byKey(const Key('settings-inline-feedback-card')),
        findsOneWidget,
      );
      expect(find.text('已切到安静观察'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-invisible-mode-item')),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
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

      expect(find.text('建议开启系统通知权限'), findsOneWidget);
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
      expect(find.text('去系统设置'), findsWidgets);
      expect(find.text('通知待授权'), findsOneWidget);
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

      await tester.tap(find.byKey(const Key('settings-phone-cancel')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-phone-sheet')), findsNothing);

      final passwordItem = find.byKey(const Key('settings-password-item'));
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

      await tester.tap(find.byKey(const Key('settings-password-cancel')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-password-sheet')), findsNothing);
    },
  );
}
