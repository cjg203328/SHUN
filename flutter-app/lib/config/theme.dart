// ignore_for_file: deprecated_member_use

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppThemeConfig {
  static bool get isDayTheme => false;

  static void setDayTheme(bool isDayTheme) {}
}

class _AdaptiveColor extends Color {
  final Color day;
  final Color night;

  const _AdaptiveColor({
    required this.day,
    required this.night,
  }) : super(0x00000000);

  Color get _active => night;

  @override
  int get value => _active.value;

  @override
  double get a => _active.a;

  @override
  double get r => _active.r;

  @override
  double get g => _active.g;

  @override
  double get b => _active.b;

  @override
  ColorSpace get colorSpace => _active.colorSpace;

  @override
  Color withAlpha(int a) => _active.withAlpha(a);

  @override
  Color withBlue(int b) => _active.withBlue(b);

  @override
  Color withGreen(int g) => _active.withGreen(g);

  @override
  Color withRed(int r) => _active.withRed(r);

  @override
  Color withValues({
    double? alpha,
    double? red,
    double? green,
    double? blue,
    ColorSpace? colorSpace,
  }) {
    return _active.withValues(
      alpha: alpha,
      red: red,
      green: green,
      blue: blue,
      colorSpace: colorSpace,
    );
  }

  @override
  String toString() => _active.toString();
}

class AppColors {
  static const pureBlack = _AdaptiveColor(
    day: Color(0xFFEEF2F7),
    night: Color(0xFF000000),
  );
  static const cardBg = _AdaptiveColor(
    day: Color(0xFFF8FBFF),
    night: Color(0xFF1A1A1A),
  );
  static const darkBg = _AdaptiveColor(
    day: Color(0xFFE3EAF3),
    night: Color(0xFF0A0A0A),
  );

  static const textPrimary = _AdaptiveColor(
    day: Color(0xFF101828),
    night: Color(0xFFFFFFFF),
  );
  static const textSecondary = _AdaptiveColor(
    day: Color(0xBF344054),
    night: Color(0x99FFFFFF),
  );
  static const textTertiary = _AdaptiveColor(
    day: Color(0x8A475467),
    night: Color(0x66FFFFFF),
  );
  static const textDisabled = _AdaptiveColor(
    day: Color(0x66475467),
    night: Color(0x33FFFFFF),
  );

  static const brandBlue = _AdaptiveColor(
    day: Color(0xFF2D6FD4),
    night: Color(0xFF4A90E2),
  );
  static const deepSeaBlue = _AdaptiveColor(
    day: Color(0xFF3F6996),
    night: Color(0xFF2E5C8A),
  );

  static const success = _AdaptiveColor(
    day: Color(0xFF278F44),
    night: Color(0xFF52C41A),
  );
  static const warning = _AdaptiveColor(
    day: Color(0xFFB97900),
    night: Color(0xFFFFAA00),
  );
  static const error = _AdaptiveColor(
    day: Color(0xFFD13F3F),
    night: Color(0xFFFF4D4F),
  );

  static const white05 = _AdaptiveColor(
    day: Color(0x140F172A),
    night: Color(0x0DFFFFFF),
  );
  static const white08 = _AdaptiveColor(
    day: Color(0x1F0F172A),
    night: Color(0x14FFFFFF),
  );
  static const white12 = _AdaptiveColor(
    day: Color(0x2B0F172A),
    night: Color(0x1FFFFFFF),
  );
  static const white15 = _AdaptiveColor(
    day: Color(0x330F172A),
    night: Color(0x26FFFFFF),
  );
  static const white20 = _AdaptiveColor(
    day: Color(0x3D0F172A),
    night: Color(0x33FFFFFF),
  );
}

class AppOverlay {
  static const BorderRadius sheetBorderRadius =
      BorderRadius.vertical(top: Radius.circular(24));
  static final BorderRadius dialogBorderRadius = BorderRadius.circular(22);

  static List<BoxShadow> get softShadow => const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 28,
          offset: Offset(0, -6),
        ),
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 10,
          offset: Offset(0, -2),
        ),
      ];

  static final AnimationStyle sheetAnimationStyle = AnimationStyle(
    duration: Duration(milliseconds: 280),
    reverseDuration: Duration(milliseconds: 220),
  );
}

class AppTheme {
  static ThemeData themeData({required bool isDay}) {
    AppThemeConfig.setDayTheme(false);
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.brandBlue,
      onPrimary: AppColors.pureBlack,
      secondary: AppColors.deepSeaBlue,
      onSecondary: AppColors.textPrimary,
      error: AppColors.error,
      onError: AppColors.pureBlack,
      surface: AppColors.cardBg,
      onSurface: AppColors.textPrimary,
    );

    return ThemeData(
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.pureBlack,
      primaryColor: AppColors.brandBlue,
      fontFamily: 'PingFang',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
          letterSpacing: 0.6,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: AppOverlay.dialogBorderRadius,
        ),
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppOverlay.sheetBorderRadius,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.cardBg.withValues(alpha: 0.96),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.white12),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w300,
          letterSpacing: 16,
          color: AppColors.textPrimary,
        ),
        displayMedium: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w300,
          letterSpacing: 8,
          color: AppColors.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w300,
          letterSpacing: 2,
          color: AppColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.3,
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.3,
          color: AppColors.textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.5,
          color: AppColors.textTertiary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.textPrimary,
          foregroundColor: AppColors.pureBlack,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            letterSpacing: 2,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white05,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.brandBlue),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: const TextStyle(
          color: AppColors.textTertiary,
          fontSize: 16,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }

  static ThemeData get darkTheme => themeData(isDay: false);

  static ThemeData get dayTheme => darkTheme;
}
