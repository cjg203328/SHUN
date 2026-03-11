import 'package:flutter/material.dart';
import '../../config/theme.dart';

class UiTokens {
  static const double radiusXs = 8;
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 24;

  static const Duration motionFast = Duration(milliseconds: 180);
  static const Duration motionNormal = Duration(milliseconds: 260);
  static const Duration motionSlow = Duration(milliseconds: 320);

  static const EdgeInsets screenHorizontal =
      EdgeInsets.symmetric(horizontal: 20);
  static const EdgeInsets cardPadding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 16,
  );

  static List<BoxShadow> get softShadow => AppOverlay.softShadow;
}
