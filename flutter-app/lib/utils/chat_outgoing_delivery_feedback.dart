import '../models/models.dart';

class OutgoingDeliveryObservation {
  const OutgoingDeliveryObservation({
    required this.status,
    required this.isRead,
    this.isRetryTransition = false,
  });

  factory OutgoingDeliveryObservation.fromMessage(
    Message message, {
    bool isRetryTransition = false,
  }) {
    return OutgoingDeliveryObservation(
      status: message.status,
      isRead: message.isRead,
      isRetryTransition: isRetryTransition,
    );
  }

  final MessageStatus status;
  final bool isRead;
  final bool isRetryTransition;
}

class OutgoingDeliveryFeedback {
  const OutgoingDeliveryFeedback({
    required this.message,
    required this.priority,
    required this.timestamp,
    this.isError = false,
  });

  final String message;
  final bool isError;
  final int priority;
  final DateTime timestamp;
}

class OutgoingDeliveryFeedbackResolution {
  const OutgoingDeliveryFeedbackResolution({
    required this.snapshot,
    this.feedback,
  });

  final OutgoingDeliveryFeedback? feedback;
  final Map<String, OutgoingDeliveryObservation> snapshot;
}

String buildOutgoingDeliveryTrackingKey(int index, Message message) {
  return [
    index,
    message.type.name,
    message.content,
    message.isBurnAfterReading,
  ].join('|');
}

Map<String, OutgoingDeliveryObservation> captureOutgoingDeliverySnapshot(
  List<Message> messages,
) {
  final outgoingMessages = messages.where((message) => message.isMe).toList();
  return Map<String, OutgoingDeliveryObservation>.fromEntries(
    outgoingMessages.asMap().entries.map(
          (entry) => MapEntry(
            buildOutgoingDeliveryTrackingKey(entry.key, entry.value),
            OutgoingDeliveryObservation.fromMessage(entry.value),
          ),
        ),
  );
}

OutgoingDeliveryFeedbackResolution resolveOutgoingDeliveryFeedback({
  required List<Message> messages,
  required Map<String, OutgoingDeliveryObservation> previousSnapshot,
}) {
  final feedbacks = <OutgoingDeliveryFeedback>[];
  final nextSnapshot = <String, OutgoingDeliveryObservation>{};
  final outgoingMessages = messages.where((item) => item.isMe).toList();

  for (final entry in outgoingMessages.asMap().entries) {
    final message = entry.value;
    final trackingKey = buildOutgoingDeliveryTrackingKey(entry.key, message);
    final previous = previousSnapshot[trackingKey];
    var isRetryTransition = previous?.isRetryTransition ?? false;
    if (previous?.status == MessageStatus.failed &&
        message.status == MessageStatus.sending) {
      isRetryTransition = true;
    }

    nextSnapshot[trackingKey] = OutgoingDeliveryObservation.fromMessage(
      message,
      isRetryTransition: isRetryTransition,
    );
    if (previous == null || message.isBurnAfterReading) {
      continue;
    }

    if (previous.status == MessageStatus.sending &&
        message.status == MessageStatus.failed &&
        previous.isRetryTransition) {
      feedbacks.add(
        OutgoingDeliveryFeedback(
          message: '重试失败，请重试',
          isError: true,
          priority: 4,
          timestamp: message.timestamp,
        ),
      );
      continue;
    }

    if (previous.status == MessageStatus.sending &&
        message.status == MessageStatus.sent) {
      feedbacks.add(
        OutgoingDeliveryFeedback(
          message: previous.isRetryTransition ? '重试成功，已送达' : '消息已送达',
          priority: previous.isRetryTransition ? 3 : 2,
          timestamp: message.timestamp,
        ),
      );
    }

    if (!previous.isRead &&
        message.isRead &&
        message.status == MessageStatus.sent) {
      feedbacks.add(
        OutgoingDeliveryFeedback(
          message: previous.isRetryTransition ? '重试成功，对方已读' : '对方刚刚已读',
          priority: previous.isRetryTransition ? 5 : 3,
          timestamp: message.timestamp,
        ),
      );
    }
  }

  if (feedbacks.isEmpty) {
    return OutgoingDeliveryFeedbackResolution(snapshot: nextSnapshot);
  }

  feedbacks.sort((left, right) {
    final priorityCompare = right.priority.compareTo(left.priority);
    if (priorityCompare != 0) {
      return priorityCompare;
    }
    return right.timestamp.compareTo(left.timestamp);
  });
  return OutgoingDeliveryFeedbackResolution(
    feedback: feedbacks.first,
    snapshot: nextSnapshot,
  );
}
