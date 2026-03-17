import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sunliao/models/models.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/friend_provider.dart';
import 'package:sunliao/providers/notification_center_provider.dart';
import 'package:sunliao/services/chat_service.dart';
import 'package:sunliao/services/chat_socket_service.dart';
import 'package:sunliao/services/media_upload_service.dart';
import 'package:sunliao/widgets/messages_tab.dart';

import '../helpers/test_bootstrap.dart';

User _buildUser(String id) {
  return User(
    id: id,
    uid: 'SN$id',
    nickname: 'User-$id',
    avatar: '🙂',
    distance: '2km',
    status: 'available',
    isOnline: true,
  );
}

ChatThread _buildThread(String id, {DateTime? expiresAt}) {
  final now = DateTime.now();
  return ChatThread(
    id: id,
    otherUser: _buildUser(id),
    createdAt: now.subtract(const Duration(minutes: 10)),
    expiresAt: expiresAt ?? now.add(const Duration(hours: 24)),
    intimacyPoints: 60,
  );
}

Widget _buildHost({
  required ChatProvider chatProvider,
  required FriendProvider friendProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<NotificationCenterProvider>.value(
        value: NotificationCenterProvider.instance,
      ),
      ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
      ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
    ],
    child: const MaterialApp(home: MessagesTab()),
  );
}

Future<void> _disposeHost(
  WidgetTester tester,
  ChatProvider chatProvider,
  FriendProvider friendProvider,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  chatProvider.dispose();
  friendProvider.dispose();
  await tester.pump(const Duration(milliseconds: 250));
}

