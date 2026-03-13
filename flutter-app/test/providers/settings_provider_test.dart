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

  test('should apply bundled experience preset and expose active preset',
      () async {
    final provider = SettingsProvider(enableRemoteHydration: false);

    await provider.applyExperiencePreset(SettingsExperiencePreset.quietObserve);

    expect(provider.invisibleMode, isTrue);
    expect(provider.notificationEnabled, isFalse);
    expect(provider.vibrationEnabled, isFalse);
    expect(
      provider.activeExperiencePreset,
      SettingsExperiencePreset.quietObserve,
    );

    final restored = SettingsProvider(enableRemoteHydration: false);
    expect(
      restored.activeExperiencePreset,
      SettingsExperiencePreset.quietObserve,
    );
  });
}
