part of 'chat_provider.dart';

extension ChatProviderThreads on ChatProvider {
  void setActiveThread(String threadId) {
    threadId = _resolveThreadId(threadId);
    final hadClaim = (_activeThreadClaims[threadId] ?? 0) > 0;
    _activeThreadClaims[threadId] = (_activeThreadClaims[threadId] ?? 0) + 1;
    _activeThreadFocusOrder.remove(threadId);
    _activeThreadFocusOrder.add(threadId);
    if (_activeThreadId == threadId && hadClaim) {
      return;
    }
    _activateThread(threadId);
  }

  void _activateThread(String threadId) {
    _activeThreadId = threadId;
    markAsRead(threadId);
    unawaited(_joinThreadRealtime(threadId));
    if (_shouldRefreshThreadMessages(threadId)) {
      unawaited(_loadMessagesRemote(threadId));
    }
  }

  void clearActiveThread(String threadId) {
    threadId = _resolveThreadId(threadId);
    final claimCount = _activeThreadClaims[threadId] ?? 0;
    if (claimCount <= 1) {
      _activeThreadClaims.remove(threadId);
      _activeThreadFocusOrder.remove(threadId);
    } else {
      _activeThreadClaims[threadId] = claimCount - 1;
    }

    if (_activeThreadId != threadId) {
      return;
    }
    if ((_activeThreadClaims[threadId] ?? 0) > 0) {
      return;
    }

    final fallbackThreadId = _activeThreadFocusOrder.isNotEmpty
        ? _activeThreadFocusOrder.last
        : null;
    _activeThreadId = fallbackThreadId;
    if (fallbackThreadId != null) {
      _activateThread(fallbackThreadId);
    }
  }

