import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../config/app_env.dart';
import '../models/models.dart';
import '../repositories/app_data_repository.dart';
import '../services/analytics_service.dart';
import '../services/chat_socket_service.dart';
import '../services/chat_service.dart';
import '../services/media_upload_service.dart';
import 'notification_center_provider.dart';
import '../utils/intimacy_system.dart';
import '../utils/image_helper.dart';

class ChatProvider extends ChangeNotifier {
  final AppDataRepository _repository;
  final ChatService _chatService;
  final ChatSocketService _chatSocketService;
  final MediaUploadService _mediaUploadService;
  final Map<String, List<Message>> _messages = {};
  final Map<String, ChatThread> _threads = {};
  final Map<String, DateTime> _lastMessageTime = {}; // 记录最后消息时间
  final Map<String, bool> _deletedThreads = {}; // 软删除的会话
  String? _activeThreadId; // 当前正在浏览的会话
  Timer? _persistTimer;
  bool _isRestoring = false;

  ChatProvider({
    AppDataRepository? repository,
    ChatService? chatService,
    ChatSocketService? chatSocketService,
    MediaUploadService? mediaUploadService,
  })  : _repository = repository ?? AppDataRepository.instance,
        _chatService = chatService ?? ChatService(),
        _chatSocketService = chatSocketService ?? ChatSocketService.instance,
        _mediaUploadService = mediaUploadService ?? MediaUploadService() {
    _bindRealtime();
    _restoreFromStorage();
    unawaited(_hydrateRemote());
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    _unbindRealtime();
    super.dispose();
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (_isRestoring) return;
    _schedulePersist();
  }

  Map<String, ChatThread> get threads {
    // 过滤掉已软删除的会话
    return Map.fromEntries(_threads.entries.where((entry) =>
        !(_deletedThreads[entry.key] ?? false) &&
        (entry.value.isFriend || !entry.value.isExpired)));
  }

  List<ChatThread> get sortedThreads {
    final items = threads.values.toList();
    items.sort((a, b) {
      final compare = _lastActivityAt(b).compareTo(_lastActivityAt(a));
      if (compare != 0) return compare;
      return b.createdAt.compareTo(a.createdAt);
    });
    return items;
  }

  List<Message> getMessages(String threadId) {
    return _messages[threadId] ?? [];
  }

