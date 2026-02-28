import '../../models/models.dart';
import '../../utils/intimacy_system.dart';

class FeaturePolicy {
  static const int _profileMinMinutes = 3;
  static const int _stageTwoMinMinutes = 12;

  static bool canOpenProfile(ChatThread thread) => thread.hasUnlockedProfile;

  static bool canSendImage(ChatThread thread) => thread.canSendImage;

  static bool canFlashImage(ChatThread thread) => thread.canSendImage;

  static bool canVoiceCall({
    required ChatThread thread,
    required bool isFriend,
    required bool isBlocked,
  }) {
    if (isBlocked) return false;
    return isFriend || thread.canAddFriend;
  }

  static bool canMutualFollow({
    required ChatThread thread,
    required bool isFriend,
    required bool isBlocked,
  }) {
    if (isBlocked || isFriend) return false;
    return thread.canAddFriend;
  }

  static int profilePointsRemaining(ChatThread thread) =>
      (IntimacyUnlock.unlockProfile - thread.intimacyPoints).clamp(0, 9999);

  static int stageTwoPointsRemaining(ChatThread thread) =>
      (IntimacyUnlock.canAddFriend - thread.intimacyPoints).clamp(0, 9999);

  static int profileMinutesRemaining(ChatThread thread) {
    final chatMinutes = DateTime.now().difference(thread.createdAt).inMinutes;
    return (_profileMinMinutes - chatMinutes).clamp(0, 9999);
  }

  static int stageTwoMinutesRemaining(ChatThread thread) {
    final chatMinutes = DateTime.now().difference(thread.createdAt).inMinutes;
    return (_stageTwoMinMinutes - chatMinutes).clamp(0, 9999);
  }

  static String? nextUnlockName(ChatThread thread) {
    if (!thread.hasUnlockedProfile) return '主页权限';
    if (!thread.canAddFriend) return '互关与语音';
    return null;
  }

  static int pointsToNextUnlock(ChatThread thread) {
    if (!thread.hasUnlockedProfile) return profilePointsRemaining(thread);
    if (!thread.canAddFriend) return stageTwoPointsRemaining(thread);
    return 0;
  }

  static String profileUnlockHint(ChatThread thread, String featureName) {
    final pointsToUnlock = profilePointsRemaining(thread);
    final minutesToUnlock = profileMinutesRemaining(thread);
    final minutePart = minutesToUnlock > 0 ? '，至少再聊$minutesToUnlock分钟' : '';
    return '继续互动解锁$featureName：还差$pointsToUnlock分$minutePart';
  }

  static String stageTwoUnlockHint(ChatThread thread, String featureName) {
    final pointsToUnlock = stageTwoPointsRemaining(thread);
    final minutesToUnlock = stageTwoMinutesRemaining(thread);
    final minutePart = minutesToUnlock > 0 ? '，至少再聊$minutesToUnlock分钟' : '';
    return '继续互动解锁$featureName：还差$pointsToUnlock分$minutePart';
  }
}
