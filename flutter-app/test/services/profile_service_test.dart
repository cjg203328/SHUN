import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/services/image_upload_service.dart';
import 'package:sunliao/services/api_client.dart';
import 'package:sunliao/services/profile_service.dart';
import 'package:sunliao/services/storage_service.dart';

import '../helpers/test_bootstrap.dart';

void main() {
  setUp(() async {
    await initTestAppStorage();
    await StorageService.clearSessionData(preserveDeviceId: false);
    await ImageUploadService.clearAvatar();
    await ImageUploadService.clearBackground();
  });

  test('syncRemoteMediaReferences should persist remote avatar and background',
      () async {
    final service = ProfileService();

    await service.syncRemoteMediaReferences({
      'avatarUrl': 'avatar/u_test/remote_avatar.jpg',
      'backgroundUrl': 'background/u_test/remote_background.jpg',
    });

    expect(
      await ImageUploadService.getAvatarPath(),
      'avatar/u_test/remote_avatar.jpg',
    );
    expect(
      await ImageUploadService.getBackgroundPath(),
      'background/u_test/remote_background.jpg',
    );
  });

  test(
      'syncRemoteMediaReferences should keep existing media when remote payload is empty',
      () async {
    final service = ProfileService();
    await ImageUploadService.saveAvatarReference('avatar/u_test/existing.jpg');
    await ImageUploadService.saveBackgroundReference(
      'background/u_test/existing.jpg',
    );

    await service.syncRemoteMediaReferences({});

    expect(
      await ImageUploadService.getAvatarPath(),
      'avatar/u_test/existing.jpg',
    );
    expect(
      await ImageUploadService.getBackgroundPath(),
      'background/u_test/existing.jpg',
    );
  });

  test('refreshProfileWithStatus should stay local when session is missing',
      () async {
    final service = ProfileService();

    final result = await service.refreshProfileWithStatus();

    expect(result.remoteAttempted, isFalse);
    expect(result.remoteSucceeded, isFalse);
    expect(result.remoteFailed, isFalse);
  });

  test('saveNicknameWithStatus should stay local when session is missing',
      () async {
    final service = ProfileService();

    final result = await service.saveNicknameWithStatus('本地昵称');

    expect(result.remoteAttempted, isFalse);
    expect(result.remoteSucceeded, isFalse);
    expect(result.localOnly, isTrue);
    expect(result.snapshot.nickname, '本地昵称');
  });

  test('saveNicknameWithStatus should fallback to local when remote save fails',
      () async {
    await StorageService.saveToken('token');
    final service = ProfileService(apiClient: _FakeApiClient.patchFailure());

    final result = await service.saveNicknameWithStatus('待同步昵称');

    expect(result.remoteAttempted, isTrue);
    expect(result.remoteSucceeded, isFalse);
    expect(result.remoteFailed, isTrue);
    expect(result.localOnly, isFalse);
    expect(result.snapshot.nickname, '待同步昵称');
  });
}

class _FakeApiClient implements ApiClient {
  _FakeApiClient._({required this.patchHandler});

  factory _FakeApiClient.patchFailure() {
    return _FakeApiClient._(
      patchHandler: ({required String path, Object? data}) async {
        throw Exception('patch failed');
      },
    );
  }

  final Future<Map<String, dynamic>> Function({
    required String path,
    Object? data,
  }) patchHandler;

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
  }) async {
    return await patchHandler(path: path, data: data) as T;
  }

  @override
  Future<T> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    bool authRequired = true,
  }) {
    throw UnimplementedError();
  }
}
