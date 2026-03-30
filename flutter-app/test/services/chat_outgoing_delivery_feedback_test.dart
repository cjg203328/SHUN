import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/models/models.dart';
import 'package:sunliao/utils/chat_outgoing_delivery_feedback.dart';

Message _buildMessage({
  required String id,
  required MessageStatus status,
  bool isRead = false,
  bool isMe = true,
  String content = 'payload',
  DateTime? timestamp,
}) {
  return Message(
    id: id,
    content: content,
    isMe: isMe,
    timestamp: timestamp ?? DateTime.now(),
    status: status,
    isRead: isRead,
  );
}

void main() {
  test('captureOutgoingDeliverySnapshot only keeps outgoing messages', () {
    final snapshot = captureOutgoingDeliverySnapshot([
      _buildMessage(id: 'incoming-1', status: MessageStatus.sent, isMe: false),
      _buildMessage(id: 'outgoing-1', status: MessageStatus.sending),
    ]);

    expect(snapshot, hasLength(1));
    expect(snapshot.values.single.status, MessageStatus.sending);
  });

  test('resolveOutgoingDeliveryFeedback emits delivery confirmation', () {
    final previousSnapshot = captureOutgoingDeliverySnapshot([
      _buildMessage(id: 'outgoing-1', status: MessageStatus.sending),
    ]);

    final resolution = resolveOutgoingDeliveryFeedback(
      messages: [
        _buildMessage(
          id: 'outgoing-1',
          status: MessageStatus.sent,
          timestamp: DateTime.parse('2026-03-17T12:00:00.000'),
        ),
      ],
      previousSnapshot: previousSnapshot,
    );

    expect(resolution.feedback, isNotNull);
    expect(resolution.feedback!.message, '消息已送达');
    expect(resolution.feedback!.isError, isFalse);
  });

  test('resolveOutgoingDeliveryFeedback emits retry success after recovery',
      () {
    final failedSnapshot = captureOutgoingDeliverySnapshot([
      _buildMessage(id: 'outgoing-1', status: MessageStatus.failed),
    ]);
    final sendingResolution = resolveOutgoingDeliveryFeedback(
      messages: [
        _buildMessage(id: 'outgoing-1', status: MessageStatus.sending),
      ],
      previousSnapshot: failedSnapshot,
    );

    final sentResolution = resolveOutgoingDeliveryFeedback(
      messages: [
        _buildMessage(
          id: 'outgoing-1',
          status: MessageStatus.sent,
          timestamp: DateTime.parse('2026-03-17T12:00:01.000'),
        ),
      ],
      previousSnapshot: sendingResolution.snapshot,
    );

    expect(sentResolution.feedback, isNotNull);
    expect(sentResolution.feedback!.message, '重试成功，已送达');
    expect(sentResolution.feedback!.isError, isFalse);
  });

  test('resolveOutgoingDeliveryFeedback emits retry failure after resend fails',
      () {
    final failedSnapshot = captureOutgoingDeliverySnapshot([
      _buildMessage(id: 'outgoing-1', status: MessageStatus.failed),
    ]);
    final sendingResolution = resolveOutgoingDeliveryFeedback(
      messages: [
        _buildMessage(id: 'outgoing-1', status: MessageStatus.sending),
      ],
      previousSnapshot: failedSnapshot,
    );

    final failedAgainResolution = resolveOutgoingDeliveryFeedback(
      messages: [
        _buildMessage(
          id: 'outgoing-1',
          status: MessageStatus.failed,
          timestamp: DateTime.parse('2026-03-17T12:00:02.000'),
        ),
      ],
      previousSnapshot: sendingResolution.snapshot,
    );

    expect(failedAgainResolution.feedback, isNotNull);
    expect(failedAgainResolution.feedback!.message, '重试失败，请重试');
    expect(failedAgainResolution.feedback!.isError, isTrue);
  });

  test('resolveOutgoingDeliveryFeedback prefers read confirmation over sent',
      () {
    final previousSnapshot = captureOutgoingDeliverySnapshot([
      _buildMessage(
          id: 'outgoing-1', status: MessageStatus.sending, isRead: false),
    ]);

    final resolution = resolveOutgoingDeliveryFeedback(
      messages: [
        _buildMessage(
          id: 'outgoing-1',
          status: MessageStatus.sent,
          isRead: true,
          timestamp: DateTime.parse('2026-03-17T12:00:03.000'),
        ),
      ],
      previousSnapshot: previousSnapshot,
    );

    expect(resolution.feedback, isNotNull);
    expect(resolution.feedback!.message, '对方刚刚已读');
    expect(resolution.feedback!.isError, isFalse);
  });
}
