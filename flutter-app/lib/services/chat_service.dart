import 'package:dio/dio.dart';

import '../models/models.dart';
import '../config/app_env.dart';
import '../core/network/api_exception.dart';
import 'api_client.dart';
import 'storage_service.dart';

class ChatThreadHydrationSnapshot {
  const ChatThreadHydrationSnapshot({
    required this.threads,
  });

  final List<ChatThread> threads;
}

class ChatRequestFailure {
  const ChatRequestFailure({
    required this.code,
    required this.message,
    this.statusCode,
    this.detail,
  });

  final String code;
  final String message;
  final int? statusCode;
  final String? detail;
}

class ChatRequestResult<T> {
  const ChatRequestResult.success(this.data) : error = null;

  const ChatRequestResult.failure(this.error) : data = null;

  final T? data;
  final ChatRequestFailure? error;

  bool get isSuccess => data != null;
}

class ChatService {
  ChatService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;
  static const List<String> _mockReplies = [
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

  bool canSendText(ChatThread thread) => thread.canSendMessage;

  bool canSendImage(ChatThread thread) =>
      thread.canSendMessage && thread.canSendImage;

  bool get hasSession {
    final token = StorageService.getToken();
    return token != null && token.isNotEmpty;
  }

  Future<List<ChatThread>> loadThreads() async {
    if (!hasSession) return const [];
    try {
      final data = await _apiClient.get<List<dynamic>>('/threads');
      return data
          .whereType<Map<String, dynamic>>()
          .map(_mapThread)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<ChatThreadHydrationSnapshot?> loadThreadHydrationSnapshot() async {
    if (!hasSession) return null;
    try {
      final data = await _apiClient.get<List<dynamic>>('/threads');
      return ChatThreadHydrationSnapshot(
        threads: data
            .whereType<Map<String, dynamic>>()
            .map(_mapThread)
            .toList(growable: false),
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<Message>> loadMessages(String threadId) async {
    if (!hasSession) return const [];
    try {
      final data =
          await _apiClient.get<List<dynamic>>('/threads/$threadId/messages');
      return data
          .whereType<Map<String, dynamic>>()
          .map(_mapMessage)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<ChatThread?> createDirectThread(User user) async {
    if (!hasSession) return null;
    try {
      final data = await _apiClient.post<Map<String, dynamic>>(
        '/threads/direct',
        data: {'targetUserId': user.id},
      );
      return _mapThread(data);
    } catch (_) {
      return null;
    }
  }

  Future<Message?> sendTextMessage(
    String threadId,
    String content,
    String clientMsgId,
  ) async {
    final result = await sendTextMessageResult(threadId, content, clientMsgId);
    return result.data;
  }

  Future<ChatRequestResult<Message>> sendTextMessageResult(
    String threadId,
    String content,
    String clientMsgId,
  ) async {
    if (!hasSession) {
      return const ChatRequestResult.failure(
        ChatRequestFailure(
          code: 'AUTH_TOKEN_INVALID',
          message: 'Missing session',
        ),
      );
    }
    try {
      final data = await _apiClient.post<Map<String, dynamic>>(
        '/threads/$threadId/messages/text',
        data: {'content': content, 'clientMsgId': clientMsgId},
      );
      return ChatRequestResult.success(_mapMessage(data));
    } catch (error) {
      return ChatRequestResult.failure(_resolveRequestFailure(error));
    }
  }

  Future<Message?> sendImageMessage(
    String threadId,
    String imageKey,
    bool burnAfterReading,
    String clientMsgId,
  ) async {
    final result = await sendImageMessageResult(
      threadId,
      imageKey,
      burnAfterReading,
      clientMsgId,
    );
    return result.data;
  }

  Future<ChatRequestResult<Message>> sendImageMessageResult(
    String threadId,
    String imageKey,
    bool burnAfterReading,
    String clientMsgId,
  ) async {
    if (!hasSession) {
      return const ChatRequestResult.failure(
        ChatRequestFailure(
          code: 'AUTH_TOKEN_INVALID',
          message: 'Missing session',
        ),
      );
    }
    try {
      final data = await _apiClient.post<Map<String, dynamic>>(
        '/threads/$threadId/messages/image',
        data: {
          'imageKey': imageKey,
          'burnAfterReading': burnAfterReading,
          'burnSeconds': burnAfterReading ? 5 : null,
          'clientMsgId': clientMsgId,
        },
      );
      return ChatRequestResult.success(_mapMessage(data));
    } catch (error) {
      return ChatRequestResult.failure(_resolveRequestFailure(error));
    }
  }

  Future<void> markThreadRead(String threadId,
      {String? lastReadMessageId}) async {
    await markThreadReadResult(
      threadId,
      lastReadMessageId: lastReadMessageId,
    );
  }

  Future<ChatRequestResult<bool>> markThreadReadResult(
    String threadId, {
    String? lastReadMessageId,
  }) async {
    if (!hasSession) {
      return const ChatRequestResult.failure(
        ChatRequestFailure(
          code: 'AUTH_TOKEN_INVALID',
          message: 'Missing session',
        ),
      );
    }
    try {
      await _apiClient.post<Map<String, dynamic>>(
        '/threads/$threadId/read',
        data: {
          if (lastReadMessageId != null) 'lastReadMessageId': lastReadMessageId,
        },
      );
      return const ChatRequestResult.success(true);
    } catch (error) {
      return ChatRequestResult.failure(_resolveRequestFailure(error));
    }
  }

  Future<void> deleteThread(String threadId) async {
    if (!hasSession) return;
    try {
      await _apiClient.delete<Map<String, dynamic>>('/threads/$threadId');
    } catch (_) {}
  }

  Future<void> recallMessage(String messageId) async {
    if (!hasSession) return;
    try {
      await _apiClient
          .post<Map<String, dynamic>>('/messages/$messageId/recall');
    } catch (_) {}
  }

  ChatThread mapThreadPayload(Map<String, dynamic> json) {
    final user =
        (json['user'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    return ChatThread(
      id: (json['threadId'] ?? json['id']).toString(),
      otherUser: User(
        id: (user['userId'] ?? user['id']).toString(),
        uid: (user['uid'] ?? '').toString(),
        nickname: (user['nickname'] ?? '神秘人').toString(),
        avatar: _mapAvatar(user['avatarUrl']?.toString()),
        distance: '附近',
        status: (user['status'] ?? '想找人聊聊').toString(),
        isOnline: true,
      ),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
          DateTime.now().add(const Duration(hours: 24)),
      intimacyPoints: 0,
      isFriend: json['isFriend'] == true,
    );
  }

  Message mapMessagePayload(Map<String, dynamic> json) {
    final typeRaw = json['type']?.toString() ?? 'text';
    final imageKey = json['imageKey']?.toString();
    return Message(
      id: (json['messageId'] ?? json['id']).toString(),
      content:
          (json['content'] ?? (typeRaw == 'image' ? '[图片]' : '')).toString(),
      isMe: json['isMe'] == true,
      timestamp: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      status: _mapStatus(json['status']?.toString()),
      type: typeRaw == 'image' ? MessageType.image : MessageType.text,
      imagePath: typeRaw == 'image' && imageKey != null
          ? AppEnv.resolveMediaUrl(imageKey)
          : imageKey,
      isBurnAfterReading: json['isBurnAfterReading'] == true,
      isRead: json['isRead'] == true,
      imageQuality: typeRaw == 'image' ? ImageQuality.compressed : null,
    );
  }

  ChatThread _mapThread(Map<String, dynamic> json) => mapThreadPayload(json);

  Message _mapMessage(Map<String, dynamic> json) => mapMessagePayload(json);

  MessageStatus _mapStatus(String? status) {
    switch (status) {
      case 'sending':
        return MessageStatus.sending;
      case 'failed':
        return MessageStatus.failed;
      default:
        return MessageStatus.sent;
    }
  }

  String _mapAvatar(String? avatarUrl) {
    final normalizedAvatar = avatarUrl?.trim();
    if (normalizedAvatar == null || normalizedAvatar.isEmpty) {
      return '👤';
    }
    return normalizedAvatar;
  }

  String getMockReply() {
    return _mockReplies[DateTime.now().second % _mockReplies.length];
  }

  ChatRequestFailure _resolveRequestFailure(Object error) {
    if (error is ApiException) {
      return ChatRequestFailure(
        code: error.code,
        message: error.message,
        statusCode: error.statusCode,
        detail: error.detail,
      );
    }
    if (error is DioException && error.error is ApiException) {
      final apiError = error.error as ApiException;
      return ChatRequestFailure(
        code: apiError.code,
        message: apiError.message,
        statusCode: apiError.statusCode ?? error.response?.statusCode,
        detail: apiError.detail,
      );
    }
    return ChatRequestFailure(
      code: 'NETWORK_ERROR',
      message: '网络连接失败',
      statusCode: error is DioException ? error.response?.statusCode : null,
      detail: error.toString(),
    );
  }
}
