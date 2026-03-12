part of 'chat_provider.dart';

const Duration _remoteSyncGracePeriod = Duration(minutes: 10);
const Duration _pendingRemoteMatchWindow = Duration(minutes: 2);
const Duration _recentRemoteMessageSyncWindow = Duration(seconds: 3);

extension ChatProviderStorage on ChatProvider {
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
      'recalledMessageIds': _recalledMessageIds.map(
        (key, value) => MapEntry(key, value.toList(growable: false)),
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
    final rawRecalledMessageIds = snapshot['recalledMessageIds'];
    final rawDeletedThreads = snapshot['deletedThreads'];

    _isRestoring = true;
    try {
      _threads.clear();
      _messages.clear();
      _lastMessageTime.clear();
      _recalledMessageIds.clear();
      _deletedThreads.clear();

      if (rawThreads is Map) {
        for (final entry in rawThreads.entries) {
          final key = entry.key.toString();
          final value = entry.value;
          if (value is! Map) continue;
          final threadJson = value.map((k, v) => MapEntry(k.toString(), v));
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

      if (rawRecalledMessageIds is Map) {
        for (final entry in rawRecalledMessageIds.entries) {
          final key = entry.key.toString();
          final value = entry.value;
          if (value is! List) continue;
          _recalledMessageIds[key] = value
              .map((item) => item?.toString())
              .whereType<String>()
              .where((item) => item.isNotEmpty)
              .toSet();
        }
      }

      if (rawDeletedThreads is Map) {
        for (final entry in rawDeletedThreads.entries) {
          _deletedThreads[entry.key.toString()] = entry.value == true;
        }
      }

      for (final threadId in _threads.keys) {
        _messages.putIfAbsent(threadId, () => <Message>[]);
        _recalledMessageIds.putIfAbsent(threadId, () => <String>{});
        _deletedThreads.putIfAbsent(threadId, () => false);
      }
    } finally {
      _isRestoring = false;
    }

    if (_threads.isNotEmpty) {
      notifyListeners();
    }
  }

  Future<void> _hydrateRemote() async {
    await _ensureRealtimeReady();
    final snapshot = await _chatService.loadThreadHydrationSnapshot();
    if (snapshot == null) return;

    final remoteThreads = snapshot.threads;
    final remoteThreadIds = remoteThreads
        .map((thread) => thread.id)
        .toSet();
    final staleRemoteThreadIds = _threads.keys
        .where(
          (threadId) =>
              _isRemoteThreadId(threadId) &&
              _deletedThreads[threadId] != true &&
              !remoteThreadIds.contains(threadId) &&
              _canPruneStaleRemoteThread(threadId),
        )
        .toList(growable: false);

    for (final threadId in staleRemoteThreadIds) {
      _removeThreadState(threadId);
    }

    final mergedThreadIds = <String>[];
    _isRestoring = true;
    try {
      for (final thread in remoteThreads) {
        final mergedThread = _upsertThread(
          thread,
          notify: false,
          restoreDeleted: false,
        );
        mergedThreadIds.add(mergedThread.id);
      }
    } finally {
      _isRestoring = false;
    }

    for (final threadId in mergedThreadIds) {
      if (_deletedThreads[threadId] == true) {
        continue;
      }
      unawaited(_loadMessagesRemote(threadId));
    }
    _joinKnownThreads();
    notifyListeners();
  }

  Future<void> refreshFromRemote() async {
    await _hydrateRemote();
  }

  Future<void> _loadMessagesRemote(String threadId) async {
    final ongoing = _remoteMessageLoads[threadId];
    if (ongoing != null) {
      return ongoing;
    }

    final future = _loadMessagesRemoteInternal(threadId);
    _remoteMessageLoads[threadId] = future;
    try {
      await future;
    } finally {
      if (identical(_remoteMessageLoads[threadId], future)) {
        _remoteMessageLoads.remove(threadId);
      }
    }
  }

  Future<void> _loadMessagesRemoteInternal(String threadId) async {
    final remoteMessages = await _chatService.loadMessages(threadId);
    if (!_threads.containsKey(threadId)) return;
    if (_deletedThreads[threadId] == true) {
      return;
    }
    final recalledIds = _recalledMessageIds[threadId] ?? const <String>{};
    final localMessages = _messages[threadId] ?? const <Message>[];
    final consumedLocalIndexes = <int>{};
    final mergedMessages = <Message>[];

    for (final remoteMessage in remoteMessages) {
      if (recalledIds.contains(remoteMessage.id)) {
        continue;
      }
      final localIndex = _findLocalMessageMatchIndex(
        localMessages,
        remoteMessage,
        consumedLocalIndexes,
      );
      if (localIndex == -1) {
        mergedMessages.add(remoteMessage);
        continue;
      }

      consumedLocalIndexes.add(localIndex);
      mergedMessages.add(
        _mergeRemoteMessage(localMessages[localIndex], remoteMessage),
      );
    }

    final retainedLocalMessages = localMessages
        .asMap()
        .entries
        .where(
          (entry) =>
              _shouldRetainLocalMessageDuringHydration(entry.value) &&
              !consumedLocalIndexes.contains(entry.key),
        )
        .map((entry) => entry.value)
        .toList(growable: false);
    for (final pending in retainedLocalMessages) {
      final exists = mergedMessages.any(
        (msg) => _isSameMessage(msg, pending),
      );
      if (!exists) {
        mergedMessages.add(pending);
      }
    }
    mergedMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _messages[threadId] = mergedMessages;
    _lastRemoteMessageSyncAt[threadId] = DateTime.now();
    notifyListeners();
  }

  void _removeThreadState(String threadId) {
    _threads.remove(threadId);
    _messages.remove(threadId);
    _lastMessageTime.remove(threadId);
    _lastRemoteMessageSyncAt.remove(threadId);
    _recentImageSubmitAt.remove(threadId);
    _recalledMessageIds.remove(threadId);
    _deletedThreads.remove(threadId);
    _remoteMessageLoads.remove(threadId);
    _lastReadSyncMessageIds.remove(threadId);
    _activeThreadClaims.remove(threadId);
    _activeThreadFocusOrder.remove(threadId);
    _joinedRealtimeThreads.remove(threadId);
    _joiningRealtimeThreads.remove(threadId);
    _threadIdAliases.remove(threadId);
    for (final alias in _threadIdAliases.keys.toList(growable: false)) {
      if (_threadIdAliases[alias] == threadId) {
        _threadIdAliases.remove(alias);
      }
    }
    if (_activeThreadId == threadId) {
      _activeThreadId = _activeThreadFocusOrder.isNotEmpty
          ? _activeThreadFocusOrder.last
          : null;
    }
    unawaited(
      NotificationCenterProvider.instance.removeThreadNotifications(threadId),
    );
  }

  bool _canPruneStaleRemoteThread(String threadId) {
    final thread = _threads[threadId];
    if (thread == null) {
      return true;
    }
    return DateTime.now().difference(_lastActivityAt(thread)) >
        _remoteSyncGracePeriod;
  }

  int _findLocalMessageMatchIndex(
    List<Message> localMessages,
    Message remoteMessage,
    Set<int> consumedLocalIndexes,
  ) {
    var fallbackIndex = -1;
    var fallbackDelta = _pendingRemoteMatchWindow + const Duration(seconds: 1);

    for (var i = 0; i < localMessages.length; i++) {
      if (consumedLocalIndexes.contains(i)) continue;
      final localMessage = localMessages[i];
      if (_isSameMessage(localMessage, remoteMessage)) {
        return i;
      }

      if (!_canTreatAsRemoteResolution(localMessage, remoteMessage)) {
        continue;
      }

      final delta = _timestampDelta(localMessage, remoteMessage);
      if (delta <= _pendingRemoteMatchWindow && delta < fallbackDelta) {
        fallbackIndex = i;
        fallbackDelta = delta;
      }
    }
    return fallbackIndex;
  }

  bool _isSameMessage(Message left, Message right) {
    return left.id == right.id ||
        (left.timestamp == right.timestamp &&
            left.content == right.content &&
            left.isMe == right.isMe);
  }

  bool _canTreatAsRemoteResolution(
      Message localMessage, Message remoteMessage) {
    if (localMessage.isMe != remoteMessage.isMe || !localMessage.isMe) {
      return false;
    }
    if (localMessage.status == MessageStatus.sent) {
      return false;
    }
    if (remoteMessage.status != MessageStatus.sent) {
      return false;
    }
    if (localMessage.type != remoteMessage.type) {
      return false;
    }
    if (localMessage.content != remoteMessage.content) {
      return false;
    }
    if (!_hasMatchingResolutionFingerprint(localMessage, remoteMessage)) {
      return false;
    }
    return true;
  }

  bool _hasMatchingResolutionFingerprint(
    Message localMessage,
    Message remoteMessage,
  ) {
    if (localMessage.type != MessageType.image) {
      return true;
    }

    return localMessage.isBurnAfterReading == remoteMessage.isBurnAfterReading &&
        localMessage.imageQuality == remoteMessage.imageQuality;
  }

  Duration _timestampDelta(Message left, Message right) {
    final difference = left.timestamp.difference(right.timestamp);
    return difference.isNegative ? difference.abs() : difference;
  }

  bool _shouldRetainLocalMessageDuringHydration(Message message) {
    if (message.status != MessageStatus.sent) {
      return true;
    }
    if (!message.isMe) {
      return false;
    }
    return DateTime.now().difference(message.timestamp) <=
        _remoteSyncGracePeriod;
  }
}
