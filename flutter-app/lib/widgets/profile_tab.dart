import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/app_env.dart';
import '../config/theme.dart';
import '../core/feedback/app_feedback.dart';
import '../core/ui/ui_tokens.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/friend_provider.dart';
import '../providers/profile_provider.dart';
import '../services/image_upload_service.dart';
import '../services/media_upload_service.dart';
import '../services/profile_service.dart';
import 'app_toast.dart';

const Object _profileMediaStateUnchanged = Object();

class ProfileTab extends StatefulWidget {
  const ProfileTab({
    super.key,
    this.mediaUploadService,
  });

  final MediaUploadService? mediaUploadService;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  static const String _defaultStatus = '想找人聊聊';
  final ValueNotifier<_ProfileMediaState> _mediaStateNotifier =
      ValueNotifier(const _ProfileMediaState());
  final ValueNotifier<_ProfileInlineFeedbackState?> _inlineFeedbackNotifier =
      ValueNotifier(null);
  Timer? _inlineFeedbackTimer;
  final ValueNotifier<_ProfileIdentitySyncCueState?> _identitySyncCueNotifier =
      ValueNotifier(null);
  Timer? _identitySyncCueTimer;
  final ScrollController _scrollController = ScrollController();
  late final MediaUploadService _mediaUploadService;

  String? get _avatarPath => _mediaStateNotifier.value.avatarPath;

  String? get _backgroundPath => _mediaStateNotifier.value.backgroundPath;

  @override
  void initState() {
    super.initState();
    _mediaUploadService = widget.mediaUploadService ?? MediaUploadService();
    _loadImages();
  }

  @override
  void dispose() {
    _inlineFeedbackTimer?.cancel();
    _identitySyncCueTimer?.cancel();
    _mediaStateNotifier.dispose();
    _inlineFeedbackNotifier.dispose();
    _identitySyncCueNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadImages() async {
    final avatarPath = await ImageUploadService.getAvatarPath();
    final backgroundPath = await ImageUploadService.getBackgroundPath();

    if (mounted) {
      _setMediaState(
        avatarPath: avatarPath,
        backgroundPath: backgroundPath,
      );

      if (backgroundPath == null) {
        final profileProvider = context.read<ProfileProvider>();
        if (profileProvider.portraitFullscreenBackground ||
            profileProvider.transparentHomepage) {
          await profileProvider.updatePortraitFullscreenBackground(false);
        }
      }
    }
  }

  _ProfileIdentitySnapshot _captureIdentitySnapshot(BuildContext context) {
    final profileProvider = context.read<ProfileProvider>();
    final authProvider = context.read<AuthProvider>();
    return _ProfileIdentitySnapshot(
      phone: authProvider.phone ?? '',
      uid: authProvider.uid ?? '',
      nickname: profileProvider.nickname,
      status: profileProvider.status,
      signature: profileProvider.signature,
      avatarPath: _avatarPath ?? '',
      backgroundPath: _backgroundPath ?? '',
    );
  }

  Future<void> _openSettings(BuildContext context) async {
    final beforeSnapshot = _captureIdentitySnapshot(context);
    await context.push('/settings');
    if (!mounted) return;
    await _refreshIdentityStateAfterSettingsReturn(
      beforeSnapshot: beforeSnapshot,
    );
  }

  Future<void> _refreshIdentityStateAfterSettingsReturn({
    required _ProfileIdentitySnapshot beforeSnapshot,
  }) async {
    final profileProvider = context.read<ProfileProvider>();
    try {
      await Future.wait<void>([
        _loadImages(),
        profileProvider.refreshFromRemote(),
      ]);
    } catch (_) {
      await _loadImages();
    }

    if (!mounted) return;
    final afterSnapshot = _captureIdentitySnapshot(context);
    final syncState = _resolveSettingsReturnSyncState(
      before: beforeSnapshot,
      after: afterSnapshot,
    );
    if (syncState != null) {
      await _presentSettingsReturnSyncState(syncState);
    }
  }

  Future<void> _presentSettingsReturnSyncState(
    _ProfileSettingsReturnSyncState syncState,
  ) async {
    if (!syncState.shouldRefocusIdentityArea) {
      _showInlineFeedback(syncState.feedback);
      return;
    }

    final shouldShowSyncingCue = await _shouldRefocusIdentityArea();
    if (!mounted) return;

    if (shouldShowSyncingCue) {
      _showIdentitySyncCue(
        state: _ProfileIdentitySyncCueState.syncing,
        duration: null,
      );
      await _animateIdentityAreaToTop();
      if (!mounted) return;
      _showIdentitySyncCue(state: _ProfileIdentitySyncCueState.synced);
      await Future<void>.delayed(const Duration(milliseconds: 120));
    } else {
      _showIdentitySyncCue(state: _ProfileIdentitySyncCueState.synced);
    }

    if (!mounted) return;
    _showInlineFeedback(syncState.feedback);
  }

  _ProfileSettingsReturnSyncState? _resolveSettingsReturnSyncState({
    required _ProfileIdentitySnapshot before,
    required _ProfileIdentitySnapshot after,
  }) {
    final avatarChanged = before.avatarPath != after.avatarPath;
    final backgroundChanged = before.backgroundPath != after.backgroundPath;
    final nicknameChanged = before.nickname != after.nickname;
    final signatureChanged = before.signature != after.signature;
    final statusChanged = before.status != after.status;
    final phoneChanged = before.phone != after.phone;
    final uidChanged = before.uid != after.uid;

    final mediaChanged = avatarChanged || backgroundChanged;
    final textChanged = nicknameChanged || signatureChanged || statusChanged;
    final accountChanged = phoneChanged || uidChanged;

    if (!mediaChanged && !textChanged && !accountChanged) {
      return null;
    }

    if (mediaChanged && textChanged) {
      return const _ProfileSettingsReturnSyncState(
        shouldRefocusIdentityArea: true,
        feedback: _ProfileInlineFeedbackState(
          cardKey: Key('profile-settings-sync-hint'),
          icon: Icons.verified_user_outlined,
          title: '资料和展示已同步到首页',
          badgeLabel: '主页已刷新',
          description: '刚才在设置里改的头像、背景和资料内容，已经回到当前个人页。',
        ),
      );
    }

    if (avatarChanged && backgroundChanged) {
      return const _ProfileSettingsReturnSyncState(
        shouldRefocusIdentityArea: true,
        feedback: _ProfileInlineFeedbackState(
          cardKey: Key('profile-settings-sync-hint'),
          icon: Icons.verified_user_outlined,
          title: '头像和背景已同步到首页',
          badgeLabel: '展示已刷新',
          description: '刚才在设置里更新的头像和背景，已经回到当前个人页展示。',
        ),
      );
    }

    if (avatarChanged) {
      return const _ProfileSettingsReturnSyncState(
        shouldRefocusIdentityArea: true,
        feedback: _ProfileInlineFeedbackState(
          cardKey: Key('profile-settings-sync-hint'),
          icon: Icons.photo_camera_outlined,
          title: '头像已同步到首页',
          badgeLabel: '资料已刷新',
          description: '刚才在设置里更新的头像，已经回显到当前个人页和资料展示里。',
        ),
      );
    }

    if (backgroundChanged) {
      return const _ProfileSettingsReturnSyncState(
        shouldRefocusIdentityArea: true,
        feedback: _ProfileInlineFeedbackState(
          cardKey: Key('profile-settings-sync-hint'),
          icon: Icons.wallpaper_outlined,
          title: '背景已同步到首页',
          badgeLabel: '封面已刷新',
          description: '刚才在设置里调整的背景已经生效，当前首页看到的是最新封面。',
        ),
      );
    }

    if (textChanged) {
      return const _ProfileSettingsReturnSyncState(
        shouldRefocusIdentityArea: true,
        feedback: _ProfileInlineFeedbackState(
          cardKey: Key('profile-settings-sync-hint'),
          icon: Icons.person_outline,
          title: '个人资料已同步到首页',
          badgeLabel: '主页已刷新',
          description: '刚才在设置里修改的昵称、状态或签名，已经回到当前个人页。',
        ),
      );
    }

    return const _ProfileSettingsReturnSyncState(
      shouldRefocusIdentityArea: false,
      feedback: _ProfileInlineFeedbackState(
        cardKey: Key('profile-settings-sync-hint'),
        icon: Icons.verified_user_outlined,
        title: '账号设置已经更新',
        badgeLabel: '设置已同步',
        description: '账号与系统设置改动已经保存，当前首页展示保持不变。',
      ),
    );
  }

  Future<bool> _shouldRefocusIdentityArea() async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    if (!mounted || !_scrollController.hasClients) return false;
    return _scrollController.offset > 8;
  }