  ChatThread? getThread(String threadId) {
    return _threads[threadId];
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 180), () {
      _persistState();
    });
  }

  Future<void> _persistState() async {
    final snapshot = <String, dynamic>{
      'threads': _threads.map((key, value) => MapEntry(key, value.toJson())),
      'messages': _messages.map(
        (key, value) => MapEntry(
          key,
          value.map((msg) => msg.toJson()).toList(),
        ),
      ),
      'lastMessageTime': _lastMessageTime.map(
        (key, value) => MapEntry(key, value.toIso8601String()),
      ),
      'deletedThreads': _deletedThreads,
    };
    await _repository.saveChatState(snapshot);
  }

  void _restoreFromStorage() {
    final snapshot = _repository.loadChatState();
    if (snapshot == null) return;

    final rawThreads = snapshot['threads'];
    final rawMessages = snapshot['messages'];
    final rawLastMessageTime = snapshot['lastMessageTime'];
    final rawDeletedThreads = snapshot['deletedThreads'];

    _isRestoring = true;
    try {
      _threads.clear();
      _messages.clear();
      _lastMessageTime.clear();
      _deletedThreads.clear();

      if (rawThreads is Map) {
        for (final entry in rawThreads.entries) {
          final key = entry.key.toString();
          final value = entry.value;
          if (value is! Map) continue;
          final threadJson = value.map(
            (k, v) => MapEntry(k.toString(), v),
          );
          try {
            _threads[key] = ChatThread.fromJson(threadJson);
          } catch (_) {}
        }
      }

      if (rawMessages is Map) {
        for (final entry in rawMessages.entries) {
          final key = entry.key.toString();
          final value = entry.value;
          if (value is! List) continue;
          final parsed = <Message>[];
          for (final item in value) {
            if (item is! Map) continue;
            try {
              parsed.add(
                Message.fromJson(
                  item.map((k, v) => MapEntry(k.toString(), v)),
                ),
              );
            } catch (_) {}
          }
          _messages[key] = parsed;
        }
      }

      if (rawLastMessageTime is Map) {
        for (final entry in rawLastMessageTime.entries) {
          final key = entry.key.toString();
          final value = entry.value;
          if (value is! String) continue;
          try {
            _lastMessageTime[key] = DateTime.parse(value);
          } catch (_) {}
        }
      }

      if (rawDeletedThreads is Map) {
        for (final entry in rawDeletedThreads.entries) {
          _deletedThreads[entry.key.toString()] = entry.value == true;
        }
      }

      for (final threadId in _threads.keys) {
        _messages.putIfAbsent(threadId, () => <Message>[]);
        _deletedThreads.putIfAbsent(threadId, () => false);
      }
    } finally {
      _isRestoring = false;
    }

    if (_threads.isNotEmpty) {
      notifyListeners();
    }
  }

  void setActiveThread(String threadId) {
    _activeThreadId = threadId;
    markAsRead(threadId);
    unawaited(_chatSocketService.joinThread(threadId));
    unawaited(_loadMessagesRemote(threadId));
  }

  void clearActiveThread(String threadId) {
    if (_activeThreadId == threadId) {
      _activeThreadId = null;
    }
  }

  Future<void> _hydrateRemote() async {
    await _ensureRealtimeReady();
    final remoteThreads = await _chatService.loadThreads();
    if (remoteThreads.isEmpty) return;

    _isRestoring = true;
    try {
      for (final thread in remoteThreads) {
        _upsertThread(thread, notify: false);
      }
    } finally {
      _isRestoring = false;
    }

    for (final thread in remoteThreads) {
      unawaited(_loadMessagesRemote(thread.id));
    }
    _joinKnownThreads();
    notifyListeners();
  }

  Future<void> refreshFromRemote() async {
    await _hydrateRemote();
  }

  Future<void> _loadMessagesRemote(String threadId) async {
    final remoteMessages = await _chatService.loadMessages(threadId);
    if (remoteMessages.isEmpty && !_threads.containsKey(threadId)) return;
    final localMessages = _messages[threadId] ?? const <Message>[];
    final pendingMessages = localMessages
        .where((msg) => msg.status != MessageStatus.sent)
        .toList(growable: false);
    final mergedMessages = <Message>[...remoteMessages];
    for (final pending in pendingMessages) {
      final exists = mergedMessages.any(
        (msg) => msg.id == pending.id ||
            (msg.timestamp == pending.timestamp &&
                msg.content == pending.content &&
                msg.isMe == pending.isMe),
      );
      if (!exists) {
        mergedMessages.add(pending);
      }
    }
    mergedMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _messages[threadId] = mergedMessages;
    notifyListeners();
  }

  Future<ChatThread> ensureDirectThreadForUser(
    User user, {
    bool isFriend = false,
  }) async {
    final existingThread = _findThreadByUserId(user.id);
    if (existingThread != null) {
      _deletedThreads[existingThread.id] = false;
      if (!_chatService.hasSession || _isRemoteThreadId(existingThread.id)) {
        notifyListeners();
        return existingThread;
      }

      final remoteThread = await _chatService.createDirectThread(user);
      if (remoteThread != null) {
        final mergedThread = _upsertThread(remoteThread);
        unawaited(_chatSocketService.joinThread(mergedThread.id));
        unawaited(_loadMessagesRemote(mergedThread.id));
        return mergedThread;
      }

      notifyListeners();
      return existingThread;
    }

    final remoteThread = await _chatService.createDirectThread(user);
    if (remoteThread != null) {
      final mergedThread = _upsertThread(remoteThread);
      unawaited(_chatSocketService.joinThread(mergedThread.id));
      unawaited(_loadMessagesRemote(mergedThread.id));
      return mergedThread;
    }

    final localThread = ChatThread(
      id: user.id,
      otherUser: user,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(
        isFriend ? const Duration(days: 365) : const Duration(hours: 24),
      ),
      intimacyPoints: isFriend ? 250 : 0,
      isFriend: isFriend,
    );
    return _upsertThread(localThread);
  }

  void addThread(ChatThread thread) {
    _upsertThread(thread);
  }

  ChatThread _upsertThread(ChatThread thread, {bool notify = true}) {
    final existingThread = _threads[thread.id];
    if (existingThread != null) {
      final mergedThread = ChatThread(
        id: existingThread.id,
        otherUser: thread.otherUser,
        unreadCount: thread.unreadCount,
        createdAt: existingThread.createdAt,
        expiresAt: thread.expiresAt,
        intimacyPoints: existingThread.intimacyPoints,
        isFriend: thread.isFriend || existingThread.isFriend,
        isUnfollowed: existingThread.isUnfollowed,
        messagesSinceUnfollow: existingThread.messagesSinceUnfollow,
      );
      _threads[thread.id] = mergedThread;
      _messages[thread.id] ??= [];
      _deletedThreads[thread.id] = false;
      unawaited(_chatSocketService.joinThread(thread.id));
      if (notify) {
        notifyListeners();
      }
      return mergedThread;
    }

    final existingByUserId = _findThreadByUserId(thread.otherUser.id);
    if (existingByUserId != null) {
      final mergedThread = ChatThread(
        id: thread.id,
        otherUser: thread.otherUser,
        unreadCount: thread.unreadCount,
        createdAt: existingByUserId.createdAt,
        expiresAt: thread.expiresAt,
        intimacyPoints: existingByUserId.intimacyPoints,
        isFriend: thread.isFriend || existingByUserId.isFriend,
        isUnfollowed: existingByUserId.isUnfollowed,
        messagesSinceUnfollow: existingByUserId.messagesSinceUnfollow,
      );
      _replaceThread(existingByUserId.id, mergedThread);
      unawaited(_chatSocketService.joinThread(mergedThread.id));
      if (notify) {
        notifyListeners();
      }
      return mergedThread;
    }

    _threads[thread.id] = thread;
    _messages.putIfAbsent(thread.id, () => <Message>[]);
    _deletedThreads[thread.id] = false;
    unawaited(_chatSocketService.joinThread(thread.id));
    if (notify) {
      notifyListeners();
    }
    return thread;
  }

  ChatThread? _findThreadByUserId(String userId) {
    for (final thread in _threads.values) {
      if (thread.otherUser.id == userId) {
        return thread;
      }
    }
    return null;
  }

  bool _isRemoteThreadId(String threadId) {
    return threadId.startsWith('th_');
  }

  void _replaceThread(String oldThreadId, ChatThread newThread) {
    final oldMessages = _messages.remove(oldThreadId) ?? const <Message>[];
    final mergedMessages = <Message>[
      ...(_messages[newThread.id] ?? const <Message>[]),
    ];

    for (final message in oldMessages) {
      final exists = mergedMessages.any(
        (item) => item.id == message.id ||
            (item.timestamp == message.timestamp &&
                item.content == message.content &&
                item.isMe == message.isMe),
      );
      if (!exists) {
        mergedMessages.add(message);
      }
    }

    mergedMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final previousLastMessageTime = _lastMessageTime.remove(oldThreadId);
    final previousDeleted = _deletedThreads.remove(oldThreadId) ?? false;

    _threads.remove(oldThreadId);
    _threads[newThread.id] = newThread;
    _messages[newThread.id] = mergedMessages;
    _deletedThreads[newThread.id] = previousDeleted;

    if (previousLastMessageTime != null) {
      final existingLastMessageTime = _lastMessageTime[newThread.id];
      if (existingLastMessageTime == null ||
          previousLastMessageTime.isAfter(existingLastMessageTime)) {
        _lastMessageTime[newThread.id] = previousLastMessageTime;
      }
    }

    if (_activeThreadId == oldThreadId) {
      _activeThreadId = newThread.id;
    }
  }

  bool sendMessage(String threadId, String content) {
    final normalized = content.trim();
    if (normalized.isEmpty) return false;

    final thread = _threads[threadId];
    if (thread == null) return false;

    // 检查是否可以发送消息（取关限制）
    if (!_chatService.canSendText(thread)) {
      // 不能发送，需要对方确认
      return false;
    }

    final messageId = const Uuid().v4();
    final message = Message(
      id: messageId,
      content: normalized,
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

    unawaited(
      AnalyticsService.instance.track(
        'chat_message_send_requested',
        properties: {
          'threadId': threadId,
          'type': 'text',
          'length': normalized.length,
        },
      ),
    );

    if (_chatService.hasSession) {
      unawaited(
        _sendMessageWithResolvedThread(thread, threadId, messageId, normalized),
      );
    } else if (AppEnv.allowLocalDemoFallbacks) {
      _simulateSend(threadId, messageId, normalized);
    } else {
      _markMessageFailed(threadId, messageId);
    }
    return true;
  }

  Future<void> _sendMessageWithResolvedThread(
    ChatThread thread,
    String threadId,
    String localMessageId,
    String content,
  ) async {
    var resolvedThreadId = threadId;
    if (!_isRemoteThreadId(threadId)) {
      final remoteThread = await _chatService.createDirectThread(thread.otherUser);
      if (remoteThread != null) {
        resolvedThreadId = _upsertThread(remoteThread).id;
      }
    }

    await _sendMessageRealtime(resolvedThreadId, localMessageId, content);
  }

  Future<void> _sendMessageRealtime(
    String threadId,
    String localMessageId,
    String content,
  ) async {
    await _ensureRealtimeReady();
    final joined = await _chatSocketService.joinThread(threadId);
    final sent = joined &&
        await _chatSocketService.sendText(
          threadId: threadId,
          content: content,
          clientMsgId: localMessageId,
        );
    if (!sent) {
      await _sendMessageRemote(threadId, localMessageId, content);
    }
  }

  Future<void> _sendMessageRemote(
    String threadId,
    String localMessageId,
    String content,
  ) async {
    final remoteMessage = await _chatService.sendTextMessage(
      threadId,
      content,
      localMessageId,
    );

    final messages = _messages[threadId];
    if (messages == null) return;
    final index = messages.indexWhere((msg) => msg.id == localMessageId);
    if (index == -1) return;

    if (remoteMessage != null) {
      messages[index] = remoteMessage;
      _addIntimacy(threadId, content, true);
    } else {
      messages[index] = messages[index].copyWith(status: MessageStatus.failed);
    }
    notifyListeners();
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

        if (_chatService.hasSession) {
          unawaited(_sendMessageRealtime(threadId, messageId, content));
        } else if (AppEnv.allowLocalDemoFallbacks) {
          _simulateSend(threadId, messageId, content);
        } else {
          _markMessageFailed(threadId, messageId);
        }
      }
    }
  }

  void _markMessageFailed(String threadId, String messageId) {
    final messages = _messages[threadId];
    if (messages == null) return;
    final index = messages.indexWhere((msg) => msg.id == messageId);
    if (index == -1) return;
    messages[index] = messages[index].copyWith(status: MessageStatus.failed);
    notifyListeners();
  }

  Future<void> _mockReply(String threadId) async {
    await Future.delayed(const Duration(seconds: 2));

    final content = _chatService.getMockReply();

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

    final messages = _messages[threadId];
    final lastMessageId = messages != null && messages.isNotEmpty
        ? messages.last.id
        : null;
    if (_chatService.hasSession) {
      unawaited(_markAsReadRealtime(threadId, lastMessageId: lastMessageId));
    }
  }

  Future<void> _markAsReadRealtime(
    String threadId, {
    String? lastMessageId,
  }) async {
    await _ensureRealtimeReady();
    final joined = await _chatSocketService.joinThread(threadId);
    final sent = joined &&
        await _chatSocketService.markRead(
          threadId,
          lastReadMessageId: lastMessageId,
        );
    if (!sent) {
      await _chatService.markThreadRead(
        threadId,
        lastReadMessageId: lastMessageId,
      );
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
    final threadId = _resolveThreadIdByUserId(userId);
    if (threadId == null) return;
    final thread = _threads[threadId];
    if (thread == null) return;

    _deletedThreads[threadId] = false;

    if (!thread.isFriend) {
      final now = DateTime.now();
      _threads[threadId] = ChatThread(
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
    unawaited(_chatService.deleteThread(threadId));
  }

  /// 恢复已删除的会话（当对方发送新消息时）
  void restoreThread(String threadId) {
    _deletedThreads[threadId] = false;
    notifyListeners();
  }

  /// 发送图片消息
  Future<bool> sendImageMessage(
    String threadId,
    File imageFile,
    ImageQuality quality,
    bool isBurnAfterReading,
  ) async {
    final thread = _threads[threadId];
    if (thread == null) return false;

    // 检查是否可以发送消息（取关限制）
    if (!_chatService.canSendImage(thread)) {
      return false;
    }

    try {
      // 压缩图片
      final compressedImage =
          await ImageHelper.compressImage(imageFile, quality);
      final preparedUpload = await _mediaUploadService.prepareChatImageUpload(
        threadId,
        compressedImage,
      );

      final messageId = const Uuid().v4();
      final message = Message(
        id: messageId,
        content: '[图片]',
        isMe: true,
        timestamp: DateTime.now(),
        status: MessageStatus.sending,
        type: MessageType.image,
        imagePath: preparedUpload.previewPath,
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

      unawaited(
        AnalyticsService.instance.track(
          'chat_message_send_requested',
          properties: {
            'threadId': threadId,
            'type': 'image',
            'burnAfterReading': isBurnAfterReading,
          },
        ),
      );

      if (_chatService.hasSession) {
        unawaited(_sendImageMessageRealtime(
          threadId,
          messageId,
          preparedUpload.sendKey,
          isBurnAfterReading,
        ));
      } else if (AppEnv.allowLocalDemoFallbacks) {
        _simulateSendImage(threadId, messageId);
      } else {
        _markMessageFailed(threadId, messageId);
      }
      return true;
    } catch (e) {
      debugPrint('发送图片失败: $e');
      return false;
    }
  }

  Future<void> _sendImageMessageRealtime(
    String threadId,
    String localMessageId,
    String imageKey,
    bool burnAfterReading,
  ) async {
    await _ensureRealtimeReady();
    final joined = await _chatSocketService.joinThread(threadId);
    final sent = joined &&
        await _chatSocketService.sendImage(
          threadId: threadId,
          imageKey: imageKey,
          burnAfterReading: burnAfterReading,
          clientMsgId: localMessageId,
        );
    if (!sent) {
      await _sendImageMessageRemote(
        threadId,
        localMessageId,
        imageKey,
        burnAfterReading,
      );
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

  Future<void> _sendImageMessageRemote(
    String threadId,
    String localMessageId,
    String imageKey,
    bool burnAfterReading,
  ) async {
    final remoteMessage = await _chatService.sendImageMessage(
      threadId,
      imageKey,
      burnAfterReading,
      localMessageId,
    );

    final messages = _messages[threadId];
    if (messages == null) return;
    final index = messages.indexWhere((msg) => msg.id == localMessageId);
    if (index == -1) return;

    if (remoteMessage != null) {
      messages[index] = _mergeRemoteMessage(messages[index], remoteMessage);
      _addIntimacy(threadId, '[图片]', true);
    } else {
      messages[index] = messages[index].copyWith(status: MessageStatus.failed);
    }
    notifyListeners();
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
    unawaited(_chatService.recallMessage(messageId));
  }

  DateTime _lastActivityAt(ChatThread thread) {
    final messages = _messages[thread.id];
    if (messages != null && messages.isNotEmpty) {
      return messages.last.timestamp;
    }
    return thread.createdAt;
  }

  String? _resolveThreadIdByUserId(String userId) {
    if (_threads.containsKey(userId)) return userId;
    for (final entry in _threads.entries) {
      if (entry.value.otherUser.id == userId) {
        return entry.key;
      }
    }
    return null;
  }

  void _bindRealtime() {
    _chatSocketService.onConnected = (_) {
      _joinKnownThreads();
      final activeThreadId = _activeThreadId;
      if (activeThreadId != null) {
        unawaited(_chatSocketService.joinThread(activeThreadId));
      }
    };
    _chatSocketService.onMessageAck = _handleMessageAck;
    _chatSocketService.onMessageNew = _handleIncomingMessage;
    _chatSocketService.onPeerRead = (event) {
      _markPeerReadForOutgoing(event.threadId);
    };
    _chatSocketService.onThreadUpdated = (thread) {
      addThread(thread);
    };
    _chatSocketService.onError = (message) {
      debugPrint('chat socket error: $message');
    };
  }

  void _unbindRealtime() {
    _chatSocketService.onConnected = null;
    _chatSocketService.onMessageAck = null;
    _chatSocketService.onMessageNew = null;
    _chatSocketService.onPeerRead = null;
    _chatSocketService.onThreadUpdated = null;
    _chatSocketService.onError = null;
  }

  Future<void> _ensureRealtimeReady() async {
    if (!_chatService.hasSession) return;
    final connected = await _chatSocketService.connect();
    if (connected) {
      _joinKnownThreads();
    }
  }

  void _joinKnownThreads() {
    if (!_chatSocketService.isConnected) return;
    for (final threadId in _threads.keys) {
      unawaited(_chatSocketService.joinThread(threadId));
    }
  }

  void _handleMessageAck(MessageAckEvent event) {
    final messages = _messages[event.threadId] ??= <Message>[];
    final index = messages.indexWhere((msg) => msg.id == event.clientMsgId);
    if (index != -1) {
      final previous = messages[index];
      messages[index] = _mergeRemoteMessage(previous, event.message);
      if (previous.status != MessageStatus.sent) {
        _addIntimacy(event.threadId, previous.content, true);
      }
    } else if (!messages.any((msg) => msg.id == event.message.id)) {
      messages.add(event.message);
    }
    _deletedThreads[event.threadId] = false;
    notifyListeners();
  }

  void _handleIncomingMessage(IncomingMessageEvent event) {
    final thread = _threads[event.threadId];
    if (thread == null) {
      unawaited(refreshFromRemote());
      return;
    }

    final messages = _messages[event.threadId] ??= <Message>[];
    if (!messages.any((msg) => msg.id == event.message.id)) {
      messages.add(event.message);
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _addIntimacy(event.threadId, event.message.content, false);
    }

    restoreThread(event.threadId);
    if (_activeThreadId == event.threadId) {
      markAsRead(event.threadId);
    } else {
      _updateThread(
        event.threadId,
        unreadCount: (_threads[event.threadId]?.unreadCount ?? 0) + 1,
        notify: false,
      );
      unawaited(
        NotificationCenterProvider.instance.addChatMessageNotification(
          thread: thread,
          message: event.message,
        ),
      );
      notifyListeners();
    }
  }

  Message _mergeRemoteMessage(Message localMessage, Message remoteMessage) {
    if (remoteMessage.type != MessageType.image) {
      return remoteMessage;
    }

    final remoteImagePath = remoteMessage.imagePath;
    if (_isUsableImagePath(remoteImagePath)) {
      return remoteMessage;
    }

    return Message(
      id: remoteMessage.id,
      content: remoteMessage.content,
      isMe: remoteMessage.isMe,
      timestamp: remoteMessage.timestamp,
      status: remoteMessage.status,
      type: remoteMessage.type,
      imagePath: localMessage.imagePath,
      isBurnAfterReading: remoteMessage.isBurnAfterReading,
      isRead: remoteMessage.isRead,
      imageQuality: localMessage.imageQuality ?? remoteMessage.imageQuality,
    );
  }

  bool _isUsableImagePath(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return false;
    }
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return true;
    }
    return File(imagePath).existsSync();
  }
}
