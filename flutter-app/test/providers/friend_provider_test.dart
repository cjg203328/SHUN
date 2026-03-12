import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/models/app_notification.dart';
import 'package:sunliao/models/models.dart';
import 'package:sunliao/providers/friend_provider.dart';
import 'package:sunliao/providers/notification_center_provider.dart';
import 'package:sunliao/services/friend_service.dart';

import '../helpers/test_bootstrap.dart';

User _buildUser({
  required String id,
  required String uid,
}) {
  return User(
    id: id,
    uid: uid,
    nickname: 'User-$id',
    avatar: '🙂',
    distance: '1km',
    status: 'ready',
    isOnline: true,
  );
}

class _FakeFriendService extends FriendService {
  FriendHydrationSnapshot? snapshot;

  @override
  Future<FriendHydrationSnapshot?> loadHydrationSnapshot() async => snapshot;
}

void main() {
  setUp(() async {
    await initTestAppStorage();
    await NotificationCenterProvider.instance.clearSession();
  });

  tearDown(() async {
    await NotificationCenterProvider.instance.clearSession();
  });

  test('uid search should be case-insensitive and trim spaces', () {
    final provider = FriendProvider();

    final user = provider.searchUserByUid('  snf0a101  ');

    expect(user, isNotNull);
    expect(user!.uid, 'SNF0A101');
  });

  test('blocked user should not be searchable or addable', () async {
    final provider = FriendProvider();
    final user = provider.searchUserByUid('SNF0A102');
    expect(user, isNotNull);

    await provider.blockUser(user!.id);

    expect(provider.searchUserByUid('SNF0A102'), isNull);
    expect(provider.addFriendDirect(user), isNull);

    await provider.unblockUser(user.id);
    expect(provider.searchUserByUid('SNF0A102'), isNotNull);
  });

  test('accepting request should move user into friend list', () {
    final provider = FriendProvider();
    final user = _buildUser(id: 'u_900', uid: 'SNTEST900');

    provider.sendFriendRequest(user, 'hi');
    expect(provider.pendingRequestCount, 1);

    final requestId = provider.pendingRequests.first.id;
    provider.acceptFriendRequest(requestId);

    expect(provider.pendingRequestCount, 0);
    expect(provider.isFriend(user.id), isTrue);
    expect(provider.getFriend(user.id), isNotNull);
  });

  test('blocked pending request should become rejected when accepted',
      () async {
    final provider = FriendProvider();
    final user = _buildUser(id: 'u_901', uid: 'SNTEST901');

    provider.sendFriendRequest(user, null);
    final requestId = provider.pendingRequests.first.id;
    await provider.blockUser(user.id);

    provider.acceptFriendRequest(requestId);

    expect(provider.pendingRequestCount, 0);
    expect(provider.isFriend(user.id), isFalse);
    expect(provider.hasPendingRequest(user.id), isFalse);
  });

  test(
      'accepting request should replace request notification with friend notice',
      () async {
    final provider = FriendProvider();
    final user = _buildUser(id: 'u_902', uid: 'SNTEST902');

    provider.sendFriendRequest(user, 'hi');
    final request = provider.pendingRequests.first;
    await NotificationCenterProvider.instance.upsertFriendRequestNotification(
      request,
    );

    provider.acceptFriendRequest(request.id);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final items = NotificationCenterProvider.instance.items
        .where((item) => item.userId == user.id)
        .toList(growable: false);

    expect(
      items.where((item) => item.type == AppNotificationType.friendRequest),
      isEmpty,
    );
    expect(
      items.where((item) => item.type == AppNotificationType.friendAccepted),
      hasLength(1),
    );
  });

  test('rejecting request should remove pending request notification',
      () async {
    final provider = FriendProvider();
    final user = _buildUser(id: 'u_903', uid: 'SNTEST903');

    provider.sendFriendRequest(user, 'hi');
    final request = provider.pendingRequests.first;
    await NotificationCenterProvider.instance.upsertFriendRequestNotification(
      request,
    );

    provider.rejectFriendRequest(request.id);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final items = NotificationCenterProvider.instance.items
        .where((item) => item.requestId == request.id)
        .toList(growable: false);

    expect(items, isEmpty);
  });

  test('removing friend should clear accepted friend notification', () async {
    final provider = FriendProvider();
    final user = _buildUser(id: 'u_904', uid: 'SNTEST904');

    provider.addFriendDirect(user);
    await NotificationCenterProvider.instance
        .addFriendAcceptedNotification(user);

    provider.removeFriend(user.id);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final items = NotificationCenterProvider.instance.items
        .where((item) => item.userId == user.id)
        .toList(growable: false);

    expect(items, isEmpty);
  });

  test('blocking user should clear friend relationship notifications',
      () async {
    final provider = FriendProvider();
    final user = _buildUser(id: 'u_905', uid: 'SNTEST905');

    provider.sendFriendRequest(user, 'hi');
    final request = provider.pendingRequests.first;
    await NotificationCenterProvider.instance.upsertFriendRequestNotification(
      request,
    );
    await NotificationCenterProvider.instance
        .addFriendAcceptedNotification(user);

    await provider.blockUser(user.id);

    final items = NotificationCenterProvider.instance.items
        .where((item) => item.userId == user.id)
        .toList(growable: false);

    expect(items, isEmpty);
  });

  test('remote empty hydrate should clear stale local relationship state',
      () async {
    final fakeService = _FakeFriendService();
    final provider = FriendProvider(friendService: fakeService);
    final friend = _buildUser(id: 'u_906', uid: 'SNTEST906');
    final blocked = _buildUser(id: 'u_907', uid: 'SNTEST907');

    provider.addFriendDirect(friend);
    provider.sendFriendRequest(blocked, 'hi');
    await provider.blockUser(blocked.id);

    expect(provider.isFriend(friend.id), isTrue);
    expect(provider.pendingRequestCount, 0);
    expect(provider.isBlocked(blocked.id), isTrue);

    fakeService.snapshot = const FriendHydrationSnapshot(
      friends: [],
      requests: [],
      blockedUsers: [],
    );
    await provider.refreshFromRemote();

    expect(provider.friendList, isEmpty);
    expect(provider.pendingRequests, isEmpty);
    expect(provider.blockedUserIds, isEmpty);
  });

  test('failed remote hydrate should keep local relationship state', () async {
    final fakeService = _FakeFriendService();
    final provider = FriendProvider(friendService: fakeService);
    final friend = _buildUser(id: 'u_908', uid: 'SNTEST908');

    provider.addFriendDirect(friend);
    expect(provider.isFriend(friend.id), isTrue);

    fakeService.snapshot = null;
    await provider.refreshFromRemote();

    expect(provider.isFriend(friend.id), isTrue);
  });
}
