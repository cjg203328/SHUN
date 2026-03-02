import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/providers/match_provider.dart';

import '../helpers/test_bootstrap.dart';

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
}
