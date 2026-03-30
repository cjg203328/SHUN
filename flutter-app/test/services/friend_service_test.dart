import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/services/friend_service.dart';

void main() {
  test('mapUserPayload should preserve remote avatar reference', () {
    final service = FriendService();

    final user = service.mapUserPayload({
      'userId': 'u_friend_remote_avatar',
      'uid': 'SNFRIEND001',
      'nickname': 'Friend Avatar',
      'avatarUrl': 'avatar/u_friend_remote_avatar/profile.jpg',
      'status': 'ready',
    });

    expect(user.avatar, 'avatar/u_friend_remote_avatar/profile.jpg');
  });

  test('mapUserPayload should fallback to placeholder when avatar is empty',
      () {
    final service = FriendService();

    final user = service.mapUserPayload({
      'userId': 'u_friend_placeholder',
      'uid': 'SNFRIEND002',
      'nickname': 'Friend Placeholder',
      'avatarUrl': '',
      'status': 'ready',
    });

    expect(user.avatar, '👤');
  });
}
