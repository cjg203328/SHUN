import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/theme.dart';

class PermissionManager {
  // 会话级别的位置权限缓存（内存中，不持久化）
  static bool? _sessionLocationPermission;

  // 检查本次会话是否已请求过位置权限
  static bool hasSessionLocationPermission() {
    return _sessionLocationPermission != null;
  }

  // 获取本次会话的位置权限状态
  static bool? getSessionLocationPermission() {
    return _sessionLocationPermission;
  }

  // 保存本次会话的位置权限状态
  static void setSessionLocationPermission(bool granted) {
    _sessionLocationPermission = granted;
  }

  // 清除会话缓存（退出登录或杀后台时自动清除）
  static void clearSessionCache() {
    _sessionLocationPermission = null;
  }

  // 检查并请求通知权限
  static Future<bool> requestNotificationPermission(
      BuildContext context) async {
    final status = await Permission.notification.status;
    if (!context.mounted) return false;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      final shouldRequest = await _showPermissionDialog(
        context,
        title: '开启通知权限',
        content: '开启通知后，你可以及时收到新消息提醒',
        icon: Icons.notifications_outlined,
      );

      if (shouldRequest == true) {
        final result = await Permission.notification.request();
        return result.isGranted;
      }
    }

    if (status.isPermanentlyDenied) {
      if (!context.mounted) return false;
      await _showGoToSettingsDialog(
        context,
        title: '通知权限已关闭',
        content: '请在系统设置中开启通知权限，以便及时收到消息提醒',
      );
    }

