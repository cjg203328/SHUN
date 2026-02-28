import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/friend_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../services/image_upload_service.dart';
import '../services/storage_service.dart';
import '../utils/permission_manager.dart';
import '../widgets/app_toast.dart';
import '../core/feedback/app_feedback.dart';
import '../core/ui/ui_tokens.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.pureBlack,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          '设置',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w300,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) => ListView(
          children: [
            const SizedBox(height: 20),

            // 个人资料
            _buildSectionTitle('个人资料'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.white05,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildSettingItem(
                    context,
                    icon: Icons.photo_outlined,
                    title: '头像管理',
                    onTap: () => _showAvatarManagement(context),
                  ),
                  _buildDivider(),
                  _buildSettingItem(
                    context,
                    icon: Icons.wallpaper_outlined,
                    title: '背景管理',
                    onTap: () => _showBackgroundManagement(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 账号与安全
            _buildSectionTitle('账号与安全'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.white05,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildSettingItem(
                    context,
                    icon: Icons.phone_outlined,
                    title: '手机号',
                    trailing: Consumer<AuthProvider>(
                      builder: (context, auth, child) => Text(
                        auth.phone ?? '未绑定',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                    onTap: () => _showUpdatePhoneDialog(context),
                  ),
                  _buildDivider(),
                  _buildSettingItem(
                    context,
                    icon: Icons.lock_outlined,
                    title: '修改密码',
                    onTap: () => _showChangePasswordDialog(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 隐私设置
            _buildSectionTitle('隐私设置'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.white05,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildSettingItem(
                    context,
                    icon: Icons.block_outlined,
                    title: '黑名单',
                    onTap: () => _showBlockedUsers(context),
                  ),
                  _buildDivider(),
                  _buildSettingItem(
                    context,
                    icon: Icons.visibility_off_outlined,
                    title: '隐身模式',
                    trailing: Switch(
                      value: settingsProvider.invisibleMode,
                      onChanged: _updateInvisibleMode,
                      activeColor: AppColors.brandBlue,
                    ),
                    onTap: null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 通知设置
            _buildSectionTitle('通知设置'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.white05,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildSettingItem(
                    context,
                    icon: Icons.notifications_outlined,
                    title: '消息通知',
                    trailing: Switch(
                      value: settingsProvider.notificationEnabled,
                      onChanged: _updateNotificationEnabled,
                      activeColor: AppColors.brandBlue,
                    ),
                    onTap: null,
                  ),
                  _buildDivider(),
                  _buildSettingItem(
                    context,
                    icon: Icons.vibration_outlined,
                    title: '震动',
                    trailing: Switch(
                      value: settingsProvider.vibrationEnabled,
                      onChanged: _updateVibrationEnabled,
                      activeColor: AppColors.brandBlue,
                    ),
                    onTap: null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 关于
            _buildSectionTitle('关于'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.white05,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildSettingItem(
                    context,
                    icon: Icons.info_outlined,
                    title: '关于瞬',
                    onTap: () => _showAboutDialog(context),
                  ),
                  _buildDivider(),
                  _buildSettingItem(
                    context,
                    icon: Icons.privacy_tip_outlined,
                    title: '隐私政策',
                    onTap: () => AppFeedback.showError(
                      context,
                      AppErrorCode.notSupported,
                      detail: '隐私政策内容准备中，请稍后查看',
                    ),
                  ),
                  _buildDivider(),
                  _buildSettingItem(
                    context,
                    icon: Icons.description_outlined,
                    title: '用户协议',
                    onTap: () => AppFeedback.showError(
                      context,
                      AppErrorCode.notSupported,
                      detail: '用户协议内容准备中，请稍后查看',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // 退出登录
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: OutlinedButton(
                onPressed: () => _showLogoutDialog(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppColors.error, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '退出登录',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 15,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 版本信息
            Center(
              child: Text(
                'V1.0.3',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textDisabled,
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 头像管理
  static Future<void> _showAvatarManagement(BuildContext context) async {
    final hasAvatar = await ImageUploadService.avatarExists();
    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) => Dialog(
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
                '头像管理',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // 更换头像
              _buildManagementItem(
                context,
                icon: Icons.photo_camera_outlined,
                title: '更换头像',
                onTap: () async {
                  Navigator.pop(context);
                  final imageFile =
                      await ImageUploadService.pickAvatar(context);
                  if (imageFile != null && context.mounted) {
                    AppFeedback.showToast(
                      context,
                      AppToastCode.saved,
                      subject: '头像',
                    );
                  }
                },
              ),

              // 删除头像（仅在有头像时显示）
              if (hasAvatar) ...[
                const SizedBox(height: 12),
                _buildManagementItem(
                  context,
                  icon: Icons.delete_outline,
                  title: '删除头像',
                  isDanger: true,
                  onTap: () async {
                    Navigator.pop(context);
                    final confirm = await _showConfirmDialog(
                      context,
                      title: '确定要删除头像吗？',
                      content: '删除后将恢复默认头像',
                    );

                    if (confirm == true) {
                      await ImageUploadService.clearAvatar();
                      if (context.mounted) {
                        AppFeedback.showToast(
                          context,
                          AppToastCode.deleted,
                          subject: '头像',
                        );
                      }
                    }
                  },
                ),
              ],

              const SizedBox(height: 20),

              // 取消按钮
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
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

  // 背景管理
  static Future<void> _showBackgroundManagement(BuildContext context) async {
    final hasBackground = await ImageUploadService.backgroundExists();
    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) => Dialog(
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
                '背景管理',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // 更换背景
              _buildManagementItem(
                context,
                icon: Icons.wallpaper_outlined,
                title: '更换背景',
                onTap: () async {
                  Navigator.pop(context);
                  final imageFile =
                      await ImageUploadService.pickBackground(context);
                  if (imageFile != null && context.mounted) {
                    AppFeedback.showToast(
                      context,
                      AppToastCode.saved,
                      subject: '背景',
                    );
                  }
                },
              ),

              // 删除背景（仅在有背景时显示）
              if (hasBackground) ...[
                const SizedBox(height: 12),
                _buildManagementItem(
                  context,
                  icon: Icons.delete_outline,
                  title: '删除背景',
                  isDanger: true,
                  onTap: () async {
                    Navigator.pop(context);
                    final confirm = await _showConfirmDialog(
                      context,
                      title: '确定要删除背景吗？',
                      content: '删除后将恢复默认背景',
                    );

                    if (confirm == true) {
                      await ImageUploadService.clearBackground();
                      if (context.mounted) {
                        AppFeedback.showToast(
                          context,
                          AppToastCode.deleted,
                          subject: '背景',
                        );
                      }
                    }
                  },
                ),
              ],

              const SizedBox(height: 20),

              // 取消按钮
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
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

  static Widget _buildManagementItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white05,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isDanger ? AppColors.error : AppColors.textSecondary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  color: isDanger ? AppColors.error : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<bool?> _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    return AppDialog.showConfirm(
      context,
      title: title,
      content: content,
      confirmText: '确定',
      isDanger: true,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 20, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w300,
            color: AppColors.textTertiary,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: UiTokens.cardPadding,
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            if (trailing != null)
              trailing
            else if (onTap != null)
              const Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 1,
      color: AppColors.white05,
    );
  }

  void _showAboutDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: AppOverlay.dialogBorderRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '关于瞬',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '版本：V1.0.3\n\n24小时限时匿名社交\n每个夜晚都是新的开始\n\nCopyright © 2026 瞬团队',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppColors.white12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '确定',
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
        ),
      ),
    );
  }

  void _showBlockedUsers(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        decoration: AppDialog.sheetDecoration(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  const Text(
                    '黑名单',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer2<FriendProvider, ChatProvider>(
                builder: (context, friendProvider, chatProvider, child) {
                  final blockedIds = friendProvider.blockedUserIds.toList()
                    ..sort();
                  if (blockedIds.isEmpty) {
                    return Center(
                      child: Text(
                        '暂无拉黑用户',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textTertiary,
                            ),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: blockedIds.length,
                    separatorBuilder: (_, __) =>
                        Divider(color: AppColors.white05, height: 1),
                    itemBuilder: (context, index) {
                      final userId = blockedIds[index];
                      final friend = friendProvider.getFriend(userId);
                      final thread = chatProvider.getThread(userId);
                      final avatar = friend?.user.avatar ??
                          thread?.otherUser.avatar ??
                          '👤';
                      final name = friend?.displayName ??
                          thread?.otherUser.nickname ??
                          userId;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.white08,
                          child: Text(
                            avatar,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w300,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          userId,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            await friendProvider.unblockUser(userId);
                            if (!context.mounted) return;
                            context
                                .read<ChatProvider>()
                                .restoreConversationAfterUnblock(userId);
                            if (!context.mounted) return;
                            AppFeedback.showToast(
                              context,
                              AppToastCode.disabled,
                              subject: '拉黑',
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.brandBlue,
                          ),
                          child: const Text('取消拉黑'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateInvisibleMode(bool enabled) async {
    await context.read<SettingsProvider>().updateInvisibleMode(enabled);
    if (!mounted) return;
    AppFeedback.showToast(
      context,
      enabled ? AppToastCode.enabled : AppToastCode.disabled,
      subject: '隐身模式',
    );
  }

  Future<void> _updateNotificationEnabled(bool enabled) async {
    bool finalValue = enabled;
    if (enabled) {
      final granted = await PermissionManager.requestNotificationPermission(
        context,
      );
      finalValue = granted;
      if (!granted && mounted) {
        AppFeedback.showError(context, AppErrorCode.permissionDenied);
      }
    }

    if (!mounted) return;
    await context
        .read<SettingsProvider>()
        .updateNotificationEnabled(finalValue);
    if (!mounted) return;
    AppFeedback.showToast(
      context,
      finalValue ? AppToastCode.enabled : AppToastCode.disabled,
      subject: '通知',
    );
  }

  Future<void> _updateVibrationEnabled(bool enabled) async {
    await context.read<SettingsProvider>().updateVibrationEnabled(enabled);
    if (!mounted) return;
    AppFeedback.showToast(
      context,
      enabled ? AppToastCode.enabled : AppToastCode.disabled,
      subject: '震动',
    );
  }

  Future<void> _showUpdatePhoneDialog(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final controller = TextEditingController(text: authProvider.phone ?? '');
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          decoration: AppDialog.sheetDecoration(),
          padding: const EdgeInsets.all(24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '修改手机号',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  decoration: const InputDecoration(
                    hintText: '请输入新手机号',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                        onPressed: () => Navigator.pop(sheetContext, true),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
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

    if (result == true && context.mounted) {
      final phone = controller.text.trim();
      final valid = RegExp(r'^\d{11}$').hasMatch(phone);
      if (!valid) {
        AppFeedback.showError(
          context,
          AppErrorCode.invalidInput,
          detail: '请输入11位手机号后重试',
        );
      } else {
        await authProvider.updatePhone(phone);
        if (!context.mounted) return;
        AppFeedback.showToast(context, AppToastCode.saved, subject: '手机号');
      }
    }
    controller.dispose();
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          decoration: AppDialog.sheetDecoration(),
          padding: const EdgeInsets.all(24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '修改密码',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: oldController,
                  obscureText: true,
                  decoration: const InputDecoration(hintText: '输入旧密码'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: newController,
                  obscureText: true,
                  decoration: const InputDecoration(hintText: '输入新密码（至少6位）'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(hintText: '确认新密码'),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                        onPressed: () => Navigator.pop(sheetContext, true),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.white12,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '确认',
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

    if (result == true && context.mounted) {
      final oldPassword = oldController.text.trim();
      final newPassword = newController.text.trim();
      final confirmPassword = confirmController.text.trim();
      final currentPassword = StorageService.getLocalPassword();

      if (oldPassword != currentPassword) {
        AppFeedback.showError(
          context,
          AppErrorCode.invalidInput,
          detail: '旧密码不正确，请重新输入',
        );
      } else if (newPassword.length < 6) {
        AppFeedback.showError(
          context,
          AppErrorCode.invalidInput,
          detail: '新密码至少6位，请重新设置',
        );
      } else if (newPassword != confirmPassword) {
        AppFeedback.showError(
          context,
          AppErrorCode.invalidInput,
          detail: '两次输入不一致，请重新确认',
        );
      } else {
        await StorageService.saveLocalPassword(newPassword);
        if (!context.mounted) return;
        AppFeedback.showToast(context, AppToastCode.saved, subject: '密码');
      }
    }

    oldController.dispose();
    newController.dispose();
    confirmController.dispose();
  }

  void _showLogoutDialog(BuildContext context) async {
    final confirm = await AppDialog.showConfirm(
      context,
      title: '退出登录',
      content: '确定要退出登录吗？',
      confirmText: '退出',
      isDanger: true,
    );

    if (confirm == true && context.mounted) {
      context.read<AuthProvider>().logout();
      context.go('/login');
    }
  }
}
