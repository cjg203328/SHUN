import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/services/chat_service.dart';

void main() {
  test('mapThreadPayload should preserve remote avatar reference', () {
    final service = ChatService();

    final thread = service.mapThreadPayload({
      'threadId': 'th_avatar_remote',
      'user': {
        'userId': 'u_avatar_remote',
        'uid': 'SNUAVATAR',
        'nickname': 'Avatar User',
        'avatarUrl': 'avatar/u_avatar_remote/profile.jpg',
        'status': 'online',
      },
      'createdAt': '2026-03-30T12:00:00.000Z',
      'expiresAt': '2026-03-31T12:00:00.000Z',
      'unreadCount': 0,
      'isFriend': true,
    });

    expect(thread.otherUser.avatar, 'avatar/u_avatar_remote/profile.jpg');
  });

  test('mapThreadPayload should fallback to placeholder when avatar is empty',
      () {
    final service = ChatService();

    final thread = service.mapThreadPayload({
      'threadId': 'th_avatar_placeholder',
      'user': {
        'userId': 'u_avatar_placeholder',
        'uid': 'SNPLACEHOLDER',
        'nickname': 'Placeholder User',
        'avatarUrl': '   ',
        'status': 'busy',
      },
      'createdAt': '2026-03-30T12:00:00.000Z',
      'expiresAt': '2026-03-31T12:00:00.000Z',
    });

    expect(thread.otherUser.avatar, '👤');
  });
}
