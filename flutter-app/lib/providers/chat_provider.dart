import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../config/app_env.dart';
import '../core/policy/feature_policy.dart';
import '../models/models.dart';
import '../repositories/app_data_repository.dart';
import '../services/analytics_service.dart';
import '../services/chat_service.dart';
import '../services/chat_delivery_stats_service.dart';
import '../services/chat_socket_service.dart';
import '../services/media_upload_service.dart';
import '../utils/chat_delivery_state.dart';
import '../utils/image_helper.dart';
import '../utils/intimacy_system.dart';
import 'notification_center_provider.dart';

part 'chat_provider_messages.dart';
part 'chat_provider_realtime.dart';
part 'chat_provider_storage.dart';
part 'chat_provider_threads.dart';

class ChatProvider extends ChangeNotifier {
  final AppDataRepository _repository;
  final ChatService _chatService;
  final ChatSocketService _chatSocketService;
  final MediaUploadService _mediaUploadService;
  final ChatDeliveryStatsService _deliveryStatsService;
  final Map<String, List<Message>> _messages = {};
  final Map<String, ChatThread> _threads = {};
  final Map<String, String> _threadIdAliases = {};
  final Map<String, DateTime> _lastMessageTime = {};
  final Map<String, DateTime> _lastRemoteMessageSyncAt = {};
  final Map<String, DateTime> _recentImageSubmitAt = {};
  final Map<String, String> _threadDrafts = {};
  final Map<String, Set<String>> _recalledMessageIds = {};
  final Map<String, bool> _deletedThreads = {};
  final Map<String, Future<void>> _remoteMessageLoads = {};
  final Map<String, String?> _lastReadSyncMessageIds = {};
  final Map<String, int> _activeThreadClaims = {};
  final List<String> _activeThreadFocusOrder = <String>[];
  final Set<String> _joinedRealtimeThreads = <String>{};
  final Map<String, Future<ChatSocketAckResult>> _joiningRealtimeThreads = {};
  final Set<String> _retryingMessageIds = <String>{};
  final Map<String, ChatDeliveryFailureState> _messageFailureStates = {};
  final Set<String> _pinnedThreadIds = <String>{};
  List<String>? _sortedVisibleThreadIdsCache;
  final Map<String, ChatThreadSummarySnapshot> _threadSummaryCache = {};
  final Map<String, int> _threadSummaryRevisions = {};
  final Map<String, int> _threadComposerRevisions = {};
  final Map<String, int> _threadOutgoingDeliveryRevisions = {};
  final Map<String, int> _threadHeaderRevisions = {};
  int _threadListPresentationRevision = 0;
  final Map<String, int> _threadInteractionRevisions = {};
  final bool _enableRealtime;
  final bool _enableRemoteHydration;
  String? _activeThreadId;
  Timer? _persistTimer;
  bool _persistInFlight = false;
  bool _persistRequestedWhileInFlight = false;
  bool _isRestoring = false;
  bool _isDisposed = false;
  bool _skipPersistForNextNotify = false;

  ChatProvider({
    AppDataRepository? repository,
    ChatService? chatService,
    ChatSocketService? chatSocketService,
    MediaUploadService? mediaUploadService,
    ChatDeliveryStatsService? deliveryStatsService,
    bool enableRealtime = true,
    bool enableRemoteHydration = true,
  })  : _repository = repository ?? AppDataRepository.instance,
        _chatService = chatService ?? ChatService(),
        _chatSocketService = chatSocketService ?? ChatSocketService.instance,
        _mediaUploadService = mediaUploadService ?? MediaUploadService(),
        _deliveryStatsService =
            deliveryStatsService ?? ChatDeliveryStatsService(),
        _enableRealtime = enableRealtime,
        _enableRemoteHydration = enableRemoteHydration {
    if (_enableRealtime) {
      _bindRealtime();
    }
    _restoreFromStorage();
    if (_enableRemoteHydration) {
      unawaited(_hydrateRemote());
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _persistTimer?.cancel();
    if (_enableRealtime) {
      _unbindRealtime();
    }
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_isDisposed) {
      return;
    }
    final skipPersist = _skipPersistForNextNotify;
    _skipPersistForNextNotify = false;
    super.notifyListeners();
    if (_isRestoring || skipPersist) return;
    _schedulePersist();
  }

