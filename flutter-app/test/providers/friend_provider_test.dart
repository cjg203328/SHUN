import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/models/models.dart';
import 'package:sunliao/providers/friend_provider.dart';

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

void main() {
  setUp(() async {
    await initTestAppStorage();
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
}
