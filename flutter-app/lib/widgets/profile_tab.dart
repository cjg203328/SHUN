import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../core/feedback/app_feedback.dart';
import '../core/ui/ui_tokens.dart';
import '../providers/chat_provider.dart';
import '../providers/friend_provider.dart';
import '../providers/profile_provider.dart';
import '../services/image_upload_service.dart';
import '../services/media_upload_service.dart';
import '../services/profile_service.dart';
import 'app_toast.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  String? _avatarPath;
  String? _backgroundPath;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    final avatarPath = await ImageUploadService.getAvatarPath();
    final backgroundPath = await ImageUploadService.getBackgroundPath();

    if (mounted) {
      setState(() {
        _avatarPath = avatarPath;
        _backgroundPath = backgroundPath;
      });

      if (backgroundPath == null) {
        final profileProvider = context.read<ProfileProvider>();
        if (profileProvider.portraitFullscreenBackground ||
            profileProvider.transparentHomepage) {
          await profileProvider.updatePortraitFullscreenBackground(false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final isCompactScreen = screenSize.height < 760 || screenSize.width < 390;

    return Scaffold(
      backgroundColor: AppColors.pureBlack,
      body: Consumer<ProfileProvider>(
        builder: (context, profileProvider, child) {
          final screenHeight = mediaQuery.size.height;
          final hasBackground = _backgroundPath != null;
          final isPortraitFullscreen =
              hasBackground && profileProvider.portraitFullscreenBackground;
          final usesCompactIdentityPanel =
              isCompactScreen && !isPortraitFullscreen;
          final isTransparentBackground =
              isPortraitFullscreen && profileProvider.transparentHomepage;
          final normalHeight = (screenHeight *
                  (usesCompactIdentityPanel
                      ? 0.30
                      : (isCompactScreen ? 0.34 : 0.52)))
              .clamp(
            usesCompactIdentityPanel
                ? 184.0
                : (isCompactScreen ? 192.0 : 320.0),
            usesCompactIdentityPanel
                ? 252.0
                : (isCompactScreen ? 280.0 : 520.0),
          );
          final fullHeight = screenHeight - mediaQuery.padding.top;
          final backgroundHeight =
              isPortraitFullscreen ? fullHeight : normalHeight;
          final profileTopOffset = isPortraitFullscreen
              ? backgroundHeight * (isCompactScreen ? 0.4 : 0.5)
              : backgroundHeight -
                  (usesCompactIdentityPanel
                      ? 48.0
                      : (isCompactScreen ? 34 : 62));
          final pageHorizontalPadding = isCompactScreen ? 16.0 : 20.0;
          final identityMaxWidth = usesCompactIdentityPanel
              ? double.infinity
              : (isCompactScreen ? 240.0 : 300.0);
          final avatarSize = usesCompactIdentityPanel
              ? 64.0
              : (isCompactScreen ? 68.0 : 100.0);
          final headerBottomPadding =
              usesCompactIdentityPanel ? 12.0 : (isCompactScreen ? 16.0 : 40.0);
          final identityGap =
              usesCompactIdentityPanel ? 8.0 : (isCompactScreen ? 10.0 : 20.0);
          final statusGap =
              usesCompactIdentityPanel ? 10.0 : (isCompactScreen ? 12.0 : 24.0);
          final listBottomInset = mediaQuery.padding.bottom +
              (isPortraitFullscreen ? 28.0 : (isCompactScreen ? 34.0 : 40.0));
          final signatureText = profileProvider.signature.trim().isEmpty
              ? '这个人很神秘，什么都没留下'
              : profileProvider.signature.trim();
          return SingleChildScrollView(
            padding: EdgeInsets.only(bottom: listBottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 顶部背景和个人信息区域
                Stack(
                  children: [
                    // 背景图片
                    GestureDetector(
                      onTap: () => _changeBackground(),
                      child: Container(
                        height: backgroundHeight,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.white08,
                          image: _backgroundPath != null
                              ? DecorationImage(
                                  image: _buildImageProvider(_backgroundPath!),
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
                                alpha: isTransparentBackground ? 0.03 : 0.08,
                              ),
                              AppColors.pureBlack.withValues(
                                alpha: isTransparentBackground
                                    ? 0.16
                                    : (isPortraitFullscreen ? 0.3 : 0.4),
                              ),
                            ],
                          ),
                        ),
                        child: _backgroundPath == null
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate_outlined,
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
                            : (!isPortraitFullscreen
                                ? Container(
                                    alignment: Alignment.topRight,
                                    padding: const EdgeInsets.all(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.pureBlack
                                            .withValues(alpha: 0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.edit,
                                        size: 16,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink()),
                      ),
                    ),

                    // 个人信息
                    Container(
                      margin: EdgeInsets.only(top: profileTopOffset),
                      padding: EdgeInsets.fromLTRB(
                        pageHorizontalPadding,
                        0,
                        pageHorizontalPadding,
                        headerBottomPadding,
                      ),
                      child: usesCompactIdentityPanel
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
                                  profileProvider: profileProvider,
                                  avatarSize: avatarSize,
                                  isCompact: isCompactScreen,
                                ),

                                SizedBox(height: identityGap),

                                // 昵称
                                Center(
                                  child: GestureDetector(
                                    key: const Key('profile-nickname-trigger'),
                                    onTap: () =>
                                        _presentNicknameEditor(context),
                                    behavior: HitTestBehavior.opaque,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: identityMaxWidth,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              profileProvider.nickname,
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
                                  ),
                                ),

                                const SizedBox(height: 8),

                                // 个性签名
                                Center(
                                  child: TextButton(
                                    key: const Key('profile-signature-trigger'),
                                    onPressed: () =>
                                        _presentSignatureEditor(context),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      foregroundColor: AppColors.textTertiary,
                                    ),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: identityMaxWidth,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                  ),
                                ),

                                SizedBox(height: statusGap),

                                // 状态
                                GestureDetector(
                                  key: const Key('profile-status-trigger'),
                                  onTap: () => _presentStatusEditor(context),
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isCompactScreen ? 16 : 20,
                                      vertical: isCompactScreen ? 10 : 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isTransparentBackground
                                          ? AppColors.white15
                                          : AppColors.white05,
                                      borderRadius: BorderRadius.circular(20),
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
                                            color: AppColors.textTertiary,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            profileProvider.status,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.edit,
                                          size: 14,
                                          color: AppColors.textTertiary,
                                        ),
                                      ],
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
                        child: Column(
                          children: [
                            _buildCompactActionButton(
                              icon: Icons.layers_outlined,
                              onTap: () => _showBackgroundModeSheet(
                                context,
                                hasBackground: hasBackground,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildCompactActionButton(
                              icon: Icons.settings_outlined,
                              onTap: () => context
                                  .push('/settings')
                                  .then((_) => _loadImages()),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                // 统计数据行
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
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatItem(
                                '好友', '${friendProv.friends.length}'),
                            _buildStatDivider(),
                            _buildStatItem('会话', '${chatProv.threads.length}'),
                          ],
                        );
                      },
                    ),
                  ),

                SizedBox(height: usesCompactIdentityPanel ? 12 : 16),

                // 功能列表
                if (!isPortraitFullscreen)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      pageHorizontalPadding,
                      0,
                      pageHorizontalPadding,
                      16,
                    ),
                    child: _buildQuickActionsCard(
                      context,
                      hasBackground: hasBackground,
                      profileProvider: profileProvider,
                    ),
                  ),

                SizedBox(
                  height: isPortraitFullscreen ? 0 : 8,
                ),
              ],
            ),
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
    final readinessState = _resolveReadinessState(
      hasBackground: hasBackground,
      profileProvider: profileProvider,
      isCompactScreen: isCompactScreen,
    );
    final description = isCompactScreen
        ? (hasBackground ? '把常用整理入口统一收在这里。' : '先补背景和签名，再收口常用入口。')
        : (hasBackground
            ? '签名、背景显示和设置入口都集中在这里，发起聊天前可以顺手收拾一下。'
            : '先补背景和签名，再统一检查设置入口，个人页第一眼会更完整。');

    return Container(
      key: const Key('profile-quick-actions-card'),
      padding: EdgeInsets.all(isCompactScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(UiTokens.radiusMd),
        border: Border.all(color: AppColors.white08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '个人页快速整理',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
            ),
          ),
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
          SizedBox(height: isCompactScreen ? 10 : 14),
          Container(
            key: const Key('profile-readiness-chip'),
            padding: EdgeInsets.symmetric(
              horizontal: isCompactScreen ? 10 : 12,
              vertical: isCompactScreen ? 8 : 10,
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
                            color:
                                AppColors.textTertiary.withValues(alpha: 0.92),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isCompactScreen ? 8 : 12),
          _buildProfileCompletionChecklist(
            hasBackground: hasBackground,
            profileProvider: profileProvider,
          ),
          SizedBox(height: isCompactScreen ? 8 : 12),
          Wrap(
            spacing: isCompactScreen ? 8 : 10,
            runSpacing: isCompactScreen ? 8 : 10,
            children: [
              _buildQuickActionButton(
                key: const Key('profile-quick-signature'),
                icon: Icons.edit_note_outlined,
                label: '编辑签名',
                onTap: () => _presentSignatureEditor(context),
              ),
              _buildQuickActionButton(
                key: const Key('profile-quick-background-mode'),
                icon: Icons.layers_outlined,
                label: '背景模式',
                onTap: () => _showBackgroundModeSheet(
                  context,
                  hasBackground: hasBackground,
                ),
              ),
              _buildQuickActionButton(
                key: const Key('profile-quick-settings'),
                icon: Icons.settings_outlined,
                label: '打开设置',
                onTap: () =>
                    context.push('/settings').then((_) => _loadImages()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCompletionChecklist({
    required bool hasBackground,
    required ProfileProvider profileProvider,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final isCompactScreen = screenSize.height < 760 || screenSize.width < 390;
    final hasCustomSignature = profileProvider.signature.trim().isNotEmpty &&
        profileProvider.signature.trim() != ProfileService.defaultSignature;
    final hasCustomStatus = profileProvider.status.trim().isNotEmpty &&
        profileProvider.status.trim() != '想找人聊聊';
    final items = <_ProfileChecklistItem>[
      _ProfileChecklistItem(
        key: const Key('profile-check-background'),
        label: '背景图',
        isReady: hasBackground,
      ),
      _ProfileChecklistItem(
        key: const Key('profile-check-signature'),
        label: '个性签名',
        isReady: hasCustomSignature,
      ),
      _ProfileChecklistItem(
        key: const Key('profile-check-status'),
        label: '聊天状态',
        isReady: hasCustomStatus,
      ),
    ];

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
              '补齐这三项后，别人从匹配页或消息列表点进来时，会更容易建立第一印象。',
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
    return Container(
      key: item.key,
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
            color: item.isReady ? AppColors.textSecondary : AppColors.brandBlue,
          ),
          const SizedBox(width: 6),
          Text(
            item.label,
            style: TextStyle(
              fontSize: isCompactScreen ? 10.5 : 11,
              fontWeight: FontWeight.w300,
              color:
                  item.isReady ? AppColors.textSecondary : AppColors.brandBlue,
            ),
          ),
        ],
      ),
    );
  }

  _ProfileReadinessState _resolveReadinessState({
    required bool hasBackground,
    required ProfileProvider profileProvider,
    required bool isCompactScreen,
  }) {
    final hasCustomSignature = profileProvider.signature.trim().isNotEmpty &&
        profileProvider.signature.trim() != ProfileService.defaultSignature;
    final hasCustomStatus = profileProvider.status.trim().isNotEmpty &&
        profileProvider.status.trim() != '想找人聊聊';
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
      if (!hasBackground) '背景图',
      if (!hasCustomSignature) '个性签名',
      if (!hasCustomStatus) '状态',
    ];

    return _ProfileReadinessState(
      icon: Icons.auto_awesome_outlined,
      title: '个人页还差 ${3 - completedCount} 项细节',
      subtitle: isCompactScreen
          ? '优先补齐${missingLabels.join('、')}，首屏会更像真实可聊天的人。'
          : '建议优先补齐${missingLabels.join('、')}，这样第一眼信息会更完整，也更像真实可互动的人。',
    );
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
        padding: EdgeInsets.symmetric(
          horizontal: isCompactScreen ? 10 : 12,
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
              size: isCompactScreen ? 15 : 16,
              color: AppColors.textSecondary,
            ),
            SizedBox(width: isCompactScreen ? 6 : 8),
            Text(
              label,
              style: TextStyle(
                fontSize: isCompactScreen ? 11.5 : 12,
                fontWeight: FontWeight.w300,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.pureBlack.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: AppColors.white12),
        ),
        child: Icon(
          icon,
          size: 18,
          color: AppColors.textSecondary,
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.pureBlack.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.white12),
        boxShadow: [
          BoxShadow(
            color: AppColors.pureBlack.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
          const SizedBox(width: 12),
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
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.edit,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
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
                              fontSize: 13,
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
                            Icons.edit_outlined,
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  key: const Key('profile-status-trigger'),
                  onTap: () => _presentStatusEditor(context),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white08,
                      borderRadius: BorderRadius.circular(16),
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
    final badgePadding = isCompact ? 6.0 : 8.0;
    final badgeIconSize = isCompact ? 14.0 : 16.0;
    final fallbackFontSize = avatarSize * 0.46;

    return GestureDetector(
      onTap: () => _changeAvatar(),
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
                  blurRadius: 12,
                  offset: const Offset(0, 4),
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
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.all(badgePadding),
              decoration: BoxDecoration(
                color: AppColors.white20,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.white20,
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.camera_alt,
                size: badgeIconSize,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatsCard({
    required int friendCount,
    required int threadCount,
  }) {
    return Container(
      key: const Key('profile-stats-card'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(18),
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
        final displayValue = double.tryParse(value) != null
            ? animVal.round().toString()
            : value;
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

    final mediaRef = await MediaUploadService().uploadUserMedia(
      'avatar',
      imageFile,
    );
    await ImageUploadService.saveAvatarReference(mediaRef);
    if (!mounted) return;
    setState(() {
      _avatarPath = mediaRef;
    });
    AppFeedback.showToast(context, AppToastCode.saved, subject: '头像');
  }

  // 修改背景
  Future<void> _changeBackground() async {
    final imageFile = await ImageUploadService.pickBackground(context);

    if (imageFile == null || !mounted) return;

    final mediaRef = await MediaUploadService().uploadUserMedia(
      'background',
      imageFile,
    );
    await ImageUploadService.saveBackgroundReference(mediaRef);
    if (!mounted) return;
    setState(() {
      _backgroundPath = mediaRef;
    });
    AppFeedback.showToast(context, AppToastCode.saved, subject: '背景');
  }

  ImageProvider _buildImageProvider(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    }
    return FileImage(File(path));
  }

  Widget _buildProfileImage(String path, String fallbackAvatar) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
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
      File(path),
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
      description: '推荐保留容易被记住的称呼，后续别人回看消息列表时更容易认出你。',
      hintText: '输入昵称',
      helperText: '建议 2 到 8 个字，避免纯符号或测试占位名。',
      controller: controller,
      maxLength: 12,
    );

    if (result == true && context.mounted) {
      final nickname = controller.text.trim();
      if (nickname.isNotEmpty) {
        await context.read<ProfileProvider>().updateNickname(nickname);
        if (context.mounted) {
          AppFeedback.showToast(context, AppToastCode.saved, subject: '昵称');
        }
      }
    }

    controller.dispose();
  }

  Future<void> _presentSignatureEditor(BuildContext context) async {
    final profileProvider = context.read<ProfileProvider>();
    final controller = TextEditingController(text: profileProvider.signature);
    final result = await _showProfileEditorSheet(
      context,
      sheetKey: const Key('profile-signature-sheet'),
      title: '个性签名',
      description: '一句短签名就够了，最好能让别人快速感受到你的状态和聊天气质。',
      hintText: '输入你的签名',
      helperText: '适合 10 到 24 个字，越具体越容易让人主动开口。',
      controller: controller,
      maxLength: 30,
    );

    if (result == true && context.mounted) {
      final signature = controller.text.trim();
      await context.read<ProfileProvider>().updateSignature(
            signature.isEmpty ? ProfileService.defaultSignature : signature,
          );
      if (context.mounted) {
        AppFeedback.showToast(context, AppToastCode.saved, subject: '签名');
      }
    }

    controller.dispose();
  }

  Future<void> _presentStatusEditor(BuildContext context) async {
    const statuses = <String>[
      '想找人聊聊',
      '有点失眠',
      '心情不好',
      '分享快乐',
      '深夜emo',
      '随便聊聊',
    ];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (sheetContext) => Container(
        key: const Key('profile-status-sheet'),
        child: AppDialog.buildSheetSurface(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileSheetHeader(
                title: '选择状态',
                description: '状态会直接出现在个人页上，适合选一个能代表你当下聊天氛围的短句。',
              ),
              ...statuses.asMap().entries.map(
                    (entry) => Padding(
                      padding: EdgeInsets.only(
                        bottom: entry.key == statuses.length - 1 ? 0 : 10,
                      ),
                      child: InkWell(
                        key: Key('profile-status-option-${entry.key}'),
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          await context
                              .read<ProfileProvider>()
                              .updateStatus(entry.value);
                          if (context.mounted) {
                            AppFeedback.showToast(
                              context,
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
                            color: AppColors.white05,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.white08),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.value,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w300,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: AppColors.textTertiary,
                              ),
                            ],
                          ),
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

  Future<bool?> _showProfileEditorSheet(
    BuildContext context, {
    required Key sheetKey,
    required String title,
    required String description,
    required String hintText,
    required String helperText,
    required TextEditingController controller,
    required int maxLength,
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
        child: Container(
          key: sheetKey,
          child: AppDialog.buildSheetSurface(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileSheetHeader(
                    title: title,
                    description: description,
                  ),
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
                      color: AppColors.textTertiary.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          key: const Key('profile-editor-cancel'),
                          onPressed: () => Navigator.pop(sheetContext, false),
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextButton(
                          key: const Key('profile-editor-save'),
                          onPressed: () => Navigator.pop(sheetContext, true),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
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

class _ProfileChecklistItem {
  const _ProfileChecklistItem({
    required this.key,
    required this.label,
    required this.isReady,
  });

  final Key key;
  final String label;
  final bool isReady;
}