  void _notifyListeners({bool persist = true}) {
    if (!persist) {
      _skipPersistForNextNotify = true;
    }
    notifyListeners();
  }

  int get threadListPresentationRevision => _threadListPresentationRevision;

  int threadSummaryRevision(String threadId) {
    return _threadSummaryRevisions[_resolveThreadId(threadId)] ?? 0;
  }

  int threadComposerRevision(String threadId) {
    return _threadComposerRevisions[_resolveThreadId(threadId)] ?? 0;
  }

  int threadOutgoingDeliveryRevision(String threadId) {
    return _threadOutgoingDeliveryRevisions[_resolveThreadId(threadId)] ?? 0;
  }

  int threadHeaderRevision(String threadId) {
    return _threadHeaderRevisions[_resolveThreadId(threadId)] ?? 0;
  }

  int threadInteractionRevision(String threadId) {
    return _threadInteractionRevisions[_resolveThreadId(threadId)] ?? 0;
  }

  Map<String, ChatThread> get threads {
    return Map.fromEntries(
      _threads.entries.where(
        (entry) => _isVisibleThread(entry.key, entry.value),
      ),
    );
  }

  List<ChatThread> get sortedThreads {
    final items = _sortedVisibleThreadIds
        .map((threadId) => _threads[threadId])
        .whereType<ChatThread>()
        .toList(growable: false);
    if (items.length <= 1) {
      return items;
    }
    return items;
  }

  List<String> get _sortedVisibleThreadIds {
    final cached = _sortedVisibleThreadIdsCache;
    if (cached != null) {
      return cached;
    }

    final items = _threads.entries
        .where((entry) => _isVisibleThread(entry.key, entry.value))
        .map((entry) => entry.value)
        .toList();
    items.sort((a, b) {
      final aPinned = _pinnedThreadIds.contains(a.id) ? 0 : 1;
      final bPinned = _pinnedThreadIds.contains(b.id) ? 0 : 1;
      if (aPinned != bPinned) return aPinned - bPinned;
      final compare = _lastActivityAt(b).compareTo(_lastActivityAt(a));
      if (compare != 0) return compare;
      return b.createdAt.compareTo(a.createdAt);
    });
    final sortedIds = List<String>.unmodifiable(
      items.map((thread) => thread.id),
    );
    _sortedVisibleThreadIdsCache = sortedIds;
    return sortedIds;
  }

  bool _isVisibleThread(String threadId, ChatThread thread) {
    return !(_deletedThreads[threadId] ?? false) &&
        (thread.isFriend || !thread.isExpired);
  }

  Object? _threadListPresentationFingerprint(String threadId) {
    final resolvedThreadId = _resolveThreadId(threadId);
    final thread = _threads[resolvedThreadId];
    if (thread == null || !_isVisibleThread(resolvedThreadId, thread)) {
      return null;
    }
    return Object.hash(
      resolvedThreadId,
      thread.otherUser.nickname,
      _pinnedThreadIds.contains(resolvedThreadId),
      _lastActivityAt(thread),
    );
  }

  void _markThreadListPresentationDirty() {
    _sortedVisibleThreadIdsCache = null;
    _threadListPresentationRevision++;
  }

  void _markThreadSummaryDirty(String threadId) {
    final resolvedThreadId = _resolveThreadId(threadId);
    _threadSummaryRevisions[resolvedThreadId] =
        (_threadSummaryRevisions[resolvedThreadId] ?? 0) + 1;
    _threadSummaryCache.remove(resolvedThreadId);
  }

  Object? _threadComposerFingerprint(String threadId) {
    final resolvedThreadId = _resolveThreadId(threadId);
    final thread = _threads[resolvedThreadId];
    if (thread == null) {
      return null;
    }
    return Object.hash(
      resolvedThreadId,
      thread.canSendMessage,
      FeaturePolicy.canSendImage(thread),
      thread.intimacyPoints,
      thread.expiresAt.millisecondsSinceEpoch,
    );
  }

  void _markThreadComposerDirty(String threadId) {
    final resolvedThreadId = _resolveThreadId(threadId);
    _threadComposerRevisions[resolvedThreadId] =
        (_threadComposerRevisions[resolvedThreadId] ?? 0) + 1;
  }

