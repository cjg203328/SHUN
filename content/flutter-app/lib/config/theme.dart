import 'package:flutter/material.dart';

class AppColors {
  // 基础色
  static const pureBlack = Color(0xFF000000);
  static const cardBg = Color(0xFF1A1A1A);
  static const darkBg = Color(0xFF0A0A0A);
  
  // 文字色
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0x99FFFFFF);
  static const textTertiary = Color(0x66FFFFFF);
  static const textDisabled = Color(0x33FFFFFF);
  
  // 品牌色
  static const brandBlue = Color(0xFF4A90E2);
  static const deepSeaBlue = Color(0xFF2E5C8A);
  
  // 功能色
  static const success = Color(0xFF52C41A);
  static const warning = Color(0xFFFFAA00);
  static const error = Color(0xFFFF4D4F);
  
  // 半透明
  static const white05 = Color(0x0DFFFFFF);
  static const white08 = Color(0x14FFFFFF);
  static const white12 = Color(0x1FFFFFFF);
  static const white15 = Color(0x26FFFFFF);
  static const white20 = Color(0x33FFFFFF);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.pureBlack,
      primaryColor: AppColors.brandBlue,
      fontFamily: 'PingFang',
      
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: const TextStyle(
          color: AppColors.textTertiary,
          fontSize: 16,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }
}


