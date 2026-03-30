import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../utils/media_reference_resolver.dart';

class SettingsMediaPreviewSurface extends StatelessWidget {
  const SettingsMediaPreviewSurface({
    super.key,
    required this.mediaPath,
    required this.width,
    required this.height,
    required this.iconSize,
    required this.fallbackIcon,
    this.isCircular = false,
    this.borderRadius = 10,
  });

  final String? mediaPath;
  final double width;
  final double height;
  final double iconSize;
  final IconData fallbackIcon;
  final bool isCircular;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final previewImage = _buildMediaPreviewImageProvider(mediaPath);
    final fallback = Center(
      child: Icon(
        fallbackIcon,
        size: iconSize,
        color: AppColors.textTertiary,
      ),
    );

    final content = previewImage == null
        ? fallback
        : Image(
            image: previewImage,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallback,
          );

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircular ? null : BorderRadius.circular(borderRadius),
        color: AppColors.white08,
        border: Border.all(color: AppColors.white12),
      ),
      child: isCircular
          ? ClipOval(child: content)
          : ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: content,
            ),
    );
  }

  ImageProvider<Object>? _buildMediaPreviewImageProvider(String? mediaRef) {
    final resolvedPath = resolveRenderableMediaPath(mediaRef);
    if (resolvedPath == null) {
      return null;
    }
    if (isRemoteMediaReference(resolvedPath)) {
      return NetworkImage(resolvedPath);
    }
    return FileImage(resolveLocalMediaFile(resolvedPath));
  }
}
