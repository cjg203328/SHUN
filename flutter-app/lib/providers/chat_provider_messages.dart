part of 'chat_provider.dart';

const Duration _duplicateTextSubmitWindow = Duration(milliseconds: 800);
const Duration _duplicateImageSubmitWindow = Duration(milliseconds: 800);

extension ChatProviderMessages on ChatProvider {
  bool sendMessage(String threadId, String content) {
    final normalized = content.trim();
    if (normalized.isEmpty) return false;

    final thread = _getSendableThread(
      threadId,
      requireImagePermission: false,
    );
    if (thread == null) return false;
    if (_isDuplicateTextSubmit(threadId, normalized)) {
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

    if (thread.isUnfollowed) {
      _updateThread(
        threadId,
        messagesSinceUnfollow: thread.messagesSinceUnfollow + 1,
      );
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
    } else if (AppEnv.allowMockChatReplies) {
      _simulateSend(threadId, messageId, normalized);
    } else {
      _markMessageFailed(threadId, messageId);
    }
    return true;
  }

  ChatThread? _getSendableThread(
    String threadId, {
    required bool requireImagePermission,
  }) {
    threadId = _resolveThreadId(threadId);
    final thread = _threads[threadId];
    if (thread == null) {
      return null;
    }
    if (_deletedThreads[threadId] ?? false) {
      return null;
    }
    if (!thread.isFriend && thread.isExpired) {
      return null;
    }
    final canSend = requireImagePermission
        ? _chatService.canSendImage(thread)
        : _chatService.canSendText(thread);
    return canSend ? thread : null;
  }

  bool _isDuplicateTextSubmit(String threadId, String normalizedContent) {
    final messages = _messages[threadId];
    if (messages == null || messages.isEmpty) {
      return false;
    }

    final latest = messages.last;
    if (!latest.isMe ||
        latest.type != MessageType.text ||
        latest.status != MessageStatus.sending ||
        latest.content != normalizedContent) {
      return false;
    }

    return DateTime.now().difference(latest.timestamp) <=
        _duplicateTextSubmitWindow;
  }

  Future<void> _sendMessageWithResolvedThread(
    ChatThread thread,
    String threadId,
    String localMessageId,
    String content,
  ) async {
    var resolvedThreadId = threadId;
    if (!_isRemoteThreadId(threadId)) {
      final remoteThread =
          await _chatService.createDirectThread(thread.otherUser);
      if (remoteThread != null) {
        resolvedThreadId = _upsertThread(remoteThread).id;
      }
    }

    if (_getSendableThread(
          resolvedThreadId,
          requireImagePermission: false,
        ) ==
        null) {
      _markMessageFailed(resolvedThreadId, localMessageId);
      return;
    }

    await _sendMessageRealtime(resolvedThreadId, localMessageId, content);
  }

  Future<void> _sendMessageRealtime(
    String threadId,
    String localMessageId,
    String content,
  ) async {
    await _ensureRealtimeReady();
    final joined = await _joinThreadRealtime(threadId);
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
      _recordDeliverySuccess(MessageType.text, localMessageId);
    } else {
      messages[index] = messages[index].copyWith(status: MessageStatus.failed);
      _recordDeliveryFailure(MessageType.text, localMessageId);
    }
    notifyListeners();
  }

