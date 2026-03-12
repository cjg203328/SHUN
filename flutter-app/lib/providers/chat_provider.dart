import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../config/app_env.dart';
import '../models/models.dart';
import '../repositories/app_data_repository.dart';
import '../services/analytics_service.dart';
import '../services/chat_service.dart';
import '../services/chat_socket_service.dart';
import '../services/media_upload_service.dart';
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
  final Map<String, List<Message>> _messages = {};
  final Map<String, ChatThread> _threads = {};
  final Map<String, String> _threadIdAliases = {};
  final Map<String, DateTime> _lastMessageTime = {};
  final Map<String, DateTime> _lastRemoteMessageSyncAt = {};
  final Map<String, DateTime> _recentImageSubmitAt = {};
  final Map<String, Set<String>> _recalledMessageIds = {};
  final Map<String, bool> _deletedThreads = {};
  final Map<String, Future<void>> _remoteMessageLoads = {};
  final Map<String, String?> _lastReadSyncMessageIds = {};
  final Map<String, int> _activeThreadClaims = {};
  final List<String> _activeThreadFocusOrder = <String>[];
  final Set<String> _joinedRealtimeThreads = <String>{};
  final Map<String, Future<bool>> _joiningRealtimeThreads = {};
  String? _activeThreadId;
  Timer? _persistTimer;
  bool _isRestoring = false;
  bool _isDisposed = false;

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
    _isDisposed = true;
    _persistTimer?.cancel();
    _unbindRealtime();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_isDisposed) {
      return;
    }
    super.notifyListeners();
    if (_isRestoring) return;
    _schedulePersist();
  }

  Map<String, ChatThread> get threads {
    return Map.fromEntries(
      _threads.entries.where(
        (entry) =>
            !(_deletedThreads[entry.key] ?? false) &&
            (entry.value.isFriend || !entry.value.isExpired),
      ),
    );
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
    return _messages[_resolveThreadId(threadId)] ?? [];
  }

  ChatThread? getThread(String threadId) {
    return _threads[_resolveThreadId(threadId)];
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
}
