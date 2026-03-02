import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/storage_service.dart';

class FriendProvider extends ChangeNotifier {
  final Map<String, Friend> _friends = {};
  final Map<String, FriendRequest> _requests = {};
  final Set<String> _blockedUserIds = <String>{};
  final Map<String, User> _discoverableUsersByUid = {};

  static const List<Map<String, String>> _discoverableProfiles = [
    {
      'id': 'u_001',
      'uid': 'SNF0A101',
      'nickname': '阿澈',
      'avatar': '😄',
      'status': '想找人聊聊',
    },
    {
      'id': 'u_002',
      'uid': 'SNF0A102',
      'nickname': '小野',
      'avatar': '🙂',
      'status': '今晚有点失眠',
    },
    {
      'id': 'u_003',
      'uid': 'SNF0A103',
      'nickname': '晚风',
      'avatar': '🫧',
      'status': '随便聊聊',
    },
    {
      'id': 'u_004',
      'uid': 'SNF0A104',
      'nickname': 'Mia',
      'avatar': '🌙',
      'status': '分享今天的小事',
    },
    {
      'id': 'u_005',
      'uid': 'SNF0A105',
      'nickname': '阿宁',
      'avatar': '✨',
      'status': '想听听你的故事',
    },
    {
      'id': 'u_006',
      'uid': 'SNF0A106',
      'nickname': 'Echo',
      'avatar': '🎧',
      'status': '深夜在线',
    },
    {
      'id': 'u_007',
      'uid': 'SNF0A107',
      'nickname': '小北',
      'avatar': '🧩',
      'status': '想认识新朋友',
    },
    {
      'id': 'u_008',
      'uid': 'SNF0A108',
      'nickname': 'Kiki',
      'avatar': '🐱',
      'status': '今天心情不错',
    },
  ];

  Map<String, Friend> get friends => _friends;
  Set<String> get blockedUserIds => Set.unmodifiable(_blockedUserIds);

  List<Friend> get friendList => _friends.values
      .where((friend) => !_blockedUserIds.contains(friend.id))
      .toList()
    ..sort((a, b) => b.becameFriendAt.compareTo(a.becameFriendAt));

  List<FriendRequest> get pendingRequests => _requests.values
      .where((r) => r.status == FriendRequestStatus.pending)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int get pendingRequestCount => pendingRequests.length;

  FriendProvider() {
    _blockedUserIds.addAll(StorageService.getBlockedUserIds());
    _seedDiscoverableUsers();
  }

  void _seedDiscoverableUsers() {
    for (final profile in _discoverableProfiles) {
      final user = User(
        id: profile['id']!,
        uid: profile['uid'],
        nickname: profile['nickname']!,
        avatar: profile['avatar'],
        distance: '附近',
        status: profile['status']!,
        isOnline: true,
      );
      _discoverableUsersByUid[_normalizeUid(user.uid)] = user;
    }
  }

  String _normalizeUid(String uid) {
    return uid.trim().toUpperCase();
  }

  void registerDiscoverableUser(User user) {
    _discoverableUsersByUid[_normalizeUid(user.uid)] = user;
  }

  User? searchUserByUid(String uid, {String? excludeUid}) {
    final targetUid = _normalizeUid(uid);
    if (targetUid.isEmpty) return null;
    if (excludeUid != null && targetUid == _normalizeUid(excludeUid)) {
      return null;
    }
    final user = _discoverableUsersByUid[targetUid];
    if (user == null || isBlocked(user.id)) return null;
    return user;
  }

  Friend? addFriendDirect(User user) {
    if (isBlocked(user.id)) return null;
    registerDiscoverableUser(user);
    final existing = _friends[user.id];
    if (existing != null) return existing;

    final friend = Friend(
      id: user.id,
      user: user,
      becameFriendAt: DateTime.now(),
    );
    _friends[user.id] = friend;
    notifyListeners();
    return friend;
  }

  Friend? getFriend(String userId) {
    return _friends[userId];
  }

  bool isFriend(String userId) {
    return _friends.containsKey(userId);
  }

  bool hasPendingRequest(String userId) {
    return _requests.values.any(
      (r) => r.fromUser.id == userId && r.status == FriendRequestStatus.pending,
    );
  }

  bool isBlocked(String userId) {
    return _blockedUserIds.contains(userId);
  }

  Future<void> blockUser(String userId) async {
    if (_blockedUserIds.add(userId)) {
      // 保留好友与历史数据，解除拉黑后可恢复
      _requests.removeWhere((_, request) => request.fromUser.id == userId);
      await StorageService.saveBlockedUserIds(_blockedUserIds.toList());
      notifyListeners();
    }
  }

  Future<void> unblockUser(String userId) async {
    if (_blockedUserIds.remove(userId)) {
      await StorageService.saveBlockedUserIds(_blockedUserIds.toList());
      notifyListeners();
    }
  }

  void sendFriendRequest(User user, String? message) {
    if (isBlocked(user.id)) return;
    registerDiscoverableUser(user);
    final request = FriendRequest(
      id: const Uuid().v4(),
      fromUser: user,
      message: message,
      createdAt: DateTime.now(),
    );
    _requests[request.id] = request;
    notifyListeners();
  }

  void acceptFriendRequest(String requestId) {
    final request = _requests[requestId];
    if (request != null && request.status == FriendRequestStatus.pending) {
      if (isBlocked(request.fromUser.id)) {
        _requests[requestId] = FriendRequest(
          id: request.id,
          fromUser: request.fromUser,
          message: request.message,
          createdAt: request.createdAt,
          status: FriendRequestStatus.rejected,
        );
        notifyListeners();
        return;
      }
      // 更新请求状态
      _requests[requestId] = FriendRequest(
        id: request.id,
        fromUser: request.fromUser,
        message: request.message,
        createdAt: request.createdAt,
        status: FriendRequestStatus.accepted,
      );

      // 添加为好友
      _friends[request.fromUser.id] = Friend(
        id: request.fromUser.id,
        user: request.fromUser,
        becameFriendAt: DateTime.now(),
      );

      notifyListeners();
    }
  }

  void rejectFriendRequest(String requestId) {
    final request = _requests[requestId];
    if (request != null && request.status == FriendRequestStatus.pending) {
      _requests[requestId] = FriendRequest(
        id: request.id,
        fromUser: request.fromUser,
        message: request.message,
        createdAt: request.createdAt,
        status: FriendRequestStatus.rejected,
      );
      notifyListeners();
    }
  }

  void setRemark(String userId, String? remark) {
    if (_friends.containsKey(userId)) {
      final friend = _friends[userId]!;
      _friends[userId] = Friend(
        id: friend.id,
        user: friend.user,
        becameFriendAt: friend.becameFriendAt,
        remark: remark,
        chatCount: friend.chatCount,
        totalMinutes: friend.totalMinutes,
      );
      notifyListeners();
    }
  }

  void updateChatStats(String userId, int additionalMinutes) {
    if (_friends.containsKey(userId)) {
      final friend = _friends[userId]!;
      _friends[userId] = Friend(
        id: friend.id,
        user: friend.user,
        becameFriendAt: friend.becameFriendAt,
        remark: friend.remark,
        chatCount: friend.chatCount + 1,
        totalMinutes: friend.totalMinutes + additionalMinutes,
      );
      notifyListeners();
    }
  }

  void removeFriend(String userId) {
    _friends.remove(userId);
    notifyListeners();
  }
}
