import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/providers/match_provider.dart';
import 'package:sunliao/services/match_service.dart';

import '../helpers/test_bootstrap.dart';

class _FakeMatchService extends MatchService {
  _FakeMatchService({required this.startMatchHandler});

  final Future<MatchStartAttempt> Function(List<String> excludedUserIds)
      startMatchHandler;

  @override
  Future<MatchStartAttempt> startMatch({
    required List<String> excludedUserIds,
  }) {
    return startMatchHandler(excludedUserIds);
  }
}

void main() {
  setUp(() async {
    await initTestAppStorage();
  });

  test('startMatch should produce user and consume one quota', () async {
    final provider = MatchProvider();
    final before = provider.matchCount;

    await provider.startMatch();

    expect(provider.isMatching, isFalse);
    expect(provider.matchedUser, isNotNull);
    expect(provider.matchCount, before - 1);
  });

  test('cancelMatch should stop matching without consuming quota', () async {
    final provider = MatchProvider();
    final before = provider.matchCount;

    final matching = provider.startMatch();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    provider.cancelMatch();
    await matching;

    expect(provider.isMatching, isFalse);
    expect(provider.matchedUser, isNull);
    expect(provider.matchCount, before);
  });

  test('startMatch should expose failure reason when mock fallback is disabled',
      () async {
    final provider = MatchProvider(
      matchService: _FakeMatchService(
        startMatchHandler: (_) async => const MatchStartAttempt.failure(
          errorCode: 'MATCH_UNAVAILABLE',
          errorMessage: 'Match service has no available candidates',
        ),
      ),
      allowMockFallback: false,
    );

    await provider.startMatch();

    expect(provider.isMatching, isFalse);
    expect(provider.matchedUser, isNull);
    expect(provider.lastFailureCode, 'MATCH_UNAVAILABLE');
    expect(provider.lastFailureMessage, '当前环境还没有可用匹配对象，请先完成联调配置。');
  });
}
