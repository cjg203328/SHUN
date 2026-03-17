import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/models/models.dart';
import 'package:sunliao/utils/chat_delivery_state.dart';
import 'package:sunliao/widgets/chat_delivery_status.dart';

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

Message _buildFailedMessage({
  required String id,
  MessageType type = MessageType.text,
  String content = 'payload',
  String? imagePath,
  ImageQuality? imageQuality,
}) {
  return Message(
    id: id,
    content: content,
    isMe: true,
    timestamp: DateTime.now(),
    status: MessageStatus.failed,
    type: type,
    imagePath: imagePath,
    imageQuality: imageQuality,
  );
}

void _expectActionableFailureSpec(
  ChatDeliveryStatusSpec spec, {
  required ChatDeliveryAction actionType,
  required IconData badgeIcon,
  required IconData cardIcon,
  ChatDeliveryFailureState? guideFailureState,
}) {
  expect(spec.hasBadge, isTrue);
  expect(spec.hasCard, isTrue);
  expect(spec.badgeIcon, badgeIcon);
  expect(spec.cardIcon, cardIcon);
  expect(spec.actionType, actionType);
  expect(spec.actionLabel, isNotNull);
  expect(spec.guideFailureState, guideFailureState);
}

void main() {
  test(
    'resolveChatDeliveryStatus keeps retry action for failed original image when preview exists',
    () async {
      final imageFile = await _createTestImageFile('delivery_status_retryable');
      addTearDown(() async {
        if (await imageFile.exists()) {
          await imageFile.delete();
        }
      });

      final spec = resolveChatDeliveryStatus(
        _buildFailedMessage(
          id: 'failed-original-image',
          type: MessageType.image,
          content: '',
          imagePath: imageFile.path,
          imageQuality: ImageQuality.original,
        ),
      );

      expect(spec, isNotNull);
      _expectActionableFailureSpec(
        spec!,
        actionType: ChatDeliveryAction.retry,
        badgeIcon: Icons.error_outline,
        cardIcon: Icons.error_outline,
      );
    },
  );

  test(
    'resolveChatDeliveryStatus shows non-actionable expired state for failed message',
    () {
      final spec = resolveChatDeliveryStatus(
        _buildFailedMessage(id: 'failed-expired-message'),
        failureState: ChatDeliveryFailureState.threadExpired,
      );

      expect(spec, isNotNull);
      expect(spec!.hasBadge, isTrue);
      expect(spec.hasCard, isTrue);
      expect(spec.badgeIcon, Icons.hourglass_disabled_outlined);
      expect(spec.cardIcon, Icons.hourglass_disabled_outlined);
      expect(spec.actionType, isNull);
      expect(spec.actionLabel, isNull);
      expect(spec.guideFailureState, isNull);
    },
  );

  test('resolveChatDeliveryStatus shows non-actionable blocked relation state',
      () {
    final spec = resolveChatDeliveryStatus(
      _buildFailedMessage(id: 'failed-blocked-message'),
      failureState: ChatDeliveryFailureState.blockedRelation,
    );

    expect(spec, isNotNull);
    expect(spec!.badgeIcon, Icons.block_outlined);
    expect(spec.cardIcon, Icons.block_outlined);
    expect(spec.actionType, isNull);
    expect(spec.actionLabel, isNull);
    expect(spec.guideFailureState, isNull);
  });

  test('resolveChatDeliveryStatus shows retryable network issue state', () {
    final spec = resolveChatDeliveryStatus(
      _buildFailedMessage(id: 'failed-network-message'),
      failureState: ChatDeliveryFailureState.networkIssue,
    );

    expect(spec, isNotNull);
    _expectActionableFailureSpec(
      spec!,
      actionType: ChatDeliveryAction.retry,
      badgeIcon: Icons.wifi_off_rounded,
      cardIcon: Icons.wifi_off_rounded,
    );
  });

  test('resolveChatDeliveryStatus shows non-actionable retry unavailable state',
      () {
    final spec = resolveChatDeliveryStatus(
      _buildFailedMessage(id: 'failed-retry-unavailable-message'),
      failureState: ChatDeliveryFailureState.retryUnavailable,
    );

    expect(spec, isNotNull);
    expect(spec!.badgeLabel, '暂不可重试');
    expect(spec.cardLabel, '暂不可重试');
    expect(spec.badgeIcon, Icons.block_outlined);
    expect(spec.cardIcon, Icons.block_outlined);
    expect(spec.actionType, isNull);
    expect(spec.actionLabel, isNull);
    expect(spec.guideFailureState, isNull);
  });

  test('resolveChatDeliveryStatus shows upload preparation failure state', () {
    final spec = resolveChatDeliveryStatus(
      _buildFailedMessage(
        id: 'failed-upload-prepare-message',
        type: MessageType.image,
      ),
      failureState: ChatDeliveryFailureState.imageUploadPreparationFailed,
    );

    expect(spec, isNotNull);
    _expectActionableFailureSpec(
      spec!,
      actionType: ChatDeliveryAction.retry,
      badgeIcon: Icons.cloud_off_rounded,
      cardIcon: Icons.cloud_off_rounded,
    );
  });

  test('resolveChatDeliveryStatus shows upload interruption state', () {
    final spec = resolveChatDeliveryStatus(
      _buildFailedMessage(
        id: 'failed-upload-transfer-message',
        type: MessageType.image,
      ),
      failureState: ChatDeliveryFailureState.imageUploadInterrupted,
    );

    expect(spec, isNotNull);
    _expectActionableFailureSpec(
      spec!,
      actionType: ChatDeliveryAction.retry,
      badgeIcon: Icons.upload_file_rounded,
      cardIcon: Icons.upload_file_rounded,
    );
  });

  test('resolveChatDeliveryStatus shows upload token invalid state', () {
    final spec = resolveChatDeliveryStatus(
      _buildFailedMessage(
        id: 'failed-upload-token-invalid-message',
        type: MessageType.image,
      ),
      failureState: ChatDeliveryFailureState.imageUploadTokenInvalid,
    );

    expect(spec, isNotNull);
    _expectActionableFailureSpec(
      spec!,
      actionType: ChatDeliveryAction.retry,
      badgeIcon: Icons.vpn_key_off_rounded,
      cardIcon: Icons.vpn_key_off_rounded,
    );
  });

  test('resolveChatDeliveryStatus shows file too large guide state', () {
    final spec = resolveChatDeliveryStatus(
      _buildFailedMessage(
        id: 'failed-upload-too-large-message',
        type: MessageType.image,
      ),
      failureState: ChatDeliveryFailureState.imageUploadFileTooLarge,
    );

    expect(spec, isNotNull);
    _expectActionableFailureSpec(
      spec!,
      actionType: ChatDeliveryAction.showGuide,
      badgeIcon: Icons.photo_size_select_large_rounded,
      cardIcon: Icons.photo_size_select_large_rounded,
      guideFailureState: ChatDeliveryFailureState.imageUploadFileTooLarge,
    );
  });

  test('resolveChatDeliveryStatus shows unsupported format guide state', () {
    final spec = resolveChatDeliveryStatus(
      _buildFailedMessage(
        id: 'failed-upload-unsupported-message',
        type: MessageType.image,
      ),
      failureState: ChatDeliveryFailureState.imageUploadUnsupportedFormat,
    );

    expect(spec, isNotNull);
    _expectActionableFailureSpec(
      spec!,
      actionType: ChatDeliveryAction.showGuide,
      badgeIcon: Icons.broken_image_outlined,
      cardIcon: Icons.broken_image_outlined,
      guideFailureState: ChatDeliveryFailureState.imageUploadUnsupportedFormat,
    );
  });
}
