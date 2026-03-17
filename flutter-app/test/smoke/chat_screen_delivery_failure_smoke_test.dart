import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sunliao/models/models.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/friend_provider.dart';
import 'package:sunliao/providers/notification_center_provider.dart';
import 'package:sunliao/screens/chat_screen.dart';
import 'package:sunliao/services/chat_service.dart';
import 'package:sunliao/services/chat_socket_service.dart';
import 'package:sunliao/services/media_upload_service.dart';

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

ChatThread _buildThread(String id) {
  final now = DateTime.now();
  return ChatThread(
    id: id,
    otherUser: _buildUser(id),
    createdAt: now.subtract(const Duration(minutes: 10)),
    expiresAt: now.add(const Duration(hours: 24)),
    intimacyPoints: 60,
  );
}

Widget _buildHost({
  required String threadId,
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
    child: MaterialApp(
      home: ChatScreen(threadId: threadId),
    ),
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

class _FakeChatService extends ChatService {
  _FakeChatService({required this.hasSessionOverride});

  final bool hasSessionOverride;

  @override
  bool get hasSession => hasSessionOverride;
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

class _FakeChatSocketService implements ChatSocketService {
  _FakeChatSocketService({
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

Future<({ChatProvider provider, File imageFile, String threadId})>
    _buildProviderWithUploadFailure({
  required String threadId,
  required String errorCode,
  required String errorMessage,
}) async {
  final provider = ChatProvider(
    chatService: _FakeChatService(hasSessionOverride: true),
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
  return (provider: provider, imageFile: imageFile, threadId: thread.id);
}

Future<({ChatProvider provider, File imageFile, String threadId})>
    _buildProviderWithSendFailure({
  required String threadId,
  required String errorCode,
  required String errorMessage,
}) async {
  final provider = ChatProvider(
    chatService: _FakeChatService(hasSessionOverride: true),
    chatSocketService: _FakeChatSocketService(
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
  return (provider: provider, imageFile: imageFile, threadId: thread.id);
}

Future<({ChatProvider provider, String threadId})> _buildProviderWithTextFailure({
  required String threadId,
  required String errorCode,
  required String errorMessage,
  String content = '这是一条待发送的文本消息',
}) async {
  final provider = ChatProvider(
    chatService: _FakeChatService(hasSessionOverride: true),
    chatSocketService: _FakeChatSocketService(
      sendTextResultsByThread: <String, ChatSocketAckResult>{
        threadId: ChatSocketAckResult.failure(
          ChatRequestFailure(
            code: errorCode,
            message: errorMessage,
            statusCode: 503,
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
  return (provider: provider, threadId: thread.id);
}

({ChatProvider provider, String threadId}) _buildProviderWithFailedTextMessage({
  required String threadId,
  required DateTime expiresAt,
  String content = '这是一条失败的文本消息',
}) {
  final provider = ChatProvider(
    enableRealtime: false,
    enableRemoteHydration: false,
  );
  final baseThread = _buildThread(threadId);
  final thread = ChatThread(
    id: baseThread.id,
    otherUser: baseThread.otherUser,
    unreadCount: baseThread.unreadCount,
    createdAt: baseThread.createdAt,
    expiresAt: expiresAt,
    intimacyPoints: baseThread.intimacyPoints,
    isFriend: baseThread.isFriend,
    isUnfollowed: baseThread.isUnfollowed,
    messagesSinceUnfollow: baseThread.messagesSinceUnfollow,
  );
  provider.addThread(thread);
  provider.getMessages(thread.id).add(
        Message(
          id: 'failed-text-${thread.id}',
          content: content,
          isMe: true,
          timestamp: DateTime.now(),
          status: MessageStatus.failed,
          type: MessageType.text,
        ),
      );
  return (provider: provider, threadId: thread.id);
}

void main() {
  setUp(() async {
    await initTestAppStorage();
    await NotificationCenterProvider.instance.clearSession();
  });

  tearDown(() async {
    await NotificationCenterProvider.instance.clearSession();
  });

  testWidgets('chat screen should show file too large guide content',
      (tester) async {
    final setup = (await tester.runAsync(
      () => _buildProviderWithUploadFailure(
        threadId: 'th_chat_screen_upload_too_large',
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
        threadId: setup.threadId,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('图片过大'), findsWidgets);
    expect(find.text('查看说明'), findsOneWidget);

    await tester.ensureVisible(find.text('查看说明'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看说明'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('图片体积过大'), findsOneWidget);
    expect(find.text('先压缩后再发送'), findsOneWidget);
    expect(find.text('裁剪掉不必要区域'), findsOneWidget);

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets('chat screen should show unsupported format guide content',
      (tester) async {
    final setup = (await tester.runAsync(
      () => _buildProviderWithUploadFailure(
        threadId: 'th_chat_screen_upload_unsupported',
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
        threadId: setup.threadId,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('格式异常'), findsWidgets);
    expect(find.text('查看说明'), findsOneWidget);

    await tester.ensureVisible(find.text('查看说明'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看说明'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('图片格式暂不支持'), findsOneWidget);
    expect(find.text('重新选择常见图片格式'), findsOneWidget);
    expect(find.text('先重新保存一遍图片'), findsOneWidget);

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets('chat screen should show upload token invalid retry state',
      (tester) async {
    final setup = (await tester.runAsync(
      () => _buildProviderWithUploadFailure(
        threadId: 'th_chat_screen_upload_token_invalid',
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
        threadId: setup.threadId,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.vpn_key_off_rounded), findsWidgets);
    expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
    expect(find.text('鏌ョ湅璇存槑'), findsNothing);
    expect(find.byIcon(Icons.photo_size_select_large_rounded), findsNothing);
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets('chat screen should show blocked relation without retry action',
      (tester) async {
    final setup = (await tester.runAsync(
      () => _buildProviderWithUploadFailure(
        threadId: 'th_chat_screen_blocked_relation',
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
        threadId: setup.threadId,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('关系受限'), findsWidgets);
    expect(find.byIcon(Icons.block_outlined), findsWidgets);
    expect(find.text('立即重试'), findsNothing);
    expect(find.text('查看说明'), findsNothing);
    expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets('chat screen should show network issue with retry action',
      (tester) async {
    final setup = (await tester.runAsync(
      () => _buildProviderWithSendFailure(
        threadId: 'th_chat_screen_network_issue',
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
        threadId: setup.threadId,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('网络波动'), findsWidgets);
    expect(find.byIcon(Icons.wifi_off_rounded), findsWidgets);
    expect(find.text('立即重试'), findsOneWidget);
    expect(find.text('查看说明'), findsNothing);
    expect(find.byIcon(Icons.block_outlined), findsNothing);

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'chat screen should show blocked relation for text message without retry action',
      (tester) async {
    final setup = (await tester.runAsync(
      () => _buildProviderWithTextFailure(
        threadId: 'th_chat_screen_text_blocked_relation',
        errorCode: 'BLOCKED_RELATION',
        errorMessage: 'Blocked relation',
      ),
    ))!;
    final chatProvider = setup.provider;
    final friendProvider = FriendProvider();

    await tester.pumpWidget(
      _buildHost(
        threadId: setup.threadId,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('关系受限'), findsWidgets);
    expect(find.byIcon(Icons.block_outlined), findsWidgets);
    expect(find.text('立即重试'), findsNothing);
    expect(find.text('查看说明'), findsNothing);
    expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets('chat screen should show network issue for text message',
      (tester) async {
    final setup = (await tester.runAsync(
      () => _buildProviderWithTextFailure(
        threadId: 'th_chat_screen_text_network_issue',
        errorCode: 'NETWORK_ERROR',
        errorMessage: 'Socket transport unavailable',
      ),
    ))!;
    final chatProvider = setup.provider;
    final friendProvider = FriendProvider();

    await tester.pumpWidget(
      _buildHost(
        threadId: setup.threadId,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('网络波动'), findsWidgets);
    expect(find.byIcon(Icons.wifi_off_rounded), findsWidgets);
    expect(find.text('立即重试'), findsOneWidget);
    expect(find.text('查看说明'), findsNothing);
    expect(find.byIcon(Icons.block_outlined), findsNothing);

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets('chat screen should show thread expired for text message',
      (tester) async {
    final setup = _buildProviderWithFailedTextMessage(
      threadId: 'th_chat_screen_text_thread_expired',
      expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
    );
    final chatProvider = setup.provider;
    final friendProvider = FriendProvider();

    await tester.pumpWidget(
      _buildHost(
        threadId: setup.threadId,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('会话已过期'), findsWidgets);
    expect(find.byIcon(Icons.hourglass_disabled_outlined), findsWidgets);
    expect(find.text('立即重试'), findsNothing);
    expect(find.text('查看说明'), findsNothing);

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets('chat screen should show retry unavailable for text message',
      (tester) async {
    final setup = (await tester.runAsync(
      () => _buildProviderWithTextFailure(
        threadId: 'th_chat_screen_text_retry_unavailable',
        errorCode: 'THREAD_NOT_FOUND',
        errorMessage: 'Thread not found',
      ),
    ))!;
    final chatProvider = setup.provider;
    final friendProvider = FriendProvider();

    await tester.pumpWidget(
      _buildHost(
        threadId: setup.threadId,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂不可重试'), findsWidgets);
    expect(find.byIcon(Icons.block_outlined), findsWidgets);
    expect(find.text('立即重试'), findsNothing);
    expect(find.text('查看说明'), findsNothing);
    expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);

    await _disposeHost(tester, chatProvider, friendProvider);
  });
}
