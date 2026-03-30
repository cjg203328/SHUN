import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../utils/media_reference_resolver.dart';

class AppUserAvatar extends StatelessWidget {
  const AppUserAvatar({
    super.key,
    required this.avatar,
    required this.textStyle,
    this.fit = BoxFit.cover,
  });

  final String? avatar;
  final TextStyle textStyle;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final normalizedAvatar = avatar?.trim();
    final mediaPath = _resolveMediaPath(normalizedAvatar);
    final fallbackText = _resolveFallbackText(normalizedAvatar);

    if (mediaPath == null) {
      return _buildFallbackText(
        fallbackText,
        key: const ValueKey<String>('app-user-avatar-text-fallback'),
      );
    }

    if (!isRemoteMediaReference(mediaPath)) {
      final localMediaFile = resolveLocalMediaFile(mediaPath);
      if (!localMediaFile.existsSync()) {
        return ClipOval(
          child: _buildMediaPlaceholder(
            fallbackText,
            key: const ValueKey<String>('app-user-avatar-error'),
            statusBadge: _buildErrorIndicator(),
          ),
        );
      }
    }

    final imageProvider = _buildImageProvider(mediaPath);

    return ClipOval(
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildMediaPlaceholder(
            fallbackText,
            key: const ValueKey<String>('app-user-avatar-loading'),
            statusBadge: SizedBox(
              key: const ValueKey<String>('app-user-avatar-loading-indicator'),
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.4,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.textTertiary.withValues(alpha: 0.78),
                ),
              ),
            ),
          ),
          Image(
            key: const ValueKey<String>('app-user-avatar-image'),
            image: imageProvider,
            fit: fit,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              final isReady = wasSynchronouslyLoaded || frame != null;
              return AnimatedOpacity(
                opacity: isReady ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: child,
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return _buildMediaPlaceholder(
                fallbackText,
                key: const ValueKey<String>('app-user-avatar-error'),
                statusBadge: _buildErrorIndicator(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPlaceholder(
    String fallbackText, {
    required Key key,
    required Widget statusBadge,
  }) {
    return DecoratedBox(
      key: key,
      decoration: BoxDecoration(
        color: AppColors.white05,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.white12.withValues(alpha: 0.18),
            AppColors.white05,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildFallbackText(fallbackText),
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: statusBadge,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackText(
    String fallbackText, {
    Key? key,
  }) {
    return Center(
      key: key,
      child: Text(
        fallbackText,
        style: textStyle,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildErrorIndicator() {
    return Container(
      key: const ValueKey<String>('app-user-avatar-error-indicator'),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.white12,
          width: 0.5,
        ),
      ),
      child: Icon(
        Icons.broken_image_outlined,
        size: 10,
        color: AppColors.textTertiary.withValues(alpha: 0.84),
      ),
    );
  }

  String? _resolveMediaPath(String? value) {
    if (value == null || value.isEmpty || !looksLikeMediaReference(value)) {
      return null;
    }
    return resolveDisplayMediaPath(value);
  }

  String _resolveFallbackText(String? value) {
    if (value == null || value.isEmpty || looksLikeMediaReference(value)) {
      return '\u{1F464}';
    }
    return value;
  }

  ImageProvider<Object> _buildImageProvider(String path) {
    if (isRemoteMediaReference(path)) {
      return NetworkImage(path);
    }
    return FileImage(resolveLocalMediaFile(path));
  }
}
