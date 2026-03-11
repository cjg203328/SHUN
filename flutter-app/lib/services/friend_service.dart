import '../models/models.dart';
import 'api_client.dart';
import 'storage_service.dart';

class FriendService {
  FriendService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  bool get hasSession {
    final token = StorageService.getToken();
    return token != null && token.isNotEmpty;
  }

  Future<User?> searchUserByUid(String uid, {String? excludeUid}) async {
    if (!hasSession) return null;

    final normalizedUid = uid.trim().toUpperCase();
    if (normalizedUid.isEmpty) return null;
    if (excludeUid != null && normalizedUid == excludeUid.trim().toUpperCase()) {
      return null;
    }

    try {
      final data = await _apiClient.get<Map<String, dynamic>>(
        '/users/search',
        queryParameters: {'uid': normalizedUid},
      );
      return _mapUser(data);
    } catch (_) {
      return null;
    }
  }

  Future<List<Friend>> loadFriends() async {
    if (!hasSession) return const [];

    try {
      final data = await _apiClient.get<List<dynamic>>('/friends');
      return data
          .whereType<Map<String, dynamic>>()
          .map(_mapFriend)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<FriendRequest>> loadPendingRequests() async {
    if (!hasSession) return const [];

    try {
      final data = await _apiClient.get<List<dynamic>>('/friends/requests/pending');
      return data
          .whereType<Map<String, dynamic>>()
          .map(_mapFriendRequest)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<User>> loadBlockedUsers() async {
    if (!hasSession) return const [];

    try {
      final data = await _apiClient.get<List<dynamic>>('/users/blocked');
      return data
          .whereType<Map<String, dynamic>>()
          .map(_mapUser)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> sendFriendRequest(User user, String? message) async {
    if (!hasSession) return;
    try {
      await _apiClient.post<Map<String, dynamic>>(
        '/friends/requests',
        data: {
          'targetUserId': user.id,
          'message': message,
        },
      );
    } catch (_) {}
  }

  Future<void> acceptFriendRequest(String requestId) async {
    if (!hasSession) return;
    try {
      await _apiClient.post<Map<String, dynamic>>('/friends/requests/$requestId/accept');
    } catch (_) {}
  }

  Future<void> rejectFriendRequest(String requestId) async {
    if (!hasSession) return;
    try {
      await _apiClient.post<Map<String, dynamic>>('/friends/requests/$requestId/reject');
    } catch (_) {}
  }

  Future<void> blockUser(String userId) async {
    if (!hasSession) return;
    try {
      await _apiClient.post<Map<String, dynamic>>('/friends/$userId/block');
    } catch (_) {}
  }

  Future<void> unblockUser(String userId) async {
    if (!hasSession) return;
    try {
      await _apiClient.delete<Map<String, dynamic>>('/friends/$userId/block');
    } catch (_) {}
  }

  Friend _mapFriend(Map<String, dynamic> json) {
    final userJson = (json['user'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    return Friend(
      id: (json['id'] ?? userJson['userId'] ?? userJson['id']).toString(),
      user: _mapUser(userJson),
      becameFriendAt: DateTime.tryParse(json['becameFriendAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  FriendRequest _mapFriendRequest(Map<String, dynamic> json) {
    final fromUserJson = (json['fromUser'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    return FriendRequest(
      id: (json['id'] ?? json['requestId']).toString(),
      fromUser: _mapUser(fromUserJson),
      message: json['message']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      status: _mapRequestStatus(json['status']?.toString()),
    );
  }

  User _mapUser(Map<String, dynamic> json) {
    final userId = (json['userId'] ?? json['id'] ?? '').toString();
    return User(
      id: userId,
      uid: (json['uid'] ?? userId).toString(),
      nickname: (json['nickname'] ?? '神秘人').toString(),
      avatar: _mapAvatar(json['avatarUrl']?.toString()),
      distance: '附近',
      status: (json['status'] ?? '想找人聊聊').toString(),
      isOnline: true,
    );
  }

  String? _mapAvatar(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.trim().isEmpty) {
      return '👤';
    }
    return '👤';
  }

  FriendRequestStatus _mapRequestStatus(String? status) {
    switch (status) {
      case 'accepted':
        return FriendRequestStatus.accepted;
      case 'rejected':
        return FriendRequestStatus.rejected;
      default:
        return FriendRequestStatus.pending;
    }
  }
}