Future<File> _createTestImageFile(String name) async {
  const pixelBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Z0S8AAAAASUVORK5CYII=';
  final bytes = base64Decode(pixelBase64);
  final file = File(
    '${Directory.systemTemp.path}\\${name}_${DateTime.now().microsecondsSinceEpoch}.png',
  );
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

class _FakeMessagesChatService extends ChatService {
  _FakeMessagesChatService({required this.hasSessionOverride});

  final bool hasSessionOverride;

  @override
  bool get hasSession => hasSessionOverride;

  @override
  Future<ChatRequestResult<Message>> sendImageMessageResult(
    String threadId,
    String imageKey,
    bool burnAfterReading,
    String clientMsgId,
  ) async {
    return ChatRequestResult.success(
      Message(
        id: 'remote-$clientMsgId',
        content: '[图片]',
        isMe: true,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
        type: MessageType.image,
        imagePath: imageKey,
        isBurnAfterReading: burnAfterReading,
        imageQuality: ImageQuality.compressed,
      ),
    );
  }
}

class _FakeMediaUploadService extends MediaUploadService {
  _FakeMediaUploadService({
    required this.preparedUploadBuilder,
    this.preparedUploadResultBuilder,
  });

  final PreparedChatImageUpload Function(String threadId, File imageFile)
      preparedUploadBuilder;
  final ChatImageUploadPreparationResult Function(
    String threadId,
    File imageFile,
  )? preparedUploadResultBuilder;

  @override
  Future<PreparedChatImageUpload> prepareChatImageUpload(
    String threadId,
    File imageFile,
  ) async {
    return preparedUploadBuilder(threadId, imageFile);
  }

  @override
  Future<ChatImageUploadPreparationResult> prepareChatImageUploadResult(
    String threadId,
    File imageFile,
  ) async {
    return preparedUploadResultBuilder?.call(threadId, imageFile) ??
        ChatImageUploadPreparationResult.success(
          preparedUploadBuilder(threadId, imageFile),
        );
  }
}

class _FakeMessagesChatSocketService implements ChatSocketService {
  _FakeMessagesChatSocketService({
    this.sendTextResultsByThread = const <String, ChatSocketAckResult>{},
    this.sendImageResultsByThread = const <String, ChatSocketAckResult>{},
  });

  @override
  ValueChanged<String>? onConnected;

  @override
  ValueChanged<MessageAckEvent>? onMessageAck;

  @override
  ValueChanged<IncomingMessageEvent>? onMessageNew;

  @override
  ValueChanged<PeerReadEvent>? onPeerRead;

  @override
  ValueChanged<ChatThread>? onThreadUpdated;

  @override
  ValueChanged<String>? onError;

  final Map<String, ChatSocketAckResult> sendTextResultsByThread;
  final Map<String, ChatSocketAckResult> sendImageResultsByThread;

  @override
  bool get isConnected => true;

  @override
  Future<bool> connect() async => true;

  @override
  void disconnect() {}

  @override
  Future<bool> joinThread(String threadId) async {
    final result = await joinThreadResult(threadId);
    return result.isSuccess;
  }

  @override
  Future<ChatSocketAckResult> joinThreadResult(String threadId) async {
    return const ChatSocketAckResult.success();
  }

  @override
  Future<bool> sendText({
    required String threadId,
    required String content,
    required String clientMsgId,
  }) async {
    final result = await sendTextResult(
      threadId: threadId,
      content: content,
      clientMsgId: clientMsgId,
    );
    return result.isSuccess;
  }

  @override
  Future<ChatSocketAckResult> sendTextResult({
    required String threadId,
    required String content,
    required String clientMsgId,
  }) async {
    return sendTextResultsByThread[threadId] ??
        const ChatSocketAckResult.success();
  }

  @override
  Future<bool> sendImage({
    required String threadId,
    required String imageKey,
    required bool burnAfterReading,
    required String clientMsgId,
  }) async {
    final result = await sendImageResult(
      threadId: threadId,
      imageKey: imageKey,
      burnAfterReading: burnAfterReading,
      clientMsgId: clientMsgId,
    );
    return result.isSuccess;
  }

  @override
  Future<ChatSocketAckResult> sendImageResult({
    required String threadId,
    required String imageKey,
    required bool burnAfterReading,
    required String clientMsgId,
  }) async {
    return sendImageResultsByThread[threadId] ??
        const ChatSocketAckResult.success();
  }

  @override
  Future<bool> markRead(String threadId, {String? lastReadMessageId}) async {
    final result = await markReadResult(
      threadId,
      lastReadMessageId: lastReadMessageId,
    );
    return result.isSuccess;
  }

  @override
  Future<ChatSocketAckResult> markReadResult(
    String threadId, {
    String? lastReadMessageId,
  }) async {
    return const ChatSocketAckResult.success();
  }
}

Future<({ChatProvider provider, File imageFile})>
    _buildProviderWithUploadFailure({
  required String threadId,
  required String errorCode,
  required String errorMessage,
  DateTime? threadExpiresAt,
}) async {
  final provider = ChatProvider(
    chatService: _FakeMessagesChatService(hasSessionOverride: true),
    mediaUploadService: _FakeMediaUploadService(
      preparedUploadBuilder: (resolvedThreadId, imageFile) =>
          PreparedChatImageUpload(
        sendKey: imageFile.path,
        previewPath: imageFile.path,
        isRemotePrepared: false,
      ),
      preparedUploadResultBuilder: (resolvedThreadId, imageFile) =>
          ChatImageUploadPreparationResult.failure(
        stage: ChatImageUploadFailureStage.upload,
        error: ChatRequestFailure(
          code: errorCode,
          message: errorMessage,
          statusCode: 400,
        ),
      ),
    ),
    enableRealtime: false,
    enableRemoteHydration: false,
  );

  final thread = _buildThread(threadId, expiresAt: threadExpiresAt);
  provider.addThread(thread);
  final imageFile = await _createTestImageFile(threadId);
  await provider.sendImageMessage(
    thread.id,
    imageFile,
    ImageQuality.compressed,
    false,
  );
  await Future<void>.delayed(const Duration(milliseconds: 40));
  return (provider: provider, imageFile: imageFile);
}

Future<({ChatProvider provider, File imageFile})> _buildProviderWithSendFailure({
  required String threadId,
  required String errorCode,
  required String errorMessage,
}) async {
  final provider = ChatProvider(
    chatService: _FakeMessagesChatService(hasSessionOverride: true),
    chatSocketService: _FakeMessagesChatSocketService(
      sendImageResultsByThread: <String, ChatSocketAckResult>{
        threadId: ChatSocketAckResult.failure(
          ChatRequestFailure(
            code: errorCode,
            message: errorMessage,
            statusCode: 503,
          ),
        ),
      },
    ),
    mediaUploadService: _FakeMediaUploadService(
      preparedUploadBuilder: (resolvedThreadId, imageFile) =>
          PreparedChatImageUpload(
        sendKey: 'prepared-$resolvedThreadId',
        previewPath: imageFile.path,
        isRemotePrepared: true,
      ),
    ),
    enableRemoteHydration: false,
  );

  final thread = _buildThread(threadId);
  provider.addThread(thread);
  final imageFile = await _createTestImageFile(threadId);
  await provider.sendImageMessage(
    thread.id,
    imageFile,
    ImageQuality.compressed,
    false,
  );
  await Future<void>.delayed(const Duration(milliseconds: 40));
  return (provider: provider, imageFile: imageFile);
}

Future<ChatProvider> _buildProviderWithTextFailure({
  required String threadId,
  required String errorCode,
  required String errorMessage,
  String content = '这是一条待发送的文本消息',
}) async {
  final provider = ChatProvider(
    chatService: _FakeMessagesChatService(hasSessionOverride: true),
    chatSocketService: _FakeMessagesChatSocketService(
      sendTextResultsByThread: <String, ChatSocketAckResult>{
        threadId: ChatSocketAckResult.failure(
          ChatRequestFailure(
            code: errorCode,
            message: errorMessage,
            statusCode: 404,
          ),
        ),
      },
    ),
    enableRemoteHydration: false,
  );

  final thread = _buildThread(threadId);
  provider.addThread(thread);
  provider.sendMessage(thread.id, content);
  await Future<void>.delayed(const Duration(milliseconds: 40));
  return provider;
}

void main() {
  setUp(() async {
    await initTestAppStorage();
    await NotificationCenterProvider.instance.clearSession();
  });

  tearDown(() async {
    await NotificationCenterProvider.instance.clearSession();
  });

  testWidgets('messages tab should surface file too large delivery state',
      (tester) async {
    final setup = (await tester.runAsync(
      () => _buildProviderWithUploadFailure(
        threadId: 'th_messages_upload_too_large',
        errorCode: 'IMAGE_UPLOAD_TOO_LARGE',
        errorMessage: 'Image file is too large',
      ),
    ))!;
    final chatProvider = setup.provider;
    final friendProvider = FriendProvider();
    addTearDown(() async {
      if (await setup.imageFile.exists()) {
        await setup.imageFile.delete();
      }
    });

    await tester.pumpWidget(
      _buildHost(
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('图片过大，请重新选图'), findsOneWidget);
    expect(find.text('图片过大'), findsNWidgets(2));

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets('messages tab should surface unsupported format delivery state',
      (tester) async {
    final setup = (await tester.runAsync(
      () => _buildProviderWithUploadFailure(
        threadId: 'th_messages_upload_unsupported',
        errorCode: 'IMAGE_UPLOAD_UNSUPPORTED_FORMAT',
        errorMessage: 'Only image upload is allowed',
      ),
    ))!;
    final chatProvider = setup.provider;
    final friendProvider = FriendProvider();
    addTearDown(() async {
      if (await setup.imageFile.exists()) {
        await setup.imageFile.delete();
      }
    });

    await tester.pumpWidget(
      _buildHost(
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('图片格式异常，请重新选图'), findsOneWidget);
    expect(find.text('格式异常'), findsNWidgets(2));

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets('messages tab should surface upload token invalid delivery state',
      (tester) async {
    final setup = (await tester.runAsync(
      () => _buildProviderWithUploadFailure(
        threadId: 'th_messages_upload_token_invalid',
        errorCode: 'UPLOAD_TOKEN_INVALID',
        errorMessage: 'Invalid upload token',
      ),
    ))!;
    final chatProvider = setup.provider;
    final friendProvider = FriendProvider();
    addTearDown(() async {
      if (await setup.imageFile.exists()) {
        await setup.imageFile.delete();
      }
    });

    await tester.pumpWidget(
      _buildHost(
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('凭证失效'), findsOneWidget);
    expect(find.byIcon(Icons.vpn_key_off_rounded), findsOneWidget);
    expect(find.byIcon(Icons.photo_size_select_large_rounded), findsNothing);
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets('messages tab should surface network issue delivery state',
      (tester) async {
    final setup = (await tester.runAsync(
      () => _buildProviderWithSendFailure(
        threadId: 'th_messages_network_issue',
        errorCode: 'NETWORK_ERROR',
        errorMessage: 'Socket transport unavailable',
      ),
    ))!;
    final chatProvider = setup.provider;
    final friendProvider = FriendProvider();
    addTearDown(() async {
      if (await setup.imageFile.exists()) {
        await setup.imageFile.delete();
      }
    });

    await tester.pumpWidget(
      _buildHost(
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('网络波动'), findsNWidgets(2));
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets('messages tab should surface blocked relation delivery state',
      (tester) async {
    final setup = (await tester.runAsync(
      () => _buildProviderWithUploadFailure(
        threadId: 'th_messages_blocked_relation',
        errorCode: 'BLOCKED_RELATION',
        errorMessage: 'Blocked relation',
      ),
    ))!;
    final chatProvider = setup.provider;
    final friendProvider = FriendProvider();
    addTearDown(() async {
      if (await setup.imageFile.exists()) {
        await setup.imageFile.delete();
      }
    });

    await tester.pumpWidget(
      _buildHost(
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('关系受限'), findsNWidgets(2));
    expect(find.byIcon(Icons.block_outlined), findsOneWidget);

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets('messages tab should surface retry unavailable delivery state',
      (tester) async {
    final chatProvider = (await tester.runAsync(
      () => _buildProviderWithTextFailure(
        threadId: 'th_messages_retry_unavailable',
        errorCode: 'THREAD_NOT_FOUND',
        errorMessage: 'Thread not found',
      ),
    ))!;
    final friendProvider = FriendProvider();

    await tester.pumpWidget(
      _buildHost(
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂不可重试'), findsNWidgets(2));
    expect(find.byIcon(Icons.block_outlined), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);

    await _disposeHost(tester, chatProvider, friendProvider);
  });
}
