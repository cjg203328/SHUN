import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../core/feedback/app_feedback.dart';
import '../core/ui/ui_tokens.dart';
import '../providers/profile_provider.dart';
import '../services/image_upload_service.dart';

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
    return Scaffold(
      backgroundColor: AppColors.pureBlack,
      body: Consumer<ProfileProvider>(
        builder: (context, profileProvider, child) {
          final screenHeight = MediaQuery.of(context).size.height;
          final hasBackground = _backgroundPath != null;
          final isPortraitFullscreen =
              hasBackground && profileProvider.portraitFullscreenBackground;
          final isTransparentBackground =
              isPortraitFullscreen && profileProvider.transparentHomepage;
          final normalHeight = (screenHeight * 0.52).clamp(320.0, 520.0);
          final fullHeight = screenHeight - MediaQuery.of(context).padding.top;
          final backgroundHeight =
              isPortraitFullscreen ? fullHeight : normalHeight;
          final profileTopOffset = isPortraitFullscreen
              ? backgroundHeight * 0.62
              : backgroundHeight - 62;
          final signatureText = profileProvider.signature.trim().isEmpty
              ? '这个人很神秘，什么都没留下'
              : profileProvider.signature.trim();
          return CustomScrollView(
            slivers: [
              // 顶部背景和个人信息区域
              SliverToBoxAdapter(
                child: Stack(
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
                                  image: FileImage(File(_backgroundPath!)),
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
                              Colors.black.withValues(
                                alpha: isTransparentBackground ? 0.06 : 0.1,
                              ),
                              Colors.black.withValues(
                                alpha: isTransparentBackground
                                    ? 0.24
                                    : (isPortraitFullscreen ? 0.4 : 0.5),
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
                            : Container(
                                alignment: Alignment.topRight,
                                padding: const EdgeInsets.all(12),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                      ),
                    ),

                    // 个人信息
                    Container(
                      margin: EdgeInsets.only(top: profileTopOffset),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                      child: Column(
                        children: [
                          // 头像
                          GestureDetector(
                            onTap: () => _changeAvatar(),
                            child: Stack(
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.white08,
                                    border: Border.all(
                                      color: AppColors.pureBlack,
                                      width: 4,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: _avatarPath != null
                                        ? Image.file(
                                            File(_avatarPath!),
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Center(
                                                child: Text(
                                                  profileProvider.avatar,
                                                  style: const TextStyle(
                                                      fontSize: 48),
                                                ),
                                              );
                                            },
                                          )
                                        : Center(
                                            child: Text(
                                              profileProvider.avatar,
                                              style:
                                                  const TextStyle(fontSize: 48),
                                            ),
                                          ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.white12,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.pureBlack,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 16,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // 昵称
                          GestureDetector(
                            onTap: () => _showEditNickname(context),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  profileProvider.nickname,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w300,
                                    color: AppColors.textPrimary,
                                    letterSpacing: 1,
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

                          const SizedBox(height: 8),

                          // 个性签名
                          GestureDetector(
                            onTap: () => _showEditSignature(context),
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 290),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
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
                          ),

                          const SizedBox(height: 24),

                          // 状态
                          GestureDetector(
                            onTap: () => _showEditStatus(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isTransparentBackground
                                    ? Colors.black.withValues(alpha: 0.28)
                                    : AppColors.white05,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isTransparentBackground
                                      ? AppColors.white08
                                      : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '状态：',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                  Text(
                                    profileProvider.status,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
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
                  ],
                ),
              ),

              // 功能列表
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: isTransparentBackground
                        ? Colors.black.withValues(alpha: 0.24)
                        : AppColors.white05,
                    borderRadius: BorderRadius.circular(UiTokens.radiusMd),
                    border: Border.all(
                      color: isTransparentBackground
                          ? AppColors.white08
                          : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildMenuSwitchItem(
                        icon: Icons.stay_current_portrait_outlined,
                        title: '竖屏全屏背景',
                        subtitle: hasBackground ? '按竖屏全屏展示背景图' : '先设置背景图后开启',
                        value: isPortraitFullscreen,
                        enabled: hasBackground,
                        onChanged: hasBackground
                            ? _setPortraitFullscreenBackground
                            : null,
                      ),
                      _buildMenuSwitchItem(
                        icon: Icons.layers_outlined,
                        title: '竖屏透明背景',
                        subtitle: isPortraitFullscreen
                            ? '降低遮罩，突出竖屏全屏背景'
                            : '开启竖屏全屏背景后可设置',
                        value: isTransparentBackground,
                        enabled: isPortraitFullscreen,
                        onChanged: isPortraitFullscreen
                            ? _setTransparentHomepage
                            : null,
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.settings_outlined,
                        title: '设置',
                        onTap: () => context
                            .push('/settings')
                            .then((_) => _loadImages()),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }

  // 修改头像
  Future<void> _changeAvatar() async {
    final imageFile = await ImageUploadService.pickAvatar(context);

    if (imageFile != null && mounted) {
      setState(() {
        _avatarPath = imageFile.path;
      });
      AppFeedback.showToast(context, AppToastCode.saved, subject: '头像');
    }
  }

  // 修改背景
  Future<void> _changeBackground() async {
    final imageFile = await ImageUploadService.pickBackground(context);

    if (imageFile != null && mounted) {
      setState(() {
        _backgroundPath = imageFile.path;
      });
      AppFeedback.showToast(context, AppToastCode.saved, subject: '背景');
    }
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

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSwitchItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    bool enabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: enabled
                ? AppColors.textSecondary
                : AppColors.textSecondary.withValues(alpha: 0.45),
            size: 22,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    color: enabled
                        ? AppColors.textPrimary
                        : AppColors.textDisabled.withValues(alpha: 0.8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: enabled
                        ? AppColors.textTertiary
                        : AppColors.textDisabled.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeColor: AppColors.textPrimary,
            activeTrackColor: AppColors.white20,
            inactiveThumbColor: AppColors.textSecondary,
            inactiveTrackColor: AppColors.white08,
          ),
        ],
      ),
    );
  }

  void _showEditNickname(BuildContext context) async {
    final profileProvider = context.read<ProfileProvider>();
    final controller = TextEditingController(text: profileProvider.nickname);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: AppOverlay.dialogBorderRadius,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '修改昵称',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  maxLength: 12,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '输入昵称',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 24),
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
                        onPressed: () => Navigator.pop(dialogContext, true),
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
        );
      },
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

  void _showEditSignature(BuildContext context) async {
    final profileProvider = context.read<ProfileProvider>();
    final controller = TextEditingController(text: profileProvider.signature);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: AppOverlay.dialogBorderRadius,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '个性签名',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  maxLength: 30,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '输入你的签名',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 24),
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
                        onPressed: () => Navigator.pop(dialogContext, true),
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
        );
      },
    );

    if (result == true && context.mounted) {
      final signature = controller.text.trim();
      await context.read<ProfileProvider>().updateSignature(
            signature.isEmpty ? '这个人很神秘，什么都没留下' : signature,
          );
      if (context.mounted) {
        AppFeedback.showToast(context, AppToastCode.saved, subject: '签名');
      }
    }

    controller.dispose();
  }

  void _showEditStatus(BuildContext context) async {
    final statuses = [
      '想找人聊聊',
      '有点失眠',
      '心情不好',
      '分享快乐',
      '深夜emo',
      '随便聊聊',
    ];

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: AppOverlay.dialogBorderRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  '选择状态',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...statuses.map((status) => InkWell(
                    onTap: () async {
                      Navigator.pop(context);
                      await context
                          .read<ProfileProvider>()
                          .updateStatus(status);
                      if (context.mounted) {
                        AppFeedback.showToast(
                          context,
                          AppToastCode.saved,
                          subject: '状态',
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              status,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w300,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
