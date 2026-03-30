import 'dart:io';

import '../config/app_env.dart';

bool looksLikeMediaReference(String mediaRef) {
  final normalized = mediaRef.trim();
  if (normalized.isEmpty) {
    return false;
  }
  if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
    return true;
  }
  if (normalized.startsWith('file://')) {
    return true;
  }
  if (normalized.startsWith('avatar/') ||
      normalized.startsWith('background/') ||
      normalized.startsWith('chat/')) {
    return true;
  }
  if (normalized.startsWith('/')) {
    return true;
  }
  final windowsDrivePattern = RegExp(r'^[A-Za-z]:[\\/]');
  return windowsDrivePattern.hasMatch(normalized);
}

bool isRemoteMediaReference(String mediaRef) {
  final normalized = mediaRef.trim();
  return normalized.startsWith('http://') ||
      normalized.startsWith('https://') ||
      normalized.startsWith('avatar/') ||
      normalized.startsWith('background/') ||
      normalized.startsWith('chat/');
}

String resolveDisplayMediaPath(String mediaRef) {
  return AppEnv.resolveMediaUrl(mediaRef.trim());
}

String? resolveRenderableMediaPath(String? mediaRef) {
  final normalized = mediaRef?.trim();
  if (normalized == null ||
      normalized.isEmpty ||
      !looksLikeMediaReference(normalized)) {
    return null;
  }

  final resolvedPath = resolveDisplayMediaPath(normalized);
  if (isRemoteMediaReference(resolvedPath)) {
    return resolvedPath;
  }

  final mediaFile = resolveLocalMediaFile(resolvedPath);
  if (!mediaFile.existsSync()) {
    return null;
  }

  return resolvedPath;
}

File resolveLocalMediaFile(String path) {
  if (path.startsWith('file://')) {
    return File.fromUri(Uri.parse(path));
  }
  return File(path);
}
