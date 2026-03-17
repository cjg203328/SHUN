part of 'chat_provider.dart';

extension ChatProviderRealtime on ChatProvider {
  void _bindRealtime() {
    _chatSocketService.onConnected = (_) {
      _joinedRealtimeThreads.clear();
      _joiningRealtimeThreads.clear();
      _joinKnownThreads();
      final activeThreadId = _activeThreadId;
      if (activeThreadId != null) {
        unawaited(_joinThreadRealtime(activeThreadId));
      }
    };
    _chatSocketService.onMessageAck = _handleMessageAck;
    _chatSocketService.onMessageNew = _handleIncomingMessage;
    _chatSocketService.onPeerRead = (event) {
      _markPeerReadForOutgoing(
        event.threadId,
        lastReadMessageId: event.lastReadMessageId,
      );
    };
    _chatSocketService.onThreadUpdated = (thread) {
      _upsertThread(thread, restoreDeleted: false);
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
    if (!_enableRealtime || !_chatService.hasSession) return;
    final wasConnected = _chatSocketService.isConnected;
    final connected = await _chatSocketService.connect();
    if (connected && !wasConnected) {
      _joinedRealtimeThreads.clear();
      _joiningRealtimeThreads.clear();
    }
    if (connected) {
      _joinKnownThreads();
    }
  }

  void _joinKnownThreads() {
    if (!_chatSocketService.isConnected) return;
    for (final threadId in _threads.keys) {
      unawaited(_joinThreadRealtime(threadId));
    }
  }

  Future<ChatSocketAckResult> _joinThreadRealtimeResult(String threadId) {
    if (_chatSocketService.isConnected &&
        _joinedRealtimeThreads.contains(threadId)) {
      return Future<ChatSocketAckResult>.value(
        const ChatSocketAckResult.success(),
      );
    }

    final ongoing = _joiningRealtimeThreads[threadId];
    if (ongoing != null) {
      return ongoing;
    }

    final future = _chatSocketService.joinThreadResult(threadId).then((result) {
      if (result.isSuccess) {
        _joinedRealtimeThreads.add(threadId);
      }
      return result;
    });
    _joiningRealtimeThreads[threadId] = future;
    return future.whenComplete(() {
      if (identical(_joiningRealtimeThreads[threadId], future)) {
        _joiningRealtimeThreads.remove(threadId);
      }
    });
  }

  Future<bool> _joinThreadRealtime(String threadId) {
    return _joinThreadRealtimeResult(threadId)
        .then((result) => result.isSuccess);
  }

  void _handleMessageAck(MessageAckEvent event) {
    if (_deletedThreads[event.threadId] == true) {
      return;
    }
    if (_isRecalledMessage(event.threadId, event.message.id) ||
        _isRecalledMessage(event.threadId, event.clientMsgId)) {
      return;
    }

    final messages = _messages[event.threadId] ??= <Message>[];
    final index = messages.indexWhere((msg) => msg.id == event.clientMsgId);
    if (index != -1) {
      final previous = messages[index];
      messages[index] = _mergeRemoteMessage(previous, event.message);
      if (previous.status != MessageStatus.sent) {
        _clearDeliveryFailureState(event.threadId, previous.id);
        _addIntimacy(event.threadId, previous.content, true);
        _recordDeliverySuccess(previous.type, previous.id);
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
    if (_isRecalledMessage(event.threadId, event.message.id)) {
      return;
    }

    final messages = _messages[event.threadId] ??= <Message>[];
    final alreadyExists = messages.any((msg) => msg.id == event.message.id);
    if (alreadyExists) {
      restoreThread(event.threadId);
      return;
    }

    if (event.message.isMe) {
      _handleSelfEchoMessage(event.threadId, event.message);
      return;
    }

    messages.add(event.message);
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _addIntimacy(event.threadId, event.message.content, false);

    final hadUnread = (_threads[event.threadId]?.unreadCount ?? 0) > 0;
    restoreThread(event.threadId, notify: false);
    if (_activeThreadId == event.threadId) {
      markAsRead(event.threadId);
      if (!hadUnread) {
        notifyListeners();
      }
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

  void _handleSelfEchoMessage(String threadId, Message remoteMessage) {
    if (_deletedThreads[threadId] == true) {
      return;
    }
    if (_isRecalledMessage(threadId, remoteMessage.id)) {
      return;
    }

    final messages = _messages[threadId] ??= <Message>[];
    final localIndex = _findLocalMessageMatchIndex(
      messages,
      remoteMessage,
      <int>{},
    );

    if (localIndex != -1) {
      final previous = messages[localIndex];
      messages[localIndex] = _mergeRemoteMessage(previous, remoteMessage);
      if (previous.status != MessageStatus.sent) {
        _clearDeliveryFailureState(threadId, previous.id);
        _addIntimacy(threadId, previous.content, true);
        _recordDeliverySuccess(previous.type, previous.id);
      }
    } else if (!messages.any((msg) => msg.id == remoteMessage.id)) {
      messages.add(remoteMessage);
    } else {
      return;
    }

    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    restoreThread(threadId, notify: false);
    notifyListeners();
  }

  bool _isRecalledMessage(String threadId, String? messageId) {
    if (messageId == null || messageId.isEmpty) {
      return false;
    }
    return _recalledMessageIds[threadId]?.contains(messageId) == true;
  }
}
