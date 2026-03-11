import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/core/policy/feature_policy.dart';
import 'package:sunliao/models/models.dart';

ChatThread _thread({
  required int points,
  required int ageMinutes,
}) {
  final now = DateTime.now();
  return ChatThread(
    id: 'u_policy',
    otherUser: User(
      id: 'u_policy',
      uid: 'SNPOLICY',
      nickname: 'Policy',
      distance: 'nearby',
      status: 'ready',
    ),
    createdAt: now.subtract(Duration(minutes: ageMinutes)),
    expiresAt: now.add(const Duration(hours: 24)),
    intimacyPoints: points,
  );
}

void main() {
  test('stage one should require both score and minutes', () {
    final thread = _thread(points: 39, ageMinutes: 2);

    expect(FeaturePolicy.canOpenProfile(thread), isFalse);
    expect(FeaturePolicy.profilePointsRemaining(thread), 1);
    expect(FeaturePolicy.profileMinutesRemaining(thread), 1);
  });

  test('stage one unlocked should allow profile and image send', () {
    final thread = _thread(points: 80, ageMinutes: 5);

    expect(FeaturePolicy.canOpenProfile(thread), isTrue);
    expect(FeaturePolicy.canSendImage(thread), isTrue);
    expect(FeaturePolicy.nextUnlockName(thread), '互关与语音');
  });

  test(
      'stage two unlocked should allow voice and mutual follow when not blocked',
      () {
    final thread = _thread(points: 160, ageMinutes: 15);

    expect(
      FeaturePolicy.canVoiceCall(
        thread: thread,
        isFriend: false,
        isBlocked: false,
      ),
      isTrue,
    );
    expect(
      FeaturePolicy.canMutualFollow(
        thread: thread,
        isFriend: false,
        isBlocked: false,
      ),
      isTrue,
    );
    expect(FeaturePolicy.pointsToNextUnlock(thread), 0);
  });

  test('blocked user should not be able to voice call or mutual follow', () {
    final thread = _thread(points: 200, ageMinutes: 20);

    expect(
      FeaturePolicy.canVoiceCall(
        thread: thread,
        isFriend: false,
        isBlocked: true,
      ),
      isFalse,
    );
    expect(
      FeaturePolicy.canMutualFollow(
        thread: thread,
        isFriend: false,
        isBlocked: true,
      ),
      isFalse,
    );
  });
}
