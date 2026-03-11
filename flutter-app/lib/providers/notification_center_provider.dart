import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/app_notification.dart';
import '../models/models.dart';
import '../services/storage_service.dart';

class NotificationCenterProvider extends ChangeNotifier {
  NotificationCenterProvider._() {
    _loadFromStorage();
  }

  static final NotificationCenterProvider instance =
      NotificationCenterProvider._();

  final List<AppNotification> _items = <AppNotification>[];

  List<AppNotification> get items => List.unmodifiable(_items);

  int get unreadCount => _items.where((item) => !item.isRead).length;

  Future<void> reloadFromStorage() async {
    _loadFromStorage();
    notifyListeners();
  }

  Future<void> clearSession() async {
    _items.clear();
    await StorageService.clearNotificationCenterState();
    notifyListeners();
  }

  Future<void> markRead(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1) return;
    _items[index] = _items[index].copyWith(isRead: true);
    await _persist();
    notifyListeners();
  }

  Future<void> markAllRead() async {
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].isRead) continue;
      _items[i] = _items[i].copyWith(isRead: true);
      changed = true;
    }
    if (!changed) return;
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _items.removeWhere((item) => item.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _items.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> addChatMessageNotification({
    required ChatThread thread,
    required Message message,
  }) async {
    await _prepend(
      AppNotification(
        id: const Uuid().v4(),
        type: AppNotificationType.message,
        title: thread.otherUser.nickname,
        body: message.type == MessageType.image ? '[图片消息]' : message.content,
        createdAt: message.timestamp,
        threadId: thread.id,
        userId: thread.otherUser.id,
      ),
    );
  }

  Future<void> upsertFriendRequestNotification(FriendRequest request) async {
    final sourceKey = 'friend-request:${request.id}';
    final index = _items.indexWhere((item) => item.sourceKey == sourceKey);
    final notification = AppNotification(
      id: index == -1 ? const Uuid().v4() : _items[index].id,
      type: AppNotificationType.friendRequest,
      title: '新的好友申请',
      body: '${request.fromUser.nickname} 想添加你为好友',
      createdAt: request.createdAt,
      requestId: request.id,
      userId: request.fromUser.id,
      sourceKey: sourceKey,
      isRead: index == -1 ? false : _items[index].isRead,
    );

    if (index == -1) {
      _items.insert(0, notification);
    } else {
      _items[index] = notification;
      _sort();
    }
    await _persist();
    notifyListeners();
  }

  Future<void> addFriendAcceptedNotification(User user) async {
    await _prepend(
      AppNotification(
        id: const Uuid().v4(),
        type: AppNotificationType.friendAccepted,
        title: '已成为好友',
        body: '你和 ${user.nickname} 已互关，可以继续聊天啦',
        createdAt: DateTime.now(),
        userId: user.id,
      ),
    );
  }

  Future<void> addSystemNotification({
    required String title,
    required String body,
    String? sourceKey,
  }) async {
    if (sourceKey != null &&
        _items.any((item) => item.sourceKey == sourceKey)) {
      return;
    }

    await _prepend(
      AppNotification(
        id: const Uuid().v4(),
        type: AppNotificationType.system,
        title: title,
        body: body,
        createdAt: DateTime.now(),
        sourceKey: sourceKey,
      ),
    );
  }

  void _loadFromStorage() {
    _items.clear();
    final raw = StorageService.getNotificationCenterState();
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final item in decoded) {
        if (item is! Map) continue;
        _items.add(
          AppNotification.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        );
      }
      _sort();
    } catch (_) {}
  }

  Future<void> _prepend(AppNotification notification) async {
    _items.insert(0, notification);
    if (_items.length > 100) {
      _items.removeRange(100, _items.length);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await StorageService.saveNotificationCenterState(
      jsonEncode(_items.map((item) => item.toJson()).toList(growable: false)),
    );
  }

  void _sort() {
    _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
