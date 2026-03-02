import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/providers/settings_provider.dart';

import '../helpers/test_bootstrap.dart';

void main() {
  setUp(() async {
    await initTestAppStorage();
  });

  test('should use default settings on first launch', () {
    final provider = SettingsProvider();

    expect(provider.invisibleMode, isFalse);
    expect(provider.notificationEnabled, isTrue);
    expect(provider.vibrationEnabled, isTrue);
  });

  test('should persist updates across provider instances', () async {
    final provider = SettingsProvider();

    await provider.updateInvisibleMode(true);
    await provider.updateNotificationEnabled(false);
    await provider.updateVibrationEnabled(false);

    final restored = SettingsProvider();
    expect(restored.invisibleMode, isTrue);
    expect(restored.notificationEnabled, isFalse);
    expect(restored.vibrationEnabled, isFalse);
  });
}
