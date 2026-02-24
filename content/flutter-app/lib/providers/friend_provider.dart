import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

class FriendProvider extends ChangeNotifier {
  final Map<String, Friend> _friends = {};
  final Map<String, FriendRequest> _requests = {};
  
  Map<String, Friend> get friends => _friends;
  
  List<Friend> get friendList => _friends.values.toList()
    ..sort((a, b) => b.becameFriendAt.compareTo(a.becameFriendAt));
  
  List<FriendRequest> get pendingRequests => _requests.values
      .where((r) => r.status == FriendRequestStatus.pending)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  
  int get pendingRequestCount => pendingRequests.length;
  
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
  
  void sendFriendRequest(User user, String? message) {
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