  void _markThreadComposerDirtyIfChanged(
    String threadId,
    Object? previousFingerprint,
  ) {
    if (_threadComposerFingerprint(threadId) != previousFingerprint) {
      _markThreadComposerDirty(threadId);
    }
  }

  Object? _threadOutgoingDeliveryFingerprint(String threadId) {
    final resolvedThreadId = _resolveThreadId(threadId);
    final messages = _messages[resolvedThreadId];
    if (messages == null || messages.isEmpty) {
      return null;
    }
    return Object.hashAll(
      messages.where((message) => message.isMe).map((message) {
        return Object.hash(
          message.id,
          message.status,
          message.isRead,
          message.type,
          message.imagePath,
          message.imageQuality,
        );
      }),
    );
  }

  void _markThreadOutgoingDeliveryDirty(String threadId) {
    final resolvedThreadId = _resolveThreadId(threadId);
    _threadOutgoingDeliveryRevisions[resolvedThreadId] =
        (_threadOutgoingDeliveryRevisions[resolvedThreadId] ?? 0) + 1;
  }

  void _markThreadOutgoingDeliveryDirtyIfChanged(
    String threadId,
    Object? previousFingerprint,
  ) {
    if (_threadOutgoingDeliveryFingerprint(threadId) != previousFingerprint) {
      _markThreadOutgoingDeliveryDirty(threadId);
    }
  }

  Object? _threadHeaderFingerprint(String threadId) {
    final resolvedThreadId = _resolveThreadId(threadId);
    final thread = _threads[resolvedThreadId];
    if (thread == null) {
      return null;
    }
    return Object.hash(
      resolvedThreadId,
      thread.otherUser.id,
      thread.otherUser.nickname,
      thread.otherUser.avatar,
      thread.otherUser.isOnline,
      thread.createdAt.millisecondsSinceEpoch,
      thread.intimacyPoints,
      thread.isUnfollowed,
      thread.messagesSinceUnfollow,
    );
  }

  void _markThreadHeaderDirty(String threadId) {
    final resolvedThreadId = _resolveThreadId(threadId);
    _threadHeaderRevisions[resolvedThreadId] =
        (_threadHeaderRevisions[resolvedThreadId] ?? 0) + 1;
  }

  void _markThreadHeaderDirtyIfChanged(
    String threadId,
    Object? previousFingerprint,
  ) {
    if (_threadHeaderFingerprint(threadId) != previousFingerprint) {
      _markThreadHeaderDirty(threadId);
    }
  }

  void _markThreadListPresentationDirtyIfChanged(
    String threadId,
    Object? previousFingerprint,
  ) {
    if (_threadListPresentationFingerprint(threadId) != previousFingerprint) {
      _markThreadListPresentationDirty();
    }
  }

  void _markThreadInteractionChanged(String threadId) {
    final resolvedThreadId = _resolveThreadId(threadId);
    _threadInteractionRevisions[resolvedThreadId] =
        (_threadInteractionRevisions[resolvedThreadId] ?? 0) + 1;
    _markThreadSummaryDirty(resolvedThreadId);
  }

  ChatThreadSummarySnapshot? threadSummarySnapshot(String threadId) {
    final resolvedThreadId = _resolveThreadId(threadId);
    final thread = _threads[resolvedThreadId];
    if (thread == null || !_isVisibleThread(resolvedThreadId, thread)) {
      return null;
    }

    final cached = _threadSummaryCache[resolvedThreadId];
    if (cached != null) {
      return cached;
    }

    final messages = _messages[resolvedThreadId];
    final lastMessage =
        messages != null && messages.isNotEmpty ? messages.last : null;
    final failureState =
        lastMessage != null && lastMessage.status == MessageStatus.failed
            ? _deliveryFailureStateForMessage(resolvedThreadId, lastMessage)
            : null;
    final snapshot = ChatThreadSummarySnapshot(
      threadId: thread.id,
      userId: thread.otherUser.id,
      nickname: thread.otherUser.nickname,
      avatar: thread.otherUser.avatar,
      isOnline: thread.otherUser.isOnline,
      unreadCount: thread.unreadCount,
      createdAt: thread.createdAt,
      expiresAt: thread.expiresAt,
      intimacyPoints: thread.intimacyPoints,
      draft: _threadDrafts[resolvedThreadId] ?? '',
      isPinned: _pinnedThreadIds.contains(resolvedThreadId),
      lastMessage: lastMessage == null
          ? null
          : ChatMessagePreviewSnapshot.fromMessage(
              lastMessage,
              failureState: failureState,
            ),
    );
    _threadSummaryCache[resolvedThreadId] = snapshot;
    return snapshot;
  }

