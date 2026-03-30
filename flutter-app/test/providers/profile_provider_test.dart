import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/providers/profile_provider.dart';
import 'package:sunliao/services/api_client.dart';
import 'package:sunliao/services/profile_service.dart';
import 'package:sunliao/services/storage_service.dart';

import '../helpers/test_bootstrap.dart';

void main() {
  setUp(() async {
    await initTestAppStorage();
    await StorageService.clearSessionData(preserveDeviceId: false);
  });

  test('blank signature should fallback to default signature', () async {
    final provider = ProfileProvider();
    await provider.updateSignature('   ');

    expect(provider.signature, ProfileService.defaultSignature);
  });

  test('transparent homepage should require portrait fullscreen enabled',
      () async {
    final provider = ProfileProvider();

    await provider.updateTransparentHomepage(true);
    expect(provider.transparentHomepage, isFalse);

    await provider.updatePortraitFullscreenBackground(true);
    await provider.updateTransparentHomepage(true);
    expect(provider.transparentHomepage, isTrue);

    await provider.updatePortraitFullscreenBackground(false);
    expect(provider.transparentHomepage, isFalse);
  });

  test('profile preference toggles should only notify when state changes',
      () async {
    final provider = ProfileProvider();
    var notifications = 0;
    provider.addListener(() => notifications += 1);

    await provider.updateTransparentHomepage(true);
    expect(provider.transparentHomepage, isFalse);
    expect(notifications, 0);

    await provider.updatePortraitFullscreenBackground(true);
    expect(provider.portraitFullscreenBackground, isTrue);
    expect(notifications, 1);

    await provider.updateTransparentHomepage(true);
    expect(provider.transparentHomepage, isTrue);
    expect(notifications, 2);

    await provider.updateTransparentHomepage(true);
    expect(notifications, 2);

    await provider.updatePortraitFullscreenBackground(false);
    expect(provider.portraitFullscreenBackground, isFalse);
    expect(provider.transparentHomepage, isFalse);
    expect(notifications, 3);

    await provider.updatePortraitFullscreenBackground(false);
    expect(notifications, 3);
  });

  test('refresh from remote should skip notify when profile is unchanged',
      () async {
    final provider = ProfileProvider();
    var notifications = 0;
    provider.addListener(() => notifications += 1);

    await provider.refreshFromRemote();

    expect(notifications, 0);
  });

  test(
      'refresh from remote with status should report local-only state without session',
      () async {
    final provider = ProfileProvider();

    final result = await provider.refreshFromRemoteWithStatus();

    expect(result.remoteAttempted, isFalse);
    expect(result.remoteSucceeded, isFalse);
    expect(result.remoteFailed, isFalse);
  });

  test(
      'nickname update with status should report local-only state without session',
      () async {
    final provider = ProfileProvider();

    final result = await provider.updateNicknameWithStatus('本地昵称');

    expect(provider.nickname, '本地昵称');
    expect(result.remoteAttempted, isFalse);
    expect(result.localOnly, isTrue);
    expect(result.remoteFailed, isFalse);
  });

  test(
      'nickname update with status should expose deferred sync when remote save fails',
      () async {
    await StorageService.saveToken('token');
    final provider = ProfileProvider(
      profileService: ProfileService(apiClient: _FakeApiClient.patchFailure()),
    );

    final result = await provider.updateNicknameWithStatus('待同步昵称');

    expect(provider.nickname, '待同步昵称');
    expect(result.remoteAttempted, isTrue);
    expect(result.remoteSucceeded, isFalse);
    expect(result.remoteFailed, isTrue);
    expect(result.localOnly, isFalse);
  });

  test('avatar updates should skip notify when avatar is unchanged', () async {
    final provider = ProfileProvider();
    var notifications = 0;
    provider.addListener(() => notifications += 1);

    await provider.updateAvatar(provider.avatar);
    expect(notifications, 0);

    await provider.updateAvatar('avatar/tester');
    expect(provider.avatar, 'avatar/tester');
    expect(notifications, 1);
  });

  test('profile updates should persist', () async {
    final provider = ProfileProvider();

    await provider.updateNickname('Tester');
    await provider.updateStatus('Online');
    await provider.updateSignature('Hello world');

    final restored = ProfileProvider();
    expect(restored.nickname, 'Tester');
    expect(restored.status, 'Online');
    expect(restored.signature, 'Hello world');
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
