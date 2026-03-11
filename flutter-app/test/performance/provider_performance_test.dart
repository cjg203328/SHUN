import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/models/models.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/settings_provider.dart';

import '../helpers/test_bootstrap.dart';

ChatThread _thread(int index) {
  final now = DateTime.now();
  return ChatThread(
    id: 'perf_$index',
    otherUser: User(
      id: 'perf_$index',
      uid: 'SNPERF$index',
      nickname: 'Perf-$index',
      distance: 'nearby',
      status: 'ready',
    ),
    createdAt: now.subtract(const Duration(minutes: 30)),
    expiresAt: now.add(const Duration(hours: 24)),
    intimacyPoints: 160,
  );
}

void main() {
  setUp(() async {
    await initTestAppStorage();
  });

  test('chat provider batch operations should complete within budget',
      () async {
    final provider = ChatProvider();
    final watch = Stopwatch()..start();

    for (var i = 0; i < 300; i++) {
      final thread = _thread(i);
      provider.addThread(thread);
      provider.deleteThread(thread.id);
      provider.restoreThread(thread.id);
    }

    watch.stop();
    expect(watch.elapsedMilliseconds, lessThan(3000));
  });

  test('settings toggles should complete quickly', () async {
    final provider = SettingsProvider();
    final watch = Stopwatch()..start();

    for (var i = 0; i < 200; i++) {
      final enable = i.isEven;
      await provider.updateInvisibleMode(enable);
      await provider.updateNotificationEnabled(enable);
      await provider.updateVibrationEnabled(enable);
    }

    watch.stop();
    expect(watch.elapsedMilliseconds, lessThan(3000));
  });
}
