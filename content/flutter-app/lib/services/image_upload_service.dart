import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';
import '../core/feedback/app_feedback.dart';
import '../utils/permission_manager.dart';

class ImageUploadService {
  static final ImagePicker _picker = ImagePicker();

  // 存储键
  static const String _avatarPathKey = 'user_avatar_path';
  static const String _backgroundPathKey = 'user_background_path';

  /// 显示图片来源选择对话框（主流APP样式）
  static Future<ImageSource?> showImageSourceDialog(
      BuildContext context) async {
    return await showDialog<ImageSource>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: AppOverlay.dialogBorderRadius,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                '选择图片',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),

            const Divider(height: 1, color: Color(0xFF2E2E2E)),

            // 拍照
            InkWell(
              onTap: () => Navigator.pop(context, ImageSource.camera),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 22,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '拍照',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: Color(0xFF2E2E2E)),

            // 从相册选择
            InkWell(
              onTap: () => Navigator.pop(context, ImageSource.gallery),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 22,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '从相册选择',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: Color(0xFF2E2E2E)),

            // 取消
            InkWell(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  '取消',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 选择头像（完整流程）
  static Future<File?> pickAvatar(BuildContext context) async {
    // 1. 显示来源选择
    final source = await showImageSourceDialog(context);
    if (!context.mounted) return null;
    if (source == null) return null;

    // 2. 请求权限
    bool hasPermission = false;
    if (source == ImageSource.camera) {
      hasPermission = await PermissionManager.requestCameraPermission(
        context,
        purpose: '拍摄照片设置头像',
      );
    } else {
      hasPermission = await PermissionManager.requestPhotosPermission(
        context,
        purpose: '从相册选择照片设置头像',
      );
    }

    if (!hasPermission) {
      if (context.mounted) {
        AppFeedback.showError(context, AppErrorCode.permissionDenied);
      }
      return null;
    }

    // 3. 选择图片
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );

      if (image == null) return null;

      // 4. 保存到应用目录
      final savedFile = await _saveToAppDirectory(File(image.path), 'avatar');

      // 5. 持久化存储路径
      await _saveAvatarPath(savedFile.path);

      return savedFile;
    } catch (e) {
      debugPrint('选择头像失败: $e');
      if (context.mounted) {
        AppFeedback.showError(context, AppErrorCode.unknown);
      }
      return null;
    }
  }

  /// 选择背景图片（完整流程）
  static Future<File?> pickBackground(BuildContext context) async {
    // 1. 显示来源选择
    final source = await showImageSourceDialog(context);
    if (!context.mounted) return null;
    if (source == null) return null;

    // 2. 请求权限
    bool hasPermission = false;
    if (source == ImageSource.camera) {
      hasPermission = await PermissionManager.requestCameraPermission(
        context,
        purpose: '拍摄照片设置主页背景',
      );
    } else {
      hasPermission = await PermissionManager.requestPhotosPermission(
        context,
        purpose: '从相册选择图片设置主页背景',
      );
    }

    if (!hasPermission) {
      if (context.mounted) {
        AppFeedback.showError(context, AppErrorCode.permissionDenied);
      }
      return null;
    }

    // 3. 选择图片
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return null;

      // 4. 保存到应用目录
      final savedFile =
          await _saveToAppDirectory(File(image.path), 'background');

      // 5. 持久化存储路径
      await _saveBackgroundPath(savedFile.path);

      return savedFile;
    } catch (e) {
      debugPrint('选择背景失败: $e');
      if (context.mounted) {
        AppFeedback.showError(context, AppErrorCode.unknown);
      }
      return null;
    }
  }

  /// 保存图片到应用目录
  static Future<File> _saveToAppDirectory(File sourceFile, String type) async {
    final appDir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${type}_$timestamp.jpg';
    final targetPath = '${appDir.path}/$fileName';

    // 复制文件
    final targetFile = await sourceFile.copy(targetPath);

    // 删除旧文件（如果存在）
    if (type == 'avatar') {
      final oldPath = await getAvatarPath();
      if (oldPath != null) {
        try {
          await File(oldPath).delete();
        } catch (e) {
          debugPrint('删除旧头像失败: $e');
        }
      }
    } else if (type == 'background') {
      final oldPath = await getBackgroundPath();
      if (oldPath != null) {
        try {
          await File(oldPath).delete();
        } catch (e) {
          debugPrint('删除旧背景失败: $e');
        }
      }
    }

    return targetFile;
  }

  /// 保存头像路径
  static Future<void> _saveAvatarPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarPathKey, path);
  }

  /// 保存背景路径
  static Future<void> _saveBackgroundPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backgroundPathKey, path);
  }

  /// 获取头像路径
  static Future<String?> getAvatarPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_avatarPathKey);
  }

  /// 获取背景路径
  static Future<String?> getBackgroundPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_backgroundPathKey);
  }

  /// 清除头像
  static Future<void> clearAvatar() async {
    final path = await getAvatarPath();
    if (path != null) {
      try {
        await File(path).delete();
      } catch (e) {
        debugPrint('删除头像失败: $e');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_avatarPathKey);
  }

  /// 清除背景
  static Future<void> clearBackground() async {
    final path = await getBackgroundPath();
    if (path != null) {
      try {
        await File(path).delete();
      } catch (e) {
        debugPrint('删除背景失败: $e');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_backgroundPathKey);
  }

  /// 检查文件是否存在
  static Future<bool> avatarExists() async {
    final path = await getAvatarPath();
    if (path == null) return false;
    return await File(path).exists();
  }

  /// 检查背景是否存在
  static Future<bool> backgroundExists() async {
    final path = await getBackgroundPath();
    if (path == null) return false;
    return await File(path).exists();
  }
}