  Future<ChatThread> ensureDirectThreadForUser(
    User user, {
    bool isFriend = false,
  }) async {
    final existingThread = _findThreadByUserId(user.id);
    if (existingThread != null) {
      final previousComposerFingerprint =
          _threadComposerFingerprint(existingThread.id);
      final previousFingerprint =
          _threadListPresentationFingerprint(existingThread.id);
      final previousHeaderFingerprint =
          _threadHeaderFingerprint(existingThread.id);
      _deletedThreads[existingThread.id] = false;
      _markThreadListPresentationDirtyIfChanged(
        existingThread.id,
        previousFingerprint,
      );
      _markThreadComposerDirtyIfChanged(
        existingThread.id,
        previousComposerFingerprint,
      );
      _markThreadHeaderDirtyIfChanged(
        existingThread.id,
        previousHeaderFingerprint,
      );
      if (!_chatService.hasSession || _isRemoteThreadId(existingThread.id)) {
        notifyListeners();
        return existingThread;
      }

      final remoteThread = await _chatService.createDirectThread(user);
      if (remoteThread != null) {
        final mergedThread = _upsertThread(remoteThread);
        unawaited(_joinThreadRealtime(mergedThread.id));
        unawaited(_loadMessagesRemote(mergedThread.id));
        return mergedThread;
      }

      notifyListeners();
      return existingThread;
    }

    final remoteThread = await _chatService.createDirectThread(user);
    if (remoteThread != null) {
      final mergedThread = _upsertThread(remoteThread);
      unawaited(_joinThreadRealtime(mergedThread.id));
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

  ChatThread _upsertThread(
    ChatThread thread, {
    bool notify = true,
    bool restoreDeleted = true,
  }) {
    final previousComposerFingerprint = _threadComposerFingerprint(thread.id);
    final previousFingerprint = _threadListPresentationFingerprint(thread.id);
    final previousHeaderFingerprint = _threadHeaderFingerprint(thread.id);
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
      _deletedThreads[thread.id] =
          restoreDeleted ? false : (_deletedThreads[thread.id] ?? false);
      unawaited(_joinThreadRealtime(thread.id));
      _markThreadInteractionChanged(thread.id);
      _markThreadListPresentationDirtyIfChanged(
        thread.id,
        previousFingerprint,
      );
      _markThreadComposerDirtyIfChanged(thread.id, previousComposerFingerprint);
      _markThreadHeaderDirtyIfChanged(thread.id, previousHeaderFingerprint);
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
      unawaited(_joinThreadRealtime(mergedThread.id));
      if (notify) {
        notifyListeners();
      }
      return mergedThread;
    }

    _threads[thread.id] = thread;
    _messages.putIfAbsent(thread.id, () => <Message>[]);
    _deletedThreads[thread.id] =
        restoreDeleted ? false : (_deletedThreads[thread.id] ?? false);
    unawaited(_joinThreadRealtime(thread.id));
    _markThreadInteractionChanged(thread.id);
    _markThreadListPresentationDirtyIfChanged(
      thread.id,
      previousFingerprint,
    );
    _markThreadComposerDirtyIfChanged(thread.id, previousComposerFingerprint);
    _markThreadHeaderDirtyIfChanged(thread.id, previousHeaderFingerprint);
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
    final previousOutgoingDeliveryFingerprint =
        _threadOutgoingDeliveryFingerprint(newThread.id) ??
            _threadOutgoingDeliveryFingerprint(oldThreadId);
    final oldMessages = _messages.remove(oldThreadId) ?? const <Message>[];
    final mergedMessages = <Message>[
      ...(_messages[newThread.id] ?? const <Message>[]),
    ];

    for (final message in oldMessages) {
      final exists = mergedMessages.any(
        (item) =>
            item.id == message.id ||
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
    final previousLastReadSyncMessageId =
        _lastReadSyncMessageIds.remove(oldThreadId);
    final previousRemoteMessageSyncAt =
        _lastRemoteMessageSyncAt.remove(oldThreadId);
    final previousDraft = _threadDrafts.remove(oldThreadId);
    final previousRecalledMessageIds = _recalledMessageIds.remove(oldThreadId);
    final previousDeleted = _deletedThreads.remove(oldThreadId) ?? false;
    final previousActiveClaims = _activeThreadClaims.remove(oldThreadId);
    _remoteMessageLoads.remove(oldThreadId);
    _joinedRealtimeThreads.remove(oldThreadId);
    _joiningRealtimeThreads.remove(oldThreadId);
    final focusOrderIndex = _activeThreadFocusOrder.indexOf(oldThreadId);
    if (focusOrderIndex != -1) {
      _activeThreadFocusOrder[focusOrderIndex] = newThread.id;
    }

    _threads.remove(oldThreadId);
    _threads[newThread.id] = newThread;
    _threadIdAliases[oldThreadId] = newThread.id;
    _remapDeliveryFailureStates(oldThreadId, newThread.id);
    for (final alias in _threadIdAliases.keys.toList(growable: false)) {
      if (_threadIdAliases[alias] == oldThreadId) {
        _threadIdAliases[alias] = newThread.id;
      }
    }
    _messages[newThread.id] = mergedMessages;
    if (previousActiveClaims != null && previousActiveClaims > 0) {
      _activeThreadClaims[newThread.id] =
          (_activeThreadClaims[newThread.id] ?? 0) + previousActiveClaims;
    }
    if (previousRecalledMessageIds != null &&
        previousRecalledMessageIds.isNotEmpty) {
      _recalledMessageIds
          .putIfAbsent(newThread.id, () => <String>{})
          .addAll(previousRecalledMessageIds);
    }
    _deletedThreads[newThread.id] = previousDeleted;

    if (previousLastMessageTime != null) {
      final existingLastMessageTime = _lastMessageTime[newThread.id];
      if (existingLastMessageTime == null ||
          previousLastMessageTime.isAfter(existingLastMessageTime)) {
        _lastMessageTime[newThread.id] = previousLastMessageTime;
      }
    }
    if (!_lastReadSyncMessageIds.containsKey(newThread.id) &&
        previousLastReadSyncMessageId != null) {
      _lastReadSyncMessageIds[newThread.id] = previousLastReadSyncMessageId;
    }
    if (previousRemoteMessageSyncAt != null) {
      final existingRemoteMessageSyncAt =
          _lastRemoteMessageSyncAt[newThread.id];
      if (existingRemoteMessageSyncAt == null ||
          previousRemoteMessageSyncAt.isAfter(existingRemoteMessageSyncAt)) {
        _lastRemoteMessageSyncAt[newThread.id] = previousRemoteMessageSyncAt;
      }
    }
    if (previousDraft != null && previousDraft.isNotEmpty) {
      final existingDraft = _threadDrafts[newThread.id] ?? '';
      if (existingDraft.isEmpty) {
        _threadDrafts[newThread.id] = previousDraft;
      }
    }

    if (_activeThreadId == oldThreadId) {
      _activeThreadId = newThread.id;
    }
    _threadComposerRevisions.remove(oldThreadId);
    _threadOutgoingDeliveryRevisions.remove(oldThreadId);
    _threadHeaderRevisions.remove(oldThreadId);
    _threadInteractionRevisions.remove(oldThreadId);
    _threadSummaryRevisions.remove(oldThreadId);
    _threadSummaryCache.remove(oldThreadId);
    _markThreadComposerDirty(newThread.id);
    _markThreadOutgoingDeliveryDirtyIfChanged(
      newThread.id,
      previousOutgoingDeliveryFingerprint,
    );
    _markThreadHeaderDirty(newThread.id);
    _markThreadInteractionChanged(newThread.id);
    _markThreadListPresentationDirty();
    unawaited(
      NotificationCenterProvider.instance.remapThreadNotifications(
        fromThreadId: oldThreadId,
        toThread: newThread,
      ),
    );
  }

  void markAsFriend(String threadId) {
    _updateThread(threadId, isFriend: true);
  }

  void handleFriendAccepted(String userId) {
    final threadId = _resolveThreadIdByUserId(userId);
    if (threadId == null) return;
    _updateThread(
      threadId,
      isFriend: true,
      isUnfollowed: false,
      messagesSinceUnfollow: 0,
    );
  }

  void syncFriendRelationships(Set<String> friendUserIds) {
    var changed = false;
    for (final entry in _threads.entries.toList(growable: false)) {
      final threadId = entry.key;
      final thread = entry.value;
      final isFriend = friendUserIds.contains(thread.otherUser.id);
      if (isFriend) {
        if (thread.isFriend &&
            !thread.isUnfollowed &&
            thread.messagesSinceUnfollow == 0) {
          continue;
        }
        _updateThread(
          threadId,
          isFriend: true,
          isUnfollowed: false,
          messagesSinceUnfollow: 0,
          notify: false,
        );
        changed = true;
        continue;
      }

      if (!thread.isFriend) {
        continue;
      }
      _updateThread(
        threadId,
        isFriend: false,
        isUnfollowed: false,
        messagesSinceUnfollow: 0,
        notify: false,
      );
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  void unfollowFriend(String threadId) {
    _updateThread(
      threadId,
      isFriend: false,
      isUnfollowed: true,
      messagesSinceUnfollow: 0,
    );
  }

  void confirmChat(String threadId) {
    _updateThread(
      threadId,
      isUnfollowed: false,
      messagesSinceUnfollow: 0,
    );
  }

  void restoreConversationAfterUnblock(String userId) {
    final threadId = _resolveThreadIdByUserId(userId);
    if (threadId == null) return;
    final thread = _threads[threadId];
    if (thread == null) return;
    final previousComposerFingerprint = _threadComposerFingerprint(threadId);
    final previousFingerprint = _threadListPresentationFingerprint(threadId);
    final previousHeaderFingerprint = _threadHeaderFingerprint(threadId);

    _deletedThreads[threadId] = false;
    _lastRemoteMessageSyncAt.remove(threadId);

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

    _markThreadInteractionChanged(threadId);
    _markThreadComposerDirtyIfChanged(threadId, previousComposerFingerprint);
    _markThreadListPresentationDirtyIfChanged(threadId, previousFingerprint);
    _markThreadHeaderDirtyIfChanged(threadId, previousHeaderFingerprint);
    notifyListeners();
  }

  void handleUserBlocked(String userId) {
    final threadId = _resolveThreadIdByUserId(userId);
    if (threadId == null) return;

    final currentUnread = _threads[threadId]?.unreadCount ?? 0;
    _updateThread(threadId, unreadCount: 0, notify: false);
    if (currentUnread > 0) {
      notifyListeners();
    }
    unawaited(
      NotificationCenterProvider.instance.removeThreadNotifications(threadId),
    );
  }

  void handleFriendRemoved(String userId) {
    final threadId = _resolveThreadIdByUserId(userId);
    if (threadId == null) return;

    _updateThread(
      threadId,
      isFriend: false,
      isUnfollowed: false,
      messagesSinceUnfollow: 0,
    );
  }

  void _updateThread(
    String threadId, {
    int? unreadCount,
    int? intimacyPoints,
    bool? isFriend,
    bool? isUnfollowed,
    int? messagesSinceUnfollow,
    bool notify = true,
  }) {
    threadId = _resolveThreadId(threadId);
    final thread = _threads[threadId];
    if (thread == null) return;
    final previousComposerFingerprint = _threadComposerFingerprint(threadId);
    final previousFingerprint = _threadListPresentationFingerprint(threadId);
    final previousHeaderFingerprint = _threadHeaderFingerprint(threadId);

    final nextUnreadCount = unreadCount ?? thread.unreadCount;
    final nextIntimacyPoints = intimacyPoints ?? thread.intimacyPoints;
    final nextIsFriend = isFriend ?? thread.isFriend;
    final nextIsUnfollowed = isUnfollowed ?? thread.isUnfollowed;
    final nextMessagesSinceUnfollow =
        messagesSinceUnfollow ?? thread.messagesSinceUnfollow;

    if (nextUnreadCount == thread.unreadCount &&
        nextIntimacyPoints == thread.intimacyPoints &&
        nextIsFriend == thread.isFriend &&
        nextIsUnfollowed == thread.isUnfollowed &&
        nextMessagesSinceUnfollow == thread.messagesSinceUnfollow) {
      return;
    }

    _threads[threadId] = ChatThread(
      id: thread.id,
      otherUser: thread.otherUser,
      unreadCount: nextUnreadCount,
      createdAt: thread.createdAt,
      expiresAt: thread.expiresAt,
      intimacyPoints: nextIntimacyPoints,
      isFriend: nextIsFriend,
      isUnfollowed: nextIsUnfollowed,
      messagesSinceUnfollow: nextMessagesSinceUnfollow,
    );
    _markThreadInteractionChanged(threadId);
    _markThreadComposerDirtyIfChanged(threadId, previousComposerFingerprint);
    _markThreadListPresentationDirtyIfChanged(threadId, previousFingerprint);
    _markThreadHeaderDirtyIfChanged(threadId, previousHeaderFingerprint);
    if (notify) {
      notifyListeners();
    }
  }

  void deleteThread(String threadId) {
    threadId = _resolveThreadId(threadId);
    final previousOutgoingDeliveryFingerprint =
        _threadOutgoingDeliveryFingerprint(threadId);
    final previousFingerprint = _threadListPresentationFingerprint(threadId);
    _messages[threadId] = <Message>[];
    _lastRemoteMessageSyncAt.remove(threadId);
    _updateThread(threadId, unreadCount: 0, notify: false);
    _deletedThreads[threadId] = true;
    _markThreadInteractionChanged(threadId);
    _markThreadOutgoingDeliveryDirtyIfChanged(
      threadId,
      previousOutgoingDeliveryFingerprint,
    );
    _markThreadListPresentationDirtyIfChanged(threadId, previousFingerprint);
    notifyListeners();
    unawaited(
      NotificationCenterProvider.instance.removeThreadNotifications(threadId),
    );
    unawaited(_chatService.deleteThread(threadId));
  }

  bool restoreThread(String threadId, {bool notify = true}) {
    threadId = _resolveThreadId(threadId);
    final previousFingerprint = _threadListPresentationFingerprint(threadId);
    final wasDeleted = _deletedThreads[threadId] ?? false;
    _deletedThreads[threadId] = false;
    _markThreadInteractionChanged(threadId);
    _markThreadListPresentationDirtyIfChanged(threadId, previousFingerprint);
    if (wasDeleted && notify) {
      notifyListeners();
    }
    return wasDeleted;
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

  bool _shouldRefreshThreadMessages(String threadId) {
    final lastSyncedAt = _lastRemoteMessageSyncAt[threadId];
    if (lastSyncedAt == null) {
      return true;
    }
    return DateTime.now().difference(lastSyncedAt) >
        _recentRemoteMessageSyncWindow;
  }
}
