import 'media_reference_resolver.dart';

class ResolvedMediaPreviewState {
  const ResolvedMediaPreviewState({
    this.mediaPath,
    this.hasMedia = false,
    this.isRemote = false,
  });

  final String? mediaPath;
  final bool hasMedia;
  final bool isRemote;
}

ResolvedMediaPreviewState resolveMediaPreviewState(String? mediaPath) {
  final resolvedPath = resolveRenderableMediaPath(mediaPath);
  if (resolvedPath == null) {
    return const ResolvedMediaPreviewState();
  }

  return ResolvedMediaPreviewState(
    mediaPath: resolvedPath,
    hasMedia: true,
    isRemote: isRemoteMediaReference(resolvedPath),
  );
}
