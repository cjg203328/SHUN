import 'dart:io';

import 'package:dio/dio.dart';

import '../core/network/api_exception.dart';
import '../config/app_env.dart';
import 'api_client.dart';
import 'chat_service.dart';
import 'storage_service.dart';

class PreparedChatImageUpload {
  const PreparedChatImageUpload({
    required this.sendKey,
    required this.previewPath,
    this.uploadToken,
    this.expireSeconds,
    this.isRemotePrepared = false,
  });

  final String sendKey;
  final String previewPath;
  final String? uploadToken;
  final int? expireSeconds;
  final bool isRemotePrepared;
}

enum ChatImageUploadFailureStage {
  token,
  upload,
}

class ChatImageUploadPreparationResult {
  const ChatImageUploadPreparationResult.success(this.data)
      : error = null,
        stage = null;

  const ChatImageUploadPreparationResult.failure({
    required this.stage,
    required this.error,
  }) : data = null;

  final PreparedChatImageUpload? data;
  final ChatRequestFailure? error;
  final ChatImageUploadFailureStage? stage;

  bool get isSuccess => data != null;
}

class UserMediaUploadResult {
  const UserMediaUploadResult({
    required this.mediaRef,
    required this.remoteAttempted,
    required this.remoteSucceeded,
  });

  final String mediaRef;
  final bool remoteAttempted;
  final bool remoteSucceeded;

  bool get remoteFailed => remoteAttempted && !remoteSucceeded;
  bool get localOnly => !remoteAttempted;
}

ChatRequestFailure normalizeChatImageUploadFailure({
  required ChatImageUploadFailureStage stage,
  required ChatRequestFailure failure,
}) {
  final normalizedMessage = failure.message.trim().toLowerCase();

  if (failure.code == 'INVALID_INPUT') {
    if (normalizedMessage.contains('image file is too large')) {
      return ChatRequestFailure(
        code: 'IMAGE_UPLOAD_TOO_LARGE',
        message: failure.message,
        statusCode: failure.statusCode,
        detail: failure.detail,
      );
    }

    if (normalizedMessage.contains('only image upload is allowed')) {
      return ChatRequestFailure(
        code: 'IMAGE_UPLOAD_UNSUPPORTED_FORMAT',
        message: failure.message,
        statusCode: failure.statusCode,
        detail: failure.detail,
      );
    }

    if (normalizedMessage.contains('invalid upload token') ||
        normalizedMessage.contains('unsafe object key')) {
      return ChatRequestFailure(
        code: 'UPLOAD_TOKEN_INVALID',
        message: failure.message,
        statusCode: failure.statusCode,
        detail: failure.detail,
      );
    }
  }

  if (stage == ChatImageUploadFailureStage.token &&
      failure.code == 'REQUEST_FAILED' &&
      normalizedMessage.contains('objectkey')) {
    return ChatRequestFailure(
      code: 'UPLOAD_TOKEN_INVALID',
      message: failure.message,
      statusCode: failure.statusCode,
      detail: failure.detail,
    );
  }

  return failure;
}

class MediaUploadService {
  MediaUploadService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  bool get hasSession {
    final token = StorageService.getToken();
    return token != null && token.isNotEmpty;
  }

  Future<PreparedChatImageUpload> prepareChatImageUpload(
    String threadId,
    File imageFile,
  ) async {
    final previewPath = imageFile.path;
    final result = await prepareChatImageUploadResult(threadId, imageFile);
    return result.data ??
        PreparedChatImageUpload(
          sendKey: previewPath,
          previewPath: previewPath,
        );
  }