  Future<void> _simulateSend(
    String threadId,
    String messageId,
    String content,
  ) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final messages = _messages[threadId];
    if (messages != null) {
      final index = messages.indexWhere((msg) => msg.id == messageId);
      if (index != -1) {
        final isSuccess = DateTime.now().millisecond % 10 != 0;

        messages[index] = messages[index].copyWith(
          status: isSuccess ? MessageStatus.sent : MessageStatus.failed,
        );
        if (isSuccess) {
          _recordDeliverySuccess(MessageType.text, messageId);
        } else {
          _recordDeliveryFailure(MessageType.text, messageId);
        }
        notifyListeners();

        if (isSuccess) {
          _addIntimacy(threadId, content, true);
          _mockReply(threadId);
        }
      }
    }
  }

  void _addIntimacy(String threadId, String content, bool isSend) {
    final thread = _threads[threadId];
    if (thread == null || thread.isFriend) return;

    var points = 0;
    if (isSend) {
      points += IntimacyCalculator.sendMessage(content);
    } else {
      points += IntimacyCalculator.receiveMessage(content);
    }

    if (thread.intimacyPoints == 0) {
      points += IntimacyCalculator.firstChat();
    }

    final lastTime = _lastMessageTime[threadId];
    if (lastTime != null) {
      final diff = DateTime.now().difference(lastTime);
      if (diff.inMinutes < 5) {
        points += IntimacyCalculator.continuousChat();
      }
    }

    points += IntimacyCalculator.lateNightChat();
    _lastMessageTime[threadId] = DateTime.now();

    final newPoints = thread.intimacyPoints + points;
    _updateThread(threadId, intimacyPoints: newPoints);
  }

  bool canResendMessage(String threadId, String messageId) {
    threadId = _resolveThreadId(threadId);
    if (_getSendableThread(threadId, requireImagePermission: false) == null) {
      return false;
    }
    final messages = _messages[threadId];
    if (messages == null) return false;
    final message = messages.cast<Message?>().firstWhere(
          (msg) => msg?.id == messageId,
          orElse: () => null,
        );
    if (message == null || !message.isMe) {
      return false;
    }
    return message.status == MessageStatus.failed &&
        message.type == MessageType.text;
  }

  Future<bool> retryFailedMessage(String threadId, String messageId) async {
    threadId = _resolveThreadId(threadId);
    final messages = _messages[threadId];
    if (messages == null) {
      return false;
    }
    final message = messages.cast<Message?>().firstWhere(
          (msg) => msg?.id == messageId,
          orElse: () => null,
        );
    if (message == null ||
        !message.isMe ||
        message.status != MessageStatus.failed) {
      return false;
    }
    if (message.type == MessageType.image) {
      return resendImageMessage(threadId, messageId);
    }
    return resendMessage(threadId, messageId);
  }

  Future<bool> resendImageMessage(String threadId, String messageId) async {
    threadId = _resolveThreadId(threadId);
    final thread = _getSendableThread(
      threadId,
      requireImagePermission: true,
    );
    if (thread == null) {
      return false;
    }

    final messages = _messages[threadId];
    if (messages == null) return false;
    final index = messages.indexWhere((msg) => msg.id == messageId);
    if (index == -1) return false;

    final message = messages[index];
    if (!message.isMe ||
        message.status != MessageStatus.failed ||
        message.type != MessageType.image) {
      return false;
    }

    final imagePath = message.imagePath;
    if (imagePath == null || imagePath.isEmpty) {
      _deliveryStatsService.recordImageReselectRequired();
      return false;
    }
    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      _deliveryStatsService.recordImageReselectRequired();
      return false;
    }

    _deliveryStatsService.recordRetryRequested();
    _retryingMessageIds.add(messageId);
    messages[index] = message.copyWith(status: MessageStatus.sending);
    notifyListeners();

    if (_chatService.hasSession) {
      unawaited(
        _sendImageMessageWithResolvedThread(
          thread,
          threadId,
          messageId,
          imageFile,
          message.isBurnAfterReading,
        ),
      );
    } else if (AppEnv.allowMockChatReplies) {
      _simulateSendImage(threadId, messageId);
    } else {
      _markMessageFailed(threadId, messageId);
    }

    return true;
  }

  bool resendMessage(String threadId, String messageId) {
    threadId = _resolveThreadId(threadId);
    if (!canResendMessage(threadId, messageId)) {
      return false;
    }

    final thread = _getSendableThread(
      threadId,
      requireImagePermission: false,
    );
    if (thread == null) {
      return false;
    }

    final messages = _messages[threadId];
    if (messages == null) return false;
    final index = messages.indexWhere((msg) => msg.id == messageId);
    if (index == -1) return false;

    final content = messages[index].content;
    _deliveryStatsService.recordRetryRequested();
    _retryingMessageIds.add(messageId);
    messages[index] = messages[index].copyWith(
      status: MessageStatus.sending,
    );
    notifyListeners();

    if (_chatService.hasSession) {
      unawaited(
        _sendMessageWithResolvedThread(thread, threadId, messageId, content),
      );
    } else if (AppEnv.allowMockChatReplies) {
      _simulateSend(threadId, messageId, content);
    } else {
      _markMessageFailed(threadId, messageId);
    }

    return true;
  }

  void _markMessageFailed(String threadId, String messageId) {
    threadId = _resolveThreadId(threadId);
    final messages = _messages[threadId];
    if (messages == null) return;
    final index = messages.indexWhere((msg) => msg.id == messageId);
    if (index == -1) return;
    final message = messages[index];
    messages[index] = message.copyWith(status: MessageStatus.failed);
    _recordDeliveryFailure(message.type, messageId);
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
    _addIntimacy(threadId, content, false);

    if (isActiveThread) {
      markAsRead(threadId);
    } else {
      _updateThread(
        threadId,
        unreadCount: (_threads[threadId]?.unreadCount ?? 0) + 1,
      );
    }
  }

  void markAsRead(String threadId) {
    threadId = _resolveThreadId(threadId);
    final messages = _messages[threadId];
    final lastMessageId = _resolveAutoReadMessageId(messages);
    final readMessageIds = _resolveAutoReadMessageIds(messages);
    final remainingUnread = _countUnreadIncomingMessages(
      messages,
      lastReadMessageId: lastMessageId,
    );
    var messageUpdated = false;
    final currentUnread = _threads[threadId]?.unreadCount ?? 0;
    if (currentUnread != remainingUnread) {
      _updateThread(threadId, unreadCount: remainingUnread, notify: false);
      messageUpdated = true;
    }

    if (messageUpdated) {
      notifyListeners();
    }

    if (readMessageIds.isNotEmpty) {
      unawaited(
        NotificationCenterProvider.instance
            .markThreadNotificationsReadByMessageIds(
          threadId,
          readMessageIds,
        ),
      );
    }

    final shouldSyncRemote = lastMessageId != null &&
        (_lastReadSyncMessageIds[threadId] != lastMessageId ||
            currentUnread > 0);
    if (_chatService.hasSession) {
      if (shouldSyncRemote) {
        _lastReadSyncMessageIds[threadId] = lastMessageId;
        unawaited(_markAsReadRealtime(threadId, lastMessageId: lastMessageId));
      }
    }
  }

  Future<void> _markAsReadRealtime(
    String threadId, {
    String? lastMessageId,
  }) async {
    await _ensureRealtimeReady();
    final joined = await _joinThreadRealtime(threadId);
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

  void _markPeerReadForOutgoing(
    String threadId, {
    String? lastReadMessageId,
  }) {
    final messages = _messages[threadId];
    if (messages == null || messages.isEmpty) return;

    final upperBound = _resolvePeerReadUpperBound(
      messages,
      lastReadMessageId: lastReadMessageId,
    );
    if (upperBound < 0) return;

    var changed = false;
    for (var i = 0; i <= upperBound; i++) {
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

  String? _resolveAutoReadMessageId(List<Message>? messages) {
    final readMessageIds = _resolveAutoReadMessageIds(messages);
    if (readMessageIds.isEmpty) {
      return null;
    }
    return messages!
        .lastWhere((message) => readMessageIds.contains(message.id))
        .id;
  }

  Set<String> _resolveAutoReadMessageIds(List<Message>? messages) {
    if (messages == null || messages.isEmpty) {
      return <String>{};
    }

    final readMessageIds = <String>{};
    for (final message in messages) {
      if (!message.isMe && message.isBurnAfterReading && !message.isRead) {
        break;
      }
      if (!message.isMe) {
        readMessageIds.add(message.id);
      }
    }
    return readMessageIds;
  }

  int _countUnreadIncomingMessages(
    List<Message>? messages, {
    String? lastReadMessageId,
  }) {
    if (messages == null || messages.isEmpty) {
      return 0;
    }
    if (lastReadMessageId == null || lastReadMessageId.isEmpty) {
      return messages.where((message) => !message.isMe).length;
    }
    final upperBound = _resolvePeerReadUpperBound(
      messages,
      lastReadMessageId: lastReadMessageId,
    );
    var unread = 0;
    for (var i = upperBound + 1; i < messages.length; i++) {
      if (!messages[i].isMe) {
        unread += 1;
      }
    }
    return unread;
  }

  int _resolvePeerReadUpperBound(
    List<Message> messages, {
    String? lastReadMessageId,
  }) {
    if (lastReadMessageId == null || lastReadMessageId.isEmpty) {
      return messages.length - 1;
    }
    return messages.indexWhere((message) => message.id == lastReadMessageId);
  }

  Future<bool> sendImageMessage(
    String threadId,
    File imageFile,
    ImageQuality quality,
    bool isBurnAfterReading,
  ) async {
    threadId = _resolveThreadId(threadId);
    final thread = _getSendableThread(
      threadId,
      requireImagePermission: true,
    );
    if (thread == null) return false;
    if (_isDuplicateImageSubmit(
      threadId,
      imageFile.path,
      quality,
      isBurnAfterReading,
    )) {
      return false;
    }

    try {
      final compressedImage =
          await ImageHelper.compressImage(imageFile, quality);
      final latestThread = _getSendableThread(
        threadId,
        requireImagePermission: true,
      );
      if (latestThread == null) {
        return false;
      }

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

      if (latestThread.isUnfollowed) {
        _updateThread(
          threadId,
          messagesSinceUnfollow: latestThread.messagesSinceUnfollow + 1,
        );
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
        unawaited(
          _sendImageMessageWithResolvedThread(
            latestThread,
            threadId,
            messageId,
            compressedImage,
            isBurnAfterReading,
          ),
        );
      } else if (AppEnv.allowMockChatReplies) {
        _simulateSendImage(threadId, messageId);
      } else {
        _markMessageFailed(threadId, messageId);
      }
      return true;
    } catch (error) {
      debugPrint('发送图片失败: $error');
      return false;
    }
  }

  Future<void> _sendImageMessageWithResolvedThread(
    ChatThread thread,
    String threadId,
    String localMessageId,
    File compressedImage,
    bool burnAfterReading,
  ) async {
    var resolvedThreadId = threadId;
    if (!_isRemoteThreadId(threadId)) {
      final remoteThread =
          await _chatService.createDirectThread(thread.otherUser);
      if (remoteThread != null) {
        resolvedThreadId = _upsertThread(remoteThread).id;
      }
    }

    final resolvedThread = _getSendableThread(
      resolvedThreadId,
      requireImagePermission: true,
    );
    if (resolvedThread == null) {
      _markMessageFailed(resolvedThreadId, localMessageId);
      return;
    }

    final preparedUpload = await _mediaUploadService.prepareChatImageUpload(
      resolvedThreadId,
      compressedImage,
    );
    if (_getSendableThread(resolvedThreadId, requireImagePermission: true) ==
        null) {
      _markMessageFailed(resolvedThreadId, localMessageId);
      return;
    }
    if (_chatService.hasSession && !preparedUpload.isRemotePrepared) {
      _markMessageFailed(resolvedThreadId, localMessageId);
      return;
    }

    await _sendImageMessageRealtime(
      resolvedThreadId,
      localMessageId,
      preparedUpload.sendKey,
      burnAfterReading,
    );
  }

  bool _isDuplicateImageSubmit(
    String threadId,
    String imagePath,
    ImageQuality quality,
    bool isBurnAfterReading,
  ) {
    final fingerprint =
        '$threadId|$imagePath|${quality.name}|$isBurnAfterReading';
    final lastSubmittedAt = _recentImageSubmitAt[fingerprint];
    final now = DateTime.now();
    _recentImageSubmitAt[fingerprint] = now;
    if (lastSubmittedAt == null) {
      return false;
    }
    return now.difference(lastSubmittedAt) <= _duplicateImageSubmitWindow;
  }

  Future<void> _sendImageMessageRealtime(
    String threadId,
    String localMessageId,
    String imageKey,
    bool burnAfterReading,
  ) async {
    await _ensureRealtimeReady();
    final joined = await _joinThreadRealtime(threadId);
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
        final isSuccess = DateTime.now().millisecond % 20 != 0;

        messages[index] = messages[index].copyWith(
          status: isSuccess ? MessageStatus.sent : MessageStatus.failed,
        );
        if (isSuccess) {
          _recordDeliverySuccess(MessageType.image, messageId);
        } else {
          _recordDeliveryFailure(MessageType.image, messageId);
        }
        notifyListeners();

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
      _recordDeliverySuccess(MessageType.image, localMessageId);
    } else {
      messages[index] = messages[index].copyWith(status: MessageStatus.failed);
      _recordDeliveryFailure(MessageType.image, localMessageId);
    }
    notifyListeners();
  }

  void markImageAsRead(String threadId, String messageId) {
    threadId = _resolveThreadId(threadId);
    final messages = _messages[threadId];
    if (messages != null) {
      final index = messages.indexWhere((msg) => msg.id == messageId);
      if (index != -1) {
        final message = messages[index];
        if (message.isBurnAfterReading && !message.isRead) {
          messages[index] = message.copyWith(isRead: true);
          final remainingUnread = _countUnreadIncomingMessages(
            messages,
            lastReadMessageId: messageId,
          );
          if ((_threads[threadId]?.unreadCount ?? 0) != remainingUnread) {
            _updateThread(threadId,
                unreadCount: remainingUnread, notify: false);
          }
          final readMessageIds = _resolveAutoReadMessageIds(messages);
          if (readMessageIds.isNotEmpty) {
            unawaited(
              NotificationCenterProvider.instance
                  .markThreadNotificationsReadByMessageIds(
                threadId,
                readMessageIds,
              ),
            );
          }
          notifyListeners();
          final lastMessageId = _resolveAutoReadMessageId(messages);
          if (_chatService.hasSession &&
              lastMessageId != null &&
              _lastReadSyncMessageIds[threadId] != lastMessageId) {
            _lastReadSyncMessageIds[threadId] = lastMessageId;
            unawaited(
              _markAsReadRealtime(threadId, lastMessageId: lastMessageId),
            );
          }
        }
      }
    }
  }

  bool canRecallMessage(String threadId, String messageId) {
    threadId = _resolveThreadId(threadId);
    final messages = _messages[threadId];
    if (messages == null) return false;
    final message = messages.cast<Message?>().firstWhere(
          (msg) => msg?.id == messageId,
          orElse: () => null,
        );
    if (message == null || !message.isMe) {
      return false;
    }
    if (message.status != MessageStatus.sent) {
      return false;
    }
    return DateTime.now().difference(message.timestamp).inMinutes < 2;
  }

  bool recallMessage(String threadId, String messageId) {
    threadId = _resolveThreadId(threadId);
    if (!canRecallMessage(threadId, messageId)) {
      return false;
    }

    final messages = _messages[threadId];
    if (messages == null) return false;
    messages.removeWhere((msg) => msg.id == messageId);
    (_recalledMessageIds[threadId] ??= <String>{}).add(messageId);
    notifyListeners();
    unawaited(_chatService.recallMessage(messageId));
    return true;
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

  void _recordDeliverySuccess(MessageType type, String messageId) {
    if (type == MessageType.image) {
      _deliveryStatsService.recordImageSucceeded();
    } else {
      _deliveryStatsService.recordTextSucceeded();
    }
    if (_retryingMessageIds.remove(messageId)) {
      _deliveryStatsService.recordRetrySucceeded();
    }
  }

  void _recordDeliveryFailure(MessageType type, String messageId) {
    if (type == MessageType.image) {
      _deliveryStatsService.recordImageFailed();
    } else {
      _deliveryStatsService.recordTextFailed();
    }
    if (_retryingMessageIds.remove(messageId)) {
      _deliveryStatsService.recordRetryFailed();
    }
  }
}
