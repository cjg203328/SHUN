import 'package:flutter/services.dart';

class ScreenshotGuard {
  static const MethodChannel _channel =
      MethodChannel('sunliao/screen_security');

  static Future<void> setSecure(bool enabled) async {
    try {
      await _channel.invokeMethod<void>(
        'setSecureScreen',
        <String, dynamic>{'enabled': enabled},
      );
    } catch (_) {
      // 非Android平台或通道不可用时忽略
    }
  }
}