  Future<ChatImageUploadPreparationResult> prepareChatImageUploadResult(
    String threadId,
    File imageFile,
  ) async {
    final previewPath = imageFile.path;
    if (!hasSession) {
      return ChatImageUploadPreparationResult.success(
        PreparedChatImageUpload(
          sendKey: previewPath,
          previewPath: previewPath,
        ),
      );
    }

    Map<String, dynamic> tokenData;
    try {
      tokenData = await _apiClient.post<Map<String, dynamic>>(
        '/threads/$threadId/messages/image/upload-token',
      );
    } catch (error) {
      return ChatImageUploadPreparationResult.failure(
        stage: ChatImageUploadFailureStage.token,
        error: normalizeChatImageUploadFailure(
          stage: ChatImageUploadFailureStage.token,
          failure: _resolveRequestFailure(error),
        ),
      );
    }

    final objectKey = tokenData['objectKey']?.toString().trim();
    if (objectKey == null || objectKey.isEmpty) {
      return const ChatImageUploadPreparationResult.failure(
        stage: ChatImageUploadFailureStage.token,
        error: ChatRequestFailure(
          code: 'UPLOAD_TOKEN_INVALID',
          message: '上传令牌返回缺少 objectKey',
        ),
      );
    }

    try {
      await _apiClient.post<Map<String, dynamic>>(
        '/threads/$threadId/messages/image/upload',
        data: FormData.fromMap({
          'uploadToken': tokenData['uploadToken']?.toString() ?? '',
          'objectKey': objectKey,
          'file': await MultipartFile.fromFile(
            previewPath,
            filename: imageFile.uri.pathSegments.isNotEmpty
                ? imageFile.uri.pathSegments.last
                : 'chat-image.jpg',
          ),
        }),
      );
    } catch (error) {
      return ChatImageUploadPreparationResult.failure(
        stage: ChatImageUploadFailureStage.upload,
        error: normalizeChatImageUploadFailure(
          stage: ChatImageUploadFailureStage.upload,
          failure: _resolveRequestFailure(error),
        ),
      );
    }

    return ChatImageUploadPreparationResult.success(
      PreparedChatImageUpload(
        sendKey: objectKey,
        previewPath: previewPath,
        uploadToken: tokenData['uploadToken']?.toString(),
        expireSeconds: (tokenData['expireSeconds'] as num?)?.toInt(),
        isRemotePrepared: true,
      ),
    );
  }

  Future<String> uploadUserMedia(
    String type,
    File imageFile,
  ) async {
    final result = await uploadUserMediaWithStatus(type, imageFile);
    return result.mediaRef;
  }

  Future<UserMediaUploadResult> uploadUserMediaWithStatus(
    String type,
    File imageFile,
  ) async {
    final previewPath = imageFile.path;
    if (!hasSession) {
      return UserMediaUploadResult(
        mediaRef: previewPath,
        remoteAttempted: false,
        remoteSucceeded: false,
      );
    }

    try {
      final tokenData = await _apiClient.post<Map<String, dynamic>>(
        '/users/me/$type/upload-token',
      );
      final objectKey = tokenData['objectKey']?.toString().trim();
      if (objectKey == null || objectKey.isEmpty) {
        throw const ApiException(
          code: 'UPLOAD_TOKEN_INVALID',
          message: '上传令牌返回缺少 objectKey',
        );
      }

      await _apiClient.post<Map<String, dynamic>>(
        '/users/me/$type/upload',
        data: FormData.fromMap({
          'uploadToken': tokenData['uploadToken']?.toString() ?? '',
          'objectKey': objectKey,
          'file': await MultipartFile.fromFile(
            previewPath,
            filename: imageFile.uri.pathSegments.isNotEmpty
                ? imageFile.uri.pathSegments.last
                : '$type-image.jpg',
          ),
        }),
      );

      return UserMediaUploadResult(
        mediaRef: AppEnv.resolveMediaUrl(objectKey),
        remoteAttempted: true,
        remoteSucceeded: true,
      );
    } catch (_) {
      return UserMediaUploadResult(
        mediaRef: previewPath,
        remoteAttempted: true,
        remoteSucceeded: false,
      );
    }
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
