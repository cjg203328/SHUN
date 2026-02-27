import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../utils/intimacy_system.dart';
import '../utils/image_helper.dart';

class ChatProvider extends ChangeNotifier {
  final Map<String, List<Message>> _messages = {};
  final Map<String, ChatThread> _threads = {};
  final Map<String, DateTime> _lastMessageTime = {}; // 记录最后消息时间
  final Map<String, bool> _deletedThreads = {}; // 软删除的会话
  String? _activeThreadId; // 当前正在浏览的会话

  Map<String, ChatThread> get threads {
    // 过滤掉已软删除的会话
    return Map.fromEntries(_threads.entries.where((entry) =>
        !(_deletedThreads[entry.key] ?? false) &&
        (entry.value.isFriend || !entry.value.isExpired)));
  }

  List<Message> getMessages(String threadId) {
    return _messages[threadId] ?? [];
  }

  ChatThread? getThread(String threadId) {
    return _threads[threadId];
  }

  void setActiveThread(String threadId) {
    _activeThreadId = threadId;
    markAsRead(threadId);
  }

  void clearActiveThread(String threadId) {
    if (_activeThreadId == threadId) {
      _activeThreadId = null;
    }
  }

  void addThread(ChatThread thread) {
    final existingThread = _threads[thread.id];
    if (existingThread != null) {
      // 已有会话时保留历史消息和会话起始时间，避免重复匹配覆盖历史记录
      _threads[thread.id] = ChatThread(
        id: existingThread.id,
        otherUser: existingThread.otherUser,
        unreadCount: existingThread.unreadCount,
        createdAt: existingThread.createdAt,
        expiresAt: existingThread.expiresAt,
        intimacyPoints: existingThread.intimacyPoints,
        isFriend: existingThread.isFriend,
        isUnfollowed: existingThread.isUnfollowed,
        messagesSinceUnfollow: existingThread.messagesSinceUnfollow,
      );
      _messages[thread.id] ??= [];
      _deletedThreads[thread.id] = false;
      notifyListeners();
      return;
    }

    _threads[thread.id] = thread;
    _messages[thread.id] = [];
    _deletedThreads[thread.id] = false;
    notifyListeners();
  }

  void sendMessage(String threadId, String content) {
    final thread = _threads[threadId];
    if (thread == null) return;

    // 检查是否可以发送消息（取关限制）
    if (!thread.canSendMessage) {
      // 不能发送，需要对方确认
      return;
    }

    final messageId = const Uuid().v4();
    final message = Message(
      id: messageId,
      content: content,
      isMe: true,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      type: MessageType.text,
    );

    _messages[threadId]?.add(message);

    // 如果被取关，增加计数
    if (thread.isUnfollowed) {
      _updateThread(threadId,
          messagesSinceUnfollow: thread.messagesSinceUnfollow + 1);
    }

    notifyListeners();

    // 模拟发送（检测网络状态）
    _simulateSend(threadId, messageId, content);
  }