  bool isThreadPinned(String threadId) =>
      _pinnedThreadIds.contains(_resolveThreadId(threadId));

  void pinThread(String threadId) {
    final id = _resolveThreadId(threadId);
    final previousFingerprint = _threadListPresentationFingerprint(id);
    if (_pinnedThreadIds.add(id)) {
      _markThreadSummaryDirty(id);
      _markThreadListPresentationDirtyIfChanged(id, previousFingerprint);
      _notifyListeners(persist: false);
    }
  }

  void unpinThread(String threadId) {
    final id = _resolveThreadId(threadId);
    final previousFingerprint = _threadListPresentationFingerprint(id);
    if (_pinnedThreadIds.remove(id)) {
      _markThreadSummaryDirty(id);
      _markThreadListPresentationDirtyIfChanged(id, previousFingerprint);
      _notifyListeners(persist: false);
    }
  }

  List<Message> getMessages(String threadId) {
    return _messages[_resolveThreadId(threadId)] ?? [];
  }

  ChatThread? getThread(String threadId) {
    return _threads[_resolveThreadId(threadId)];
  }

  String draftForThread(String threadId) {
    return _threadDrafts[_resolveThreadId(threadId)] ?? '';
  }

  void saveDraft(String threadId, String text, {bool notify = false}) {
    final resolvedThreadId = _resolveThreadId(threadId);
    final normalized = text.trimRight();
    final previous = _threadDrafts[resolvedThreadId] ?? '';
    if (normalized.isEmpty) {
      if (_threadDrafts.remove(resolvedThreadId) != null && notify) {
        _markThreadSummaryDirty(resolvedThreadId);
        _notifyListeners(persist: false);
      }
      return;
    }
    if (previous == normalized) {
      return;
    }
    _threadDrafts[resolvedThreadId] = normalized;
    _markThreadSummaryDirty(resolvedThreadId);
    if (notify) {
      _notifyListeners(persist: false);
    }
  }

  void clearDraft(String threadId, {bool notify = false}) {
    final resolvedThreadId = _resolveThreadId(threadId);
    if (_threadDrafts.remove(resolvedThreadId) != null && notify) {
      _markThreadSummaryDirty(resolvedThreadId);
      _notifyListeners(persist: false);
    }
  }

  String? canonicalThreadId(String threadId) {
    final resolvedThreadId = _resolveThreadId(threadId);
    if (_threads.containsKey(resolvedThreadId)) {
      return resolvedThreadId;
    }
    return null;
  }

  String? routeThreadId({String? threadId, String? userId}) {
    if (threadId != null) {
      final canonical = canonicalThreadId(threadId);
      if (canonical != null) {
        return canonical;
      }
    }
    if (userId != null) {
      return canonicalThreadId(userId);
    }
    return null;
  }

  String _resolveThreadId(String threadId) {
    var resolvedThreadId = threadId;
    final visited = <String>{};
    while (visited.add(resolvedThreadId)) {
      if (!_threads.containsKey(resolvedThreadId) &&
          !resolvedThreadId.startsWith('th_')) {
        final threadIdByUserId = _findThreadIdByUserId(resolvedThreadId);
        if (threadIdByUserId != null) {
          resolvedThreadId = threadIdByUserId;
          continue;
        }
      }
      final nextThreadId = _threadIdAliases[resolvedThreadId];
      if (nextThreadId == null || nextThreadId == resolvedThreadId) {
        break;
      }
      resolvedThreadId = nextThreadId;
    }
    return resolvedThreadId;
  }

  String? _findThreadIdByUserId(String userId) {
    for (final thread in _threads.values) {
      if (thread.otherUser.id == userId) {
        return thread.id;
      }
    }
    return null;
  }

