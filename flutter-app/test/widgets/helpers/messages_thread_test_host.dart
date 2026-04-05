import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sunliao/models/models.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/friend_provider.dart';
import 'package:sunliao/providers/notification_center_provider.dart';
import 'package:sunliao/widgets/messages_tab.dart';

import '../../helpers/test_bootstrap.dart';

Future<void> initMessagesThreadTestApp() async {
  await initTestAppStorage();
  await NotificationCenterProvider.instance.clearSession();
}

Future<void> clearMessagesThreadTestSession() async {
  await NotificationCenterProvider.instance.clearSession();
}

void setMessagesThreadViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

User buildMessagesThreadUser(
  String id, {
  String? nickname,
  bool isOnline = true,
}) {
  return User(
    id: id,
    uid: 'SN$id',
    nickname: nickname ?? 'User-$id',
    avatar: '🙂',
    distance: '2km',
    status: 'available',
    isOnline: isOnline,
  );
}

ChatThread buildMessagesThread({
  required String id,
  User? otherUser,
  int unreadCount = 0,
  Duration createdAgo = const Duration(minutes: 20),
  Duration expiresIn = const Duration(hours: 24),
  int intimacyPoints = 60,
  bool isFriend = false,
  DateTime? now,
}) {
  final resolvedNow = now ?? DateTime.now();
  return ChatThread(
    id: id,
    otherUser: otherUser ?? buildMessagesThreadUser(id),
    unreadCount: unreadCount,
    createdAt: resolvedNow.subtract(createdAgo),
    expiresAt: resolvedNow.add(expiresIn),
    intimacyPoints: intimacyPoints,
    isFriend: isFriend,
  );
}

Widget buildMessagesThreadHost({
  required ChatProvider chatProvider,
  required FriendProvider friendProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<NotificationCenterProvider>.value(
        value: NotificationCenterProvider.instance,
      ),
      ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
      ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
    ],
    child: const MaterialApp(home: MessagesTab()),
  );
}

Future<void> disposeMessagesThreadHost(
  WidgetTester tester,
  ChatProvider chatProvider,
  FriendProvider friendProvider,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  chatProvider.dispose();
  friendProvider.dispose();
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> pumpMessagesThreadScene(
  WidgetTester tester, {
  required ChatProvider chatProvider,
  required FriendProvider friendProvider,
  required ChatThread thread,
  List<Message> messages = const <Message>[],
  String? draft,
  bool pinThread = false,
}) async {
  chatProvider.addThread(thread);
  if (pinThread) {
    chatProvider.pinThread(thread.id);
  }
  if (messages.isNotEmpty) {
    chatProvider.getMessages(thread.id).addAll(messages);
  }
  if (draft != null) {
    chatProvider.saveDraft(thread.id, draft);
  }

  await tester.pumpWidget(
    buildMessagesThreadHost(
      chatProvider: chatProvider,
      friendProvider: friendProvider,
    ),
  );
  await tester.pump();
}