  Future<void> _animateIdentityAreaToTop() async {
    if (!mounted || !_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _setMediaState({
    Object? avatarPath = _profileMediaStateUnchanged,
    Object? backgroundPath = _profileMediaStateUnchanged,
  }) {
    final nextState = _mediaStateNotifier.value.copyWith(
      avatarPath: avatarPath,
      backgroundPath: backgroundPath,
    );
    if (nextState == _mediaStateNotifier.value) {
      return;
    }
    _mediaStateNotifier.value = nextState;
  }

  void _showInlineFeedback(
    _ProfileInlineFeedbackState state, {
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    _inlineFeedbackTimer?.cancel();
    _inlineFeedbackNotifier.value = state;
    _inlineFeedbackTimer = Timer(duration, () {
      if (!mounted) return;
      _inlineFeedbackNotifier.value = null;
    });
  }

  void _showIdentitySyncCue({
    required _ProfileIdentitySyncCueState state,
    Duration? duration = const Duration(milliseconds: 2200),
  }) {
    _identitySyncCueTimer?.cancel();
    _identitySyncCueNotifier.value = state;
    if (duration == null) {
      return;
    }
    _identitySyncCueTimer = Timer(duration, () {
      if (!mounted) return;
      _identitySyncCueNotifier.value = null;
    });
  }

  _ProfileInlineFeedbackState _buildSavedFeedback({
    required IconData icon,
    required String title,
    required String badgeLabel,
    required String description,
  }) {
    return _ProfileInlineFeedbackState(
      cardKey: const Key('profile-inline-feedback-card'),
      icon: icon,
      title: title,
      badgeLabel: badgeLabel,
      description: description,
    );
  }

  _ProfileInlineFeedbackState _buildFailedFeedback({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return _ProfileInlineFeedbackState(
      cardKey: const Key('profile-inline-feedback-card'),
      icon: icon,
      title: title,
      badgeLabel: '稍后重试',
      description: description,
      isHealthy: false,
    );
  }

  _ProfileInlineFeedbackState _buildMediaUpdatedFeedback({
    required bool isBackground,
    required String mediaRef,
  }) {
    final isRemoteReference = _isRemoteMediaReference(mediaRef);
    if (isBackground) {
      return _buildSavedFeedback(
        icon: Icons.wallpaper_outlined,
        title: '背景已经更新',
        badgeLabel: '氛围已刷新',
        description: isRemoteReference
            ? '新的背景已经走远端媒体链路保存，别人进入主页时会优先看到最新封面。'
            : '新的背景已经写回本地资料缓存，当前主页氛围会继续保持最新状态。',
      );
    }

    return _buildSavedFeedback(
      icon: Icons.photo_camera_outlined,
      title: '头像已经更新',
      badgeLabel: '资料已刷新',
      description: isRemoteReference
          ? '新的头像已经走远端媒体链路保存，消息列表和个人页会优先回显最新资料。'
          : '新的头像已经写回本地资料缓存，当前页面会继续保持最新资料。',
    );
  }

  bool _isRemoteMediaReference(String mediaRef) {
    final normalized = mediaRef.trim();
    return normalized.startsWith('http://') ||
        normalized.startsWith('https://') ||
        normalized.startsWith('avatar/') ||
        normalized.startsWith('background/');
  }

  void _disposeEditorController(TextEditingController controller) {
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 280), () {
        controller.dispose();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final isCompactScreen = screenSize.height < 760 || screenSize.width < 390;

    return Scaffold(
      backgroundColor: AppColors.pureBlack,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Consumer<ProfileProvider>(
            builder: (context, profileProvider, child) {
              return ValueListenableBuilder<_ProfileMediaState>(
                valueListenable: _mediaStateNotifier,
                builder: (context, mediaState, _) {
                  final screenHeight = constraints.maxHeight;
                  final backgroundPath = mediaState.backgroundPath;
                  final hasBackground = mediaState.hasBackground;
                  final isPortraitFullscreen = hasBackground &&
                      profileProvider.portraitFullscreenBackground;
                  final usesCompactIdentityPanel =
                      isCompactScreen && !isPortraitFullscreen;
                  final isTransparentBackground = isPortraitFullscreen &&
                      profileProvider.transparentHomepage;
                  final normalHeight = (screenHeight *
                          (usesCompactIdentityPanel
                              ? 0.30
                              : (isCompactScreen ? 0.34 : 0.52)))
                      .clamp(
                    usesCompactIdentityPanel
                        ? 164.0
                        : (isCompactScreen ? 192.0 : 320.0),
                    usesCompactIdentityPanel
                        ? 220.0
                        : (isCompactScreen ? 280.0 : 520.0),
                  );
                  final fullHeight = screenHeight - mediaQuery.padding.top;
                  final backgroundHeight =
                      isPortraitFullscreen ? fullHeight : normalHeight;
                  final profileTopOffset = isPortraitFullscreen
                      ? backgroundHeight * (isCompactScreen ? 0.4 : 0.5)
                      : backgroundHeight -
                          (usesCompactIdentityPanel
                              ? 60.0
                              : (isCompactScreen ? 34 : 62));
                  final pageHorizontalPadding = isCompactScreen ? 16.0 : 20.0;
                  final identityMaxWidth = usesCompactIdentityPanel
                      ? double.infinity
                      : (isCompactScreen ? 240.0 : 300.0);
                  final avatarSize = usesCompactIdentityPanel
                      ? 64.0
                      : (isCompactScreen ? 68.0 : 100.0);
                  final headerBottomPadding = usesCompactIdentityPanel
                      ? 8.0
                      : (isCompactScreen ? 16.0 : 40.0);
                  final identityGap = usesCompactIdentityPanel
                      ? 6.0
                      : (isCompactScreen ? 10.0 : 20.0);
                  final statusGap = usesCompactIdentityPanel
                      ? 8.0
                      : (isCompactScreen ? 12.0 : 24.0);
                  final listBottomInset = mediaQuery.padding.bottom +
                      (isPortraitFullscreen
                          ? 24.0
                          : (isCompactScreen ? 18.0 : 40.0));
                  final signatureText = profileProvider.signature.trim().isEmpty
                      ? '这个人很神秘，什么都没留下。'
                      : profileProvider.signature.trim();
                  final backgroundManagementSummary =
                      _resolveBackgroundManagementSummary(
                    hasMedia: hasBackground,
                  );
                  final contentMinHeight =
                      (constraints.maxHeight - listBottomInset).clamp(
                    0.0,
                    double.infinity,
                  );
                  return SingleChildScrollView(
                    key: const Key('profile-main-scroll'),
                    controller: _scrollController,
                    padding: EdgeInsets.only(bottom: listBottomInset),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: contentMinHeight),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Stack(
                            children: [
                              Semantics(
                                button: true,
                                label: backgroundManagementSummary
                                    .quickActionLabel,
                                child: Tooltip(
                                  message: backgroundManagementSummary
                                      .quickActionLabel,
                                  child: GestureDetector(
                                    onTap: _openBackgroundManagementSheet,
                                    behavior: HitTestBehavior.opaque,
                                    child: Container(
                                      key: const Key(
                                          'profile-background-surface'),
                                      height: backgroundHeight,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: AppColors.white08,
                                        image: backgroundPath != null
                                            ? DecorationImage(
                                                image: _buildImageProvider(
                                                    backgroundPath),
                                                fit: BoxFit.cover,
                                                alignment: isPortraitFullscreen
                                                    ? Alignment.topCenter
                                                    : Alignment.center,
                                              )
                                            : null,
                                      ),
                                      foregroundDecoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            AppColors.pureBlack.withValues(
                                              alpha: isTransparentBackground
                                                  ? 0.03
                                                  : 0.08,
                                            ),
                                            AppColors.pureBlack.withValues(
                                              alpha: isTransparentBackground
                                                  ? 0.16
                                                  : (isPortraitFullscreen
                                                      ? 0.3
                                                      : 0.4),
                                            ),
                                          ],
                                        ),
                                      ),
                                      child: backgroundPath == null
                                          ? Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .add_photo_alternate_outlined,
                                                    size: 40,
                                                    color: AppColors
                                                        .textTertiary
                                                        .withValues(alpha: 0.5),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    '点击设置背景',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: AppColors
                                                          .textTertiary
                                                          .withValues(
                                                              alpha: 0.5),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : Container(
                                              alignment: Alignment.topRight,
                                              padding: EdgeInsets.all(
                                                isCompactScreen ? 10 : 12,
                                              ),
                                              child: _buildMediaEditBadge(
                                                key: const Key(
                                                  'profile-background-edit-pill',
                                                ),
                                                icon: Icons.wallpaper_outlined,
                                                label: '编辑背景',
                                                isCompact: isCompactScreen,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                margin: EdgeInsets.only(top: profileTopOffset),
                                padding: EdgeInsets.fromLTRB(
                                  pageHorizontalPadding,
                                  0,
                                  pageHorizontalPadding,
                                  headerBottomPadding,
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    usesCompactIdentityPanel
                                        ? _buildCompactIdentityCard(
                                            context,
                                            profileProvider: profileProvider,
                                            signatureText: signatureText,
                                            avatarSize: avatarSize,
                                          )
                                        : Column(
                                            children: [
                                              // 头像
                                              _buildAvatarTrigger(
                                                profileProvider:
                                                    profileProvider,
                                                avatarSize: avatarSize,
                                                isCompact: isCompactScreen,
                                              ),

                                              SizedBox(height: identityGap),

                                              // 昵称
                                              Center(
                                                child: GestureDetector(
                                                  key: const Key(
                                                      'profile-nickname-trigger'),
                                                  onTap: () =>
                                                      _presentNicknameEditor(
                                                          context),
                                                  behavior:
                                                      HitTestBehavior.opaque,
                                                  child: ConstrainedBox(
                                                    constraints: BoxConstraints(
                                                      maxWidth:
                                                          identityMaxWidth,
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            profileProvider
                                                                .nickname,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 22,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w300,
                                                              color: AppColors
                                                                  .textPrimary,
                                                              letterSpacing: 1,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        const Icon(
                                                          Icons.edit,
                                                          size: 18,
                                                          color: AppColors
                                                              .textTertiary,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              const SizedBox(height: 8),

                                              Center(
                                                child: TextButton(
                                                  key: const Key(
                                                    'profile-signature-trigger',
                                                  ),
                                                  onPressed: () =>
                                                      _presentSignatureEditor(
                                                    context,
                                                  ),
                                                  style: TextButton.styleFrom(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    foregroundColor:
                                                        AppColors.textTertiary,
                                                  ),
                                                  child: ConstrainedBox(
                                                    constraints: BoxConstraints(
                                                      maxWidth:
                                                          identityMaxWidth,
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            signatureText,
                                                            maxLines: 2,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            textAlign: TextAlign
                                                                .center,
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w300,
                                                              color: AppColors
                                                                  .textTertiary,
                                                              height: 1.35,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 6),
                                                        const Padding(
                                                          padding:
                                                              EdgeInsets.only(
                                                                  top: 2),
                                                          child: Icon(
                                                            Icons.edit,
                                                            size: 14,
                                                            color: AppColors
                                                                .textTertiary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              SizedBox(height: statusGap),

                                              GestureDetector(
                                                key: const Key(
                                                  'profile-status-trigger',
                                                ),
                                                onTap: () =>
                                                    _presentStatusEditor(
                                                        context),
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: isCompactScreen
                                                        ? 16
                                                        : 20,
                                                    vertical: isCompactScreen
                                                        ? 10
                                                        : 12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        isTransparentBackground
                                                            ? AppColors.white15
                                                            : AppColors.white05,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                    border: Border.all(
                                                      color:
                                                          isTransparentBackground
                                                              ? AppColors
                                                                  .white15
                                                              : AppColors
                                                                  .white08,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    children: [
                                                      const Text(
                                                        '状态：',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: AppColors
                                                              .textTertiary,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          profileProvider
                                                              .status,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 13,
                                                            color: AppColors
                                                                .textSecondary,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      const Icon(
                                                        Icons.edit,
                                                        size: 14,
                                                        color: AppColors
                                                            .textTertiary,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                    Positioned(
                                      top: usesCompactIdentityPanel ? -10 : 6,
                                      right: usesCompactIdentityPanel ? 6 : 0,
                                      child: IgnorePointer(
                                        child: ValueListenableBuilder<
                                            _ProfileIdentitySyncCueState?>(
                                          valueListenable:
                                              _identitySyncCueNotifier,
                                          builder: (context,
                                              identitySyncCueState, _) {
                                            return AnimatedSwitcher(
                                              duration: const Duration(
                                                  milliseconds: 220),
                                              switchInCurve:
                                                  Curves.easeOutCubic,
                                              switchOutCurve:
                                                  Curves.easeInCubic,
                                              transitionBuilder:
                                                  (child, animation) {
                                                final curvedAnimation =
                                                    CurvedAnimation(
                                                  parent: animation,
                                                  curve: Curves.easeOutCubic,
                                                );
                                                return FadeTransition(
                                                  opacity: curvedAnimation,
                                                  child: ScaleTransition(
                                                    scale: Tween<double>(
                                                      begin: 0.96,
                                                      end: 1,
                                                    ).animate(curvedAnimation),
                                                    child: child,
                                                  ),
                                                );
                                              },
                                              child:
                                                  identitySyncCueState != null
                                                      ? KeyedSubtree(
                                                          key: ValueKey<
                                                                  _ProfileIdentitySyncCueState>(
                                                              identitySyncCueState),
                                                          child:
                                                              _buildIdentitySyncBadge(
                                                            isCompactScreen:
                                                                usesCompactIdentityPanel,
                                                            state:
                                                                identitySyncCueState,
                                                          ),
                                                        )
                                                      : const SizedBox.shrink(),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isPortraitFullscreen)
                                Positioned(
                                  top: mediaQuery.padding.top + 10,
                                  right: 14,
                                  child: _buildFullscreenActionRail(
                                    context,
                                  ),
                                ),
                            ],
                          ),
                          if (!isPortraitFullscreen)
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                pageHorizontalPadding,
                                usesCompactIdentityPanel ? 10 : 12,
                                pageHorizontalPadding,
                                0,
                              ),
                              child: Consumer2<FriendProvider, ChatProvider>(
                                builder: (context, friendProv, chatProv, _) {
                                  if (usesCompactIdentityPanel) {
                                    return _buildCompactStatsCard(
                                      friendCount: friendProv.friends.length,
                                      threadCount: chatProv.threads.length,
                                    );
                                  }
                                  return Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildStatItem(
                                          '好友', '${friendProv.friends.length}'),
                                      _buildStatDivider(),
                                      _buildStatItem(
                                          '会话', '${chatProv.threads.length}'),
                                    ],
                                  );
                                },
                              ),
                            ),
                          if (!isPortraitFullscreen)
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                pageHorizontalPadding,
                                0,
                                pageHorizontalPadding,
                                usesCompactIdentityPanel ? 12 : 16,
                              ),
                              child: _buildQuickActionsCard(
                                context,
                                hasBackground: hasBackground,
                                profileProvider: profileProvider,
                              ),
                            ),
                          SizedBox(
                            height: isPortraitFullscreen ? 0 : 4,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildQuickActionsCard(
    BuildContext context, {
    required bool hasBackground,
    required ProfileProvider profileProvider,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final isCompactScreen = screenSize.height < 760 || screenSize.width < 390;
    final avatarManagementSummary = _resolveAvatarManagementSummary(
      hasMedia: _hasAvatarMedia,
    );
    final backgroundManagementSummary = _resolveBackgroundManagementSummary(
      hasMedia: hasBackground,
    );
    final readinessState = _resolveReadinessState(
      hasBackground: hasBackground,
      profileProvider: profileProvider,
      isCompactScreen: isCompactScreen,
    );
    final checklistItems = _buildProfileChecklistItems(
      context,
      hasBackground: hasBackground,
      profileProvider: profileProvider,
    );
    final pendingCount = checklistItems.where((item) => !item.isReady).length;
    final description =
        isCompactScreen ? null : '先把头像、状态和背景整理到位，通知、账号与隐私设置放到下面继续处理。';

    return Container(
      key: const Key('profile-quick-actions-card'),
      padding: EdgeInsets.all(isCompactScreen ? 10 : 16),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(UiTokens.radiusMd),
        border: Border.all(color: AppColors.white08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '个人页快速整理',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isCompactScreen) ...[
                      const SizedBox(width: 8),
                      _buildCompactSettingsEntry(),
                    ],
                  ],
                ),
              ),
              if (!isCompactScreen) ...[
                const SizedBox(width: 8),
                Container(
                  key: const Key('profile-quick-actions-badge'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: pendingCount == 0
                        ? AppColors.white12
                        : AppColors.brandBlue.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: pendingCount == 0
                          ? AppColors.white12
                          : AppColors.brandBlue.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    pendingCount == 0 ? '已就绪' : '还差 $pendingCount 项',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w300,
                      color: pendingCount == 0
                          ? AppColors.textSecondary
                          : AppColors.brandBlue,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w300,
                color: AppColors.textTertiary.withValues(alpha: 0.92),
                height: 1.45,
              ),
            ),
          ],
          SizedBox(height: isCompactScreen ? 8 : 14),
          ValueListenableBuilder<_ProfileInlineFeedbackState?>(
            valueListenable: _inlineFeedbackNotifier,
            builder: (context, inlineFeedback, _) {
              if (inlineFeedback != null) {
                return _buildInlineFeedbackBanner(
                  inlineFeedback,
                  isCompactScreen: isCompactScreen,
                );
              }

              return _buildReadinessChip(
                readinessState,
                isCompactScreen: isCompactScreen,
              );
            },
          ),
          if (isCompactScreen) ...[
            const SizedBox(height: 6),
            _buildQuickActionsWrap(
              isCompactScreen: isCompactScreen,
              avatarManagementSummary: avatarManagementSummary,
              backgroundManagementSummary: backgroundManagementSummary,
            ),
          ],
          SizedBox(height: isCompactScreen ? 6 : 12),
          _buildProfileCompletionChecklist(
            hasBackground: hasBackground,
            profileProvider: profileProvider,
          ),
          if (!isCompactScreen) ...[
            const SizedBox(height: 12),
            _buildProfilePriorityActions(
              context,
              hasBackground: hasBackground,
              profileProvider: profileProvider,
            ),
          ],
          if (!isCompactScreen) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: isCompactScreen ? 8 : 10,
              runSpacing: isCompactScreen ? 8 : 10,
              children: [
                if (isCompactScreen)
                  _buildQuickActionButton(
                    key: const Key('profile-quick-avatar'),
                    icon: Icons.photo_camera_outlined,
                    label: avatarManagementSummary.quickActionLabel,
                    onTap: _openAvatarManagementSheet,
                  ),
                _buildQuickActionButton(
                  key: const Key('profile-quick-status'),
                  icon: Icons.chat_bubble_outline,
                  label: isCompactScreen ? '改状态' : '编辑状态',
                  onTap: () => _presentStatusEditor(context),
                ),
                if (!isCompactScreen)
                  _buildQuickActionButton(
                    key: const Key('profile-quick-avatar'),
                    icon: Icons.photo_camera_outlined,
                    label: avatarManagementSummary.quickActionLabel,
                    onTap: _openAvatarManagementSheet,
                  ),
                _buildQuickActionButton(
                  key: const Key('profile-quick-background-mode'),
                  icon: Icons.layers_outlined,
                  label: backgroundManagementSummary.quickActionLabel,
                  onTap: _openBackgroundManagementSheet,
                ),
              ],
            ),
          ],
          if (!isCompactScreen) ...[
            const SizedBox(height: 12),
            _buildSecondarySettingsEntry(isCompactScreen: isCompactScreen),
          ],
        ],
      ),
    );
  }

  Widget _buildReadinessChip(
    _ProfileReadinessState readinessState, {
    required bool isCompactScreen,
  }) {
    return Container(
      key: const Key('profile-readiness-chip'),
      padding: EdgeInsets.symmetric(
        horizontal: isCompactScreen ? 10 : 12,
        vertical: isCompactScreen ? 7 : 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.white08,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            readinessState.icon,
            size: 16,
            color: readinessState.isReady
                ? AppColors.textSecondary
                : AppColors.brandBlue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  readinessState.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (!isCompactScreen) ...[
                  const SizedBox(height: 4),
                  Text(
                    readinessState.subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textTertiary.withValues(alpha: 0.92),
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsWrap({
    required bool isCompactScreen,
    required _ProfileMediaManagementSummary avatarManagementSummary,
    required _ProfileMediaManagementSummary backgroundManagementSummary,
  }) {
    return Wrap(
      spacing: isCompactScreen ? 8 : 10,
      runSpacing: isCompactScreen ? 8 : 10,
      children: [
        if (isCompactScreen)
          _buildQuickActionButton(
            key: const Key('profile-quick-avatar'),
            icon: Icons.photo_camera_outlined,
            label: avatarManagementSummary.quickActionLabel,
            onTap: _openAvatarManagementSheet,
          ),
        _buildQuickActionButton(
          key: const Key('profile-quick-status'),
          icon: Icons.chat_bubble_outline,
          label: isCompactScreen ? '改状态' : '编辑状态',
          onTap: () => _presentStatusEditor(context),
        ),
        if (!isCompactScreen)
          _buildQuickActionButton(
            key: const Key('profile-quick-avatar'),
            icon: Icons.photo_camera_outlined,
            label: avatarManagementSummary.quickActionLabel,
            onTap: _openAvatarManagementSheet,
          ),
        _buildQuickActionButton(
          key: const Key('profile-quick-background-mode'),
          icon: Icons.layers_outlined,
          label: backgroundManagementSummary.quickActionLabel,
          onTap: _openBackgroundManagementSheet,
        ),
      ],
    );
  }

  Widget _buildCompactSettingsEntry() {
    return Semantics(
      button: true,
      label: '更多设置',
      child: InkWell(
        key: const Key('profile-quick-settings'),
        onTap: () => _openSettings(context),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 36,
            minWidth: 84,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.white08,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.settings_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 5),
              Text(
                '更多设置',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondarySettingsEntry({
    required bool isCompactScreen,
  }) {
    return InkWell(
      key: const Key('profile-quick-settings'),
      onTap: () => _openSettings(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompactScreen ? 10 : 12,
          vertical: isCompactScreen ? 9 : 10,
        ),
        decoration: BoxDecoration(
          color: AppColors.white08,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.white12),
        ),
        child: Row(
          children: [
            Container(
              width: isCompactScreen ? 28 : 30,
              height: isCompactScreen ? 28 : 30,
              decoration: BoxDecoration(
                color: AppColors.white12,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.settings_outlined,
                size: isCompactScreen ? 16 : 17,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '更多设置',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isCompactScreen
                        ? '通知、隐私和账号安全去这里继续处理。'
                        : '通知、隐私、账号安全和系统级设置，统一去这里继续处理。',
                    style: TextStyle(
                      fontSize: isCompactScreen ? 10.5 : 11,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textTertiary.withValues(alpha: 0.92),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  List<_ProfileChecklistItem> _buildProfileChecklistItems(
    BuildContext context, {
    required bool hasBackground,
    required ProfileProvider profileProvider,
  }) {
    final signature = profileProvider.signature.trim();
    final hasCustomSignature = _hasCustomSignature(profileProvider);
    final currentStatus = profileProvider.status.trim().isEmpty
        ? _defaultStatus
        : profileProvider.status.trim();
    final hasCustomStatus = _hasCustomStatus(profileProvider);

    return [
      _ProfileChecklistItem(
        key: const Key('profile-check-signature'),
        priorityKey: const Key('profile-priority-signature'),
        icon: Icons.edit_note_outlined,
        label: '个性签名',
        summary: hasCustomSignature ? signature : '还在使用默认签名，建议换成更像你的短句。',
        isReady: hasCustomSignature,
        onTap: () => _presentSignatureEditor(context),
      ),
      _ProfileChecklistItem(
        key: const Key('profile-check-status'),
        priorityKey: const Key('profile-priority-status'),
        icon: Icons.chat_bubble_outline,
        label: '聊天状态',
        summary: hasCustomStatus
            ? currentStatus
            : '当前还在使用默认状态“$currentStatus”，可以换成更贴近你的聊天氛围。',
        isReady: hasCustomStatus,
        onTap: () => _presentStatusEditor(context),
      ),
      _ProfileChecklistItem(
        key: const Key('profile-check-background'),
        priorityKey: const Key('profile-priority-background'),
        icon: Icons.wallpaper_outlined,
        label: '背景图',
        summary: hasBackground
            ? '当前主页首屏已有背景图，可以继续调整封面或展示模式。'
            : '还没有背景图，先补一张会更容易建立第一印象。',
        isReady: hasBackground,
        onTap: _openBackgroundManagementSheet,
      ),
    ];
  }

  Widget _buildProfilePriorityActions(
    BuildContext context, {
    required bool hasBackground,
    required ProfileProvider profileProvider,
  }) {
    final pendingItems = _buildProfileChecklistItems(
      context,
      hasBackground: hasBackground,
      profileProvider: profileProvider,
    ).where((item) => !item.isReady).toList();

    if (pendingItems.isEmpty) {
      return Container(
        key: const Key('profile-priority-complete-hint'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white08,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.white12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.white12,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.verified_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '这三项都已就绪',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '想继续微调时，直接点上方完成清单即可，不用再在多个区域里找入口。',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textTertiary.withValues(alpha: 0.92),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '现在先补 ${pendingItems.length} 项',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '上面的完成清单用来看整体进度，这里只保留还没整理好的项目，避免来回扫两遍。',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w300,
            color: AppColors.textTertiary.withValues(alpha: 0.92),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        ...pendingItems.asMap().entries.map(
              (entry) => Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key == pendingItems.length - 1 ? 0 : 8,
                ),
                child: _buildPriorityActionTile(
                  key: entry.value.priorityKey,
                  icon: entry.value.icon,
                  title: entry.value.label,
                  summary: entry.value.summary,
                  badgeLabel: entry.value.priorityBadgeLabel,
                  highlight: true,
                  onTap: entry.value.onTap,
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildProfileCompletionChecklist({
    required bool hasBackground,
    required ProfileProvider profileProvider,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final isCompactScreen = screenSize.height < 760 || screenSize.width < 390;
    final items = _buildProfileChecklistItems(
      context,
      hasBackground: hasBackground,
      profileProvider: profileProvider,
    );
    final pendingCount = items.where((item) => !item.isReady).length;

    return Container(
      key: const Key('profile-completion-checklist'),
      padding: EdgeInsets.all(isCompactScreen ? 9 : 12),
      decoration: BoxDecoration(
        color: AppColors.white08,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '个人页完成清单',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
            ),
          ),
          if (!isCompactScreen) ...[
            const SizedBox(height: 4),
            Text(
              pendingCount == 0
                  ? '这三项都已就绪，点点标签就可以继续微调展示效果。'
                  : '先看进度；未完成项会在下方继续展开成可操作卡片，已就绪的项目也可以直接点标签微调。',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w300,
                color: AppColors.textTertiary.withValues(alpha: 0.92),
                height: 1.4,
              ),
            ),
          ],
          SizedBox(height: isCompactScreen ? 8 : 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map(_buildChecklistChip).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistChip(_ProfileChecklistItem item) {
    final screenSize = MediaQuery.of(context).size;
    final isCompactScreen = screenSize.height < 760 || screenSize.width < 390;
    final foregroundColor =
        item.isReady ? AppColors.textSecondary : AppColors.brandBlue;
    return Semantics(
      button: true,
      label: item.semanticsLabel,
      child: InkWell(
        key: item.key,
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompactScreen ? 9 : 10,
            vertical: isCompactScreen ? 7 : 8,
          ),
          decoration: BoxDecoration(
            color: item.isReady
                ? AppColors.white12
                : AppColors.brandBlue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: item.isReady
                  ? AppColors.white12
                  : AppColors.brandBlue.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                item.isReady
                    ? Icons.check_circle_outline
                    : Icons.radio_button_unchecked,
                size: 14,
                color: foregroundColor,
              ),
              const SizedBox(width: 6),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: isCompactScreen ? 10.5 : 11,
                  fontWeight: FontWeight.w300,
                  color: foregroundColor,
                ),
              ),
              if (!isCompactScreen) ...[
                const SizedBox(width: 6),
                Text(
                  item.checklistActionLabel,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w300,
                    color: foregroundColor.withValues(
                      alpha: item.isReady ? 0.9 : 0.98,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineFeedbackBanner(
    _ProfileInlineFeedbackState state, {
    required bool isCompactScreen,
  }) {
    final accentColor =
        state.isHealthy ? AppColors.textSecondary : AppColors.brandBlue;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: state.cardKey,
        padding: EdgeInsets.symmetric(
          horizontal: isCompactScreen ? 10 : 12,
          vertical: isCompactScreen ? 9 : 10,
        ),
        decoration: BoxDecoration(
          color: state.isHealthy
              ? AppColors.white08
              : AppColors.brandBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: state.isHealthy
                ? AppColors.white12
                : AppColors.brandBlue.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: isCompactScreen ? 24 : 28,
              height: isCompactScreen ? 24 : 28,
              decoration: BoxDecoration(
                color: state.isHealthy
                    ? AppColors.white12
                    : AppColors.brandBlue.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(isCompactScreen ? 8 : 10),
              ),
              child: Icon(
                state.icon,
                size: isCompactScreen ? 14 : 16,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          state.title,
                          key: const Key('profile-inline-feedback-title'),
                          style: TextStyle(
                            fontSize: isCompactScreen ? 12 : 12.5,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompactScreen ? 7 : 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: state.isHealthy
                              ? AppColors.white12
                              : AppColors.brandBlue.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: state.isHealthy
                                ? AppColors.white12
                                : AppColors.brandBlue.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Text(
                          state.badgeLabel,
                          key: const Key('profile-inline-feedback-badge'),
                          style: TextStyle(
                            fontSize: isCompactScreen ? 10 : 10.5,
                            fontWeight: FontWeight.w300,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!isCompactScreen) ...[
                    const SizedBox(height: 4),
                    Text(
                      state.description,
                      key: const Key('profile-inline-feedback-description'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w300,
                        color: AppColors.textTertiary.withValues(alpha: 0.92),
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentitySyncBadge({
    required bool isCompactScreen,
    required _ProfileIdentitySyncCueState state,
  }) {
    final isSyncing = state == _ProfileIdentitySyncCueState.syncing;
    final borderColor = isSyncing
        ? AppColors.white12
        : AppColors.brandBlue.withValues(alpha: 0.32);
    final iconColor = isSyncing ? AppColors.textSecondary : AppColors.brandBlue;
    final label = isSyncing ? '首页同步中' : '首页已同步';

    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('profile-identity-sync-badge'),
        padding: EdgeInsets.symmetric(
          horizontal: isCompactScreen ? 9 : 10,
          vertical: isCompactScreen ? 5 : 6,
        ),
        decoration: BoxDecoration(
          color: AppColors.pureBlack.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: (isSyncing ? AppColors.white12 : AppColors.brandBlue)
                  .withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSyncing ? Icons.sync_rounded : Icons.verified_outlined,
              key: Key(
                isSyncing
                    ? 'profile-identity-sync-progress-icon'
                    : 'profile-identity-sync-complete-icon',
              ),
              size: isCompactScreen ? 12 : 13,
              color: iconColor,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              key: const Key('profile-identity-sync-label'),
              style: TextStyle(
                fontSize: isCompactScreen ? 10.5 : 11,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _ProfileReadinessState _resolveReadinessState({
    required bool hasBackground,
    required ProfileProvider profileProvider,
    required bool isCompactScreen,
  }) {
    final hasCustomSignature = _hasCustomSignature(profileProvider);
    final hasCustomStatus = _hasCustomStatus(profileProvider);
    final completedCount = (hasBackground ? 1 : 0) +
        (hasCustomSignature ? 1 : 0) +
        (hasCustomStatus ? 1 : 0);

    if (completedCount >= 3) {
      return _ProfileReadinessState(
        icon: Icons.verified_outlined,
        title: '个人页已整理完成 3/3',
        subtitle: isCompactScreen
            ? '背景、签名和状态都已就绪，当前首屏已经足够完整。'
            : '背景、签名和状态都已经就绪，当前观感已经接近正式上线版本。',
        isReady: true,
      );
    }

    final missingLabels = <String>[
      if (!hasCustomSignature) '个性签名',
      if (!hasCustomStatus) '聊天状态',
      if (!hasBackground) '背景图',
    ];

    return _ProfileReadinessState(
      icon: Icons.auto_awesome_outlined,
      title: '个人页还差 ${3 - completedCount} 项细节',
      subtitle: isCompactScreen
          ? '优先补齐${missingLabels.join('、')}，首屏会更像真实可聊天的人。'
          : '建议优先补齐${missingLabels.join('、')}，这样第一眼信息会更完整，也更像真实可互动的人。',
    );
  }

  bool _hasCustomSignature(ProfileProvider profileProvider) {
    final signature = profileProvider.signature.trim();
    return signature.isNotEmpty && signature != ProfileService.defaultSignature;
  }

  bool _hasCustomStatus(ProfileProvider profileProvider) {
    final status = profileProvider.status.trim();
    return status.isNotEmpty && status != _defaultStatus;
  }

  Widget _buildQuickActionButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final isCompactScreen = screenSize.height < 760 || screenSize.width < 390;
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: BoxConstraints(
          minHeight: isCompactScreen ? 36 : 0,
          minWidth: isCompactScreen ? 88 : 0,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isCompactScreen ? 11 : 12,
          vertical: isCompactScreen ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: AppColors.white08,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: isCompactScreen ? 14 : 16,
              color: AppColors.textSecondary,
            ),
            SizedBox(width: isCompactScreen ? 5 : 8),
            Text(
              label,
              style: TextStyle(
                fontSize: isCompactScreen ? 11 : 12,
                fontWeight: FontWeight.w300,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaEditBadge({
    required Key key,
    required IconData icon,
    required String label,
    required bool isCompact,
  }) {
    if (isCompact) {
      return Container(
        key: key,
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.pureBlack.withValues(alpha: 0.58),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.white20),
        ),
        child: Icon(
          icon,
          size: 16,
          color: AppColors.textPrimary,
        ),
      );
    }

    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.pureBlack.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.white20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityActionTile({
    required Key key,
    required IconData icon,
    required String title,
    required String summary,
    required String badgeLabel,
    required bool highlight,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white08,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlight
                ? AppColors.brandBlue.withValues(alpha: 0.16)
                : AppColors.white12,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: highlight
                    ? AppColors.brandBlue.withValues(alpha: 0.12)
                    : AppColors.white05,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 18,
                color:
                    highlight ? AppColors.brandBlue : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: highlight
                              ? AppColors.brandBlue.withValues(alpha: 0.14)
                              : AppColors.white12,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: highlight
                                ? AppColors.brandBlue.withValues(alpha: 0.22)
                                : AppColors.white12,
                          ),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w300,
                            color: highlight
                                ? AppColors.brandBlue
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textTertiary.withValues(alpha: 0.92),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullscreenActionRail(BuildContext context) {
    return Container(
      key: const Key('profile-fullscreen-action-rail'),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.pureBlack.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.white12),
        boxShadow: [
          BoxShadow(
            color: AppColors.pureBlack.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFullscreenActionButton(
            key: const Key('profile-fullscreen-background-action'),
            icon: Icons.layers_outlined,
            label: '背景',
            onTap: _openBackgroundManagementSheet,
          ),
          const SizedBox(height: 6),
          _buildFullscreenActionButton(
            key: const Key('profile-fullscreen-settings-action'),
            icon: Icons.settings_outlined,
            label: '设置',
            onTap: () => _openSettings(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFullscreenActionButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(
            minWidth: 74,
            minHeight: 40,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.pureBlack.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactIdentityCard(
    BuildContext context, {
    required ProfileProvider profileProvider,
    required String signatureText,
    required double avatarSize,
  }) {
    return Container(
      key: const Key('profile-compact-identity-card'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.pureBlack.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.white12),
        boxShadow: [
          BoxShadow(
            color: AppColors.pureBlack.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatarTrigger(
            profileProvider: profileProvider,
            avatarSize: avatarSize,
            isCompact: true,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  key: const Key('profile-nickname-trigger'),
                  onTap: () => _presentNicknameEditor(context),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          profileProvider.nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.edit,
                        size: 15,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  key: const Key('profile-signature-trigger'),
                  onTap: () => _presentSignatureEditor(context),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            signatureText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w300,
                              color: AppColors.textTertiary,
                              height: 1.35,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 13,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  key: const Key('profile-status-trigger'),
                  onTap: () => _presentStatusEditor(context),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white08,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.white12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.brandBlue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            profileProvider.status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w300,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarTrigger({
    required ProfileProvider profileProvider,
    required double avatarSize,
    required bool isCompact,
  }) {
    final pillInset = avatarSize * 0.16;
    const pillVerticalPadding = 4.0;
    const pillIconSize = 12.0;
    const pillFontSize = 10.0;
    final fallbackFontSize = avatarSize * 0.46;

    return Semantics(
      button: true,
      label: _resolveAvatarManagementSummary(
        hasMedia: _hasAvatarMedia,
      ).quickActionLabel,
      child: Tooltip(
        message: _resolveAvatarManagementSummary(
          hasMedia: _hasAvatarMedia,
        ).quickActionLabel,
        child: GestureDetector(
          key: const Key('profile-avatar-trigger'),
          onTap: _openAvatarManagementSheet,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: avatarSize,
            height: avatarSize,
            child: Stack(
              children: [
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.white08,
                    border: Border.all(
                      color: AppColors.white20,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.pureBlack.withValues(alpha: 0.16),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _avatarPath != null
                        ? _buildProfileImage(
                            _avatarPath!,
                            profileProvider.avatar,
                          )
                        : Center(
                            child: Text(
                              profileProvider.avatar,
                              style: TextStyle(fontSize: fallbackFontSize),
                            ),
                          ),
                  ),
                ),
                if (isCompact)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: _buildMediaEditBadge(
                      key: const Key('profile-avatar-edit-pill'),
                      icon: Icons.photo_camera_outlined,
                      label: '编辑头像',
                      isCompact: true,
                    ),
                  )
                else
                  Positioned(
                    left: pillInset,
                    right: pillInset,
                    bottom: 8,
                    child: Container(
                      key: const Key('profile-avatar-edit-pill'),
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: pillVerticalPadding,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.pureBlack.withValues(alpha: 0.68),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.white20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: pillIconSize,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '编辑',
                            style: TextStyle(
                              fontSize: pillFontSize,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactStatsCard({
    required int friendCount,
    required int threadCount,
  }) {
    return Container(
      key: const Key('profile-stats-card'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white08),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem('好友', '$friendCount', isCompact: true),
          ),
          _buildStatDivider(),
          Expanded(
            child: _buildStatItem('会话', '$threadCount', isCompact: true),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value, {
    bool isCompact = false,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: double.tryParse(value) ?? 0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, animVal, _) {
        final displayValue =
            double.tryParse(value) != null ? animVal.round().toString() : value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayValue,
              style: TextStyle(
                fontSize: isCompact ? 17 : 18,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: isCompact ? 1.5 : 2),
            Text(
              label,
              style: TextStyle(
                fontSize: isCompact ? 10.5 : 11,
                fontWeight: FontWeight.w300,
                color: AppColors.textTertiary,
                letterSpacing: 0.4,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 28,
      color: AppColors.white08,
    );
  }

  bool get _hasAvatarMedia => (_avatarPath ?? '').trim().isNotEmpty;

  bool get _hasBackgroundMedia => (_backgroundPath ?? '').trim().isNotEmpty;

  _ProfileMediaManagementSummary _resolveAvatarManagementSummary({
    required bool hasMedia,
  }) {
    if (hasMedia) {
      return const _ProfileMediaManagementSummary(
        quickActionLabel: '头像管理',
        sheetDescription: '头像会持续出现在消息列表和个人页里，建议保持清晰、稳定、容易识别。',
        previewStatusLabel: '当前头像已经同步',
        previewBadgeLabel: '展示中',
        replaceActionLabel: '重新上传头像',
      );
    }

    return const _ProfileMediaManagementSummary(
      quickActionLabel: '补头像',
      sheetDescription: '头像会持续出现在消息列表和个人页里，先补一个清晰头像会更容易识别。',
      previewStatusLabel: '当前还在使用默认头像',
      previewBadgeLabel: '待补充',
      replaceActionLabel: '补一个头像',
    );
  }

  _ProfileMediaManagementSummary _resolveBackgroundManagementSummary({
    required bool hasMedia,
  }) {
    if (hasMedia) {
      return const _ProfileMediaManagementSummary(
        quickActionLabel: '背景管理',
        sheetDescription: '背景会影响别人进入你主页时的第一眼氛围，可以在这里调整封面和展示模式。',
        previewStatusLabel: '当前背景已经生效',
        previewBadgeLabel: '首屏展示中',
        replaceActionLabel: '重新上传背景',
      );
    }

    return const _ProfileMediaManagementSummary(
      quickActionLabel: '补背景',
      sheetDescription: '背景会影响别人进入你主页时的第一眼氛围，先补一张更有辨识度的封面。',
      previewStatusLabel: '当前还在使用默认背景',
      previewBadgeLabel: '待补充',
      replaceActionLabel: '补一张背景',
    );
  }

  Future<void> _openAvatarManagementSheet() async {
    final profileProvider = context.read<ProfileProvider>();
    final summary = _resolveAvatarManagementSummary(hasMedia: _hasAvatarMedia);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (sheetContext) => AppDialog.buildSheetSurface(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        child: Column(
          key: const Key('profile-avatar-management-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileSheetHeader(
              title: '头像管理',
              description: summary.sheetDescription,
            ),
            _buildAvatarManagementPreviewCard(
              profileProvider: profileProvider,
              summary: summary,
            ),
            const SizedBox(height: 14),
            _buildProfileManagementAction(
              key: const Key('profile-avatar-replace-action'),
              icon: Icons.photo_camera_outlined,
              title: summary.replaceActionLabel,
              onTap: () => _replaceAvatarFromManagementSheet(sheetContext),
            ),
            if (_hasAvatarMedia) ...[
              const SizedBox(height: 10),
              _buildProfileManagementAction(
                key: const Key('profile-avatar-delete-action'),
                icon: Icons.delete_outline,
                title: '删除头像',
                isDanger: true,
                onTap: () => _deleteAvatarFromManagementSheet(sheetContext),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openBackgroundManagementSheet() async {
    final summary =
        _resolveBackgroundManagementSummary(hasMedia: _hasBackgroundMedia);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (sheetContext) => AppDialog.buildSheetSurface(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        child: Column(
          key: const Key('profile-background-management-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileSheetHeader(
              title: '背景管理',
              description: summary.sheetDescription,
            ),
            _buildBackgroundManagementPreviewCard(summary: summary),
            const SizedBox(height: 14),
            _buildProfileManagementAction(
              key: const Key('profile-background-replace-action'),
              icon: Icons.wallpaper_outlined,
              title: summary.replaceActionLabel,
              onTap: () => _replaceBackgroundFromManagementSheet(sheetContext),
            ),
            if (_hasBackgroundMedia) ...[
              const SizedBox(height: 10),
              _buildProfileManagementAction(
                key: const Key('profile-background-mode-action'),
                icon: Icons.layers_outlined,
                title: '调整背景模式',
                onTap: () => _openBackgroundModeFromManagementSheet(
                  sheetContext,
                ),
              ),
              const SizedBox(height: 10),
              _buildProfileManagementAction(
                key: const Key('profile-background-delete-action'),
                icon: Icons.delete_outline,
                title: '删除背景',
                isDanger: true,
                onTap: () => _deleteBackgroundFromManagementSheet(sheetContext),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarManagementPreviewCard({
    required ProfileProvider profileProvider,
    required _ProfileMediaManagementSummary summary,
  }) {
    return Container(
      key: const Key('profile-avatar-management-preview'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white08),
      ),
      child: Row(
        children: [
          Container(
            key: const Key('profile-avatar-management-avatar'),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.white08,
              border: Border.all(color: AppColors.white12),
            ),
            child: ClipOval(
              child: _avatarPath != null
                  ? Image(
                      key: const Key('profile-avatar-management-image'),
                      image: _buildImageProvider(_avatarPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Text(
                            profileProvider.avatar,
                            style: const TextStyle(fontSize: 22),
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Text(
                        profileProvider.avatar,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              summary.previewStatusLabel,
              key: const Key('profile-avatar-management-status'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildProfileManagementBadge(
            key: const Key('profile-avatar-management-badge'),
            label: summary.previewBadgeLabel,
            highlight: _hasAvatarMedia,
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundManagementPreviewCard({
    required _ProfileMediaManagementSummary summary,
  }) {
    final previewImage =
        _backgroundPath != null ? _buildImageProvider(_backgroundPath!) : null;
    return Container(
      key: const Key('profile-background-management-preview'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white08),
      ),
      child: Row(
        children: [
          Container(
            key: const Key('profile-background-management-thumbnail'),
            width: 56,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.white08,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.white12),
              image: previewImage == null
                  ? null
                  : DecorationImage(
                      image: previewImage,
                      fit: BoxFit.cover,
                    ),
            ),
            child: previewImage == null
                ? const Icon(
                    Icons.wallpaper_outlined,
                    size: 18,
                    color: AppColors.textTertiary,
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              summary.previewStatusLabel,
              key: const Key('profile-background-management-status'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildProfileManagementBadge(
            key: const Key('profile-background-management-badge'),
            label: summary.previewBadgeLabel,
            highlight: _hasBackgroundMedia,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileManagementBadge({
    required Key key,
    required String label,
    required bool highlight,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.brandBlue.withValues(alpha: 0.14)
            : AppColors.white08,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlight
              ? AppColors.brandBlue.withValues(alpha: 0.22)
              : AppColors.white12,
        ),
      ),
      child: Text(
        key: key,
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w300,
          color: highlight ? AppColors.brandBlue : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildProfileManagementAction({
    required Key key,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white05,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.white08),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isDanger
                    ? AppColors.error.withValues(alpha: 0.1)
                    : AppColors.white08,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isDanger ? AppColors.error : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w300,
                  color: isDanger ? AppColors.error : AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: isDanger ? AppColors.error : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _replaceAvatarFromManagementSheet(
      BuildContext sheetContext) async {
    Navigator.pop(sheetContext);
    await _changeAvatar();
  }

  Future<void> _replaceBackgroundFromManagementSheet(
    BuildContext sheetContext,
  ) async {
    Navigator.pop(sheetContext);
    await _changeBackground();
  }

  void _openBackgroundModeFromManagementSheet(BuildContext sheetContext) {
    Navigator.pop(sheetContext);
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 220), () {
        if (!mounted) return;
        _showBackgroundModeSheet(context, hasBackground: true);
      }),
    );
  }

  Future<void> _deleteAvatarFromManagementSheet(
      BuildContext sheetContext) async {
    Navigator.pop(sheetContext);
    final confirm = await AppDialog.showConfirm(
      context,
      title: '确定要删除头像吗？',
      content: '删除后将恢复默认头像',
      isDanger: true,
    );
    if (confirm != true) {
      return;
    }

    await ImageUploadService.clearAvatar();
    if (!mounted) return;
    _setMediaState(avatarPath: null);
    _showInlineFeedback(
      _buildSavedFeedback(
        icon: Icons.delete_outline,
        title: '头像已恢复默认',
        badgeLabel: '已清空',
        description: '当前个人页会回到默认头像，如果之后想恢复识别度，可以再补一个新的头像。',
      ),
    );
    AppFeedback.showToast(context, AppToastCode.deleted, subject: '头像');
  }

  Future<void> _deleteBackgroundFromManagementSheet(
    BuildContext sheetContext,
  ) async {
    Navigator.pop(sheetContext);
    final confirm = await AppDialog.showConfirm(
      context,
      title: '确定要删除背景吗？',
      content: '删除后将恢复默认背景',
      isDanger: true,
    );
    if (confirm != true) {
      return;
    }

    if (!mounted) return;
    final profileProvider = context.read<ProfileProvider>();
    await ImageUploadService.clearBackground();
    if (profileProvider.portraitFullscreenBackground ||
        profileProvider.transparentHomepage) {
      await profileProvider.updatePortraitFullscreenBackground(false);
    }
    if (!mounted) return;
    _setMediaState(backgroundPath: null);
    _showInlineFeedback(
      _buildSavedFeedback(
        icon: Icons.delete_outline,
        title: '背景已恢复默认',
        badgeLabel: '已清空',
        description: '当前个人页首屏已经回到默认背景，后续如果想重新做区分度，可以再补一张新的封面。',
      ),
    );
    AppFeedback.showToast(context, AppToastCode.deleted, subject: '背景');
  }

  void _showBackgroundModeSheet(
    BuildContext context, {
    required bool hasBackground,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (context) => Consumer<ProfileProvider>(
        builder: (context, profileProvider, child) {
          final isPortraitFullscreen =
              hasBackground && profileProvider.portraitFullscreenBackground;
          final isTransparentBackground =
              isPortraitFullscreen && profileProvider.transparentHomepage;
          return AppDialog.buildSheetSurface(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModeSwitchRow(
                  icon: Icons.stay_current_portrait_outlined,
                  title: '竖屏全屏背景',
                  subtitle: hasBackground ? '按竖屏全屏展示背景图' : '先设置背景图后开启',
                  value: isPortraitFullscreen,
                  enabled: hasBackground,
                  onChanged: _setPortraitFullscreenBackground,
                ),
                const SizedBox(height: 8),
                _buildModeSwitchRow(
                  icon: Icons.layers_outlined,
                  title: '竖屏透明背景',
                  subtitle:
                      isPortraitFullscreen ? '降低遮罩，突出竖屏全屏背景' : '开启竖屏全屏背景后可设置',
                  value: isTransparentBackground,
                  enabled: isPortraitFullscreen,
                  onChanged: _setTransparentHomepage,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildModeSwitchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: enabled ? AppColors.textSecondary : AppColors.textDisabled,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: enabled
                        ? AppColors.textPrimary
                        : AppColors.textDisabled,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: enabled
                        ? AppColors.textTertiary
                        : AppColors.textDisabled.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.82,
            child: Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeColor: AppColors.textPrimary,
              activeTrackColor: AppColors.white20,
              inactiveThumbColor: AppColors.textSecondary,
              inactiveTrackColor: AppColors.white08,
            ),
          ),
        ],
      ),
    );
  }

  // 修改头像
  Future<void> _changeAvatar() async {
    final imageFile = await ImageUploadService.pickAvatar(context);

    if (imageFile == null || !mounted) return;

    try {
      final mediaRef = await _mediaUploadService.uploadUserMedia(
        'avatar',
        imageFile,
      );
      await ImageUploadService.saveAvatarReference(
        mediaRef,
        cleanupLocalPath: imageFile.path,
      );
      if (!mounted) return;
      _setMediaState(avatarPath: mediaRef);
      _showInlineFeedback(
        _buildMediaUpdatedFeedback(
          isBackground: false,
          mediaRef: mediaRef,
        ),
      );
      AppFeedback.showToast(context, AppToastCode.saved, subject: '头像');
    } catch (_) {
      if (!mounted) return;
      _showInlineFeedback(
        _buildFailedFeedback(
          icon: Icons.photo_camera_outlined,
          title: '头像更新失败',
          description: '这次没有成功保存新头像，可能是网络或上传链路波动，稍后再试一次会更稳。',
        ),
      );
      AppFeedback.showError(
        context,
        AppErrorCode.unknown,
        detail: '头像更新失败，请稍后重试',
      );
    }
  }

  // 修改背景
  Future<void> _changeBackground() async {
    final imageFile = await ImageUploadService.pickBackground(context);

    if (imageFile == null || !mounted) return;

    try {
      final mediaRef = await _mediaUploadService.uploadUserMedia(
        'background',
        imageFile,
      );
      await ImageUploadService.saveBackgroundReference(
        mediaRef,
        cleanupLocalPath: imageFile.path,
      );
      if (!mounted) return;
      _setMediaState(backgroundPath: mediaRef);
      _showInlineFeedback(
        _buildMediaUpdatedFeedback(
          isBackground: true,
          mediaRef: mediaRef,
        ),
      );
      AppFeedback.showToast(context, AppToastCode.saved, subject: '背景');
    } catch (_) {
      if (!mounted) return;
      _showInlineFeedback(
        _buildFailedFeedback(
          icon: Icons.wallpaper_outlined,
          title: '背景更新失败',
          description: '这次没有成功保存新背景，可能是网络或上传链路波动，稍后再试一次会更稳。',
        ),
      );
      AppFeedback.showError(
        context,
        AppErrorCode.unknown,
        detail: '背景更新失败，请稍后重试',
      );
    }
  }

  ImageProvider _buildImageProvider(String path) {
    final resolvedPath = _resolveDisplayMediaPath(path);
    if (_isNetworkMediaPath(resolvedPath)) {
      return NetworkImage(resolvedPath);
    }
    return FileImage(_resolveLocalMediaFile(resolvedPath));
  }

  Widget _buildProfileImage(String path, String fallbackAvatar) {
    final resolvedPath = _resolveDisplayMediaPath(path);
    if (_isNetworkMediaPath(resolvedPath)) {
      return Image.network(
        resolvedPath,
        key: const Key('profile-avatar-media'),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Text(
              fallbackAvatar,
              style: const TextStyle(fontSize: 48),
            ),
          );
        },
      );
    }

    return Image.file(
      _resolveLocalMediaFile(resolvedPath),
      key: const Key('profile-avatar-media'),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Text(
            fallbackAvatar,
            style: const TextStyle(fontSize: 48),
          ),
        );
      },
    );
  }

  String _resolveDisplayMediaPath(String path) {
    return AppEnv.resolveMediaUrl(path.trim());
  }

  bool _isNetworkMediaPath(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }

  File _resolveLocalMediaFile(String path) {
    if (path.startsWith('file://')) {
      return File.fromUri(Uri.parse(path));
    }
    return File(path);
  }

  Future<void> _setTransparentHomepage(bool value) async {
    await context.read<ProfileProvider>().updateTransparentHomepage(value);
    if (!mounted) return;
    AppFeedback.showToast(
      context,
      value ? AppToastCode.enabled : AppToastCode.disabled,
      subject: '竖屏透明背景',
    );
  }

  Future<void> _setPortraitFullscreenBackground(bool value) async {
    await context
        .read<ProfileProvider>()
        .updatePortraitFullscreenBackground(value);
    if (!mounted) return;
    AppFeedback.showToast(
      context,
      value ? AppToastCode.enabled : AppToastCode.disabled,
      subject: '竖屏全屏背景',
    );
  }

  Future<void> _presentNicknameEditor(BuildContext context) async {
    final profileProvider = context.read<ProfileProvider>();
    final controller = TextEditingController(text: profileProvider.nickname);
    final result = await _showProfileEditorSheet(
      context,
      sheetKey: const Key('profile-nickname-sheet'),
      title: '修改昵称',
      description: '推荐保留容易被记住的称呼，后续别人回看消息列表时更容易认出你。',
      hintText: '输入昵称',
      helperText: '建议 2~8 个字，避免纯符号或测试占位名。',
      controller: controller,
      maxLength: 12,
      previewTitle: '当前昵称',
      previewValue: profileProvider.nickname.trim(),
      previewBadgeLabel: '展示中',
      previewHighlight: true,
    );

    if (result == true && context.mounted) {
      final nickname = controller.text.trim();
      if (nickname.isNotEmpty) {
        await context.read<ProfileProvider>().updateNickname(nickname);
        if (context.mounted) {
          _showInlineFeedback(
            _buildSavedFeedback(
              icon: Icons.badge_outlined,
              title: '昵称已经更新',
              badgeLabel: '展示已刷新',
              description: '新的昵称已经写回当前资料卡，消息列表和个人页会优先显示最新称呼。',
            ),
          );
          AppFeedback.showToast(context, AppToastCode.saved, subject: '昵称');
        }
      }
    }

    _disposeEditorController(controller);
  }

  Future<void> _presentSignatureEditor(BuildContext context) async {
    final profileProvider = context.read<ProfileProvider>();
    final controller = TextEditingController(text: profileProvider.signature);
    final hasCustomSignature = _hasCustomSignature(profileProvider);
    final result = await _showProfileEditorSheet(
      context,
      sheetKey: const Key('profile-signature-sheet'),
      title: '个性签名',
      description: '一句短签名就够了，最好能让别人快速感受到你的状态和聊天气质。',
      hintText: '输入你的签名',
      helperText: '适合 10~24 个字，越具体越容易让人主动开口。',
      controller: controller,
      maxLength: 30,
      previewTitle: '当前签名',
      previewValue:
          hasCustomSignature ? profileProvider.signature.trim() : '当前使用默认签名',
      previewBadgeLabel: hasCustomSignature ? '已设置' : '默认',
      previewHighlight: hasCustomSignature,
    );

    if (result == true && context.mounted) {
      final signature = controller.text.trim();
      await context.read<ProfileProvider>().updateSignature(
            signature.isEmpty ? ProfileService.defaultSignature : signature,
          );
      if (context.mounted) {
        _showInlineFeedback(
          _buildSavedFeedback(
            icon: Icons.edit_note_outlined,
            title: '签名已经更新',
            badgeLabel: '展示已刷新',
            description: '新的签名已经写回当前资料卡，别人查看主页时会先看到这句新的自我介绍。',
          ),
        );
        AppFeedback.showToast(context, AppToastCode.saved, subject: '签名');
      }
    }

    _disposeEditorController(controller);
  }

  Future<void> _presentStatusEditor(BuildContext context) async {
    const statuses = <String>[
      _defaultStatus,
      '有点失眠',
      '心情不好',
      '分享快乐',
      '深夜emo',
      '随便聊聊',
    ];
    final profileProvider = context.read<ProfileProvider>();
    final currentStatus = profileProvider.status.trim().isEmpty
        ? _defaultStatus
        : profileProvider.status.trim();
    final hasCustomStatus = _hasCustomStatus(profileProvider);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (sheetContext) => LayoutBuilder(
        builder: (context, constraints) {
          final maxSheetHeight = constraints.maxHeight.isFinite
              ? (constraints.maxHeight - 48)
                  .clamp(0.0, double.infinity)
                  .toDouble()
              : MediaQuery.of(sheetContext).size.height * 0.72;
          return Container(
            key: const Key('profile-status-sheet'),
            child: AppDialog.buildSheetSurface(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxSheetHeight),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileSheetHeader(
                        title: '选择状态',
                        description: '状态会直接出现在个人页上，适合选一个能代表你当下聊天氛围的短句。',
                      ),
                      _buildProfileSheetPreviewCard(
                        key: const Key('profile-status-current-card'),
                        title: '当前状态',
                        value: currentStatus,
                        badgeLabel: hasCustomStatus ? '已设置' : '默认',
                        highlightBadge: hasCustomStatus,
                        valueKey: const Key('profile-status-current-value'),
                        badgeKey: const Key('profile-status-current-badge'),
                      ),
                      const SizedBox(height: 14),
                      ...statuses.asMap().entries.map(
                            (entry) => Padding(
                              padding: EdgeInsets.only(
                                bottom:
                                    entry.key == statuses.length - 1 ? 0 : 10,
                              ),
                              child: _buildStatusOptionTile(
                                sheetContext,
                                value: entry.value,
                                optionKey:
                                    Key('profile-status-option-${entry.key}'),
                                isSelected: entry.value == currentStatus,
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<bool?> _showProfileEditorSheet(
    BuildContext context, {
    required Key sheetKey,
    required String title,
    required String description,
    required String hintText,
    required String helperText,
    required TextEditingController controller,
    required int maxLength,
    String? previewTitle,
    String? previewValue,
    String? previewBadgeLabel,
    bool previewHighlight = false,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxSheetHeight = constraints.maxHeight.isFinite
                ? (constraints.maxHeight - 48)
                    .clamp(0.0, double.infinity)
                    .toDouble()
                : MediaQuery.of(sheetContext).size.height * 0.72;
            return Container(
              key: sheetKey,
              child: AppDialog.buildSheetSurface(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxSheetHeight),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileSheetHeader(
                          title: title,
                          description: description,
                        ),
                        if (previewTitle != null &&
                            previewValue != null &&
                            previewBadgeLabel != null) ...[
                          _buildProfileSheetPreviewCard(
                            key: const Key('profile-editor-preview-card'),
                            title: previewTitle,
                            value: previewValue,
                            badgeLabel: previewBadgeLabel,
                            highlightBadge: previewHighlight,
                            valueKey: const Key('profile-editor-preview-value'),
                            badgeKey: const Key('profile-editor-preview-badge'),
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextField(
                          key: const Key('profile-editor-input'),
                          controller: controller,
                          maxLength: maxLength,
                          autofocus: false,
                          decoration: InputDecoration(
                            hintText: hintText,
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          helperText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w300,
                            color: AppColors.textTertiary.withValues(
                              alpha: 0.9,
                            ),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                key: const Key('profile-editor-cancel'),
                                onPressed: () {
                                  FocusScope.of(sheetContext).unfocus();
                                  Navigator.pop(sheetContext, false);
                                },
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
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
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextButton(
                                key: const Key('profile-editor-save'),
                                onPressed: () {
                                  FocusScope.of(sheetContext).unfocus();
                                  Navigator.pop(sheetContext, true);
                                },
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: AppColors.white12,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  '保存',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w300,
                                    color: AppColors.textPrimary,
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
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusOptionTile(
    BuildContext context, {
    required String value,
    required Key optionKey,
    required bool isSelected,
  }) {
    return InkWell(
      key: optionKey,
      onTap: () async {
        Navigator.pop(context);
        await this.context.read<ProfileProvider>().updateStatus(value);
        if (mounted) {
          _showInlineFeedback(
            _buildSavedFeedback(
              icon: Icons.chat_bubble_outline,
              title: '状态已经更新',
              badgeLabel: '展示已刷新',
              description: '新的聊天状态已经回到个人页，别人点进主页时会先看到你当前的聊天氛围。',
            ),
          );
          AppFeedback.showToast(
            this.context,
            AppToastCode.saved,
            subject: '状态',
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandBlue.withValues(alpha: 0.12)
              : AppColors.white05,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.brandBlue.withValues(alpha: 0.2)
                : AppColors.white08,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              isSelected ? Icons.check_rounded : Icons.chevron_right,
              size: 18,
              color: isSelected ? AppColors.brandBlue : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSheetHeader({
    required String title,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w300,
            color: AppColors.textTertiary.withValues(alpha: 0.92),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildProfileSheetPreviewCard({
    required Key key,
    required String title,
    required String value,
    required String badgeLabel,
    required bool highlightBadge,
    Key? valueKey,
    Key? badgeKey,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white08),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textTertiary.withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  key: valueKey,
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            key: badgeKey,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: highlightBadge
                  ? AppColors.brandBlue.withValues(alpha: 0.14)
                  : AppColors.white08,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: highlightBadge
                    ? AppColors.brandBlue.withValues(alpha: 0.22)
                    : AppColors.white12,
              ),
            ),
            child: Text(
              badgeLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w300,
                color: highlightBadge
                    ? AppColors.brandBlue
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileReadinessState {
  const _ProfileReadinessState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isReady = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isReady;
}

class _ProfileMediaManagementSummary {
  const _ProfileMediaManagementSummary({
    required this.quickActionLabel,
    required this.sheetDescription,
    required this.previewStatusLabel,
    required this.previewBadgeLabel,
    required this.replaceActionLabel,
  });

  final String quickActionLabel;
  final String sheetDescription;
  final String previewStatusLabel;
  final String previewBadgeLabel;
  final String replaceActionLabel;
}

class _ProfileMediaState {
  const _ProfileMediaState({
    this.avatarPath,
    this.backgroundPath,
  });

  final String? avatarPath;
  final String? backgroundPath;

  bool get hasBackground => (backgroundPath ?? '').trim().isNotEmpty;

  _ProfileMediaState copyWith({
    Object? avatarPath = _profileMediaStateUnchanged,
    Object? backgroundPath = _profileMediaStateUnchanged,
  }) {
    return _ProfileMediaState(
      avatarPath: identical(avatarPath, _profileMediaStateUnchanged)
          ? this.avatarPath
          : avatarPath as String?,
      backgroundPath: identical(backgroundPath, _profileMediaStateUnchanged)
          ? this.backgroundPath
          : backgroundPath as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _ProfileMediaState &&
        other.avatarPath == avatarPath &&
        other.backgroundPath == backgroundPath;
  }

  @override
  int get hashCode => Object.hash(avatarPath, backgroundPath);
}

class _ProfileInlineFeedbackState {
  const _ProfileInlineFeedbackState({
    required this.cardKey,
    required this.icon,
    required this.title,
    required this.badgeLabel,
    required this.description,
    this.isHealthy = true,
  });

  final Key cardKey;
  final IconData icon;
  final String title;
  final String badgeLabel;
  final String description;
  final bool isHealthy;
}

class _ProfileIdentitySnapshot {
  const _ProfileIdentitySnapshot({
    required this.phone,
    required this.uid,
    required this.nickname,
    required this.status,
    required this.signature,
    required this.avatarPath,
    required this.backgroundPath,
  });

  final String phone;
  final String uid;
  final String nickname;
  final String status;
  final String signature;
  final String avatarPath;
  final String backgroundPath;
}

class _ProfileSettingsReturnSyncState {
  const _ProfileSettingsReturnSyncState({
    required this.feedback,
    required this.shouldRefocusIdentityArea,
  });

  final _ProfileInlineFeedbackState feedback;
  final bool shouldRefocusIdentityArea;
}

enum _ProfileIdentitySyncCueState {
  syncing,
  synced,
}

class _ProfileChecklistItem {
  const _ProfileChecklistItem({
    required this.key,
    required this.priorityKey,
    required this.icon,
    required this.label,
    required this.summary,
    required this.isReady,
    required this.onTap,
  });

  final Key key;
  final Key priorityKey;
  final IconData icon;
  final String label;
  final String summary;
  final bool isReady;
  final VoidCallback onTap;

  String get checklistActionLabel => isReady ? '可微调' : '去完善';

  String get priorityBadgeLabel => isReady ? '已就绪' : '去完善';

  String get semanticsLabel =>
      isReady ? '$label 已就绪，点按可继续微调' : '$label 待补齐，点按去完善';
}