  DateTime _lastActivityAt(ChatThread thread) {
    final messages = _messages[thread.id];
    if (messages != null && messages.isNotEmpty) {
      return messages.last.timestamp;
    }
    return thread.createdAt;
  }

  Map<String, int> get deliveryStats => _deliveryStatsService.counters;

  List<ChatDeliveryStatEvent> get recentDeliveryEvents =>
      _deliveryStatsService.recentEvents;

  bool get hasDeliveryStats => _deliveryStatsService.hasData;

  void resetDeliveryStats() {
    _deliveryStatsService.clear();
    notifyListeners();
  }

  String _deliveryFailureKey(String threadId, String messageId) {
    return '${_resolveThreadId(threadId)}::$messageId';
  }

  void _setDeliveryFailureState(
    String threadId,
    String messageId,
    ChatDeliveryFailureState state,
  ) {
    final resolvedThreadId = _resolveThreadId(threadId);
    _messageFailureStates[_deliveryFailureKey(resolvedThreadId, messageId)] =
        state;
    _markThreadSummaryDirty(resolvedThreadId);
  }

  void _clearDeliveryFailureState(String threadId, String messageId) {
    final resolvedThreadId = _resolveThreadId(threadId);
    final removed = _messageFailureStates.remove(
      _deliveryFailureKey(resolvedThreadId, messageId),
    );
    if (removed != null) {
      _markThreadSummaryDirty(resolvedThreadId);
    }
  }

  void _remapDeliveryFailureStates(String fromThreadId, String toThreadId) {
    final updates = <String, ChatDeliveryFailureState>{};
    final removals = <String>[];
    final prefix = '$fromThreadId::';
    for (final entry in _messageFailureStates.entries) {
      if (!entry.key.startsWith(prefix)) {
        continue;
      }
      final messageId = entry.key.substring(prefix.length);
      updates[_deliveryFailureKey(toThreadId, messageId)] = entry.value;
      removals.add(entry.key);
    }
    for (final key in removals) {
      _messageFailureStates.remove(key);
    }
    _messageFailureStates.addAll(updates);
  }

  void _clearDeliveryFailureStatesForThread(String threadId) {
    final prefix = '${_resolveThreadId(threadId)}::';
    _messageFailureStates.removeWhere((key, _) => key.startsWith(prefix));
  }
}

class ChatThreadSummarySnapshot {
  const ChatThreadSummarySnapshot({
    required this.threadId,
    required this.userId,
    required this.nickname,
    required this.avatar,
    required this.isOnline,
    required this.unreadCount,
    required this.createdAt,
    required this.expiresAt,
    required this.intimacyPoints,
    required this.draft,
    required this.isPinned,
    required this.lastMessage,
  });

  final String threadId;
  final String userId;
  final String nickname;
  final String? avatar;
  final bool isOnline;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int intimacyPoints;
  final String draft;
  final bool isPinned;
  final ChatMessagePreviewSnapshot? lastMessage;
}

class ChatMessagePreviewSnapshot {
  const ChatMessagePreviewSnapshot({
    required this.id,
    required this.content,
    required this.isMe,
    required this.timestamp,
    required this.status,
    required this.type,
    required this.imagePath,
    required this.isBurnAfterReading,
    required this.isRead,
    required this.imageQuality,
    required this.failureState,
  });

  factory ChatMessagePreviewSnapshot.fromMessage(
    Message message, {
    required ChatDeliveryFailureState? failureState,
  }) {
    return ChatMessagePreviewSnapshot(
      id: message.id,
      content: message.content,
      isMe: message.isMe,
      timestamp: message.timestamp,
      status: message.status,
      type: message.type,
      imagePath: message.imagePath,
      isBurnAfterReading: message.isBurnAfterReading,
      isRead: message.isRead,
      imageQuality: message.imageQuality,
      failureState: failureState,
    );
  }

  final String id;
  final String content;
  final bool isMe;
  final DateTime timestamp;
  final MessageStatus status;
  final MessageType type;
  final String? imagePath;
  final bool isBurnAfterReading;
  final bool isRead;
  final ImageQuality? imageQuality;
  final ChatDeliveryFailureState? failureState;
}