  Future<void> _simulateSend(
      String threadId, String messageId, String content) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final messages = _messages[threadId];
    if (messages != null) {
      final index = messages.indexWhere((msg) => msg.id == messageId);
      if (index != -1) {
        // 模拟网络检测（90%成功率）
        final isSuccess = DateTime.now().millisecond % 10 != 0;

        messages[index] = messages[index].copyWith(
          status: isSuccess ? MessageStatus.sent : MessageStatus.failed,
        );
        notifyListeners();

        // 如果发送成功，增加亲密度并触发自动回复
        if (isSuccess) {
          _addIntimacy(threadId, content, true);
          _mockReply(threadId);
        }
      }
    }
  }

  /// 增加亲密度
  void _addIntimacy(String threadId, String content, bool isSend) {
    final thread = _threads[threadId];
    if (thread == null || thread.isFriend) return;

    int points = 0;

    // 基础分数
    if (isSend) {
      points += IntimacyCalculator.sendMessage(content);
    } else {
      points += IntimacyCalculator.receiveMessage(content);
    }

    // 首次对话奖励
    if (thread.intimacyPoints == 0) {
      points += IntimacyCalculator.firstChat();
    }

    // 连续对话奖励（5分钟内互动）
    final lastTime = _lastMessageTime[threadId];
    if (lastTime != null) {
      final diff = DateTime.now().difference(lastTime);
      if (diff.inMinutes < 5) {
        points += IntimacyCalculator.continuousChat();
      }
    }

    // 深夜聊天奖励
    points += IntimacyCalculator.lateNightChat();

    // 更新最后消息时间
    _lastMessageTime[threadId] = DateTime.now();

    // 更新亲密度
    final newPoints = thread.intimacyPoints + points;
    _updateThread(threadId, intimacyPoints: newPoints);
  }

  void resendMessage(String threadId, String messageId) {
    final messages = _messages[threadId];
    if (messages != null) {
      final index = messages.indexWhere((msg) => msg.id == messageId);
      if (index != -1) {
        final content = messages[index].content;
        messages[index] = messages[index].copyWith(
          status: MessageStatus.sending,
        );
        notifyListeners();

        // 重新发送
        _simulateSend(threadId, messageId, content);
      }
    }
  }

  Future<void> _mockReply(String threadId) async {
    await Future.delayed(const Duration(seconds: 2));

    final replies = [
      '你好呀',
      '在的',
      '嗯嗯',
      '哈哈哈',
      '是啊',
      '我也是',
      '有点',
      '还好吧',
      '确实',
      '对对对',
    ];

    final content = replies[DateTime.now().second % replies.length];

    final isActiveThread = _activeThreadId == threadId;
    _markPeerReadForOutgoing(threadId);
    final reply = Message(
      id: const Uuid().v4(),
      content: content,
      isMe: false,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
      type: MessageType.text,
      isRead: false,
    );

    _messages[threadId]?.add(reply);
    _deletedThreads[threadId] = false;

    // 增加亲密度
    _addIntimacy(threadId, content, false);

    if (isActiveThread) {
      // 正在查看会话时，收到新消息后立即视为已读
      markAsRead(threadId);
    } else {
      // 未在会话页时才计入未读
      _updateThread(
        threadId,
        unreadCount: (_threads[threadId]?.unreadCount ?? 0) + 1,
      );
    }
  }

  void markAsRead(String threadId) {
    var messageUpdated = false;
    final currentUnread = _threads[threadId]?.unreadCount ?? 0;
    if (currentUnread > 0) {
      _updateThread(threadId, unreadCount: 0, notify: false);
      messageUpdated = true;
    }

    if (messageUpdated) {
      notifyListeners();
    }
  }

  // 对方消息到达可视为其已查看我们此前已发送的消息
  void _markPeerReadForOutgoing(String threadId) {
    final messages = _messages[threadId];
    if (messages == null || messages.isEmpty) return;

    var changed = false;
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      if (message.isMe &&
          message.status == MessageStatus.sent &&
          !message.isRead) {
        messages[i] = message.copyWith(isRead: true);
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  void markAsFriend(String threadId) {
    _updateThread(threadId, isFriend: true);
  }

  /// 取关好友
  void unfollowFriend(String threadId) {
    _updateThread(
      threadId,
      isFriend: false,
      isUnfollowed: true,
      messagesSinceUnfollow: 0,
    );
  }

  /// 确认继续聊天（取关后）
  void confirmChat(String threadId) {
    _updateThread(
      threadId,
      isUnfollowed: false,
      messagesSinceUnfollow: 0,
    );
  }

  /// 解除拉黑后恢复会话：
  /// - 好友：直接恢复可见性并保留原会话
  /// - 陌生人：恢复可见并重置为新的24小时有效期
  void restoreConversationAfterUnblock(String userId) {
    final thread = _threads[userId];
    if (thread == null) return;

    _deletedThreads[userId] = false;

    if (!thread.isFriend) {
      final now = DateTime.now();
      _threads[userId] = ChatThread(
        id: thread.id,
        otherUser: thread.otherUser,
        unreadCount: thread.unreadCount,
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
        intimacyPoints: thread.intimacyPoints,
        isFriend: thread.isFriend,
        isUnfollowed: false,
        messagesSinceUnfollow: 0,
      );
    }

    notifyListeners();
  }

  /// 统一更新Thread的方法
  void _updateThread(
    String threadId, {
    int? unreadCount,
    int? intimacyPoints,
    bool? isFriend,
    bool? isUnfollowed,
    int? messagesSinceUnfollow,
    bool notify = true,
  }) {
    final thread = _threads[threadId];
    if (thread == null) return;

    _threads[threadId] = ChatThread(
      id: thread.id,
      otherUser: thread.otherUser,
      unreadCount: unreadCount ?? thread.unreadCount,
      createdAt: thread.createdAt,
      expiresAt: thread.expiresAt,
      intimacyPoints: intimacyPoints ?? thread.intimacyPoints,
      isFriend: isFriend ?? thread.isFriend,
      isUnfollowed: isUnfollowed ?? thread.isUnfollowed,
      messagesSinceUnfollow:
          messagesSinceUnfollow ?? thread.messagesSinceUnfollow,
    );
    if (notify) {
      notifyListeners();
    }
  }

  void deleteThread(String threadId) {
    // 用户主动删除：清空消息，再隐藏会话入口
    _messages[threadId] = <Message>[];
    _updateThread(threadId, unreadCount: 0, notify: false);
    _deletedThreads[threadId] = true;
    notifyListeners();
  }

  /// 恢复已删除的会话（当对方发送新消息时）
  void restoreThread(String threadId) {
    _deletedThreads[threadId] = false;
    notifyListeners();
  }

  /// 发送图片消息
  Future<void> sendImageMessage(
    String threadId,
    File imageFile,
    ImageQuality quality,
    bool isBurnAfterReading,
  ) async {
    final thread = _threads[threadId];
    if (thread == null) return;

    // 检查是否可以发送消息（取关限制）
    if (!thread.canSendMessage) {
      return;
    }
    if (!thread.canSendImage) {
      return;
    }

    try {
      // 压缩图片
      final compressedImage =
          await ImageHelper.compressImage(imageFile, quality);

      final messageId = const Uuid().v4();
      final message = Message(
        id: messageId,
        content: '[图片]',
        isMe: true,
        timestamp: DateTime.now(),
        status: MessageStatus.sending,
        type: MessageType.image,
        imagePath: compressedImage.path,
        isBurnAfterReading: isBurnAfterReading,
        imageQuality: quality,
      );

      _messages[threadId]?.add(message);

      // 如果被取关，增加计数
      if (thread.isUnfollowed) {
        _updateThread(threadId,
            messagesSinceUnfollow: thread.messagesSinceUnfollow + 1);
      }

      notifyListeners();

      // 模拟发送
      _simulateSendImage(threadId, messageId);
    } catch (e) {
      print('发送图片失败: $e');
    }
  }

  Future<void> _simulateSendImage(String threadId, String messageId) async {
    await Future.delayed(const Duration(seconds: 1));

    final messages = _messages[threadId];
    if (messages != null) {
      final index = messages.indexWhere((msg) => msg.id == messageId);
      if (index != -1) {
        // 模拟网络检测（95%成功率）
        final isSuccess = DateTime.now().millisecond % 20 != 0;

        messages[index] = messages[index].copyWith(
          status: isSuccess ? MessageStatus.sent : MessageStatus.failed,
        );
        notifyListeners();

        // 如果发送成功，增加亲密度
        if (isSuccess) {
          _addIntimacy(threadId, '[图片]', true);
        }
      }
    }
  }

  /// 标记图片为已读（阅后即焚）
  void markImageAsRead(String threadId, String messageId) {
    final messages = _messages[threadId];
    if (messages != null) {
      final index = messages.indexWhere((msg) => msg.id == messageId);
      if (index != -1) {
        final message = messages[index];
        if (message.isBurnAfterReading && !message.isRead) {
          messages[index] = message.copyWith(isRead: true);
          notifyListeners();
        }
      }
    }
  }

  void recallMessage(String threadId, String messageId) {
    final messages = _messages[threadId];
    if (messages != null) {
      messages.removeWhere((msg) => msg.id == messageId);
      notifyListeners();
    }
  }
}
