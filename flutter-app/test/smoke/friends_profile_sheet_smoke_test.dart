import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sunliao/models/models.dart';
import 'package:sunliao/providers/friend_provider.dart';
import 'package:sunliao/providers/notification_center_provider.dart';
import 'package:sunliao/widgets/friends_tab.dart';

import '../helpers/test_bootstrap.dart';

Widget _buildHost({
  required FriendProvider friendProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
      ChangeNotifierProvider<NotificationCenterProvider>.value(
        value: NotificationCenterProvider.instance,
      ),
    ],
    child: const MaterialApp(home: FriendsTab()),
  );
}

Future<void> _disposeHost(
  WidgetTester tester,
  FriendProvider friendProvider,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  friendProvider.dispose();
  await tester.pump(const Duration(milliseconds: 250));
}

User _buildUser(
  String id, {
  required String nickname,
  String? uid,
  String? avatar,
  String status = 'available',
}) {
  return User(
    id: id,
    uid: uid,
    nickname: nickname,
    avatar: avatar,
    distance: 'nearby',
    status: status,
    isOnline: true,
  );
}

void main() {
  setUp(() async {
    await initTestAppStorage();
    await NotificationCenterProvider.instance.clearSession();
  });

  testWidgets('friend profile sheet should stay scrollable on compact size',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final friendProvider = FriendProvider(enableRemoteHydration: false);

    friendProvider.addFriendDirect(
      _buildUser(
        'u_profile_compact',
        uid: 'SNPROFILE001',
        nickname: 'Profile Compact Friend With A Longer Nickname',
        avatar: 'R',
        status: '这是一段更长的状态，用来验证资料弹层在小屏上的可读性。',
      ),
    );
    friendProvider.setRemark(
      'u_profile_compact',
      'Compact Profile Remark With More Characters',
    );

    await tester.pumpWidget(
      _buildHost(friendProvider: friendProvider),
    );
    await tester.pump();

    await tester
        .longPress(find.byKey(const Key('friends-item-u_profile_compact')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('friends-option-profile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('friends-profile-sheet')), findsOneWidget);
    expect(
        find.byKey(const Key('friends-profile-identity-card')), findsOneWidget);

    await tester
        .ensureVisible(find.byKey(const Key('friends-profile-status-card')));
    await tester.pump();

    final statusRect =
        tester.getRect(find.byKey(const Key('friends-profile-status-card')));
    expect(statusRect.bottom, lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);

    await _disposeHost(tester, friendProvider);
  });
}
