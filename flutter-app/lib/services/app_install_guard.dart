import 'package:flutter/services.dart';

class AppInstallGuard {
  static const MethodChannel _channel = MethodChannel('sunliao/app_meta');

  static Future<int?> getFirstInstallTimeMs() async {
    try {
      final result = await _channel.invokeMethod<int>('getFirstInstallTime');
      return result;
    } catch (_) {
      return null;
    }
  }
}
