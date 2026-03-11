import 'dart:io';

import 'package:dio/dio.dart';

import '../core/network/api_exception.dart';
import '../config/app_env.dart';
import 'api_client.dart';
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
    if (!hasSession) {
      return PreparedChatImageUpload(
        sendKey: previewPath,
        previewPath: previewPath,
      );
    }

    try {
      final data = await _apiClient.post<Map<String, dynamic>>(
        '/threads/$threadId/messages/image/upload-token',
      );
      final objectKey = data['objectKey']?.toString().trim();
      if (objectKey == null || objectKey.isEmpty) {
        throw const ApiException(
          code: 'UPLOAD_TOKEN_INVALID',
          message: '上传令牌返回缺少 objectKey',
        );
      }

      await _apiClient.post<Map<String, dynamic>>(
        '/threads/$threadId/messages/image/upload',
        data: FormData.fromMap({
          'uploadToken': data['uploadToken']?.toString() ?? '',
          'objectKey': objectKey,
          'file': await MultipartFile.fromFile(
            previewPath,
            filename: imageFile.uri.pathSegments.isNotEmpty
                ? imageFile.uri.pathSegments.last
                : 'chat-image.jpg',
          ),
        }),
      );

      return PreparedChatImageUpload(
        sendKey: objectKey,
        previewPath: previewPath,
        uploadToken: data['uploadToken']?.toString(),
        expireSeconds: (data['expireSeconds'] as num?)?.toInt(),
        isRemotePrepared: true,
      );
    } catch (_) {
      return PreparedChatImageUpload(
        sendKey: previewPath,
        previewPath: previewPath,
      );
    }
  }

  Future<String> uploadUserMedia(
    String type,
    File imageFile,
  ) async {
    final previewPath = imageFile.path;
    if (!hasSession) {
      return previewPath;
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

      return AppEnv.resolveMediaUrl(objectKey);
    } catch (_) {
      return previewPath;
    }
  }
}
