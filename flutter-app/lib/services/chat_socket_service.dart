import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_env.dart';
import '../models/models.dart';
import 'chat_service.dart';
import 'storage_service.dart';

class ChatSocketService {
  ChatSocketService._({ChatService? chatService})
      : _chatService = chatService ?? ChatService();

  static final ChatSocketService instance = ChatSocketService._();

  final ChatService _chatService;
  io.Socket? _socket;
  Future<bool>? _connecting;

  ValueChanged<String>? onConnected;
  ValueChanged<MessageAckEvent>? onMessageAck;
  ValueChanged<IncomingMessageEvent>? onMessageNew;
  ValueChanged<PeerReadEvent>? onPeerRead;
  ValueChanged<ChatThread>? onThreadUpdated;
  ValueChanged<String>? onError;

  bool get isConnected => _socket?.connected == true;

  Future<bool> connect() {
    if (isConnected) return Future.value(true);
    final ongoing = _connecting;
    if (ongoing != null) return ongoing;

    final token = StorageService.getToken();
    if (token == null || token.isEmpty) {
      return Future.value(false);
    }

    final completer = Completer<bool>();
    _connecting = completer.future;

    try {
      _socket?.dispose();
      final socket = io.io(
        '${AppEnv.socketBaseUrl}/ws',
        <String, dynamic>{
          'transports': ['websocket'],
          'autoConnect': false,
          'forceNew': true,
          'reconnection': true,
          'auth': {'token': token},
          'extraHeaders': {'Authorization': 'Bearer $token'},
        },
      );

      void complete(bool value) {
        if (!completer.isCompleted) {
          completer.complete(value);
        }
        _connecting = null;
      }

      _socket = socket;
      _bindSocket(socket);

      socket.onConnect((_) {
        complete(true);
      });
      socket.onConnectError((error) {
        onError?.call(error.toString());
        complete(false);
      });
      socket.onError((error) {
        onError?.call(error.toString());
      });
      socket.connect();

      Future<void>.delayed(const Duration(seconds: 5), () {
        complete(socket.connected);
      });
    } catch (error) {
      onError?.call(error.toString());
      _connecting = null;
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    }

    return completer.future;
  }

  void disconnect() {
    _connecting = null;
    final socket = _socket;
    _socket = null;
    if (socket == null) return;
    socket.dispose();
  }

  Future<bool> joinThread(String threadId) {
    return _emitWithAck('thread.join', {'threadId': threadId});
  }

  Future<bool> sendText({
    required String threadId,
    required String content,
    required String clientMsgId,
  }) {
    return _emitWithAck('msg.send.text', {
      'threadId': threadId,
      'content': content,
      'clientMsgId': clientMsgId,
    });
  }

  Future<bool> sendImage({
    required String threadId,
    required String imageKey,
    required bool burnAfterReading,
    required String clientMsgId,
  }) {
    return _emitWithAck('msg.send.image', {
      'threadId': threadId,
      'imageKey': imageKey,
      'burnAfterReading': burnAfterReading,
      'burnSeconds': burnAfterReading ? 5 : null,
      'clientMsgId': clientMsgId,
    });
  }

  Future<bool> markRead(String threadId, {String? lastReadMessageId}) {
    return _emitWithAck('msg.read', {
      'threadId': threadId,
      if (lastReadMessageId != null) 'lastReadMessageId': lastReadMessageId,
    });
  }

  void _bindSocket(io.Socket socket) {
    socket.on('connected', (payload) {
      final data = _asMap(payload);
      final userId = data['userId']?.toString();
      if (userId != null && userId.isNotEmpty) {
        onConnected?.call(userId);
      }
    });

    socket.on('msg.ack', (payload) {
      final data = _asMap(payload);
      final message = _asMap(data['message']);
      final threadId = data['threadId']?.toString();
      final clientMsgId = data['clientMsgId']?.toString();
      if (threadId == null || clientMsgId == null || message.isEmpty) return;
      onMessageAck?.call(
        MessageAckEvent(
          threadId: threadId,
          clientMsgId: clientMsgId,
          message: _chatService.mapMessagePayload(message),
        ),
      );
    });

    socket.on('msg.new', (payload) {
      final data = _asMap(payload);
      final message = _asMap(data['message']);
      final threadId = data['threadId']?.toString();
      if (threadId == null || message.isEmpty) return;
      onMessageNew?.call(
        IncomingMessageEvent(
          threadId: threadId,
          message: _chatService.mapMessagePayload(message),
        ),
      );
    });

    socket.on('msg.read_by_peer', (payload) {
      final data = _asMap(payload);
      final threadId = data['threadId']?.toString();
      final byUserId = data['byUserId']?.toString();
      if (threadId == null || byUserId == null) return;
      onPeerRead?.call(
        PeerReadEvent(
          threadId: threadId,
          byUserId: byUserId,
          lastReadMessageId: data['lastReadMessageId']?.toString(),
        ),
      );
    });

    socket.on('thread.updated', (payload) {
      final data = _asMap(payload);
      if (data.isEmpty) return;
      onThreadUpdated?.call(_chatService.mapThreadPayload(data));
    });

    socket.on('error', (payload) {
      final data = _asMap(payload);
      final message = data['message']?.toString() ?? payload.toString();
      onError?.call(message);
    });
  }

  Future<bool> _emitWithAck(String event, Map<String, dynamic> payload) async {
    final connected = await connect();
    final socket = _socket;
    if (!connected || socket == null || !socket.connected) {
      return false;
    }

    final completer = Completer<bool>();
    socket.emitWithAck(event, payload, ack: (response) {
      if (completer.isCompleted) return;
      final data = _asMap(response);
      final hasError = data['error'] != null || data['message'] == 'error';
      completer.complete(!hasError);
    });

    Future<void>.delayed(const Duration(seconds: 5), () {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    return completer.future;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return <String, dynamic>{};
  }
}

class MessageAckEvent {
  const MessageAckEvent({
    required this.threadId,
    required this.clientMsgId,
    required this.message,
  });

  final String threadId;
  final String clientMsgId;
  final Message message;
}

class IncomingMessageEvent {
  const IncomingMessageEvent({
    required this.threadId,
    required this.message,
  });

  final String threadId;
  final Message message;
}

class PeerReadEvent {
  const PeerReadEvent({
    required this.threadId,
    required this.byUserId,
    this.lastReadMessageId,
  });

  final String threadId;
  final String byUserId;
  final String? lastReadMessageId;
}
