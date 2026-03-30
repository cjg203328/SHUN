import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sunliao/providers/auth_provider.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/friend_provider.dart';
import 'package:sunliao/providers/notification_center_provider.dart';
import 'package:sunliao/providers/settings_provider.dart';
import 'package:sunliao/screens/settings_screen.dart';
import 'package:sunliao/services/image_upload_service.dart';
import 'package:sunliao/services/push_notification_service.dart';

import '../helpers/test_bootstrap.dart';

Future<void> _revealInSettingsList(
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

Widget _buildHost({
  required ChatProvider chatProvider,
  required AuthProvider authProvider,
  required FriendProvider friendProvider,
  required SettingsProvider settingsProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
      ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
      ChangeNotifierProvider<NotificationCenterProvider>.value(
        value: NotificationCenterProvider.instance,
      ),
    ],
    child: const MaterialApp(home: SettingsScreen()),
  );
}

void main() {
  setUp(() async {
    await initTestAppStorage();
    ImageUploadService.debugResetOverrides();
    await NotificationCenterProvider.instance.clearSession();
    PushNotificationService.instance.debugSetState(
      const PushRuntimeState(
        notificationsEnabled: true,
        permissionGranted: true,
        deviceToken: 'stub_push_test_device',
      ),
    );
  });

  tearDown(() async {
    ImageUploadService.debugResetOverrides();
    await NotificationCenterProvider.instance.clearSession();
    PushNotificationService.instance.debugSetState(
      const PushRuntimeState(
        notificationsEnabled: true,
        permissionGranted: true,
        deviceToken: 'stub_push_test_device',
      ),
    );
  });

  testWidgets(
    'settings screen should fallback cleanly when local media references become stale',
    (tester) async {
      final avatarFile = File(
        '${Directory.systemTemp.path}\\settings_avatar_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      final backgroundFile = File(
        '${Directory.systemTemp.path}\\settings_background_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await avatarFile.writeAsString('temp-avatar');
      await backgroundFile.writeAsString('temp-background');
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
        _buildHost(
          chatProvider: chatProvider,
          authProvider: authProvider,
          friendProvider: friendProvider,
          settingsProvider: settingsProvider,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await avatarFile.delete();
      await backgroundFile.delete();
      await tester.pump();

      final avatarManagementFinder = find.byKey(
        const Key('settings-avatar-management-item'),
      );
      await _revealInSettingsList(
        tester,
        avatarManagementFinder,
        reverse: true,
      );
      await tester.tap(avatarManagementFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

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
      expect(
        find.byKey(const Key('settings-avatar-delete-action')),
        findsNothing,
      );

      Navigator.of(
        tester.element(find.byKey(const Key('settings-avatar-sheet'))),
      ).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final backgroundManagementFinder = find.byKey(
        const Key('settings-background-management-item'),
      );
      await _revealInSettingsList(
        tester,
        backgroundManagementFinder,
        reverse: true,
      );
      await tester.tap(backgroundManagementFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-background-sheet-status')),
            )
            .data,
        '正在使用默认背景',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('settings-background-sheet-badge')),
            )
            .data,
        '待补充',
      );
      expect(
        find.byKey(const Key('settings-background-delete-action')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
