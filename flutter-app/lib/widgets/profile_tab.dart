import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../core/feedback/app_feedback.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/friend_provider.dart';
import '../providers/profile_provider.dart';
import '../services/image_upload_service.dart';
import '../services/media_upload_service.dart';
import '../services/profile_service.dart';
import '../utils/media_reference_resolver.dart';
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
    final refreshResult = await profileProvider.refreshFromRemoteWithStatus();
    await _loadImages();

    if (!mounted) return;
    final afterSnapshot = _captureIdentitySnapshot(context);
    final syncState = _resolveSettingsReturnSyncState(
      before: beforeSnapshot,
      after: afterSnapshot,
      remoteRefreshFailed: refreshResult.remoteFailed,
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

    if (!syncState.feedback.isHealthy) {
      final shouldRefocusIdentityArea = await _shouldRefocusIdentityArea();
      if (!mounted) return;
      if (shouldRefocusIdentityArea) {
        await _animateIdentityAreaToTop();
      }
      if (!mounted) return;
      _showInlineFeedback(syncState.feedback);
      return;
    }

    _showIdentitySyncCue(
      state: _ProfileIdentitySyncCueState.syncing,
      duration: null,
    );
    final shouldShowSyncingCue = await _shouldRefocusIdentityArea();
    if (!mounted) return;

    if (shouldShowSyncingCue) {
      await _animateIdentityAreaToTop();
      if (!mounted) return;
      _showIdentitySyncCue(state: _ProfileIdentitySyncCueState.synced);
      await Future<void>.delayed(const Duration(milliseconds: 120));
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 140));
      if (!mounted) return;
      _showIdentitySyncCue(state: _ProfileIdentitySyncCueState.synced);
    }

    if (!mounted) return;
    _showInlineFeedback(syncState.feedback);
  }

  _ProfileSettingsReturnSyncState? _resolveSettingsReturnSyncState({
    required _ProfileIdentitySnapshot before,
    required _ProfileIdentitySnapshot after,
    required bool remoteRefreshFailed,
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

    if (remoteRefreshFailed) {
      return _buildDeferredSettingsSyncState(
        avatarChanged: avatarChanged,
        backgroundChanged: backgroundChanged,
        textChanged: textChanged,
        accountChanged: accountChanged,
      );
    }

    if (mediaChanged && textChanged) {
      return const _ProfileSettingsReturnSyncState(
        shouldRefocusIdentityArea: true,
        feedback: _ProfileInlineFeedbackState(
          cardKey: Key('profile-settings-sync-hint'),
          icon: Icons.verified_user_outlined,
          title: '资料和展示已同步',
          badgeLabel: '已同步',
          description: '头像、背景和资料内容已同步回当前首页。',
        ),
      );
    }

    if (avatarChanged && backgroundChanged) {
      return const _ProfileSettingsReturnSyncState(
        shouldRefocusIdentityArea: true,
        feedback: _ProfileInlineFeedbackState(
          cardKey: Key('profile-settings-sync-hint'),
          icon: Icons.verified_user_outlined,
          title: '头像和背景已同步',
          badgeLabel: '已同步',
          description: '当前首页已显示新的头像和背景。',
        ),
      );
    }

    if (avatarChanged) {
      return const _ProfileSettingsReturnSyncState(
        shouldRefocusIdentityArea: true,
        feedback: _ProfileInlineFeedbackState(
          cardKey: Key('profile-settings-sync-hint'),
          icon: Icons.photo_camera_outlined,
          title: '头像已同步',
          badgeLabel: '已同步',
          description: '当前首页已显示新头像。',
        ),
      );
    }

    if (backgroundChanged) {
      return const _ProfileSettingsReturnSyncState(
        shouldRefocusIdentityArea: true,
        feedback: _ProfileInlineFeedbackState(
          cardKey: Key('profile-settings-sync-hint'),
          icon: Icons.wallpaper_outlined,
          title: '背景已同步',
          badgeLabel: '已同步',
          description: '当前首页已显示新背景。',
        ),
      );
    }

    if (textChanged) {
      return const _ProfileSettingsReturnSyncState(
        shouldRefocusIdentityArea: true,
        feedback: _ProfileInlineFeedbackState(
          cardKey: Key('profile-settings-sync-hint'),
          icon: Icons.person_outline,
          title: '个人资料已同步',
          badgeLabel: '已同步',
          description: '当前首页已显示新的资料内容。',
        ),
      );
    }

    return const _ProfileSettingsReturnSyncState(
      shouldRefocusIdentityArea: false,
      feedback: _ProfileInlineFeedbackState(
        cardKey: Key('profile-settings-sync-hint'),
        icon: Icons.verified_user_outlined,
        title: '账号设置已同步',
        badgeLabel: '已同步',
        description: '设置已同步完成，首页展示保持不变。',
      ),
    );
  }

  _ProfileSettingsReturnSyncState _buildDeferredSettingsSyncState({
    required bool avatarChanged,
    required bool backgroundChanged,
    required bool textChanged,
    required bool accountChanged,
  }) {
    final mediaChanged = avatarChanged || backgroundChanged;
    if (mediaChanged && textChanged) {
      return const _ProfileSettingsReturnSyncState(
        shouldRefocusIdentityArea: true,
        feedback: _ProfileInlineFeedbackState(
          cardKey: Key('profile-settings-sync-hint'),
          icon: Icons.cloud_off_outlined,
          title: '资料和展示已保存在本机',
          badgeLabel: '待联网同步',
          description: '当前首页先显示本地更新，联网后会继续同步到服务器。',
          isHealthy: false,
        ),
      );
    }

    if (avatarChanged && backgroundChanged) {
      return const _ProfileSettingsReturnSyncState(
        shouldRefocusIdentityArea: true,
        feedback: _ProfileInlineFeedbackState(
          cardKey: Key('profile-settings-sync-hint'),
          icon: Icons.cloud_off_outlined,
          title: '头像和背景已保存在本机',
          badgeLabel: '待联网同步',
          description: '当前首页先显示新的头像和背景，联网后会继续同步到服务器。',
          isHealthy: false,
        ),
      );
    }

    if (avatarChanged) {
      return const _ProfileSettingsReturnSyncState(
        shouldRefocusIdentityArea: true,
        feedback: _ProfileInlineFeedbackState(
          cardKey: Key('profile-settings-sync-hint'),
          icon: Icons.cloud_off_outlined,
          title: '头像已保存在本机',
          badgeLabel: '待联网同步',
          description: '当前首页先显示新头像，联网后会继续同步到服务器。',
          isHealthy: false,
        ),
      );
    }

    if (backgroundChanged) {
      return const _ProfileSettingsReturnSyncState(
        shouldRefocusIdentityArea: true,
        feedback: _ProfileInlineFeedbackState(
          cardKey: Key('profile-settings-sync-hint'),
          icon: Icons.cloud_off_outlined,
          title: '背景已保存在本机',
          badgeLabel: '待联网同步',
          description: '当前首页先显示新背景，联网后会继续同步到服务器。',
          isHealthy: false,
        ),
      );
    }

    if (textChanged) {
      return const _ProfileSettingsReturnSyncState(
        shouldRefocusIdentityArea: true,
        feedback: _ProfileInlineFeedbackState(
          cardKey: Key('profile-settings-sync-hint'),
          icon: Icons.cloud_off_outlined,
          title: '个人资料已保存在本机',
          badgeLabel: '待联网同步',
          description: '当前首页先显示新的资料内容，联网后会继续同步到服务器。',
          isHealthy: false,
        ),
      );
    }

    if (accountChanged) {
      return const _ProfileSettingsReturnSyncState(
        shouldRefocusIdentityArea: false,
        feedback: _ProfileInlineFeedbackState(
          cardKey: Key('profile-settings-sync-hint'),
          icon: Icons.cloud_off_outlined,
          title: '设置已保存在本机',
          badgeLabel: '待联网同步',
          description: '这次远端同步没有完成，网络恢复后会继续更新账号设置。',
          isHealthy: false,
        ),
      );
    }

    return const _ProfileSettingsReturnSyncState(
      shouldRefocusIdentityArea: false,
      feedback: _ProfileInlineFeedbackState(
        cardKey: Key('profile-settings-sync-hint'),
        icon: Icons.cloud_off_outlined,
        title: '设置已更新',
        badgeLabel: '待联网同步',
        description: '当前变更已先保存在本机，网络恢复后会继续同步。',
        isHealthy: false,
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
      badgeLabel: '未保存',
      description: description,
      isHealthy: false,
    );
  }

  _ProfileInlineFeedbackState _buildDeferredSavedFeedback({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return _ProfileInlineFeedbackState(
      cardKey: const Key('profile-inline-feedback-card'),
      icon: icon,
      title: title,
      badgeLabel: '待联网同步',
      description: description,
      isHealthy: false,
    );
  }

  void _showTextSaveFeedback({
    required BuildContext context,
    required ProfileSaveResult result,
    required IconData icon,
    required String subject,
    required String successTitle,
    required String successDescription,
    required String localTitle,
    required String localDescription,
    required String deferredTitle,
    required String deferredDescription,
  }) {
    if (result.remoteSucceeded) {
      _showInlineFeedback(
        _buildSavedFeedback(
          icon: icon,
          title: successTitle,
          badgeLabel: '展示已刷新',
          description: successDescription,
        ),
      );
      AppFeedback.showToast(context, AppToastCode.saved, subject: subject);
      return;
    }

    if (result.localOnly) {
      _showInlineFeedback(
        _buildSavedFeedback(
          icon: icon,
          title: localTitle,
          badgeLabel: '本机已更新',
          description: localDescription,
        ),
      );
      AppToast.show(context, '$subject已保存在本机');
      return;
    }

    _showInlineFeedback(
      _buildDeferredSavedFeedback(
        icon: icon,
        title: deferredTitle,
        description: deferredDescription,
      ),
    );
  }

  _ProfileInlineFeedbackState _buildMediaUpdatedFeedback({
    required bool isBackground,
    required UserMediaUploadResult result,
  }) {
    if (isBackground) {
      if (result.remoteSucceeded) {
        return _buildSavedFeedback(
          icon: Icons.wallpaper_outlined,
          title: '背景已经更新',
          badgeLabel: '氛围已刷新',
          description: '新背景已保存，主页会优先显示最新封面。',
        );
      }

      if (result.localOnly) {
        return _buildSavedFeedback(
          icon: Icons.wallpaper_outlined,
          title: '背景已保存在本机',
          badgeLabel: '本机已更新',
          description: '当前主页已经显示新背景，联网后会继续同步到服务器。',
        );
      }

      return _buildDeferredSavedFeedback(
        icon: Icons.wallpaper_outlined,
        title: '背景已更新，远端同步未完成',
        description: '当前设备已经显示新背景，网络恢复后会继续同步到服务器。',
      );
    }

    if (result.remoteSucceeded) {
      return _buildSavedFeedback(
        icon: Icons.photo_camera_outlined,
        title: '头像已经更新',
        badgeLabel: '资料已刷新',
        description: '新头像已保存，列表和个人页会显示最新资料。',
      );
    }

    if (result.localOnly) {
      return _buildSavedFeedback(
        icon: Icons.photo_camera_outlined,
        title: '头像已保存在本机',
        badgeLabel: '本机已更新',
        description: '当前资料已经显示新头像，联网后会继续同步到服务器。',
      );
    }

    return _buildDeferredSavedFeedback(
      icon: Icons.photo_camera_outlined,
      title: '头像已更新，远端同步未完成',
      description: '当前设备已经显示新头像，网络恢复后会继续同步到服务器。',
    );
  }

  void _showMediaUploadToast({
    required String subject,
    required UserMediaUploadResult result,
  }) {
    if (result.remoteSucceeded) {
      AppFeedback.showToast(context, AppToastCode.saved, subject: subject);
      return;
    }

    if (result.localOnly) {
      AppToast.show(context, '$subject已保存在本机');
    }
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
    final headerModeState =
        context.select<ProfileProvider, _ProfileHeaderModeState>(
            _selectProfileHeaderModeState);

    return Scaffold(
      backgroundColor: AppColors.pureBlack,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return ValueListenableBuilder<_ProfileMediaState>(
            valueListenable: _mediaStateNotifier,
            builder: (context, mediaState, _) {
              final screenHeight = constraints.maxHeight;
              final backgroundPath = mediaState.backgroundPath;
              final hasBackground = mediaState.hasBackground;
              final isPortraitFullscreen =
                  hasBackground && headerModeState.portraitFullscreenBackground;
              final usesCompactIdentityPanel =
                  isCompactScreen && !isPortraitFullscreen;
              final isTransparentBackground =
                  isPortraitFullscreen && headerModeState.transparentHomepage;
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
              final backgroundManagementSummary =
                  _resolveBackgroundManagementSummary(
                hasMedia: hasBackground,
                isRemote: _hasRemoteBackgroundMedia,
              );
              final backgroundImage = _buildImageProvider(backgroundPath);
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
                            label: backgroundManagementSummary.quickActionLabel,
                            child: Tooltip(
                              message:
                                  backgroundManagementSummary.quickActionLabel,
                              child: GestureDetector(
                                onTap: _openBackgroundManagementSheet,
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  key: const Key('profile-background-surface'),
                                  height: backgroundHeight,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: AppColors.white08,
                                    image: backgroundImage != null
                                        ? DecorationImage(
                                            image: backgroundImage,
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
                                  child: backgroundImage == null
                                      ? Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons
                                                    .add_photo_alternate_outlined,
                                                size: 40,
                                                color: AppColors.textTertiary
                                                    .withValues(alpha: 0.5),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                '点击设置背景',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: AppColors.textTertiary
                                                      .withValues(alpha: 0.5),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ),
                          if (!isPortraitFullscreen)
                            Positioned(
                              top: mediaQuery.padding.top + 10,
                              right: pageHorizontalPadding,
                              child: _buildHeaderActionDock(
                                context,
                                isCompactScreen:
                                    usesCompactIdentityPanel || isCompactScreen,
                                showBackgroundAction: hasBackground,
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
                                        avatarSize: avatarSize,
                                      )
                                    : Column(
                                        children: [
                                          // 头像
                                          _buildAvatarTrigger(
                                            avatarSize: avatarSize,
                                            isCompact: isCompactScreen,
                                          ),

                                          SizedBox(height: identityGap),

                                          // 昵称
                                          _buildNicknameTrigger(
                                            context,
                                            identityMaxWidth: identityMaxWidth,
                                          ),

                                          const SizedBox(height: 8),

                                          _buildSignatureTrigger(
                                            context,
                                            identityMaxWidth: identityMaxWidth,
                                          ),

                                          SizedBox(height: statusGap),

                                          GestureDetector(
                                            key: const Key(
                                              'profile-status-trigger',
                                            ),
                                            onTap: () =>
                                                _presentStatusEditor(context),
                                            behavior: HitTestBehavior.opaque,
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal:
                                                    isCompactScreen ? 16 : 20,
                                                vertical:
                                                    isCompactScreen ? 10 : 12,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isTransparentBackground
                                                    ? AppColors.white15
                                                    : AppColors.white05,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: isTransparentBackground
                                                      ? AppColors.white15
                                                      : AppColors.white08,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.max,
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
                                                    child: Selector<
                                                        ProfileProvider,
                                                        String>(
                                                      selector: (context,
                                                              provider) =>
                                                          _selectProfileStatusText(
                                                        provider,
                                                      ),
                                                      builder: (context,
                                                          statusText, _) {
                                                        return Text(
                                                          statusText,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 13,
                                                            color: AppColors
                                                                .textSecondary,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  const Icon(
                                                    Icons.edit,
                                                    size: 14,
                                                    color:
                                                        AppColors.textTertiary,
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
                                      valueListenable: _identitySyncCueNotifier,
                                      builder:
                                          (context, identitySyncCueState, _) {
                                        return AnimatedSwitcher(
                                          duration:
                                              const Duration(milliseconds: 220),
                                          switchInCurve: Curves.easeOutCubic,
                                          switchOutCurve: Curves.easeInCubic,
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
                                          child: identitySyncCueState != null
                                              ? KeyedSubtree(
                                                  key: ValueKey<
                                                          _ProfileIdentitySyncCueState>(
                                                      identitySyncCueState),
                                                  child:
                                                      _buildIdentitySyncBadge(
                                                    isCompactScreen:
                                                        usesCompactIdentityPanel,
                                                    state: identitySyncCueState,
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
                        _buildStatsSection(
                          horizontalPadding: pageHorizontalPadding,
                          topPadding: usesCompactIdentityPanel ? 4 : 0,
                          bottomPadding: 0,
                          isCompactScreen:
                              usesCompactIdentityPanel || isCompactScreen,
                        ),
                      if (!isPortraitFullscreen)
                        _buildInlineFeedbackSection(
                          horizontalPadding: pageHorizontalPadding,
                          topPadding: usesCompactIdentityPanel ? 10 : 12,
                          bottomPadding: usesCompactIdentityPanel ? 12 : 16,
                          isCompactScreen:
                              usesCompactIdentityPanel || isCompactScreen,
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
      ),
    );
  }

  Widget _buildInlineFeedbackSection({
    required double horizontalPadding,
    required double topPadding,
    required double bottomPadding,
    required bool isCompactScreen,
  }) {
    return ValueListenableBuilder<_ProfileInlineFeedbackState?>(
      valueListenable: _inlineFeedbackNotifier,
      builder: (context, inlineFeedback, _) {
        if (inlineFeedback == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            topPadding,
            horizontalPadding,
            bottomPadding,
          ),
          child: _buildInlineFeedbackBanner(
            inlineFeedback,
            isCompactScreen: isCompactScreen,
          ),
        );
      },
    );
  }

  Widget _buildStatsSection({
    required double horizontalPadding,
    required double topPadding,
    required double bottomPadding,
    required bool isCompactScreen,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        topPadding,
        horizontalPadding,
        bottomPadding,
      ),
      child: Selector2<FriendProvider, ChatProvider, _ProfileStatsViewData>(
        selector: (context, friendProvider, chatProvider) =>
            _ProfileStatsViewData(
          friendCount: friendProvider.friendList.length,
          threadCount: chatProvider.threads.length,
        ),
        builder: (context, statsViewData, _) {
          return _buildStatsCard(
            friendCount: statsViewData.friendCount,
            threadCount: statsViewData.threadCount,
            isCompactScreen: isCompactScreen,
          );
        },
      ),
    );
  }

  Widget _buildHeaderActionDock(
    BuildContext context, {
    required bool isCompactScreen,
    required bool showBackgroundAction,
  }) {
    final backgroundSummary = _resolveBackgroundManagementSummary(
      hasMedia: showBackgroundAction,
      isRemote: _hasRemoteBackgroundMedia,
    );

    Widget buildAction({
      required Key key,
      required IconData icon,
      required String label,
      required String semanticsLabel,
      required VoidCallback onTap,
    }) {
      return Semantics(
        button: true,
        label: semanticsLabel,
        child: Tooltip(
          message: semanticsLabel,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: _buildMediaEditBadge(
              key: key,
              icon: icon,
              label: label,
              isCompact: isCompactScreen,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showBackgroundAction) ...[
          buildAction(
            key: const Key('profile-background-edit-pill'),
            icon: Icons.wallpaper_outlined,
            label: '背景',
            semanticsLabel: backgroundSummary.quickActionLabel,
            onTap: _openBackgroundManagementSheet,
          ),
          SizedBox(width: isCompactScreen ? 8 : 10),
        ],
        buildAction(
          key: const Key('profile-header-settings-action'),
          icon: Icons.settings_outlined,
          label: '设置',
          semanticsLabel: '打开设置',
          onTap: () => _openSettings(context),
        ),
      ],
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

  bool _hasCustomSignatureValue(String signature) {
    final normalized = signature.trim();
    return normalized.isNotEmpty &&
        normalized != ProfileService.defaultSignature;
  }

  bool _hasCustomSignature(ProfileProvider profileProvider) {
    final signature = profileProvider.signature;
    return _hasCustomSignatureValue(signature);
  }

  bool _hasCustomStatusValue(String status) {
    final normalized = status.trim();
    return normalized.isNotEmpty && normalized != _defaultStatus;
  }

  bool _hasCustomStatus(ProfileProvider profileProvider) {
    final status = profileProvider.status;
    return _hasCustomStatusValue(status);
  }

  String _normalizeSignatureText(String signature) {
    final normalized = signature.trim();
    return normalized.isEmpty ? ProfileService.defaultSignature : normalized;
  }

  String _normalizeStatusText(String status) {
    final normalized = status.trim();
    return normalized.isEmpty ? _defaultStatus : normalized;
  }

  _ProfileHeaderModeState _selectProfileHeaderModeState(
    ProfileProvider profileProvider,
  ) {
    return _ProfileHeaderModeState(
      portraitFullscreenBackground:
          profileProvider.portraitFullscreenBackground,
      transparentHomepage: profileProvider.transparentHomepage,
    );
  }

  _ProfileIdentityViewData _selectProfileIdentityViewData(
    ProfileProvider profileProvider,
  ) {
    return _ProfileIdentityViewData(
      nickname: profileProvider.nickname,
      signatureText: _normalizeSignatureText(profileProvider.signature),
      statusText: _normalizeStatusText(profileProvider.status),
    );
  }

  String _selectProfileStatusText(ProfileProvider profileProvider) {
    return _normalizeStatusText(profileProvider.status);
  }

  String _selectProfileSignatureText(ProfileProvider profileProvider) {
    return _normalizeSignatureText(profileProvider.signature);
  }

  String _selectProfileAvatar(ProfileProvider profileProvider) {
    return profileProvider.avatar;
  }

  _ProfileBackgroundModeViewData _selectProfileBackgroundModeViewData(
    ProfileProvider profileProvider, {
    required bool hasBackground,
  }) {
    final isPortraitFullscreen =
        hasBackground && profileProvider.portraitFullscreenBackground;
    return _ProfileBackgroundModeViewData(
      isPortraitFullscreen: isPortraitFullscreen,
      isTransparentBackground:
          isPortraitFullscreen && profileProvider.transparentHomepage,
    );
  }

  String _selectProfileNickname(ProfileProvider profileProvider) {
    return profileProvider.nickname;
  }

  Widget _buildNicknameTrigger(
    BuildContext context, {
    required double identityMaxWidth,
  }) {
    return Center(
      child: Selector<ProfileProvider, String>(
        selector: (context, provider) => _selectProfileNickname(provider),
        builder: (context, nickname, _) {
          return GestureDetector(
            key: const Key('profile-nickname-trigger'),
            onTap: () => _presentNicknameEditor(context),
            behavior: HitTestBehavior.opaque,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: identityMaxWidth),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w300,
                        color: AppColors.textPrimary,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.edit,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSignatureTrigger(
    BuildContext context, {
    required double identityMaxWidth,
  }) {
    return Center(
      child: Selector<ProfileProvider, String>(
        selector: (context, provider) => _selectProfileSignatureText(provider),
        builder: (context, signatureText, _) {
          return TextButton(
            key: const Key('profile-signature-trigger'),
            onPressed: () => _presentSignatureEditor(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              foregroundColor: AppColors.textTertiary,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: identityMaxWidth),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      signatureText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        color: AppColors.textTertiary,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.edit,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
    required double avatarSize,
  }) {
    return Selector<ProfileProvider, _ProfileIdentityViewData>(
      selector: (context, provider) => _selectProfileIdentityViewData(provider),
      child: _buildAvatarTrigger(
        avatarSize: avatarSize,
        isCompact: true,
      ),
      builder: (context, identityViewData, avatarChild) {
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
              avatarChild!,
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
                              identityViewData.nickname,
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
                                identityViewData.signatureText,
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
                        constraints: const BoxConstraints(minHeight: 48),
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
                                identityViewData.statusText,
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
      },
    );
  }

  Widget _buildAvatarTrigger({
    required double avatarSize,
    required bool isCompact,
  }) {
    final pillInset = avatarSize * 0.16;
    const pillVerticalPadding = 4.0;
    const pillIconSize = 12.0;
    const pillFontSize = 10.0;
    final fallbackFontSize = avatarSize * 0.46;

    return Selector<ProfileProvider, String>(
      selector: (context, provider) => _selectProfileAvatar(provider),
      builder: (context, avatarText, _) {
        return Semantics(
          button: true,
          label: _resolveAvatarManagementSummary(
            hasMedia: _hasAvatarMedia,
            isRemote: _hasRemoteAvatarMedia,
          ).quickActionLabel,
          child: Tooltip(
            message: _resolveAvatarManagementSummary(
              hasMedia: _hasAvatarMedia,
              isRemote: _hasRemoteAvatarMedia,
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
                                avatarText,
                              )
                            : Center(
                                child: Text(
                                  avatarText,
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
      },
    );
  }

  Widget _buildStatsCard({
    required int friendCount,
    required int threadCount,
    required bool isCompactScreen,
  }) {
    return Container(
      key: const Key('profile-stats-card'),
      padding: EdgeInsets.symmetric(
        horizontal: isCompactScreen ? 12 : 14,
        vertical: isCompactScreen ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white08),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              '好友',
              '$friendCount',
              isCompact: isCompactScreen,
            ),
          ),
          _buildStatDivider(),
          Expanded(
            child: _buildStatItem(
              '会话',
              '$threadCount',
              isCompact: isCompactScreen,
            ),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
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

  bool get _hasRemoteAvatarMedia =>
      _hasAvatarMedia && isRemoteMediaReference(_avatarPath!);

  bool get _hasRemoteBackgroundMedia =>
      _hasBackgroundMedia && isRemoteMediaReference(_backgroundPath!);

  _ProfileMediaManagementSummary _resolveAvatarManagementSummary({
    required bool hasMedia,
    required bool isRemote,
  }) {
    if (hasMedia) {
      if (!isRemote) {
        return const _ProfileMediaManagementSummary(
          quickActionLabel: '头像管理',
          sheetDescription: '当前设备会先显示这张头像，联网后会继续同步到服务器。',
          previewStatusLabel: '头像已保存在本机',
          previewBadgeLabel: '待联网同步',
          replaceActionLabel: '更换头像',
          highlightBadge: false,
        );
      }

      return const _ProfileMediaManagementSummary(
        quickActionLabel: '头像管理',
        sheetDescription: '头像会持续出现在消息列表和个人页里，建议保持清晰、稳定、容易识别。',
        previewStatusLabel: '头像已同步',
        previewBadgeLabel: '展示中',
        replaceActionLabel: '更换头像',
        highlightBadge: true,
      );
    }

    return const _ProfileMediaManagementSummary(
      quickActionLabel: '补头像',
      sheetDescription: '头像会持续出现在消息列表和个人页里，先补一个清晰头像会更容易识别。',
      previewStatusLabel: '正在使用默认头像',
      previewBadgeLabel: '待补充',
      replaceActionLabel: '上传头像',
      highlightBadge: false,
    );
  }

  _ProfileMediaManagementSummary _resolveBackgroundManagementSummary({
    required bool hasMedia,
    required bool isRemote,
  }) {
    if (hasMedia) {
      if (!isRemote) {
        return const _ProfileMediaManagementSummary(
          quickActionLabel: '背景管理',
          sheetDescription: '当前主页会先显示这张背景，联网后会继续同步到服务器。',
          previewStatusLabel: '背景已保存在本机',
          previewBadgeLabel: '待联网同步',
          replaceActionLabel: '更换背景',
          highlightBadge: false,
        );
      }

      return const _ProfileMediaManagementSummary(
        quickActionLabel: '背景管理',
        sheetDescription: '背景会影响别人进入你主页时的第一眼氛围，可以在这里调整封面和展示模式。',
        previewStatusLabel: '背景已生效',
        previewBadgeLabel: '首屏展示中',
        replaceActionLabel: '更换背景',
        highlightBadge: true,
      );
    }

    return const _ProfileMediaManagementSummary(
      quickActionLabel: '补背景',
      sheetDescription: '背景会影响别人进入你主页时的第一眼氛围，先补一张更有辨识度的封面。',
      previewStatusLabel: '正在使用默认背景',
      previewBadgeLabel: '待补充',
      replaceActionLabel: '上传背景',
      highlightBadge: false,
    );
  }

  Future<void> _openAvatarManagementSheet() async {
    final profileProvider = context.read<ProfileProvider>();
    final summary = _resolveAvatarManagementSummary(
      hasMedia: _hasAvatarMedia,
      isRemote: _hasRemoteAvatarMedia,
    );

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
    final summary = _resolveBackgroundManagementSummary(
      hasMedia: _hasBackgroundMedia,
      isRemote: _hasRemoteBackgroundMedia,
    );

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
    final avatarImage = _buildImageProvider(_avatarPath);
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
              child: avatarImage != null
                  ? Image(
                      key: const Key('profile-avatar-management-image'),
                      image: avatarImage,
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
            highlight: summary.highlightBadge,
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundManagementPreviewCard({
    required _ProfileMediaManagementSummary summary,
  }) {
    final previewImage = _buildImageProvider(_backgroundPath);
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
            highlight: summary.highlightBadge,
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
        description: '当前个人页已恢复默认头像。',
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
        description: '当前个人页已恢复默认背景。',
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
      builder: (context) =>
          Selector<ProfileProvider, _ProfileBackgroundModeViewData>(
        selector: (context, profileProvider) =>
            _selectProfileBackgroundModeViewData(
          profileProvider,
          hasBackground: hasBackground,
        ),
        builder: (context, modeViewData, child) {
          return AppDialog.buildSheetSurface(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Column(
              key: const Key('profile-background-mode-sheet'),
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModeSwitchRow(
                  icon: Icons.stay_current_portrait_outlined,
                  title: '绔栧睆鍏ㄥ睆鑳屾櫙',
                  subtitle:
                      hasBackground ? '鎸夌珫灞忓叏灞忓睍绀鸿儗鏅浘' : '鍏堣缃儗鏅浘鍚庡紑鍚?',
                  switchKey:
                      const Key('profile-background-mode-portrait-switch'),
                  value: modeViewData.isPortraitFullscreen,
                  enabled: hasBackground,
                  onChanged: _setPortraitFullscreenBackground,
                ),
                const SizedBox(height: 8),
                _buildModeSwitchRow(
                  icon: Icons.layers_outlined,
                  title: '绔栧睆閫忔槑鑳屾櫙',
                  subtitle: modeViewData.isPortraitFullscreen
                      ? '闄嶄綆閬僵锛岀獊鍑虹珫灞忓叏灞忚儗鏅?'
                      : '寮€鍚珫灞忓叏灞忚儗鏅悗鍙缃?',
                  switchKey:
                      const Key('profile-background-mode-transparent-switch'),
                  value: modeViewData.isTransparentBackground,
                  enabled: modeViewData.isPortraitFullscreen,
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
    required Key switchKey,
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
              key: switchKey,
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
      final uploadResult = await _mediaUploadService.uploadUserMediaWithStatus(
        'avatar',
        imageFile,
      );
      await ImageUploadService.saveAvatarReference(
        uploadResult.mediaRef,
        cleanupLocalPath: imageFile.path,
      );
      if (!mounted) return;
      _setMediaState(avatarPath: uploadResult.mediaRef);
      _showInlineFeedback(
        _buildMediaUpdatedFeedback(
          isBackground: false,
          result: uploadResult,
        ),
      );
      _showMediaUploadToast(subject: '头像', result: uploadResult);
    } catch (_) {
      if (!mounted) return;
      _showInlineFeedback(
        _buildFailedFeedback(
          icon: Icons.photo_camera_outlined,
          title: '头像更新失败',
          description: '新头像未保存，请重试。',
        ),
      );
      AppFeedback.showError(
        context,
        AppErrorCode.unknown,
        detail: '头像未更新，请重试',
      );
    }
  }

  // 修改背景
  Future<void> _changeBackground() async {
    final imageFile = await ImageUploadService.pickBackground(context);

    if (imageFile == null || !mounted) return;

    try {
      final uploadResult = await _mediaUploadService.uploadUserMediaWithStatus(
        'background',
        imageFile,
      );
      await ImageUploadService.saveBackgroundReference(
        uploadResult.mediaRef,
        cleanupLocalPath: imageFile.path,
      );
      if (!mounted) return;
      _setMediaState(backgroundPath: uploadResult.mediaRef);
      _showInlineFeedback(
        _buildMediaUpdatedFeedback(
          isBackground: true,
          result: uploadResult,
        ),
      );
      _showMediaUploadToast(subject: '背景', result: uploadResult);
    } catch (_) {
      if (!mounted) return;
      _showInlineFeedback(
        _buildFailedFeedback(
          icon: Icons.wallpaper_outlined,
          title: '背景更新失败',
          description: '新背景未保存，请重试。',
        ),
      );
      AppFeedback.showError(
        context,
        AppErrorCode.unknown,
        detail: '背景未更新，请重试',
      );
    }
  }

  ImageProvider? _buildImageProvider(String? path) {
    final resolvedPath = resolveRenderableMediaPath(path);
    if (resolvedPath == null) {
      return null;
    }
    if (isRemoteMediaReference(resolvedPath)) {
      return NetworkImage(resolvedPath);
    }
    return FileImage(resolveLocalMediaFile(resolvedPath));
  }

  Widget _buildProfileImage(String path, String fallbackAvatar) {
    final resolvedPath = resolveRenderableMediaPath(path);
    if (resolvedPath == null) {
      return Center(
        child: Text(
          fallbackAvatar,
          style: const TextStyle(fontSize: 48),
        ),
      );
    }

    if (isRemoteMediaReference(resolvedPath)) {
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
      resolveLocalMediaFile(resolvedPath),
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
      description: '保留容易记住的称呼就够了。',
      hintText: '输入昵称',
      helperText: '建议 2~8 个字，少用符号。',
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
        final saveResult = await context
            .read<ProfileProvider>()
            .updateNicknameWithStatus(nickname);
        if (context.mounted) {
          _showTextSaveFeedback(
            context: context,
            result: saveResult,
            icon: Icons.badge_outlined,
            subject: '昵称',
            successTitle: '昵称已经更新',
            successDescription: '新昵称已同步到资料卡和消息列表。',
            localTitle: '昵称已保存在本机',
            localDescription: '当前设备上的资料卡已经更新，联网后会继续同步到服务器。',
            deferredTitle: '昵称已更新，远端同步未完成',
            deferredDescription: '当前资料卡先显示新昵称，网络恢复后会继续同步到服务器。',
          );
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
      description: '一句短签名就够了。',
      hintText: '输入你的签名',
      helperText: '建议 10~24 个字，简短一点更自然。',
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
      final saveResult =
          await context.read<ProfileProvider>().updateSignatureWithStatus(
                signature.isEmpty ? ProfileService.defaultSignature : signature,
              );
      if (context.mounted) {
        _showTextSaveFeedback(
          context: context,
          result: saveResult,
          icon: Icons.edit_note_outlined,
          subject: '签名',
          successTitle: '签名已经更新',
          successDescription: '新签名已同步到当前资料卡。',
          localTitle: '签名已保存在本机',
          localDescription: '当前资料卡已经显示新签名，联网后会继续同步到服务器。',
          deferredTitle: '签名已更新，远端同步未完成',
          deferredDescription: '当前资料卡先显示新签名，网络恢复后会继续同步到服务器。',
        );
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
                        description: '选一句能代表当前状态的短句。',
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
        final saveResult = await this
            .context
            .read<ProfileProvider>()
            .updateStatusWithStatus(value);
        if (mounted) {
          _showTextSaveFeedback(
            context: this.context,
            result: saveResult,
            icon: Icons.chat_bubble_outline,
            subject: '状态',
            successTitle: '状态已经更新',
            successDescription: '新状态已同步到个人页。',
            localTitle: '状态已保存在本机',
            localDescription: '当前个人页已经显示新状态，联网后会继续同步到服务器。',
            deferredTitle: '状态已更新，远端同步未完成',
            deferredDescription: '当前个人页先显示新状态，网络恢复后会继续同步到服务器。',
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

class _ProfileHeaderModeState {
  const _ProfileHeaderModeState({
    required this.portraitFullscreenBackground,
    required this.transparentHomepage,
  });

  final bool portraitFullscreenBackground;
  final bool transparentHomepage;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _ProfileHeaderModeState &&
        other.portraitFullscreenBackground == portraitFullscreenBackground &&
        other.transparentHomepage == transparentHomepage;
  }

  @override
  int get hashCode =>
      Object.hash(portraitFullscreenBackground, transparentHomepage);
}

class _ProfileIdentityViewData {
  const _ProfileIdentityViewData({
    required this.nickname,
    required this.signatureText,
    required this.statusText,
  });

  final String nickname;
  final String signatureText;
  final String statusText;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _ProfileIdentityViewData &&
        other.nickname == nickname &&
        other.signatureText == signatureText &&
        other.statusText == statusText;
  }

  @override
  int get hashCode => Object.hash(nickname, signatureText, statusText);
}

class _ProfileBackgroundModeViewData {
  const _ProfileBackgroundModeViewData({
    required this.isPortraitFullscreen,
    required this.isTransparentBackground,
  });

  final bool isPortraitFullscreen;
  final bool isTransparentBackground;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _ProfileBackgroundModeViewData &&
        other.isPortraitFullscreen == isPortraitFullscreen &&
        other.isTransparentBackground == isTransparentBackground;
  }

  @override
  int get hashCode =>
      Object.hash(isPortraitFullscreen, isTransparentBackground);
}

class _ProfileStatsViewData {
  const _ProfileStatsViewData({
    required this.friendCount,
    required this.threadCount,
  });

  final int friendCount;
  final int threadCount;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _ProfileStatsViewData &&
        other.friendCount == friendCount &&
        other.threadCount == threadCount;
  }

  @override
  int get hashCode => Object.hash(friendCount, threadCount);
}

class _ProfileMediaManagementSummary {
  const _ProfileMediaManagementSummary({
    required this.quickActionLabel,
    required this.sheetDescription,
    required this.previewStatusLabel,
    required this.previewBadgeLabel,
    required this.replaceActionLabel,
    required this.highlightBadge,
  });

  final String quickActionLabel;
  final String sheetDescription;
  final String previewStatusLabel;
  final String previewBadgeLabel;
  final String replaceActionLabel;
  final bool highlightBadge;
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
