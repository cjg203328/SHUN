import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../models/app_notification.dart';
import '../providers/auth_provider.dart';
import '../providers/friend_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/notification_center_provider.dart';
import '../providers/settings_provider.dart';
import '../services/image_upload_service.dart';
import '../services/storage_service.dart';
import '../utils/notification_permission_guidance.dart';
import '../utils/permission_manager.dart';
import '../widgets/app_toast.dart';
import '../widgets/chat_delivery_debug_sheet.dart';
import '../core/feedback/app_feedback.dart';
import '../core/ui/ui_tokens.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  _SettingsInlineFeedbackState? _inlineFeedback;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }
    unawaited(_refreshNotificationPermissionAfterSystemSettingsReturn());
  }

  Future<void> _refreshNotificationPermissionAfterSystemSettingsReturn() async {
    if (!mounted) return;
    final settingsProvider = context.read<SettingsProvider>();
    final didRefresh = await settingsProvider
        .refreshPushRuntimeStateAfterSystemSettingsReturn();
    if (!mounted || !didRefresh) return;
    _showInlineFeedback(
      _buildNotificationResumeInlineFeedback(settingsProvider),
    );
  }

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
        builder: (context, settingsProvider, child) {
          final invisibleSettingHint = _resolveInvisibleSettingHint(
            settingsProvider,
          );
          final notificationSettingHint = _resolveNotificationSettingHint(
            settingsProvider,
          );
          final vibrationSettingHint = _resolveVibrationSettingHint(
            settingsProvider,
          );

          return ListView(
            padding: const EdgeInsets.only(top: 20, bottom: 40),
            children: [
              _buildSettingsOverviewCard(context, settingsProvider),
              const SizedBox(height: 28),
              _buildSectionTitle('账号与安全', subtitle: '登录、身份标识与账号找回'),
              _buildSectionCard(
                children: [
                  _buildSettingItem(
                    context,
                    key: const Key('settings-phone-item'),
                    icon: Icons.phone_outlined,
                    title: '手机号',
                    subtitle: '用于登录、接收验证码和找回账号',
                    trailing: Consumer<AuthProvider>(
                      builder: (context, auth, child) => Text(
                        auth.phone ?? '未绑定',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                    onTap: () => _presentPhoneEditorSheet(context),
                  ),
                  _buildDivider(),
                  _buildSettingItem(
                    context,
                    icon: Icons.badge_outlined,
                    title: '账号 UID',
                    subtitle: '点击即可复制，便于测试、加好友或排查问题',
                    trailing: Consumer<AuthProvider>(
                      builder: (context, auth, child) => Text(
                        auth.uid ?? '生成中',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                    onTap: () => _copyUid(context),
                  ),
                  _buildDivider(),
                  _buildSettingItem(
                    context,
                    key: const Key('settings-password-item'),
                    icon: Icons.lock_outlined,
                    title: '修改密码',
                    subtitle: '定期更新密码，能更好保护你的账号安全',
                    onTap: () => _presentPasswordEditorSheet(context),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _buildSectionTitle('隐私与展示', subtitle: '优先保留影响曝光和关系边界的核心设置'),
              _buildSectionCard(
                children: [
                  _buildSettingItem(
                    context,
                    key: const Key('settings-invisible-mode-item'),
                    icon: Icons.visibility_off_outlined,
                    title: '隐身模式',
                    subtitle: '开启后，你的活跃状态和匹配曝光会更低调',
                    helperText: invisibleSettingHint.description,
                    badgeLabel: invisibleSettingHint.badgeLabel,
                    badgeKey: const Key('settings-invisible-mode-badge'),
                    badgeHighlight: !invisibleSettingHint.isHealthy,
                    trailing: Switch(
                      value: settingsProvider.invisibleMode,
                      onChanged: _updateInvisibleMode,
                      activeColor: AppColors.brandBlue,
                    ),
                    onTap: null,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _buildSectionTitle('通知与提醒', subtitle: '建议保持消息通知开启，避免错过新回复'),
              _buildSectionCard(
                children: [
                  _buildSettingItem(
                    context,
                    key: const Key('settings-notification-item'),
                    icon: Icons.notifications_outlined,
                    title: '消息通知',
                    subtitle: '关闭后，将不再收到新消息提醒',
                    helperText: notificationSettingHint.description,
                    badgeLabel: notificationSettingHint.badgeLabel,
                    badgeKey: const Key('settings-notification-badge'),
                    badgeHighlight: !notificationSettingHint.isHealthy,
                    trailing: Switch(
                      value: settingsProvider.notificationEnabled,
                      onChanged: _updateNotificationEnabled,
                      activeColor: AppColors.brandBlue,
                    ),
                    onTap: null,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _buildSectionTitle('资料与展示', subtitle: '优先维护头像，背景等低频内容可按需调整'),
              _buildSectionCard(
                children: [
                  _buildSettingItem(
                    context,
                    key: const Key('settings-avatar-management-item'),
                    icon: Icons.photo_outlined,
                    title: '头像管理',
                    subtitle: '上传、替换或删除你的当前头像',
                    onTap: () => _presentAvatarManagementSheet(context),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _buildSectionTitle('更多设置（低频）', subtitle: '这些内容通常不用频繁修改，需要时再进入即可'),
              _buildSectionCard(
                children: [
                  _buildSettingItem(
                    context,
                    key: const Key('settings-blocked-users-item'),
                    icon: Icons.block_outlined,
                    title: '黑名单',
                    subtitle: '管理你不想再看到或接触的人',
                    onTap: () => _showBlockedUsers(context),
                  ),
                  _buildDivider(),
                  _buildSettingItem(
                    context,
                    key: const Key('settings-vibration-item'),
                    icon: Icons.vibration_outlined,
                    title: '震动提醒',
                    subtitle: '收到消息时通过震动给予提示',
                    helperText: vibrationSettingHint.description,
                    badgeLabel: vibrationSettingHint.badgeLabel,
                    badgeKey: const Key('settings-vibration-badge'),
                    badgeHighlight: !vibrationSettingHint.isHealthy,
                    trailing: Switch(
                      value: settingsProvider.vibrationEnabled,
                      onChanged: _updateVibrationEnabled,
                      activeColor: AppColors.brandBlue,
                    ),
                    onTap: null,
                  ),
                  _buildDivider(),
                  _buildSettingItem(
                    context,
                    key: const Key('settings-background-management-item'),
                    icon: Icons.wallpaper_outlined,
                    title: '背景管理',
                    subtitle: '主页背景会影响别人看到你的第一印象',
                    onTap: () => _presentBackgroundManagementSheet(context),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _buildSectionTitle('关于与协议', subtitle: '查看产品说明、协议与隐私内容'),
              _buildSectionCard(
                children: [
                  _buildSettingItem(
                    context,
                    icon: Icons.info_outlined,
                    title: '关于瞬',
                    subtitle: '查看产品介绍、版本信息与开发说明',
                    onTap: () => context.push('/about'),
                  ),
                  _buildDivider(),
                  _buildSettingItem(
                    context,
                    icon: Icons.privacy_tip_outlined,
                    title: '隐私政策',
                    subtitle: '说明我们如何收集、使用和保护你的数据',
                    onTap: () => context.push('/legal/privacy-policy'),
                  ),
                  _buildDivider(),
                  _buildSettingItem(
                    context,
                    icon: Icons.description_outlined,
                    title: '用户协议',
                    subtitle: '查看使用规则、权责说明与服务条款',
                    onTap: () => context.push('/legal/user-agreement'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
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
              const SizedBox(height: 18),
              Center(
                child: GestureDetector(
                  key: const ValueKey<String>('settings-debug-version-trigger'),
                  onLongPress: kDebugMode
                      ? () => showChatDeliveryStatsDebugSheet(context)
                      : null,
                  child: Text(
                    'V1.0.3',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 头像管理
  // ignore: unused_element
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
  // ignore: unused_element
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

  Future<void> _presentAvatarManagementSheet(BuildContext context) async {
    final hasAvatar = await ImageUploadService.avatarExists();
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (sheetContext) => _buildMediaManagementSheet(
        key: const Key('settings-avatar-sheet'),
        context: sheetContext,
        title: '头像管理',
        description: '头像会持续出现在消息列表和个人页里，建议保持清晰、稳定、容易识别。',
        replaceAction: _buildManagementItem(
          context,
          key: const Key('settings-avatar-replace-action'),
          icon: Icons.photo_camera_outlined,
          title: '更换头像',
          onTap: () async {
            Navigator.pop(sheetContext);
            final imageFile = await ImageUploadService.pickAvatar(context);
            if (imageFile != null && context.mounted) {
              _showInlineFeedback(
                const _SettingsInlineFeedbackState(
                  icon: Icons.photo_camera_outlined,
                  title: '头像已经更新',
                  badgeLabel: '资料已刷新',
                  description: '新的头像会同步出现在消息列表和个人页里，别人更容易认出你。',
                  isHealthy: true,
                ),
              );
              AppFeedback.showToast(
                context,
                AppToastCode.saved,
                subject: '头像',
              );
            }
          },
        ),
        deleteAction: hasAvatar
            ? _buildManagementItem(
                context,
                key: const Key('settings-avatar-delete-action'),
                icon: Icons.delete_outline,
                title: '删除头像',
                isDanger: true,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final confirm = await _showConfirmDialog(
                    context,
                    title: '确定要删除头像吗？',
                    content: '删除后将恢复默认头像',
                  );
                  if (confirm == true) {
                    await ImageUploadService.clearAvatar();
                    if (context.mounted) {
                      _showInlineFeedback(
                        const _SettingsInlineFeedbackState(
                          icon: Icons.delete_outline,
                          title: '头像已恢复默认',
                          badgeLabel: '已清空',
                          description: '当前资料会回到默认头像，如果之后要恢复识别度，可以再重新上传。',
                        ),
                      );
                      AppFeedback.showToast(
                        context,
                        AppToastCode.deleted,
                        subject: '头像',
                      );
                    }
                  }
                },
              )
            : null,
      ),
    );
  }

  Future<void> _presentBackgroundManagementSheet(
    BuildContext context,
  ) async {
    final hasBackground = await ImageUploadService.backgroundExists();
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (sheetContext) => _buildMediaManagementSheet(
        key: const Key('settings-background-sheet'),
        context: sheetContext,
        title: '背景管理',
        description: '背景会影响别人进入你主页时的第一眼氛围，建议保持清爽、不过度花哨。',
        replaceAction: _buildManagementItem(
          context,
          key: const Key('settings-background-replace-action'),
          icon: Icons.wallpaper_outlined,
          title: '更换背景',
          onTap: () async {
            Navigator.pop(sheetContext);
            final imageFile = await ImageUploadService.pickBackground(context);
            if (imageFile != null && context.mounted) {
              _showInlineFeedback(
                const _SettingsInlineFeedbackState(
                  icon: Icons.wallpaper_outlined,
                  title: '背景已经更新',
                  badgeLabel: '氛围已刷新',
                  description: '新的背景会影响别人进入你主页时的第一眼感受，现在已经同步生效。',
                  isHealthy: true,
                ),
              );
              AppFeedback.showToast(
                context,
                AppToastCode.saved,
                subject: '背景',
              );
            }
          },
        ),
        deleteAction: hasBackground
            ? _buildManagementItem(
                context,
                key: const Key('settings-background-delete-action'),
                icon: Icons.delete_outline,
                title: '删除背景',
                isDanger: true,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final confirm = await _showConfirmDialog(
                    context,
                    title: '确定要删除背景吗？',
                    content: '删除后将恢复默认背景',
                  );
                  if (confirm == true) {
                    await ImageUploadService.clearBackground();
                    if (context.mounted) {
                      _showInlineFeedback(
                        const _SettingsInlineFeedbackState(
                          icon: Icons.delete_outline,
                          title: '背景已恢复默认',
                          badgeLabel: '已清空',
                          description: '主页氛围已经回到默认状态，后续如果想重新做区分度，可以再上传新的背景。',
                        ),
                      );
                      AppFeedback.showToast(
                        context,
                        AppToastCode.deleted,
                        subject: '背景',
                      );
                    }
                  }
                },
              )
            : null,
      ),
    );
  }

  static Widget _buildManagementItem(
    BuildContext context, {
    Key? key,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return InkWell(
      key: key,
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

  static Widget _buildMediaManagementSheet({
    required Key key,
    required BuildContext context,
    required String title,
    required String description,
    required Widget replaceAction,
    Widget? deleteAction,
  }) {
    return Container(
      key: key,
      child: AppDialog.buildSheetSurface(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 16),
            replaceAction,
            if (deleteAction != null) ...[
              const SizedBox(height: 12),
              deleteAction,
            ],
            const SizedBox(height: 18),
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
    );
  }

  // ignore: unused_element
  static Widget _buildMediaManagementSheetLegacy({
    required Key key,
    required BuildContext context,
    required String title,
    required String description,
    required Widget replaceAction,
    Widget? deleteAction,
  }) {
    return Container(
      key: key,
      child: AppDialog.buildSheetSurface(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 16),
            replaceAction,
            if (deleteAction != null) ...[
              const SizedBox(height: 12),
              deleteAction,
            ],
            const SizedBox(height: 18),
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

  Widget _buildSettingsOverviewCard(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    final auth = context.watch<AuthProvider>();
    final focusState = _resolveOverviewFocusState(
      auth: auth,
      settingsProvider: settingsProvider,
    );
    final notificationRuntimeState = _resolveNotificationRuntimeState(
      settingsProvider,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.white08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '设置总览',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '把高频功能集中放在前面，方便你快速调整账号、安全、隐私和通知。',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w300,
              color: AppColors.textTertiary.withValues(alpha: 0.9),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          _buildOverviewFocusCard(focusState),
          const SizedBox(height: 14),
          _buildDeviceStatusCard(settingsProvider),
          const SizedBox(height: 14),
          _buildExperiencePresetCard(context, settingsProvider),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusChip(
                icon: Icons.phone_iphone_outlined,
                label: auth.phone == null ? '手机号未绑定' : '手机号已绑定',
              ),
              _buildStatusChip(
                icon: Icons.badge_outlined,
                label: auth.uid == null ? 'UID 生成中' : 'UID 已可复制',
              ),
              _buildStatusChip(
                icon: Icons.notifications_outlined,
                label: notificationRuntimeState.statusChipLabel,
              ),
              _buildStatusChip(
                icon: Icons.visibility_off_outlined,
                label: settingsProvider.invisibleMode ? '当前隐身中' : '正常展示中',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildOverviewAction(
                key: const Key('settings-overview-phone-action'),
                icon: Icons.phone_outlined,
                label: '处理手机号',
                onTap: () => _presentPhoneEditorSheet(context),
              ),
              _buildOverviewAction(
                key: const Key('settings-overview-uid-action'),
                icon: Icons.badge_outlined,
                label: '复制 UID',
                onTap: () => _copyUid(context),
              ),
              _buildOverviewAction(
                key: const Key('settings-overview-notification-action'),
                icon: notificationRuntimeState.actionIcon,
                label: notificationRuntimeState.actionLabel,
                onTap: () => _handleNotificationAction(
                  notificationRuntimeState.actionType,
                ),
              ),
            ],
          ),
          if (_inlineFeedback != null) ...[
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _buildInlineFeedbackCard(_inlineFeedback!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewFocusCard(_SettingsOverviewFocusState state) {
    return Container(
      key: const Key('settings-overview-focus-card'),
      padding: const EdgeInsets.all(14),
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
            child: Icon(
              state.icon,
              size: 18,
              color: state.isHealthy
                  ? AppColors.textSecondary
                  : AppColors.brandBlue,
            ),
          ),
          const SizedBox(width: 12),
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
                        style: const TextStyle(
                          fontSize: 14,
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
                        color: state.isHealthy
                            ? AppColors.white12
                            : AppColors.brandBlue.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        state.badgeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w300,
                          color: state.isHealthy
                              ? AppColors.textSecondary
                              : AppColors.brandBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  state.subtitle,
                  style: TextStyle(
                    fontSize: 12,
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

  Widget _buildOverviewAction({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white08,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w300,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceStatusCard(SettingsProvider settingsProvider) {
    final notificationRuntimeState = _resolveNotificationRuntimeState(
      settingsProvider,
    );
    final notificationCenterDigest = _resolveNotificationCenterDigest(
      Provider.of<NotificationCenterProvider?>(context),
    );
    final statusItems = <_SettingsDeviceStatusItem>[
      _SettingsDeviceStatusItem(
        key: const Key('settings-device-status-notification'),
        icon: notificationRuntimeState.icon,
        title: '消息触达',
        badgeLabel: notificationRuntimeState.badgeLabel,
        description: notificationRuntimeState.description,
        isHealthy: notificationRuntimeState.isHealthy,
      ),
      _SettingsDeviceStatusItem(
        key: const Key('settings-device-status-presence'),
        icon: settingsProvider.invisibleMode
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
        title: '曝光状态',
        badgeLabel: settingsProvider.invisibleMode ? '低曝光' : '正常展示',
        description: settingsProvider.invisibleMode
            ? '当前更偏隐私保护，适合观察环境，但匹配和被回复概率会更保守。'
            : '当前更适合正常匹配和聊天，别人更容易感知到你在线。 ',
        isHealthy: !settingsProvider.invisibleMode,
      ),
      _SettingsDeviceStatusItem(
        key: const Key('settings-device-status-vibration'),
        icon: settingsProvider.vibrationEnabled
            ? Icons.vibration_outlined
            : Icons.do_not_disturb_on_outlined,
        title: '提醒强度',
        badgeLabel: settingsProvider.vibrationEnabled ? '更及时' : '更安静',
        description: settingsProvider.vibrationEnabled
            ? '振动开启后，弱网或锁屏场景下更不容易错过关键提醒。'
            : '更适合安静使用，但建议配合通知开启一起看，避免完全静默。',
        isHealthy: settingsProvider.vibrationEnabled,
      ),
    ];

    return Container(
      key: const Key('settings-device-status-card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white08,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '设备状态总览',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '不用逐项扫开关，也能先判断这台设备现在更偏及时触达、安静使用还是隐私优先。',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: AppColors.textTertiary.withValues(alpha: 0.92),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          ...statusItems.asMap().entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(
                      bottom: entry.key == statusItems.length - 1 ? 0 : 10),
                  child: _buildDeviceStatusRow(entry.value),
                ),
              ),
          if (notificationRuntimeState.followUpDescription != null) ...[
            const SizedBox(height: 12),
            _buildNotificationRuntimeCard(
              context,
              notificationRuntimeState,
              digest: notificationCenterDigest,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeviceStatusRow(_SettingsDeviceStatusItem item) {
    return Container(
      key: item.key,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.white08),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: item.isHealthy
                  ? AppColors.white12
                  : AppColors.brandBlue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.icon,
              size: 16,
              color: item.isHealthy
                  ? AppColors.textSecondary
                  : AppColors.brandBlue,
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
                        item.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.isHealthy
                            ? AppColors.white12
                            : AppColors.brandBlue.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.badgeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w300,
                          color: item.isHealthy
                              ? AppColors.textSecondary
                              : AppColors.brandBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textTertiary.withValues(alpha: 0.9),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationRuntimeCard(
      BuildContext context, _SettingsNotificationRuntimeState state,
      {_SettingsNotificationCenterDigestState? digest}) {
    return Container(
      key: const Key('settings-notification-runtime-card'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: state.isHealthy
            ? AppColors.white05
            : AppColors.brandBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: state.isHealthy
              ? AppColors.white08
              : AppColors.brandBlue.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: state.isHealthy
                  ? AppColors.white08
                  : AppColors.brandBlue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              state.icon,
              size: 16,
              color: state.isHealthy
                  ? AppColors.textSecondary
                  : AppColors.brandBlue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Text(
                        '通知通道提示',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      key: const Key('settings-notification-runtime-badge'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: state.isHealthy
                            ? AppColors.white08
                            : AppColors.brandBlue.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        state.badgeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w300,
                          color: state.isHealthy
                              ? AppColors.textSecondary
                              : AppColors.brandBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  state.followUpDescription!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textTertiary.withValues(alpha: 0.92),
                    height: 1.35,
                  ),
                ),
                if (digest != null) ...[
                  const SizedBox(height: 10),
                  _buildNotificationCenterDigestCard(digest),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      key: const Key('settings-notification-runtime-action'),
                      onPressed: () =>
                          _handleNotificationAction(state.actionType),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        foregroundColor: AppColors.brandBlue,
                        backgroundColor:
                            AppColors.brandBlue.withValues(alpha: 0.12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        state.actionLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      key: const Key('settings-notification-center-action'),
                      onPressed: () => context.push('/notifications'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        foregroundColor: AppColors.textSecondary,
                        backgroundColor: AppColors.white08,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppColors.white12),
                        ),
                      ),
                      icon: const Icon(
                        Icons.notifications_none_outlined,
                        size: 16,
                      ),
                      label: const Text(
                        NotificationPermissionGuidance
                            .openNotificationCenterAction,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCenterDigestCard(
    _SettingsNotificationCenterDigestState state,
  ) {
    return Container(
      key: const Key('settings-notification-center-summary-card'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.white08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  state.title,
                  key: const Key('settings-notification-center-summary-title'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                key: const Key('settings-notification-center-summary-badge'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: state.hasUnread
                      ? AppColors.brandBlue.withValues(alpha: 0.16)
                      : AppColors.white08,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  state.badgeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                    color: state.hasUnread
                        ? AppColors.brandBlue
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            state.description,
            key: const Key('settings-notification-center-summary-description'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w300,
              color: AppColors.textTertiary.withValues(alpha: 0.92),
              height: 1.35,
            ),
          ),
          if (state.sourceItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              key: const Key('settings-notification-center-source-overview'),
              spacing: 6,
              runSpacing: 6,
              children: state.sourceItems
                  .map(_buildNotificationCenterSourceChip)
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationCenterSourceChip(
    _SettingsNotificationCenterSourceDigestItem item,
  ) {
    return InkWell(
      key: item.key,
      onTap: () =>
          context.push('/notifications?source=${item.sourceType.name}'),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: item.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: item.color.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: 12,
              color: item.color.withValues(alpha: 0.94),
            ),
            const SizedBox(width: 5),
            Text(
              '${item.label} ${item.count}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w300,
                color: item.color.withValues(alpha: 0.95),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineFeedbackCard(_SettingsInlineFeedbackState state) {
    return Container(
      key: const Key('settings-inline-feedback-card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: state.isHealthy
            ? AppColors.white08
            : AppColors.brandBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
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
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: state.isHealthy
                  ? AppColors.white12
                  : AppColors.brandBlue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              state.icon,
              size: 17,
              color: state.isHealthy
                  ? AppColors.textSecondary
                  : AppColors.brandBlue,
            ),
          ),
          const SizedBox(width: 10),
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
                        key: const Key('settings-inline-feedback-title'),
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
                        color: state.isHealthy
                            ? AppColors.white12
                            : AppColors.brandBlue.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        key: const Key('settings-inline-feedback-badge'),
                        state.badgeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w300,
                          color: state.isHealthy
                              ? AppColors.textSecondary
                              : AppColors.brandBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  state.description,
                  key: const Key('settings-inline-feedback-description'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textTertiary.withValues(alpha: 0.92),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExperiencePresetCard(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    final currentPresetState = _resolveExperiencePresetState(settingsProvider);
    final activePreset = settingsProvider.activeExperiencePreset;
    final presetOptions = _experiencePresetOptions;

    return Container(
      key: const Key('settings-experience-preset-card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white08,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  '设备模式预设',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                key: const Key('settings-experience-preset-current-badge'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: currentPresetState.isHealthy
                      ? AppColors.white12
                      : AppColors.brandBlue.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  currentPresetState.badgeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                    color: currentPresetState.isHealthy
                        ? AppColors.textSecondary
                        : AppColors.brandBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            currentPresetState.description,
            key: const Key('settings-experience-preset-summary'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: AppColors.textTertiary.withValues(alpha: 0.92),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          ...presetOptions.asMap().entries.map((entry) {
            final option = entry.value;
            final isActive = activePreset == option.preset;
            return Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == presetOptions.length - 1 ? 0 : 10,
              ),
              child: _buildExperiencePresetOption(
                context,
                option: option,
                isActive: isActive,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildExperiencePresetOption(
    BuildContext context, {
    required _SettingsExperiencePresetOption option,
    required bool isActive,
  }) {
    return InkWell(
      key: option.key,
      onTap: () => _applyExperiencePreset(option.preset),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.brandBlue.withValues(alpha: 0.12)
              : AppColors.white05,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? AppColors.brandBlue.withValues(alpha: 0.3)
                : AppColors.white08,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.brandBlue.withValues(alpha: 0.16)
                    : AppColors.white08,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                option.icon,
                size: 17,
                color: isActive ? AppColors.brandBlue : AppColors.textSecondary,
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
                          option.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.brandBlue.withValues(alpha: 0.18)
                              : AppColors.white08,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isActive ? '当前' : option.badgeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w300,
                            color: isActive
                                ? AppColors.brandBlue
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.description,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textTertiary.withValues(alpha: 0.9),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.white08,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  _SettingsToggleHint _resolveInvisibleSettingHint(
    SettingsProvider settingsProvider,
  ) {
    if (settingsProvider.invisibleMode) {
      return const _SettingsToggleHint(
        badgeLabel: '低曝光',
        description: '当前更适合安静观察，别人更难感知到你在线，但匹配和被回复概率会更保守。',
      );
    }

    return const _SettingsToggleHint(
      badgeLabel: '正常展示',
      description: '当前更适合正常匹配和聊天，别人更容易感知到你在线。',
      isHealthy: true,
    );
  }

  _SettingsExperiencePresetState _resolveExperiencePresetState(
    SettingsProvider settingsProvider,
  ) {
    switch (settingsProvider.activeExperiencePreset) {
      case SettingsExperiencePreset.responsive:
        return const _SettingsExperiencePresetState(
          badgeLabel: '在线回复',
          description: '当前这台设备更适合做主聊天入口，通知、振动和正常展示都已经打开。',
          isHealthy: true,
        );
      case SettingsExperiencePreset.balanced:
        return const _SettingsExperiencePresetState(
          badgeLabel: '低干扰',
          description: '当前保持在线触达，但提醒更克制，适合通勤或不想被频繁打断时使用。',
          isHealthy: true,
        );
      case SettingsExperiencePreset.quietObserve:
        return const _SettingsExperiencePresetState(
          badgeLabel: '安静观察',
          description: '当前更偏隐私和安静使用，适合短时离线、观察环境或暂时不想暴露在线状态。',
        );
      case null:
        return const _SettingsExperiencePresetState(
          badgeLabel: '自定义组合',
          description: '你已经手动组合了通知、隐身和振动设置；如果想快速回到稳定状态，可以直接使用下面的一键预设。',
        );
    }
  }

  List<_SettingsExperiencePresetOption> get _experiencePresetOptions => const [
        _SettingsExperiencePresetOption(
          key: Key('settings-preset-responsive'),
          preset: SettingsExperiencePreset.responsive,
          icon: Icons.flash_on_outlined,
          title: '在线回复',
          badgeLabel: '推荐',
          description: '通知、振动和正常展示全部打开，最适合作为主聊天入口。',
        ),
        _SettingsExperiencePresetOption(
          key: Key('settings-preset-balanced'),
          preset: SettingsExperiencePreset.balanced,
          icon: Icons.tune_outlined,
          title: '低干扰',
          badgeLabel: '通勤',
          description: '保持消息在线，但收起振动打扰，更适合工作或通勤场景。',
        ),
        _SettingsExperiencePresetOption(
          key: Key('settings-preset-quiet-observe'),
          preset: SettingsExperiencePreset.quietObserve,
          icon: Icons.nightlight_round_outlined,
          title: '安静观察',
          badgeLabel: '低曝光',
          description: '关闭通知和振动，并切到隐身状态，适合短时离线或观察环境。',
        ),
      ];

  _SettingsToggleHint _resolveNotificationSettingHint(
    SettingsProvider settingsProvider,
  ) {
    final pushState = settingsProvider.pushRuntimeState;
    if (!settingsProvider.notificationEnabled) {
      return const _SettingsToggleHint(
        badgeLabel: '易漏消息',
        description: '当前更偏安静使用，关闭后容易错过新回复和关键提醒。',
      );
    }

    if (!pushState.permissionGranted) {
      return const _SettingsToggleHint(
        badgeLabel: '待授权',
        description: '应用内通知已打开，但系统权限还没开启，锁屏和后台提醒仍可能缺失。',
      );
    }

    if (pushState.deviceToken == null) {
      return const _SettingsToggleHint(
        badgeLabel: '同步中',
        description: '系统权限已开启，正在准备这台设备的通知通道，稍后可刷新确认。',
      );
    }

    return const _SettingsToggleHint(
      badgeLabel: '在线',
      description: '新消息会更快到这台设备，适合把它当主要聊天入口。',
      isHealthy: true,
    );
  }

  _SettingsToggleHint _resolveVibrationSettingHint(
    SettingsProvider settingsProvider,
  ) {
    if (!settingsProvider.vibrationEnabled) {
      return const _SettingsToggleHint(
        badgeLabel: '更安静',
        description: '提醒会更克制，适合安静场景，但弱网和锁屏下更容易错过即时反馈。',
      );
    }

    return const _SettingsToggleHint(
      badgeLabel: '更及时',
      description: '弱网或锁屏时更不容易错过关键提醒，整体反馈会更直接。',
      isHealthy: true,
    );
  }

  _SettingsOverviewFocusState _resolveOverviewFocusState({
    required AuthProvider auth,
    required SettingsProvider settingsProvider,
  }) {
    final pushState = settingsProvider.pushRuntimeState;
    if ((auth.phone ?? '').trim().isEmpty) {
      return const _SettingsOverviewFocusState(
        icon: Icons.phone_outlined,
        title: '建议先绑定手机号',
        subtitle: '这样登录找回、异常排查和账号确认都会更顺手，也能减少后续联调歧义。',
        badgeLabel: '优先处理',
      );
    }

    if (settingsProvider.notificationEnabled && !pushState.permissionGranted) {
      return const _SettingsOverviewFocusState(
        icon: Icons.notifications_paused_outlined,
        title: '建议开启系统通知权限',
        subtitle: NotificationPermissionGuidance.settingsDescription,
        badgeLabel: NotificationPermissionGuidance.badgeLabel,
      );
    }

    if (!settingsProvider.notificationEnabled) {
      return const _SettingsOverviewFocusState(
        icon: Icons.notifications_active_outlined,
        title: '建议恢复消息通知',
        subtitle: '通知关闭后很容易错过新回复，打开后这台设备会更像真正在线的聊天入口。',
        badgeLabel: '建议开启',
      );
    }

    if (settingsProvider.invisibleMode) {
      return const _SettingsOverviewFocusState(
        icon: Icons.visibility_off_outlined,
        title: '当前处于隐身模式',
        subtitle: '如果你接下来准备正常使用匹配和聊天，建议恢复展示状态，避免曝光和到达率偏低。',
        badgeLabel: '继续观察',
      );
    }

    return const _SettingsOverviewFocusState(
      icon: Icons.verified_outlined,
      title: '当前设置状态良好',
      subtitle: '高频设置已经收在前面，账号、通知和展示状态都比较完整，后续按需调整即可。',
      badgeLabel: '无需处理',
      isHealthy: true,
    );
  }

  _SettingsNotificationRuntimeState _resolveNotificationRuntimeState(
    SettingsProvider settingsProvider,
  ) {
    final pushState = settingsProvider.pushRuntimeState;
    if (!settingsProvider.notificationEnabled) {
      return const _SettingsNotificationRuntimeState(
        icon: Icons.notifications_off_outlined,
        badgeLabel: '已静默',
        description: '应用内通知当前已关闭，新的消息会留在通知中心，适合主动查看型使用。',
        followUpDescription: '如果你希望这台设备承担主聊天入口，建议重新开启通知并保持系统权限可用。',
        statusChipLabel: '通知已关闭',
        actionLabel: '开启通知',
        actionIcon: Icons.notifications_active_outlined,
        actionType: _SettingsNotificationAction.enableNotifications,
      );
    }

    if (!pushState.permissionGranted) {
      return const _SettingsNotificationRuntimeState(
        icon: Icons.notifications_paused_outlined,
        badgeLabel: NotificationPermissionGuidance.badgeLabel,
        description: NotificationPermissionGuidance.settingsDescription,
        followUpDescription:
            NotificationPermissionGuidance.settingsFollowUpDescription,
        statusChipLabel: '通知待授权',
        actionLabel: NotificationPermissionGuidance.openSystemSettingsAction,
        actionIcon: Icons.settings_outlined,
        actionType: _SettingsNotificationAction.openSystemSettings,
      );
    }

    if (pushState.deviceToken == null) {
      return const _SettingsNotificationRuntimeState(
        icon: Icons.sync_outlined,
        badgeLabel: '同步中',
        description: '系统通知权限已开启，正在准备这台设备的通知通道，稍后可再次确认。',
        followUpDescription: '如果你刚刚改过权限或切换过账号，可以手动刷新一次，确认这台设备已经重新就绪。',
        statusChipLabel: '通知同步中',
        actionLabel: '刷新状态',
        actionIcon: Icons.refresh_outlined,
        actionType: _SettingsNotificationAction.refreshRuntimeState,
      );
    }

    return const _SettingsNotificationRuntimeState(
      icon: Icons.notifications_active_outlined,
      badgeLabel: '已就绪',
      description: '系统权限和设备通道都已准备好，这台设备适合作为主要聊天入口。',
      statusChipLabel: '通知已就绪',
      actionLabel: '关闭通知',
      actionIcon: Icons.notifications_off_outlined,
      actionType: _SettingsNotificationAction.disableNotifications,
      isHealthy: true,
    );
  }

  Widget _buildSectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w300,
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w300,
                color: AppColors.textDisabled.withValues(alpha: 0.9),
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white05),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    Key? key,
    required IconData icon,
    required String title,
    String? subtitle,
    String? helperText,
    String? badgeLabel,
    Key? badgeKey,
    bool badgeHighlight = false,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: UiTokens.cardPadding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.white05,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.textSecondary, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      if (badgeLabel != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          key: badgeKey,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badgeHighlight
                                ? AppColors.brandBlue.withValues(alpha: 0.16)
                                : AppColors.white08,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: badgeHighlight
                                  ? AppColors.brandBlue.withValues(alpha: 0.24)
                                  : AppColors.white12,
                            ),
                          ),
                          child: Text(
                            badgeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w300,
                              color: badgeHighlight
                                  ? AppColors.brandBlue
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (helperText != null || subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      helperText ?? subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                        color: AppColors.textTertiary.withValues(alpha: 0.9),
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
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

  // ignore: unused_element
  void _showBlockedUsersLegacy(BuildContext context) {
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

  void _showBlockedUsers(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (sheetContext) => Consumer2<FriendProvider, ChatProvider>(
        builder: (context, friendProvider, chatProvider, child) {
          final blockedIds = friendProvider.blockedUserIds.toList()..sort();
          final maxHeight = MediaQuery.of(context).size.height * 0.72;

          return Container(
            key: const Key('settings-blocked-sheet'),
            child: AppDialog.buildSheetSurface(
              constraints: BoxConstraints(maxHeight: maxHeight),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                height: maxHeight - 64,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBlockedUsersSheetHeader(
                      sheetContext,
                      blockedCount: blockedIds.length,
                    ),
                    const SizedBox(height: 14),
                    _buildBlockedUsersSummaryCard(blockedIds.length),
                    const SizedBox(height: 14),
                    Expanded(
                      child: blockedIds.isEmpty
                          ? _buildBlockedUsersEmptyState()
                          : ListView.separated(
                              key: const Key('settings-blocked-users-list'),
                              padding: EdgeInsets.zero,
                              itemCount: blockedIds.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final userId = blockedIds[index];
                                final friend = friendProvider.getFriend(userId);
                                final thread = chatProvider.getThread(userId);
                                final avatar = friend?.user.avatar ??
                                    thread?.otherUser.avatar ??
                                    '馃懁';
                                final displayName = friend?.displayName ??
                                    thread?.otherUser.nickname ??
                                    userId;

                                return _buildBlockedUserRow(
                                  context,
                                  friendProvider: friendProvider,
                                  userId: userId,
                                  displayName: displayName,
                                  avatar: avatar,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBlockedUsersSheetHeader(
    BuildContext context, {
    required int blockedCount,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '黑名单管理',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                blockedCount == 0
                    ? '当前没有拉黑对象，匹配、消息和好友关系都保持正常流转。'
                    : '被拉黑的人不会再进入你的匹配和好友链路，适合把关系边界收得更干净。',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textTertiary.withValues(alpha: 0.92),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          key: const Key('settings-blocked-count-chip'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.white08,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.white12),
          ),
          child: Text(
            '$blockedCount 人',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          key: const Key('settings-blocked-close'),
          icon: const Icon(Icons.close, color: AppColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildBlockedUsersSummaryCard(int blockedCount) {
    final bool hasBlockedUsers = blockedCount > 0;
    return Container(
      key: const Key('settings-blocked-summary-card'),
      padding: const EdgeInsets.all(14),
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
              color: hasBlockedUsers
                  ? AppColors.brandBlue.withValues(alpha: 0.16)
                  : AppColors.white12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              hasBlockedUsers ? Icons.shield_outlined : Icons.verified_outlined,
              size: 18,
              color: hasBlockedUsers
                  ? AppColors.brandBlue
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasBlockedUsers ? '边界保护已生效' : '当前无需处理',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: hasBlockedUsers
                            ? AppColors.brandBlue.withValues(alpha: 0.16)
                            : AppColors.white12,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        hasBlockedUsers ? '可继续管理' : '状态良好',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w300,
                          color: hasBlockedUsers
                              ? AppColors.brandBlue
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  hasBlockedUsers
                      ? '解除拉黑后，会话和历史关系可以恢复，但是否重新联系仍由你决定。'
                      : '如果之后需要收拢关系边界，可以在聊天页或好友页继续把用户加入黑名单。',
                  style: TextStyle(
                    fontSize: 12,
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

  Widget _buildBlockedUsersEmptyState() {
    return Center(
      child: Container(
        key: const Key('settings-blocked-empty-state'),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          color: AppColors.white05,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.white08),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.white08,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.shield_outlined,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '当前没有拉黑对象',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '后续如果遇到不想继续接触的人，可以从聊天或好友入口直接拉黑，再回这里统一管理。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w300,
                color: AppColors.textTertiary.withValues(alpha: 0.92),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedUserRow(
    BuildContext sheetContext, {
    required FriendProvider friendProvider,
    required String userId,
    required String displayName,
    required String avatar,
  }) {
    return Container(
      key: ValueKey<String>('settings-blocked-row-$userId'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white08),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.white08,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              avatar,
              style: const TextStyle(fontSize: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userId,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '当前不会再出现在匹配、好友请求和主动联系入口里。',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textTertiary.withValues(alpha: 0.9),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            key: ValueKey<String>('settings-blocked-restore-$userId'),
            onPressed: () async {
              await friendProvider.unblockUser(userId);
              if (!sheetContext.mounted) return;
              sheetContext
                  .read<ChatProvider>()
                  .restoreConversationAfterUnblock(userId);
              if (sheetContext.mounted) {
                Navigator.of(sheetContext).pop();
              }
              if (!mounted) return;
              _showInlineFeedback(
                const _SettingsInlineFeedbackState(
                  icon: Icons.person_add_alt_1_outlined,
                  title: '已解除拉黑',
                  badgeLabel: '关系已恢复',
                  description: '历史关系和会话入口已经恢复，但是否重新联系仍然由你来决定。',
                  isHealthy: true,
                ),
              );
              AppFeedback.showToast(
                context,
                AppToastCode.disabled,
                subject: '拉黑',
              );
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              foregroundColor: AppColors.brandBlue,
              backgroundColor: AppColors.brandBlue.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '解除拉黑',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateInvisibleMode(bool enabled) async {
    await context.read<SettingsProvider>().updateInvisibleMode(enabled);
    if (!mounted) return;
    _showInlineFeedback(
      enabled
          ? const _SettingsInlineFeedbackState(
              icon: Icons.visibility_off_outlined,
              title: '已切到隐身模式',
              badgeLabel: '低曝光',
              description: '你的在线曝光会更低，更适合短时观察；如果准备正常匹配，可以随时切回。',
            )
          : const _SettingsInlineFeedbackState(
              icon: Icons.visibility_outlined,
              title: '已恢复正常展示',
              badgeLabel: '可见中',
              description: '别人会更容易感知到你在线，当前更适合作为正常匹配和聊天入口。',
              isHealthy: true,
            ),
    );
    AppFeedback.showToast(
      context,
      enabled ? AppToastCode.enabled : AppToastCode.disabled,
      subject: '隐身模式',
    );
  }

  Future<void> _updateNotificationEnabled(bool enabled) async {
    final settingsProvider = context.read<SettingsProvider>();
    bool finalValue = enabled;
    if (enabled) {
      final granted = await PermissionManager.requestNotificationPermission(
        context,
      );
      finalValue = granted;
      if (!granted && mounted) {
        _showInlineFeedback(
          const _SettingsInlineFeedbackState(
            icon: Icons.notifications_paused_outlined,
            title: '系统通知权限还没打开',
            badgeLabel: '待授权',
            description: '应用内通知已尝试打开，但系统层还没有授权。可以在上面的通知通道提示里继续处理。',
          ),
        );
        AppFeedback.showError(context, AppErrorCode.permissionDenied);
      }
    }

    if (!mounted) return;
    await settingsProvider.updateNotificationEnabled(finalValue);
    if (!mounted) return;
    _showInlineFeedback(
      _buildNotificationInlineFeedback(settingsProvider),
    );
    AppFeedback.showToast(
      context,
      finalValue ? AppToastCode.enabled : AppToastCode.disabled,
      subject: '通知',
    );
  }

  Future<void> _updateVibrationEnabled(bool enabled) async {
    await context.read<SettingsProvider>().updateVibrationEnabled(enabled);
    if (!mounted) return;
    _showInlineFeedback(
      enabled
          ? const _SettingsInlineFeedbackState(
              icon: Icons.vibration_outlined,
              title: '提醒会更及时',
              badgeLabel: '更及时',
              description: '弱网和锁屏场景下更不容易错过关键消息，适合把这台设备当主聊天入口。',
              isHealthy: true,
            )
          : const _SettingsInlineFeedbackState(
              icon: Icons.do_not_disturb_on_outlined,
              title: '提醒已切到更安静',
              badgeLabel: '更安静',
              description: '震动已经收起，适合会议或通勤场景；建议配合通知状态一起观察是否会漏消息。',
            ),
    );
    AppFeedback.showToast(
      context,
      enabled ? AppToastCode.enabled : AppToastCode.disabled,
      subject: '震动',
    );
  }

  Future<void> _applyExperiencePreset(SettingsExperiencePreset preset) async {
    final settingsProvider = context.read<SettingsProvider>();
    final shouldEnableNotifications =
        preset != SettingsExperiencePreset.quietObserve;
    if (shouldEnableNotifications && !settingsProvider.notificationEnabled) {
      final granted = await PermissionManager.requestNotificationPermission(
        context,
      );
      if (!granted) {
        if (!mounted) return;
        AppFeedback.showError(context, AppErrorCode.permissionDenied);
        return;
      }
    }

    await settingsProvider.applyExperiencePreset(preset);
    if (!mounted) return;

    _showInlineFeedback(
      switch (preset) {
        SettingsExperiencePreset.responsive =>
          const _SettingsInlineFeedbackState(
            icon: Icons.flash_on_outlined,
            title: '已切到在线回复',
            badgeLabel: '推荐',
            description: '通知、振动和正常展示都已打开，这台设备现在更适合作为主聊天入口。',
            isHealthy: true,
          ),
        SettingsExperiencePreset.balanced => const _SettingsInlineFeedbackState(
            icon: Icons.tune_outlined,
            title: '已切到低干扰',
            badgeLabel: '通勤',
            description: '你会继续在线接收消息，但提醒频率更克制，适合不想被频繁打断的时候使用。',
            isHealthy: true,
          ),
        SettingsExperiencePreset.quietObserve =>
          const _SettingsInlineFeedbackState(
            icon: Icons.nightlight_round_outlined,
            title: '已切到安静观察',
            badgeLabel: '低曝光',
            description: '通知和振动已经关闭，并同步切到了隐身状态，适合短时离线或先观察环境。',
          ),
      },
    );
    final subject = switch (preset) {
      SettingsExperiencePreset.responsive => '在线回复',
      SettingsExperiencePreset.balanced => '低干扰',
      SettingsExperiencePreset.quietObserve => '安静观察',
    };
    AppFeedback.showToast(context, AppToastCode.saved, subject: subject);
  }

  Future<void> _handleNotificationAction(
    _SettingsNotificationAction action,
  ) async {
    switch (action) {
      case _SettingsNotificationAction.enableNotifications:
        await _updateNotificationEnabled(true);
        return;
      case _SettingsNotificationAction.disableNotifications:
        await _updateNotificationEnabled(false);
        return;
      case _SettingsNotificationAction.openSystemSettings:
        {
          final settingsProvider = context.read<SettingsProvider>();
          final opened = await openAppSettings();
          if (!mounted) return;
          if (!opened) {
            _showInlineFeedback(
              const _SettingsInlineFeedbackState(
                icon: Icons.settings_outlined,
                title: '未能打开系统设置',
                badgeLabel: '请手动处理',
                description: '如果这次没有成功跳到系统设置，请稍后手动打开系统通知权限，再回到应用确认状态。',
              ),
            );
            return;
          }
          settingsProvider.markNotificationPermissionRecoveryPending();
          _showInlineFeedback(
            const _SettingsInlineFeedbackState(
              icon: Icons.settings_outlined,
              title: '已打开系统设置',
              badgeLabel: '等待返回',
              description: '处理完系统通知权限后直接回到应用，我们会自动检查这台设备是否已经恢复可触达状态。',
            ),
          );
          return;
        }
      case _SettingsNotificationAction.refreshRuntimeState:
        final settingsProvider = context.read<SettingsProvider>();
        await settingsProvider.refreshPushRuntimeState();
        if (!mounted) return;
        _showInlineFeedback(
          _buildNotificationInlineFeedback(settingsProvider),
        );
        AppFeedback.showToast(context, AppToastCode.saved, subject: '通知状态');
        return;
    }
  }

  _SettingsInlineFeedbackState _buildNotificationInlineFeedback(
    SettingsProvider settingsProvider,
  ) {
    final runtimeState = _resolveNotificationRuntimeState(settingsProvider);
    return switch (runtimeState.actionType) {
      _SettingsNotificationAction.openSystemSettings =>
        const _SettingsInlineFeedbackState(
          icon: Icons.notifications_paused_outlined,
          title: NotificationPermissionGuidance.title,
          badgeLabel: NotificationPermissionGuidance.badgeLabel,
          description: NotificationPermissionGuidance.settingsDescription,
        ),
      _SettingsNotificationAction.refreshRuntimeState =>
        const _SettingsInlineFeedbackState(
          icon: Icons.sync_outlined,
          title: '通知通道正在同步',
          badgeLabel: '同步中',
          description: '系统权限已开启，当前正在等待这台设备的通知通道重新就绪，稍后可以再次刷新确认。',
        ),
      _SettingsNotificationAction.disableNotifications =>
        const _SettingsInlineFeedbackState(
          icon: Icons.notifications_active_outlined,
          title: '通知已经恢复在线',
          badgeLabel: '已就绪',
          description: '系统权限和设备通道都可用，这台设备现在更适合作为主聊天入口。',
          isHealthy: true,
        ),
      _SettingsNotificationAction.enableNotifications =>
        const _SettingsInlineFeedbackState(
          icon: Icons.notifications_off_outlined,
          title: '通知已切到静默',
          badgeLabel: '已关闭',
          description: '新消息还会保存在通知中心，但锁屏和后台提醒已经收起，适合主动查看型使用。',
        ),
    };
  }

  _SettingsInlineFeedbackState _buildNotificationResumeInlineFeedback(
    SettingsProvider settingsProvider,
  ) {
    final runtimeState = _resolveNotificationRuntimeState(settingsProvider);
    return switch (runtimeState.actionType) {
      _SettingsNotificationAction.openSystemSettings =>
        const _SettingsInlineFeedbackState(
          icon: Icons.notifications_paused_outlined,
          title: '通知权限仍待授权',
          badgeLabel: NotificationPermissionGuidance.badgeLabel,
          description: '这次返回后仍未检测到系统通知权限，锁屏和后台提醒暂时还不会生效。',
        ),
      _SettingsNotificationAction.refreshRuntimeState =>
        const _SettingsInlineFeedbackState(
          icon: Icons.sync_outlined,
          title: '通知通道正在恢复',
          badgeLabel: '同步中',
          description: '系统通知权限已经打开，当前正在等待这台设备的通知通道重新就绪。',
        ),
      _SettingsNotificationAction.disableNotifications =>
        const _SettingsInlineFeedbackState(
          icon: Icons.notifications_active_outlined,
          title: '通知已经恢复在线',
          badgeLabel: '已就绪',
          description: '检测到系统通知权限已恢复，这台设备现在更适合作为主聊天入口。',
          isHealthy: true,
        ),
      _SettingsNotificationAction.enableNotifications =>
        const _SettingsInlineFeedbackState(
          icon: Icons.notifications_off_outlined,
          title: '通知仍处于静默',
          badgeLabel: '已关闭',
          description: '系统通知权限虽然可能已恢复，但应用内通知开关当前仍是关闭状态，新的提醒会继续留在通知中心。',
        ),
    };
  }

  _SettingsNotificationCenterDigestState? _resolveNotificationCenterDigest(
    NotificationCenterProvider? provider,
  ) {
    if (provider == null || provider.items.isEmpty) {
      return null;
    }

    final unreadCount = provider.unreadCount;
    final latestItem = unreadCount > 0
        ? provider.items.firstWhere(
            (item) => !item.isRead,
            orElse: () => provider.items.first,
          )
        : provider.items.first;
    return _SettingsNotificationCenterDigestState(
      title: unreadCount > 0 ? '通知中心还有 $unreadCount 条待查看提醒' : '通知中心保留了最近一条提醒',
      badgeLabel: unreadCount > 0 ? '未读 $unreadCount' : '最近提醒',
      description: unreadCount > 0
          ? '最新待查看：${_buildNotificationCenterPreview(latestItem)}'
          : '最近一条：${_buildNotificationCenterPreview(latestItem)}',
      hasUnread: unreadCount > 0,
      sourceItems: _buildNotificationCenterSourceDigestItems(provider.items),
    );
  }

  List<_SettingsNotificationCenterSourceDigestItem>
      _buildNotificationCenterSourceDigestItems(
    List<AppNotification> items,
  ) {
    const recentWindow = 6;
    if (items.isEmpty) {
      return const <_SettingsNotificationCenterSourceDigestItem>[];
    }

    final sourceCounts = <_SettingsNotificationCenterSourceType, int>{};
    for (final item in items.take(recentWindow)) {
      final sourceType = _notificationCenterSourceTypeFor(item);
      sourceCounts.update(sourceType, (value) => value + 1, ifAbsent: () => 1);
    }

    final orderedTypes = <_SettingsNotificationCenterSourceType>[
      _SettingsNotificationCenterSourceType.message,
      _SettingsNotificationCenterSourceType.friend,
      _SettingsNotificationCenterSourceType.system,
    ];

    return orderedTypes
        .where(sourceCounts.containsKey)
        .map(
          (type) => _SettingsNotificationCenterSourceDigestItem(
            key: Key(
              'settings-notification-center-source-${type.name}',
            ),
            sourceType: type,
            label: switch (type) {
              _SettingsNotificationCenterSourceType.message => '消息',
              _SettingsNotificationCenterSourceType.friend => '好友',
              _SettingsNotificationCenterSourceType.system => '系统',
            },
            count: sourceCounts[type]!,
            icon: switch (type) {
              _SettingsNotificationCenterSourceType.message =>
                Icons.chat_bubble_outline,
              _SettingsNotificationCenterSourceType.friend =>
                Icons.person_add_alt_1_outlined,
              _SettingsNotificationCenterSourceType.system =>
                Icons.info_outline,
            },
            color: switch (type) {
              _SettingsNotificationCenterSourceType.message =>
                AppColors.brandBlue,
              _SettingsNotificationCenterSourceType.friend => AppColors.success,
              _SettingsNotificationCenterSourceType.system =>
                AppColors.textSecondary,
            },
          ),
        )
        .toList();
  }

  _SettingsNotificationCenterSourceType _notificationCenterSourceTypeFor(
    AppNotification item,
  ) {
    return switch (item.type) {
      AppNotificationType.message =>
        _SettingsNotificationCenterSourceType.message,
      AppNotificationType.friendRequest ||
      AppNotificationType.friendAccepted =>
        _SettingsNotificationCenterSourceType.friend,
      AppNotificationType.system =>
        _SettingsNotificationCenterSourceType.system,
    };
  }

  String _buildNotificationCenterPreview(AppNotification item) {
    final title = item.title.trim();
    final body = item.body.replaceAll(RegExp(r'\s+'), ' ').trim();
    final preview = body.isEmpty ? title : '$title · $body';
    if (preview.length <= 36) {
      return preview;
    }
    return '${preview.substring(0, 35)}…';
  }

  void _showInlineFeedback(_SettingsInlineFeedbackState state) {
    if (!mounted) return;
    setState(() {
      _inlineFeedback = state;
    });
  }

  Future<void> _copyUid(BuildContext context) async {
    final uid = context.read<AuthProvider>().uid;
    if (uid == null || uid.isEmpty) {
      _showInlineFeedback(
        const _SettingsInlineFeedbackState(
          icon: Icons.badge_outlined,
          title: 'UID 还未就绪',
          badgeLabel: '稍后再试',
          description: '当前账号标识还在准备中，等生成完成后再复制，会更适合联调和排查问题。',
        ),
      );
      AppFeedback.showError(
        context,
        AppErrorCode.invalidInput,
        detail: 'UID生成中，请稍后再试',
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: uid));
    if (!context.mounted) return;
    _showInlineFeedback(
      const _SettingsInlineFeedbackState(
        icon: Icons.badge_outlined,
        title: 'UID 已复制',
        badgeLabel: '可用于联调',
        description: '现在可以把 UID 发给开发、测试或其他账号，用来加好友、排查问题或做联调确认。',
        isHealthy: true,
      ),
    );
    AppFeedback.showToast(context, AppToastCode.copied);
  }

  Widget _buildAccountSheetHeader({
    required String title,
    required String description,
    required String badgeLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.white08,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.white12),
              ),
              child: Text(
                badgeLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
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
      ],
    );
  }

  Widget _buildAccountHintCard({
    required IconData icon,
    required String title,
    required String description,
    Key? key,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(14),
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
            child: Icon(icon, size: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
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

  Future<void> _presentPhoneEditorSheet(BuildContext context) async {
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
          key: const Key('settings-phone-sheet'),
          child: AppDialog.buildSheetSurface(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAccountSheetHeader(
                      title: '修改手机号',
                      description: '手机号会影响登录找回、验证码接收和账号确认，建议保持为当前常用号码。',
                      badgeLabel: '登录与找回',
                    ),
                    const SizedBox(height: 14),
                    _buildAccountHintCard(
                      key: const Key('settings-phone-hint-card'),
                      icon: Icons.sim_card_outlined,
                      title: authProvider.phone?.trim().isNotEmpty == true
                          ? '当前已绑定手机号'
                          : '当前还未绑定手机号',
                      description: authProvider.phone?.trim().isNotEmpty == true
                          ? '更新后，这台设备后续登录和排障都会以新号码为准。'
                          : '补全后会更方便账号找回和后续联调确认。',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('settings-phone-input'),
                      controller: controller,
                      keyboardType: TextInputType.phone,
                      maxLength: 11,
                      autofocus: false,
                      decoration: const InputDecoration(
                        hintText: '请输入新的 11 位手机号',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            key: const Key('settings-phone-cancel'),
                            onPressed: () {
                              FocusScope.of(sheetContext).unfocus();
                              Navigator.pop(sheetContext, false);
                            },
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
                            key: const Key('settings-phone-save'),
                            onPressed: () {
                              FocusScope.of(sheetContext).unfocus();
                              Navigator.pop(sheetContext, true);
                            },
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
        ),
      ),
    );

    if (result == true && context.mounted) {
      final phone = controller.text.trim();
      final valid = RegExp(r'^\d{11}$').hasMatch(phone);
      if (!valid) {
        _showInlineFeedback(
          const _SettingsInlineFeedbackState(
            icon: Icons.phone_outlined,
            title: '手机号格式有误',
            badgeLabel: '未保存',
            description: '请输入 11 位手机号后再保存，本次不会覆盖当前绑定号码。',
          ),
        );
        AppFeedback.showError(
          context,
          AppErrorCode.invalidInput,
          detail: '请输入 11 位手机号后重试',
        );
      } else {
        await authProvider.updatePhone(phone);
        if (!context.mounted) return;
        _showInlineFeedback(
          const _SettingsInlineFeedbackState(
            icon: Icons.phone_outlined,
            title: '手机号已经更新',
            badgeLabel: '登录与找回',
            description: '后续登录、验证码接收和账号找回都会以新的手机号为准。',
            isHealthy: true,
          ),
        );
        AppFeedback.showToast(context, AppToastCode.saved, subject: '手机号');
      }
    }
  }

  Future<void> _presentPasswordEditorSheet(BuildContext context) async {
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
          key: const Key('settings-password-sheet'),
          child: AppDialog.buildSheetSurface(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAccountSheetHeader(
                      title: '修改密码',
                      description: '建议定期更换密码，并避免和其他账号复用，减少测试环境和正式环境串用风险。',
                      badgeLabel: '账号安全',
                    ),
                    const SizedBox(height: 14),
                    _buildAccountHintCard(
                      key: const Key('settings-password-hint-card'),
                      icon: Icons.lock_clock_outlined,
                      title: '本地安全校验',
                      description: '先确认旧密码，再保存新密码。新的登录密码至少 6 位，并保持两次输入一致。',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('settings-password-old-input'),
                      controller: oldController,
                      obscureText: true,
                      autofocus: false,
                      decoration: const InputDecoration(hintText: '输入当前密码'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const Key('settings-password-new-input'),
                      controller: newController,
                      obscureText: true,
                      decoration:
                          const InputDecoration(hintText: '输入新的密码，至少 6 位'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const Key('settings-password-confirm-input'),
                      controller: confirmController,
                      obscureText: true,
                      decoration: const InputDecoration(hintText: '再次确认新密码'),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            key: const Key('settings-password-cancel'),
                            onPressed: () {
                              FocusScope.of(sheetContext).unfocus();
                              Navigator.pop(sheetContext, false);
                            },
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
                            key: const Key('settings-password-save'),
                            onPressed: () {
                              FocusScope.of(sheetContext).unfocus();
                              Navigator.pop(sheetContext, true);
                            },
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
        ),
      ),
    );

    if (result == true && context.mounted) {
      final oldPassword = oldController.text.trim();
      final newPassword = newController.text.trim();
      final confirmPassword = confirmController.text.trim();
      final currentPassword = StorageService.getLocalPassword();

      if (oldPassword != currentPassword) {
        _showInlineFeedback(
          const _SettingsInlineFeedbackState(
            icon: Icons.lock_outline,
            title: '旧密码不正确',
            badgeLabel: '未保存',
            description: '请先确认当前密码，再继续保存新密码，本次修改还没有生效。',
          ),
        );
        AppFeedback.showError(
          context,
          AppErrorCode.invalidInput,
          detail: '旧密码不正确，请重新输入',
        );
      } else if (newPassword.length < 6) {
        _showInlineFeedback(
          const _SettingsInlineFeedbackState(
            icon: Icons.lock_outline,
            title: '新密码长度不够',
            badgeLabel: '未保存',
            description: '新的密码至少需要 6 位，建议重新设置后再保存。',
          ),
        );
        AppFeedback.showError(
          context,
          AppErrorCode.invalidInput,
          detail: '新密码至少 6 位，请重新设置',
        );
      } else if (newPassword != confirmPassword) {
        _showInlineFeedback(
          const _SettingsInlineFeedbackState(
            icon: Icons.lock_outline,
            title: '两次输入不一致',
            badgeLabel: '待确认',
            description: '请重新确认两次输入的新密码一致后再保存，本次修改不会生效。',
          ),
        );
        AppFeedback.showError(
          context,
          AppErrorCode.invalidInput,
          detail: '两次输入不一致，请重新确认',
        );
      } else {
        await StorageService.saveLocalPassword(newPassword);
        if (!context.mounted) return;
        _showInlineFeedback(
          const _SettingsInlineFeedbackState(
            icon: Icons.lock_outlined,
            title: '密码已经更新',
            badgeLabel: '安全已加强',
            description: '新的本地密码已经生效，后续请优先使用新密码，避免和其他环境复用。',
            isHealthy: true,
          ),
        );
        AppFeedback.showToast(context, AppToastCode.saved, subject: '密码');
      }
    }
  }

  // ignore: unused_element
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

  // ignore: unused_element
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

class _SettingsOverviewFocusState {
  const _SettingsOverviewFocusState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    this.isHealthy = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badgeLabel;
  final bool isHealthy;
}

class _SettingsToggleHint {
  const _SettingsToggleHint({
    required this.badgeLabel,
    required this.description,
    this.isHealthy = false,
  });

  final String badgeLabel;
  final String description;
  final bool isHealthy;
}

class _SettingsDeviceStatusItem {
  const _SettingsDeviceStatusItem({
    required this.key,
    required this.icon,
    required this.title,
    required this.badgeLabel,
    required this.description,
    required this.isHealthy,
  });

  final Key key;
  final IconData icon;
  final String title;
  final String badgeLabel;
  final String description;
  final bool isHealthy;
}

class _SettingsExperiencePresetState {
  const _SettingsExperiencePresetState({
    required this.badgeLabel,
    required this.description,
    this.isHealthy = false,
  });

  final String badgeLabel;
  final String description;
  final bool isHealthy;
}

class _SettingsExperiencePresetOption {
  const _SettingsExperiencePresetOption({
    required this.key,
    required this.preset,
    required this.icon,
    required this.title,
    required this.badgeLabel,
    required this.description,
  });

  final Key key;
  final SettingsExperiencePreset preset;
  final IconData icon;
  final String title;
  final String badgeLabel;
  final String description;
}

class _SettingsInlineFeedbackState {
  const _SettingsInlineFeedbackState({
    required this.icon,
    required this.title,
    required this.badgeLabel,
    required this.description,
    this.isHealthy = false,
  });

  final IconData icon;
  final String title;
  final String badgeLabel;
  final String description;
  final bool isHealthy;
}

enum _SettingsNotificationAction {
  enableNotifications,
  disableNotifications,
  openSystemSettings,
  refreshRuntimeState,
}

class _SettingsNotificationRuntimeState {
  const _SettingsNotificationRuntimeState({
    required this.icon,
    required this.badgeLabel,
    required this.description,
    required this.statusChipLabel,
    required this.actionLabel,
    required this.actionIcon,
    required this.actionType,
    this.followUpDescription,
    this.isHealthy = false,
  });

  final IconData icon;
  final String badgeLabel;
  final String description;
  final String statusChipLabel;
  final String actionLabel;
  final IconData actionIcon;
  final _SettingsNotificationAction actionType;
  final String? followUpDescription;
  final bool isHealthy;
}

class _SettingsNotificationCenterDigestState {
  const _SettingsNotificationCenterDigestState({
    required this.title,
    required this.badgeLabel,
    required this.description,
    required this.hasUnread,
    required this.sourceItems,
  });

  final String title;
  final String badgeLabel;
  final String description;
  final bool hasUnread;
  final List<_SettingsNotificationCenterSourceDigestItem> sourceItems;
}

enum _SettingsNotificationCenterSourceType {
  message,
  friend,
  system,
}

class _SettingsNotificationCenterSourceDigestItem {
  const _SettingsNotificationCenterSourceDigestItem({
    required this.key,
    required this.sourceType,
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  final Key key;
  final _SettingsNotificationCenterSourceType sourceType;
  final String label;
  final int count;
  final IconData icon;
  final Color color;
}
