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

  Future<void> markThreadNotificationsRead(String threadId) async {
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.isRead ||
          item.type != AppNotificationType.message ||
          item.threadId != threadId) {
        continue;
      }
      _items[i] = item.copyWith(isRead: true);
      changed = true;
    }
    if (!changed) return;
    await _persist();
    notifyListeners();
  }

  Future<void> markThreadNotificationsReadByMessageIds(
    String threadId,
    Set<String> messageIds,
  ) async {
    if (messageIds.isEmpty) return;

    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.isRead ||
          item.type != AppNotificationType.message ||
          item.threadId != threadId ||
          item.sourceKey == null) {
        continue;
      }
      final sourceKey = item.sourceKey!;
      if (!messageIds.any(
          (messageId) => sourceKey == 'chat-message:$threadId:$messageId')) {
        continue;
      }
      _items[i] = item.copyWith(isRead: true);
      changed = true;
    }
    if (!changed) return;
    await _persist();
    notifyListeners();
  }

  Future<void> removeThreadNotifications(String threadId) async {
    final originalLength = _items.length;
    _items.removeWhere(
      (item) =>
          item.type == AppNotificationType.message && item.threadId == threadId,
    );
    if (_items.length == originalLength) return;
    await _persist();
    notifyListeners();
  }

  Future<void> removeFriendRequestNotification(String requestId) async {
    final originalLength = _items.length;
    _items.removeWhere(
      (item) =>
          item.type == AppNotificationType.friendRequest &&
          item.requestId == requestId,
    );
    if (_items.length == originalLength) return;
    await _persist();
    notifyListeners();
  }

  Future<void> removeUserNotifications(
    String userId, {
    Set<AppNotificationType>? types,
  }) async {
    final originalLength = _items.length;
    _items.removeWhere(
      (item) =>
          item.userId == userId && (types == null || types.contains(item.type)),
    );
    if (_items.length == originalLength) return;
    await _persist();
    notifyListeners();
  }

  Future<void> remapThreadNotifications({
    required String fromThreadId,
    required ChatThread toThread,
  }) async {
    var changed = false;
    final remappedItems = <AppNotification>[];

    for (final item in _items) {
      if (item.type != AppNotificationType.message ||
          item.threadId != fromThreadId) {
        remappedItems.add(item);
        continue;
      }

      changed = true;
      final nextSourceKey = _remapMessageSourceKey(
        item.sourceKey,
        fromThreadId: fromThreadId,
        toThreadId: toThread.id,
      );
      final updatedItem = item.copyWith(
        title: toThread.otherUser.nickname,
        threadId: toThread.id,
        userId: toThread.otherUser.id,
        sourceKey: nextSourceKey,
      );

      final existingIndex = nextSourceKey == null
          ? -1
          : remappedItems.indexWhere(
              (existing) => existing.sourceKey == nextSourceKey,
            );
      if (existingIndex == -1) {
        remappedItems.add(updatedItem);
      } else {
        remappedItems[existingIndex] = _mergeMessageNotifications(
          remappedItems[existingIndex],
          updatedItem,
        );
      }
    }

    if (!changed) return;
    _items
      ..clear()
      ..addAll(remappedItems);
    _sort();
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
    final sourceKey = 'chat-message:${thread.id}:${message.id}';
    final index = _items.indexWhere((item) => item.sourceKey == sourceKey);
    final notification = AppNotification(
      id: index == -1 ? const Uuid().v4() : _items[index].id,
      type: AppNotificationType.message,
      title: thread.otherUser.nickname,
      body: message.type == MessageType.image ? '[图片消息]' : message.content,
      createdAt: message.timestamp,
      threadId: thread.id,
      userId: thread.otherUser.id,
      sourceKey: sourceKey,
      isRead: index == -1 ? false : _items[index].isRead,
    );

    if (index == -1) {
      _items.insert(0, notification);
      if (_items.length > 100) {
        _items.removeRange(100, _items.length);
      }
    } else {
      _items[index] = notification;
      _sort();
    }
    await _persist();
    notifyListeners();
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

  String? _remapMessageSourceKey(
    String? sourceKey, {
    required String fromThreadId,
    required String toThreadId,
  }) {
    final prefix = 'chat-message:$fromThreadId:';
    if (sourceKey == null || !sourceKey.startsWith(prefix)) {
      return sourceKey;
    }
    return sourceKey.replaceFirst(prefix, 'chat-message:$toThreadId:');
  }

  AppNotification _mergeMessageNotifications(
    AppNotification existing,
    AppNotification incoming,
  ) {
    return AppNotification(
      id: existing.id,
      type: existing.type,
      title: incoming.title,
      body: incoming.body,
      createdAt: existing.createdAt.isAfter(incoming.createdAt)
          ? existing.createdAt
          : incoming.createdAt,
      isRead: existing.isRead && incoming.isRead,
      threadId: incoming.threadId,
      requestId: incoming.requestId ?? existing.requestId,
      userId: incoming.userId ?? existing.userId,
      sourceKey: incoming.sourceKey ?? existing.sourceKey,
    );
  }

  void _sort() {
    _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
