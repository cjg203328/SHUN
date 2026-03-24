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

    final previousOutgoingDeliveryFingerprint =
        _threadOutgoingDeliveryFingerprint(threadId);
    final previousFingerprint = _threadListPresentationFingerprint(threadId);
    _messages[threadId]?.add(message);
    _markThreadInteractionChanged(threadId);
    _markThreadOutgoingDeliveryDirtyIfChanged(
      threadId,
      previousOutgoingDeliveryFingerprint,
    );
    _markThreadListPresentationDirtyIfChanged(threadId, previousFingerprint);

    if (thread.isUnfollowed) {
      _updateThread(
        threadId,
        messagesSinceUnfollow: thread.messagesSinceUnfollow + 1,
        notify: false,
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
    final joinResult = await _joinThreadRealtimeResult(threadId);
    if (joinResult.shouldFallbackToHttp) {
      await _sendMessageRemote(threadId, localMessageId, content);
      return;
    }
    if (!joinResult.isSuccess) {
      _markMessageFailed(
        threadId,
        localMessageId,
        failureState: _deliveryFailureStateFromRequestFailure(joinResult.error),
      );
      return;
    }

    final socketResult = await _chatSocketService.sendTextResult(
      threadId: threadId,
      content: content,
      clientMsgId: localMessageId,
    );
    if (socketResult.isSuccess) {
      return;
    }
    if (socketResult.shouldFallbackToHttp) {
      await _sendMessageRemote(threadId, localMessageId, content);
      return;
    }

    _markMessageFailed(
      threadId,
      localMessageId,
      failureState: _deliveryFailureStateFromRequestFailure(socketResult.error),
    );
  }

  Future<void> _sendMessageRemote(
    String threadId,
    String localMessageId,
    String content,
  ) async {
    final result = await _chatService.sendTextMessageResult(
      threadId,
      content,
      localMessageId,
    );

    final messages = _messages[threadId];
    if (messages == null) return;
    final index = messages.indexWhere((msg) => msg.id == localMessageId);
    if (index == -1) return;

    final remoteMessage = result.data;
    if (remoteMessage != null) {
      final previousOutgoingDeliveryFingerprint =
          _threadOutgoingDeliveryFingerprint(threadId);
      final previousFingerprint = _threadListPresentationFingerprint(threadId);
      messages[index] = remoteMessage;
      _clearDeliveryFailureState(threadId, localMessageId);
      _markThreadInteractionChanged(threadId);
      _markThreadOutgoingDeliveryDirtyIfChanged(
        threadId,
        previousOutgoingDeliveryFingerprint,
      );
      _markThreadListPresentationDirtyIfChanged(threadId, previousFingerprint);
      _addIntimacy(threadId, content, true, notify: false);
      _recordDeliverySuccess(MessageType.text, localMessageId);
      notifyListeners();
      return;
    }

    _markMessageFailed(
      threadId,
      localMessageId,
      failureState: _deliveryFailureStateFromRequestFailure(result.error),
    );
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
        final previousOutgoingDeliveryFingerprint =
            _threadOutgoingDeliveryFingerprint(threadId);

        messages[index] = messages[index].copyWith(
          status: isSuccess ? MessageStatus.sent : MessageStatus.failed,
        );
        if (isSuccess) {
          _clearDeliveryFailureState(threadId, messageId);
          _recordDeliverySuccess(MessageType.text, messageId);
        } else {
          _clearDeliveryFailureState(threadId, messageId);
          _recordDeliveryFailure(MessageType.text, messageId);
        }
        _markThreadInteractionChanged(threadId);
        _markThreadOutgoingDeliveryDirtyIfChanged(
          threadId,
          previousOutgoingDeliveryFingerprint,
        );
        if (isSuccess) {
          _addIntimacy(threadId, content, true, notify: false);
        }
        notifyListeners();

        if (isSuccess) {
          _mockReply(threadId);
        }
      }
    }
  }

  void _addIntimacy(
    String threadId,
    String content,
    bool isSend, {
    bool notify = false,
  }) {
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
    _updateThread(threadId, intimacyPoints: newPoints, notify: notify);
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

  ChatDeliveryFailureState deliveryFailureStateFor(
    String threadId,
    String messageId,
  ) {
    threadId = _resolveThreadId(threadId);
    final messages = _messages[threadId];
    if (messages == null) {
      return ChatDeliveryFailureState.retryUnavailable;
    }

    final message = messages.cast<Message?>().firstWhere(
          (msg) => msg?.id == messageId,
          orElse: () => null,
        );
    if (message == null) {
      return ChatDeliveryFailureState.retryable;
    }

    return _deliveryFailureStateForMessage(threadId, message);
  }

  ChatDeliveryFailureState deliveryFailureStateForMessage(
    String threadId,
    Message message,
  ) {
    return _deliveryFailureStateForMessage(threadId, message);
  }

  ChatDeliveryFailureState _deliveryFailureStateForMessage(
    String threadId,
    Message message,
  ) {
    threadId = _resolveThreadId(threadId);
    if (!message.isMe || message.status != MessageStatus.failed) {
      return ChatDeliveryFailureState.retryable;
    }

    if (_deletedThreads[threadId] ?? false) {
      return ChatDeliveryFailureState.retryUnavailable;
    }

    final thread = _threads[threadId];
    if (thread == null) {
      return ChatDeliveryFailureState.retryUnavailable;
    }

    if (!thread.isFriend && thread.isExpired) {
      return ChatDeliveryFailureState.threadExpired;
    }

    if (message.type == MessageType.image &&
        !_canRetryFailedImageFromLocalPreview(message)) {
      return ChatDeliveryFailureState.imageReselectRequired;
    }

    final cachedFailureState =
        _messageFailureStates[_deliveryFailureKey(threadId, message.id)];
    if (cachedFailureState != null) {
      return cachedFailureState;
    }

    final retryable = message.type == MessageType.image
        ? _canRetryFailedImageMessage(threadId, message)
        : canResendMessage(threadId, message.id);
    return retryable
        ? ChatDeliveryFailureState.retryable
        : ChatDeliveryFailureState.retryUnavailable;
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

    if (!_canRetryFailedImageFromLocalPreview(message)) {
      _deliveryStatsService.recordImageReselectRequired();
      return false;
    }
    final imagePath = message.imagePath!.trim();
    final imageFile = File(imagePath);

    _deliveryStatsService.recordRetryRequested();
    _retryingMessageIds.add(messageId);
    final previousOutgoingDeliveryFingerprint =
        _threadOutgoingDeliveryFingerprint(threadId);
    _clearDeliveryFailureState(threadId, messageId);
    messages[index] = message.copyWith(status: MessageStatus.sending);
    _markThreadInteractionChanged(threadId);
    _markThreadOutgoingDeliveryDirtyIfChanged(
      threadId,
      previousOutgoingDeliveryFingerprint,
    );
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

  bool _canRetryFailedImageMessage(String threadId, Message message) {
    final thread = _getSendableThread(
      threadId,
      requireImagePermission: true,
    );
    if (thread == null) {
      return false;
    }
    if (!message.isMe ||
        message.status != MessageStatus.failed ||
        message.type != MessageType.image) {
      return false;
    }
    return _canRetryFailedImageFromLocalPreview(message);
  }

  bool _canRetryFailedImageFromLocalPreview(Message message) {
    if (message.type != MessageType.image) {
      return false;
    }
    return canRetryImageFromLocalPreview(message.imagePath);
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
    final previousOutgoingDeliveryFingerprint =
        _threadOutgoingDeliveryFingerprint(threadId);
    _clearDeliveryFailureState(threadId, messageId);
    messages[index] = messages[index].copyWith(
      status: MessageStatus.sending,
    );
    _markThreadInteractionChanged(threadId);
    _markThreadOutgoingDeliveryDirtyIfChanged(
      threadId,
      previousOutgoingDeliveryFingerprint,
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

  void _markMessageFailed(
    String threadId,
    String messageId, {
    ChatDeliveryFailureState? failureState,
  }) {
    threadId = _resolveThreadId(threadId);
    final messages = _messages[threadId];
    if (messages == null) return;
    final index = messages.indexWhere((msg) => msg.id == messageId);
    if (index == -1) return;
    final previousOutgoingDeliveryFingerprint =
        _threadOutgoingDeliveryFingerprint(threadId);
    final message = messages[index];
    messages[index] = message.copyWith(status: MessageStatus.failed);
    if (failureState != null) {
      _setDeliveryFailureState(threadId, messageId, failureState);
    } else {
      _clearDeliveryFailureState(threadId, messageId);
    }
    _recordDeliveryFailure(message.type, messageId);
    _markThreadInteractionChanged(threadId);
    _markThreadOutgoingDeliveryDirtyIfChanged(
      threadId,
      previousOutgoingDeliveryFingerprint,
    );
    notifyListeners();
  }

  ChatDeliveryFailureState _deliveryFailureStateFromRequestFailure(
    ChatRequestFailure? failure,
  ) {
    switch (failure?.code) {
      case 'THREAD_EXPIRED':
        return ChatDeliveryFailureState.threadExpired;
      case 'BLOCKED_RELATION':
      case 'USER_BLOCKED':
        return ChatDeliveryFailureState.blockedRelation;
      case 'UPLOAD_TOKEN_INVALID':
        return ChatDeliveryFailureState.imageUploadTokenInvalid;
      case 'IMAGE_UPLOAD_TOO_LARGE':
        return ChatDeliveryFailureState.imageUploadFileTooLarge;
      case 'IMAGE_UPLOAD_UNSUPPORTED_FORMAT':
        return ChatDeliveryFailureState.imageUploadUnsupportedFormat;
      case 'NETWORK_ERROR':
      case 'SOCKET_TRANSPORT_ERROR':
      case 'SERVICE_UNAVAILABLE':
      case 'RATE_LIMITED':
      case 'UPLOAD_TOKEN_FAILED':
        return ChatDeliveryFailureState.networkIssue;
      case 'AUTH_TOKEN_INVALID':
      case 'AUTH_TOKEN_EXPIRED':
      case 'THREAD_NOT_FOUND':
      case 'POLICY_UNLOCK_REQUIRED':
        return ChatDeliveryFailureState.retryUnavailable;
      default:
        return ChatDeliveryFailureState.retryable;
    }
  }

  ChatDeliveryFailureState
      _deliveryFailureStateFromImageUploadPreparationResult(
    ChatImageUploadPreparationResult result,
  ) {
    final requestState = _deliveryFailureStateFromRequestFailure(result.error);
    if (requestState == ChatDeliveryFailureState.threadExpired ||
        requestState == ChatDeliveryFailureState.blockedRelation ||
        requestState == ChatDeliveryFailureState.retryUnavailable ||
        requestState == ChatDeliveryFailureState.imageUploadTokenInvalid ||
        requestState == ChatDeliveryFailureState.imageUploadFileTooLarge ||
        requestState == ChatDeliveryFailureState.imageUploadUnsupportedFormat) {
      return requestState;
    }

    switch (result.stage) {
      case ChatImageUploadFailureStage.token:
        return ChatDeliveryFailureState.imageUploadPreparationFailed;
      case ChatImageUploadFailureStage.upload:
        return ChatDeliveryFailureState.imageUploadInterrupted;
      case null:
        return requestState;
    }
  }

  Future<void> _mockReply(String threadId) async {
    await Future.delayed(const Duration(seconds: 2));

    final content = _chatService.getMockReply();
    final isActiveThread = _activeThreadId == threadId;
    final hadUnread = (_threads[threadId]?.unreadCount ?? 0) > 0;
    final previousFingerprint = _threadListPresentationFingerprint(threadId);
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
    _markThreadInteractionChanged(threadId);
    _markThreadListPresentationDirtyIfChanged(threadId, previousFingerprint);
    _addIntimacy(threadId, content, false, notify: false);

    if (isActiveThread) {
      markAsRead(threadId);
      if (!hadUnread) {
        notifyListeners();
      }
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
      _markThreadInteractionChanged(threadId);
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
        final previousSyncedMessageId = _lastReadSyncMessageIds[threadId];
        _lastReadSyncMessageIds[threadId] = lastMessageId;
        unawaited(
          _markAsReadRealtime(
            threadId,
            lastMessageId: lastMessageId,
            previousSyncedMessageId: previousSyncedMessageId,
          ),
        );
      }
    }
  }

  Future<void> _markAsReadRealtime(
    String threadId, {
    String? lastMessageId,
    String? previousSyncedMessageId,
  }) async {
    await _ensureRealtimeReady();
    final joinResult = await _joinThreadRealtimeResult(threadId);
    if (!joinResult.isSuccess) {
      if (joinResult.shouldFallbackToHttp) {
        final fallbackResult = await _chatService.markThreadReadResult(
          threadId,
          lastReadMessageId: lastMessageId,
        );
        if (fallbackResult.isSuccess) {
          return;
        }
      }
      _restoreLastReadSyncState(
        threadId,
        attemptedMessageId: lastMessageId,
        previousSyncedMessageId: previousSyncedMessageId,
      );
      return;
    }

    final markReadResult = await _chatSocketService.markReadResult(
      threadId,
      lastReadMessageId: lastMessageId,
    );
    if (markReadResult.isSuccess) {
      return;
    }
    if (markReadResult.shouldFallbackToHttp) {
      final fallbackResult = await _chatService.markThreadReadResult(
        threadId,
        lastReadMessageId: lastMessageId,
      );
      if (fallbackResult.isSuccess) {
        return;
      }
    }

    _restoreLastReadSyncState(
      threadId,
      attemptedMessageId: lastMessageId,
      previousSyncedMessageId: previousSyncedMessageId,
    );
  }

  void _restoreLastReadSyncState(
    String threadId, {
    String? attemptedMessageId,
    String? previousSyncedMessageId,
  }) {
    if (attemptedMessageId == null ||
        _lastReadSyncMessageIds[threadId] != attemptedMessageId) {
      return;
    }
    if (previousSyncedMessageId == null) {
      _lastReadSyncMessageIds.remove(threadId);
      return;
    }
    _lastReadSyncMessageIds[threadId] = previousSyncedMessageId;
  }

  void _markPeerReadForOutgoing(
    String threadId, {
    String? lastReadMessageId,
  }) {
    final messages = _messages[threadId];
    if (messages == null || messages.isEmpty) return;
    final previousOutgoingDeliveryFingerprint =
        _threadOutgoingDeliveryFingerprint(threadId);

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
      _markThreadInteractionChanged(threadId);
      _markThreadOutgoingDeliveryDirtyIfChanged(
        threadId,
        previousOutgoingDeliveryFingerprint,
      );
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

      final previousOutgoingDeliveryFingerprint =
          _threadOutgoingDeliveryFingerprint(threadId);
      final previousFingerprint = _threadListPresentationFingerprint(threadId);
      _messages[threadId]?.add(message);
      _markThreadInteractionChanged(threadId);
      _markThreadOutgoingDeliveryDirtyIfChanged(
        threadId,
        previousOutgoingDeliveryFingerprint,
      );
      _markThreadListPresentationDirtyIfChanged(threadId, previousFingerprint);

      if (latestThread.isUnfollowed) {
        _updateThread(
          threadId,
          messagesSinceUnfollow: latestThread.messagesSinceUnfollow + 1,
          notify: false,
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

    final preparedUploadResult =
        await _mediaUploadService.prepareChatImageUploadResult(
      resolvedThreadId,
      compressedImage,
    );
    final preparedUpload = preparedUploadResult.data;
    if (_getSendableThread(resolvedThreadId, requireImagePermission: true) ==
        null) {
      _markMessageFailed(resolvedThreadId, localMessageId);
      return;
    }
    if (preparedUpload == null) {
      _markMessageFailed(
        resolvedThreadId,
        localMessageId,
        failureState: _deliveryFailureStateFromImageUploadPreparationResult(
          preparedUploadResult,
        ),
      );
      return;
    }
    if (_chatService.hasSession && !preparedUpload.isRemotePrepared) {
      _markMessageFailed(
        resolvedThreadId,
        localMessageId,
        failureState: ChatDeliveryFailureState.imageUploadPreparationFailed,
      );
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
    final joinResult = await _joinThreadRealtimeResult(threadId);
    if (joinResult.shouldFallbackToHttp) {
      await _sendImageMessageRemote(
        threadId,
        localMessageId,
        imageKey,
        burnAfterReading,
      );
      return;
    }
    if (!joinResult.isSuccess) {
      _markMessageFailed(
        threadId,
        localMessageId,
        failureState: _deliveryFailureStateFromRequestFailure(joinResult.error),
      );
      return;
    }

    final socketResult = await _chatSocketService.sendImageResult(
      threadId: threadId,
      imageKey: imageKey,
      burnAfterReading: burnAfterReading,
      clientMsgId: localMessageId,
    );
    if (socketResult.isSuccess) {
      return;
    }
    if (socketResult.shouldFallbackToHttp) {
      await _sendImageMessageRemote(
        threadId,
        localMessageId,
        imageKey,
        burnAfterReading,
      );
      return;
    }

    _markMessageFailed(
      threadId,
      localMessageId,
      failureState: _deliveryFailureStateFromRequestFailure(socketResult.error),
    );
  }

  Future<void> _simulateSendImage(String threadId, String messageId) async {
    await Future.delayed(const Duration(seconds: 1));

    final messages = _messages[threadId];
    if (messages != null) {
      final index = messages.indexWhere((msg) => msg.id == messageId);
      if (index != -1) {
        final isSuccess = DateTime.now().millisecond % 20 != 0;
        final previousOutgoingDeliveryFingerprint =
            _threadOutgoingDeliveryFingerprint(threadId);

        messages[index] = messages[index].copyWith(
          status: isSuccess ? MessageStatus.sent : MessageStatus.failed,
        );
        if (isSuccess) {
          _clearDeliveryFailureState(threadId, messageId);
          _recordDeliverySuccess(MessageType.image, messageId);
        } else {
          _clearDeliveryFailureState(threadId, messageId);
          _recordDeliveryFailure(MessageType.image, messageId);
        }
        _markThreadInteractionChanged(threadId);
        _markThreadOutgoingDeliveryDirtyIfChanged(
          threadId,
          previousOutgoingDeliveryFingerprint,
        );
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
    final result = await _chatService.sendImageMessageResult(
      threadId,
      imageKey,
      burnAfterReading,
      localMessageId,
    );

    final messages = _messages[threadId];
    if (messages == null) return;
    final index = messages.indexWhere((msg) => msg.id == localMessageId);
    if (index == -1) return;

    final remoteMessage = result.data;
    if (remoteMessage != null) {
      final previousOutgoingDeliveryFingerprint =
          _threadOutgoingDeliveryFingerprint(threadId);
      final previousFingerprint = _threadListPresentationFingerprint(threadId);
      messages[index] = _mergeRemoteMessage(messages[index], remoteMessage);
      _clearDeliveryFailureState(threadId, localMessageId);
      _markThreadInteractionChanged(threadId);
      _markThreadOutgoingDeliveryDirtyIfChanged(
        threadId,
        previousOutgoingDeliveryFingerprint,
      );
      _markThreadListPresentationDirtyIfChanged(threadId, previousFingerprint);
      _addIntimacy(threadId, '[图片]', true);
      _recordDeliverySuccess(MessageType.image, localMessageId);
      notifyListeners();
      return;
    }

    _markMessageFailed(
      threadId,
      localMessageId,
      failureState: _deliveryFailureStateFromRequestFailure(result.error),
    );
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
          _markThreadInteractionChanged(threadId);
          notifyListeners();
          final lastMessageId = _resolveAutoReadMessageId(messages);
          if (_chatService.hasSession &&
              lastMessageId != null &&
              _lastReadSyncMessageIds[threadId] != lastMessageId) {
            final previousSyncedMessageId = _lastReadSyncMessageIds[threadId];
            _lastReadSyncMessageIds[threadId] = lastMessageId;
            unawaited(
              _markAsReadRealtime(
                threadId,
                lastMessageId: lastMessageId,
                previousSyncedMessageId: previousSyncedMessageId,
              ),
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
    final previousFingerprint = _threadListPresentationFingerprint(threadId);
    messages.removeWhere((msg) => msg.id == messageId);
    _clearDeliveryFailureState(threadId, messageId);
    (_recalledMessageIds[threadId] ??= <String>{}).add(messageId);
    _markThreadInteractionChanged(threadId);
    _markThreadListPresentationDirtyIfChanged(threadId, previousFingerprint);
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
