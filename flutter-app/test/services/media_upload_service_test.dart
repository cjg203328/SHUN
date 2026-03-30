import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/services/api_client.dart';
import 'package:sunliao/services/chat_service.dart';
import 'package:sunliao/services/media_upload_service.dart';
import 'package:sunliao/services/storage_service.dart';

import '../helpers/test_bootstrap.dart';

void main() {
  setUp(() async {
    await initTestAppStorage();
    await StorageService.clearSessionData(preserveDeviceId: false);
  });

  test('normalizeChatImageUploadFailure should map oversized upload error', () {
    final normalized = normalizeChatImageUploadFailure(
      stage: ChatImageUploadFailureStage.upload,
      failure: const ChatRequestFailure(
        code: 'INVALID_INPUT',
        message: 'Image file is too large',
        statusCode: 400,
      ),
    );

    expect(normalized.code, 'IMAGE_UPLOAD_TOO_LARGE');
  });

  test(
      'normalizeChatImageUploadFailure should map unsupported format upload error',
      () {
    final normalized = normalizeChatImageUploadFailure(
      stage: ChatImageUploadFailureStage.upload,
      failure: const ChatRequestFailure(
        code: 'INVALID_INPUT',
        message: 'Only image upload is allowed',
        statusCode: 400,
      ),
    );

    expect(normalized.code, 'IMAGE_UPLOAD_UNSUPPORTED_FORMAT');
  });

  test('normalizeChatImageUploadFailure should map invalid upload token error',
      () {
    final normalized = normalizeChatImageUploadFailure(
      stage: ChatImageUploadFailureStage.upload,
      failure: const ChatRequestFailure(
        code: 'INVALID_INPUT',
        message: 'Invalid upload token',
        statusCode: 400,
      ),
    );

    expect(normalized.code, 'UPLOAD_TOKEN_INVALID');
  });

  test('normalizeChatImageUploadFailure should keep unrelated errors unchanged',
      () {
    const failure = ChatRequestFailure(
      code: 'NETWORK_ERROR',
      message: 'Socket transport unavailable',
    );
    final normalized = normalizeChatImageUploadFailure(
      stage: ChatImageUploadFailureStage.upload,
      failure: failure,
    );

    expect(normalized.code, failure.code);
    expect(normalized.message, failure.message);
  });

  test('uploadUserMediaWithStatus should stay local when session is missing',
      () async {
    final service = MediaUploadService();

    final result = await service.uploadUserMediaWithStatus(
      'avatar',
      _fakePreviewFile('avatar_local_preview.jpg'),
    );

    expect(result.localOnly, isTrue);
    expect(result.remoteAttempted, isFalse);
    expect(result.remoteSucceeded, isFalse);
    expect(result.mediaRef, contains('avatar_local_preview.jpg'));
  });

  test('uploadUserMediaWithStatus should fallback to local when remote fails',
      () async {
    await StorageService.saveToken('token');
    final service = MediaUploadService(
      apiClient: _FakeApiClient.uploadTokenFailure(),
    );

    final result = await service.uploadUserMediaWithStatus(
      'background',
      _fakePreviewFile('background_local_preview.jpg'),
    );

    expect(result.remoteAttempted, isTrue);
    expect(result.remoteSucceeded, isFalse);
    expect(result.remoteFailed, isTrue);
    expect(result.localOnly, isFalse);
    expect(result.mediaRef, contains('background_local_preview.jpg'));
  });
}

class _FakeApiClient implements ApiClient {
  _FakeApiClient._({required this.postHandler});

  factory _FakeApiClient.uploadTokenFailure() {
    return _FakeApiClient._(
      postHandler: ({required String path, Object? data}) async {
        throw Exception('upload-token failed');
      },
    );
  }

  final Future<Map<String, dynamic>> Function({
    required String path,
    Object? data,
  }) postHandler;

  @override
  Future<T> delete<T>(
    String path, {
    Object? data,
    bool authRequired = true,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authRequired = true,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<T> patch<T>(
    String path, {
    Object? data,
    bool authRequired = true,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<T> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    bool authRequired = true,
  }) async {
    return await postHandler(path: path, data: data) as T;
  }
}

File _fakePreviewFile(String name) {
  return File('C:\\temp\\$name');
}
