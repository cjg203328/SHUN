import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../config/theme.dart';
import '../models/models.dart';

class ImageHelper {
  static final ImagePicker _picker = ImagePicker();
  
  /// 显示图片来源选择对话框（使用Dialog避免层级冲突）
  static Future<ImageSource?> showImageSourceSelector(BuildContext context) async {
    return await showDialog<ImageSource>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSourceItem(
                context,
                icon: Icons.camera_alt_outlined,
                text: '拍照',
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              _buildSourceItem(
                context,
                icon: Icons.photo_library_outlined,
                text: '从相册选择',
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
              _buildSourceItem(
                context,
                icon: Icons.close,
                text: '取消',
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  static Widget _buildSourceItem(
    BuildContext context, {
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 从相册选择图片
  static Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 4096,
        maxHeight: 4096,
      );
      
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('选择图片失败: $e');
      return null;
    }
  }
  
  /// 拍照获取图片
  static Future<File?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 4096,
        maxHeight: 4096,
      );
      
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('拍照失败: $e');
      return null;
    }
  }
  
  /// 压缩图片
  static Future<File> compressImage(
    File imageFile,
    ImageQuality quality,
  ) async {
    try {
      // 读取图片
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        return imageFile;
      }
      
      // 根据质量选择压缩参数
      img.Image resized;
      int jpegQuality;
      
      if (quality == ImageQuality.original) {
        // 原图：不压缩，只限制最大尺寸为4K
        if (image.width > 3840 || image.height > 2160) {
          resized = img.copyResize(
            image,
            width: image.width > image.height ? 3840 : null,
            height: image.height > image.width ? 2160 : null,
          );
        } else {
          resized = image;
        }
        jpegQuality = 95;
      } else {
        // 1080p：压缩到1920x1080
        if (image.width > 1920 || image.height > 1080) {
          resized = img.copyResize(
            image,
            width: image.width > image.height ? 1920 : null,
            height: image.height > image.width ? 1080 : null,
          );
        } else {
          resized = image;
        }
        jpegQuality = 85;
      }
      
      // 保存压缩后的图片
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final compressedPath = '${tempDir.path}/compressed_$timestamp.jpg';
      
      final compressedBytes = img.encodeJpg(resized, quality: jpegQuality);
      final compressedFile = File(compressedPath);
      await compressedFile.writeAsBytes(compressedBytes);
      
      return compressedFile;
    } catch (e) {
      print('压缩图片失败: $e');
      return imageFile;
    }
  }
  
  /// 获取图片文件大小（MB）
  static Future<double> getImageSize(File imageFile) async {
    try {
      final bytes = await imageFile.length();
      return bytes / (1024 * 1024);
    } catch (e) {
      return 0;
    }
  }
  
  /// 显示图片质量选择对话框（使用Dialog避免层级冲突）
  static Future<ImageQuality?> showQualitySelector(
    BuildContext context,
    File imageFile,
  ) async {
    final originalSize = await getImageSize(imageFile);
    
    return await showDialog<ImageQuality>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '选择图片质量',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              
              // 1080p选项（推荐）
              _buildQualityOption(
                context,
                quality: ImageQuality.compressed,
                title: '1080p',
                subtitle: '推荐，适合快速发送',
                size: originalSize > 2 ? '约${(originalSize * 0.3).toStringAsFixed(1)}MB' : '小于1MB',
                isRecommended: true,
                onTap: () => Navigator.pop(context, ImageQuality.compressed),
              ),
              
              const SizedBox(height: 12),
              
              // 原图选项
              _buildQualityOption(
                context,
                quality: ImageQuality.original,
                title: '原图',
                subtitle: '保持原始质量',
                size: '${originalSize.toStringAsFixed(1)}MB',
                isRecommended: false,
                onTap: () => Navigator.pop(context, ImageQuality.original),
              ),
              
              const SizedBox(height: 24),
              
              // 取消按钮
              SizedBox(
                width: double.infinity,
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
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  static Widget _buildQualityOption(
    BuildContext context, {
    required ImageQuality quality,
    required String title,
    required String subtitle,
    required String size,
    required bool isRecommended,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white05,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRecommended 
                ? AppColors.brandBlue.withOpacity(0.3)
                : AppColors.white08,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandBlue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '推荐',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.brandBlue,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              size,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

