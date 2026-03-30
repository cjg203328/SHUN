import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sunliao/models/models.dart';
import 'package:sunliao/providers/auth_provider.dart';
import 'package:sunliao/providers/friend_provider.dart';
import 'package:sunliao/providers/notification_center_provider.dart';
import 'package:sunliao/widgets/friends_tab.dart';

import '../helpers/test_bootstrap.dart';

Widget _buildHost({
  required FriendProvider friendProvider,
  AuthProvider? authProvider,
}) {
  final providers = [
    if (authProvider != null)
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
    ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
    ChangeNotifierProvider<NotificationCenterProvider>.value(
      value: NotificationCenterProvider.instance,
    ),
  ];

  return MultiProvider(
    providers: providers,
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

class _TestAuthProvider extends ChangeNotifier implements AuthProvider {
  _TestAuthProvider(this.uid);

  @override
  final String? uid;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
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

  testWidgets(
      'friends tab should keep banner and first friend readable on compact size',
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
        'u_friends_compact',
        uid: 'SNF0A401',
        nickname: 'Compact Friend With A Very Long Nickname',
        avatar: 'F',
      ),
    );
    friendProvider.setRemark(
      'u_friends_compact',
      'Remark For Compact Layout Verification',
    );
    friendProvider.sendFriendRequest(
      _buildUser(
        'u_friends_request',
        uid: 'SNF0A402',
        nickname: 'Pending Friend',
        avatar: 'P',
      ),
      'This is a longer pending request message for compact layout verification.',
    );

    await tester.pumpWidget(
      _buildHost(
        friendProvider: friendProvider,
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('friends-pending-banner')), findsOneWidget);
    expect(find.byKey(const Key('friends-item-u_friends_compact')),
        findsOneWidget);

    final bannerRect =
        tester.getRect(find.byKey(const Key('friends-pending-banner')));
    final itemRect =
        tester.getRect(find.byKey(const Key('friends-item-u_friends_compact')));
    expect(bannerRect.bottom, lessThanOrEqualTo(640));
    expect(itemRect.bottom, lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);

    await _disposeHost(tester, friendProvider);
  });

  testWidgets(
      'friends requests sheet should keep action buttons reachable on compact size',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final friendProvider = FriendProvider(enableRemoteHydration: false);

    friendProvider.sendFriendRequest(
      _buildUser(
        'u_friends_request_sheet',
        uid: 'SNF0A403',
        nickname: 'Sheet Pending User',
        avatar: 'S',
      ),
      'Request message used to verify compact sheet action reachability.',
    );
    final requestId = friendProvider.pendingRequests.single.id;

    await tester.pumpWidget(
      _buildHost(
        friendProvider: friendProvider,
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('friends-pending-banner')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(Key('friends-request-item-$requestId')), findsOneWidget);
    expect(
        find.byKey(Key('friends-request-reject-$requestId')), findsOneWidget);
    expect(
        find.byKey(Key('friends-request-accept-$requestId')), findsOneWidget);

    final requestRect =
        tester.getRect(find.byKey(Key('friends-request-item-$requestId')));
    expect(requestRect.bottom, lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);

    await _disposeHost(tester, friendProvider);
  });

  testWidgets('friends tab should render remote avatar image when available',
      (tester) async {
    final friendProvider = FriendProvider(enableRemoteHydration: false);

    friendProvider.addFriendDirect(
      _buildUser(
        'u_friends_remote_avatar',
        uid: 'SNF0A499',
        nickname: 'Remote Avatar Friend',
        avatar: 'avatar/u_friends_remote_avatar/profile.jpg',
      ),
    );

    await tester.pumpWidget(
      _buildHost(
        friendProvider: friendProvider,
      ),
    );
    await tester.pump();

    expect(
      find.descendant(
        of: find
            .byKey(const Key('friends-item-avatar-u_friends_remote_avatar')),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );

    await _disposeHost(tester, friendProvider);
  });

  testWidgets(
      'friends options sheet should keep actions reachable on compact size',
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
        'u_friends_options',
        uid: 'SNF0A404',
        nickname: 'Options Compact Friend',
        avatar: 'O',
      ),
    );

    await tester.pumpWidget(
      _buildHost(
        friendProvider: friendProvider,
      ),
    );
    await tester.pump();

    await tester
        .longPress(find.byKey(const Key('friends-item-u_friends_options')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('friends-option-cancel')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('friends-option-cancel')));
    await tester.pump();

    final cancelRect =
        tester.getRect(find.byKey(const Key('friends-option-cancel')));
    expect(cancelRect.bottom, lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);

    await _disposeHost(tester, friendProvider);
  });

  testWidgets(
      'friends uid search sheet should keep result card reachable on compact size',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final friendProvider = FriendProvider(enableRemoteHydration: false);
    final authProvider = _TestAuthProvider('SNSELF001');

    friendProvider.registerDiscoverableUser(
      _buildUser(
        'u_search_target',
        uid: 'SNSEARCH001',
        nickname: 'Search Target User With A Slightly Longer Name',
        avatar: 'Q',
        status: '今晚在线，可直接开始聊天',
      ),
    );

    await tester.pumpWidget(
      _buildHost(
        authProvider: authProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('friends-search-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('friends-uid-search-sheet')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('friends-uid-search-input')),
      'SNSEARCH001',
    );
    await tester.tap(find.byKey(const Key('friends-uid-search-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('friends-uid-search-result-card')),
        findsOneWidget);
    expect(
      find.byKey(const Key('friends-uid-search-send-request')),
      findsOneWidget,
    );

    final resultRect =
        tester.getRect(find.byKey(const Key('friends-uid-search-result-card')));
    expect(resultRect.bottom, lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);

    Navigator.of(
      tester.element(find.byKey(const Key('friends-uid-search-sheet'))),
    ).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('friends-uid-search-sheet')), findsNothing);

    await _disposeHost(tester, friendProvider);
  });

  testWidgets(
      'friends uid search sheet should show validation feedback on compact size',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final friendProvider = FriendProvider(enableRemoteHydration: false);
    final authProvider = _TestAuthProvider('SNSELF002');

    await tester.pumpWidget(
      _buildHost(
        authProvider: authProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('friends-search-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('friends-uid-search-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
        find.byKey(const Key('friends-uid-search-feedback')), findsOneWidget);

    final feedbackRect =
        tester.getRect(find.byKey(const Key('friends-uid-search-feedback')));
    expect(feedbackRect.bottom, lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);

    await _disposeHost(tester, friendProvider);
  });
}