    return false;
  }

  // 检查并请求相机权限
  static Future<bool> requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.status;
    if (!context.mounted) return false;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      final shouldRequest = await _showPermissionDialog(
        context,
        title: '开启相机权限',
        content: '开启相机权限后，你可以拍摄照片设置头像',
        icon: Icons.camera_alt_outlined,
      );

      if (shouldRequest == true) {
        final result = await Permission.camera.request();
        return result.isGranted;
      }
    }

    if (status.isPermanentlyDenied) {
      if (!context.mounted) return false;
      await _showGoToSettingsDialog(
        context,
        title: '相机权限已关闭',
        content: '请在系统设置中开启相机权限',
      );
    }

    return false;
  }

  // 检查并请求相册权限
  static Future<bool> requestPhotosPermission(BuildContext context) async {
    final status = Platform.isAndroid
        ? await Permission.photos.status
        : await Permission.photos.status;
    final storageStatus =
        Platform.isAndroid ? await Permission.storage.status : null;
    if (!context.mounted) return false;

    if (status.isGranted || (storageStatus?.isGranted ?? false)) {
      return true;
    }

    if (status.isDenied || (storageStatus?.isDenied ?? false)) {
      final shouldRequest = await _showPermissionDialog(
        context,
        title: '开启相册权限',
        content: '开启相册权限后，你可以从相册选择照片设置头像',
        icon: Icons.photo_library_outlined,
      );

      if (shouldRequest == true) {
        final result = await Permission.photos.request();
        if (result.isGranted) {
          return true;
        }

        // Android 12及以下通常使用存储权限兜底
        if (Platform.isAndroid) {
          final storageResult = await Permission.storage.request();
          return storageResult.isGranted;
        }
      }
    }

    if (status.isPermanentlyDenied ||
        (storageStatus?.isPermanentlyDenied ?? false)) {
      if (!context.mounted) return false;
      await _showGoToSettingsDialog(
        context,
        title: '相册权限已关闭',
        content: '请在系统设置中开启相册权限',
      );
    }

    return false;
  }

  // 检查并请求麦克风权限
  static Future<bool> requestMicrophonePermission(BuildContext context) async {
    final status = await Permission.microphone.status;
    if (!context.mounted) return false;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      final shouldRequest = await _showPermissionDialog(
        context,
        title: '开启麦克风权限',
        content: '开启麦克风权限后，你可以进行语音通话',
        icon: Icons.mic_outlined,
      );

      if (shouldRequest == true) {
        final result = await Permission.microphone.request();
        return result.isGranted;
      }
    }

    if (status.isPermanentlyDenied) {
      if (!context.mounted) return false;
      await _showGoToSettingsDialog(
        context,
        title: '麦克风权限已关闭',
        content: '请在系统设置中开启麦克风权限',
      );
    }

    return false;
  }

  // 检查并请求存储权限
  static Future<bool> requestStoragePermission(BuildContext context) async {
    final status = await Permission.storage.status;
    if (!context.mounted) return false;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      final shouldRequest = await _showPermissionDialog(
        context,
        title: '开启存储权限',
        content: '开启存储权限后，你可以保存图片和文件',
        icon: Icons.folder_outlined,
      );

      if (shouldRequest == true) {
        final result = await Permission.storage.request();
        return result.isGranted;
      }
    }

    if (status.isPermanentlyDenied) {
      if (!context.mounted) return false;
      await _showGoToSettingsDialog(
        context,
        title: '存储权限已关闭',
        content: '请在系统设置中开启存储权限',
      );
    }

    return false;
  }

  // 位置权限（会话级别缓存，杀后台后重新请求）
  static Future<bool> requestLocationPermission(BuildContext context,
      {bool forceRequest = false}) async {
    // 如果不是强制请求，先检查会话缓存
    if (!forceRequest && hasSessionLocationPermission()) {
      final cachedPermission = getSessionLocationPermission();
      if (cachedPermission == true) {
        // 本次会话已授权，直接返回
        return true;
      } else if (cachedPermission == false) {
        // 本次会话已拒绝，不再弹窗
        return false;
      }
    }

    // 首次请求，显示位置选择弹窗
    final shouldUseLocation = await _showLocationSelectionDialog(context);
    if (!context.mounted) return false;

    if (!shouldUseLocation) {
      // 用户选择不使用位置，保存到会话缓存
      setSessionLocationPermission(false);
      return false;
    }

    // 用户同意使用位置后，检查系统权限
    final status = await Permission.location.status;
    if (!context.mounted) return false;

    if (status.isGranted) {
      // 已授权，保存到会话缓存
      setSessionLocationPermission(true);
      return true;
    }

    if (status.isDenied) {
      final result = await Permission.location.request();
      final granted = result.isGranted;
      // 保存授权结果到会话缓存
      setSessionLocationPermission(granted);
      return granted;
    }

    if (status.isPermanentlyDenied) {
      await _showGoToSettingsDialog(
        context,
        title: '位置权限已关闭',
        content: '请在系统设置中开启位置权限，以便为你匹配附近的人',
      );
      setSessionLocationPermission(false);
      return false;
    }

    return false;
  }

  // 显示权限请求对话框（使用Dialog替代BottomSheet避免层级冲突）
  static Future<bool?> _showPermissionDialog(
    BuildContext context, {
    required String title,
    required String content,
    required IconData icon,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: AppOverlay.dialogBorderRadius,
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.brandBlue.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 40,
                    color: AppColors.brandBlue,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textSecondary,
                    height: 1.6,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppColors.white05,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '暂不开启',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w300,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor:
                              AppColors.brandBlue.withValues(alpha: 0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '去开启',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w300,
                            color: AppColors.brandBlue,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 显示跳转设置对话框（使用Dialog替代BottomSheet避免层级冲突）
  static Future<void> _showGoToSettingsDialog(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: AppOverlay.dialogBorderRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.settings_outlined,
                  size: 40,
                  color: AppColors.error,
                ),
              ),

              const SizedBox(height: 24),

              // 标题
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // 内容
              Text(
                content,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textSecondary,
                  height: 1.6,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // 按钮
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.white05,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w300,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        openAppSettings();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor:
                            AppColors.brandBlue.withValues(alpha: 0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '去设置',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w300,
                          color: AppColors.brandBlue,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 显示位置选择对话框（首次登录时显示，使用Dialog避免层级冲突）
  static Future<bool> _showLocationSelectionDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: AppOverlay.dialogBorderRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.brandBlue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  size: 40,
                  color: AppColors.brandBlue,
                ),
              ),

              const SizedBox(height: 24),

              // 标题
              const Text(
                '使用你的位置信息',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // 内容
              const Text(
                '开启位置权限后，可以优先为你匹配附近的人\n\n位置信息仅用于匹配，不会被分享给他人',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textSecondary,
                  height: 1.6,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // 按钮
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.white05,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '暂不使用',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w300,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor:
                            AppColors.brandBlue.withValues(alpha: 0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '使用位置',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w300,
                          color: AppColors.brandBlue,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return result ?? false;
  }
}
