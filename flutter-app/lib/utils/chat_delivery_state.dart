import 'dart:io';

import '../models/models.dart';

enum ChatDeliveryFailureState {
  retryable,
  imageReselectRequired,
  imageUploadPreparationFailed,
  imageUploadInterrupted,
  imageUploadTokenInvalid,
  imageUploadFileTooLarge,
  imageUploadUnsupportedFormat,
  threadExpired,
  blockedRelation,
  networkIssue,
  retryUnavailable,
}

bool canRetryImageFromLocalPreview(String? imagePath) {
  final normalizedPath = imagePath?.trim();
  if (normalizedPath == null || normalizedPath.isEmpty) {
    return false;
  }
  if (normalizedPath.startsWith('http://') ||
      normalizedPath.startsWith('https://')) {
    return false;
  }
  return File(normalizedPath).existsSync();
}

bool failedImageNeedsReselect(Message message) {
  if (message.type != MessageType.image ||
      message.status != MessageStatus.failed) {
    return false;
  }

  return !canRetryImageFromLocalPreview(message.imagePath);
}
