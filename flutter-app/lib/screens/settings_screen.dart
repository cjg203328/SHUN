import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/app_env.dart';
import '../config/theme.dart';
import '../models/app_notification.dart';
import '../providers/auth_provider.dart';
import '../providers/friend_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/notification_center_provider.dart';
import '../providers/settings_provider.dart';
import '../services/image_upload_service.dart';
import '../services/media_upload_service.dart';
import '../services/storage_service.dart';
import '../utils/notification_permission_guidance.dart';
import '../utils/permission_manager.dart';
import '../widgets/app_toast.dart';
import '../widgets/chat_delivery_debug_sheet.dart';
import '../core/feedback/app_feedback.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.mediaUploadService,
  });

  final MediaUploadService? mediaUploadService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsLayoutSpec {
  const _SettingsLayoutSpec({
    required this.isCompact,
    required this.isTight,
    required this.pageHorizontalPadding,
    required this.topPadding,
    required this.bottomPadding,
    required this.sectionSpacing,
    required this.sectionTitleInset,
    required this.sectionTitleBottomSpacing,
    required this.overviewPadding,
    required this.overviewGap,
    required this.sectionCardRadius,
    required this.itemHorizontalPadding,
    required this.itemVerticalPadding,
    required this.leadingBoxSize,
    required this.leadingIconSize,
    required this.trailingGap,
  });

  final bool isCompact;
  final bool isTight;
  final double pageHorizontalPadding;
  final double topPadding;
  final double bottomPadding;
  final double sectionSpacing;
  final double sectionTitleInset;
  final double sectionTitleBottomSpacing;
  final double overviewPadding;
  final double overviewGap;
  final double sectionCardRadius;
  final double itemHorizontalPadding;
  final double itemVerticalPadding;
  final double leadingBoxSize;
  final double leadingIconSize;
  final double trailingGap;

  static _SettingsLayoutSpec fromSize(Size size) {
    final isTight = size.width <= 340 || size.height <= 620;
    final isCompact = isTight || size.width <= 390 || size.height <= 720;
    if (isTight) {
      return const _SettingsLayoutSpec(
        isCompact: true,
        isTight: true,
        pageHorizontalPadding: 13,
        topPadding: 12,
        bottomPadding: 20,
        sectionSpacing: 16,
        sectionTitleInset: 2,
        sectionTitleBottomSpacing: 8,
        overviewPadding: 10,
        overviewGap: 8,
        sectionCardRadius: 14,
        itemHorizontalPadding: 11,
        itemVerticalPadding: 10,
        leadingBoxSize: 30,
        leadingIconSize: 16,
        trailingGap: 8,
      );
    }

    if (isCompact) {
      return const _SettingsLayoutSpec(
        isCompact: true,
        isTight: false,
        pageHorizontalPadding: 15,
        topPadding: 14,
        bottomPadding: 24,
        sectionSpacing: 18,
        sectionTitleInset: 4,
        sectionTitleBottomSpacing: 9,
        overviewPadding: 12,
        overviewGap: 10,
        sectionCardRadius: 14,
        itemHorizontalPadding: 13,
        itemVerticalPadding: 11,
        leadingBoxSize: 32,
        leadingIconSize: 17,
        trailingGap: 8,
      );
    }

    return const _SettingsLayoutSpec(
      isCompact: false,
      isTight: false,
      pageHorizontalPadding: 20,
      topPadding: 20,
      bottomPadding: 40,
      sectionSpacing: 28,
      sectionTitleInset: 8,
      sectionTitleBottomSpacing: 12,
      overviewPadding: 18,
      overviewGap: 14,
      sectionCardRadius: 16,
      itemHorizontalPadding: 16,
      itemVerticalPadding: 16,
      leadingBoxSize: 34,
      leadingIconSize: 18,
      trailingGap: 12,
    );
  }
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  _SettingsInlineFeedbackState? _inlineFeedback;
  _SettingsMediaPreviewState _avatarPreviewState =
      const _SettingsMediaPreviewState();
  _SettingsMediaPreviewState _backgroundPreviewState =
      const _SettingsMediaPreviewState();
  late final MediaUploadService _mediaUploadService;

  @override
  void initState() {
    super.initState();
    _mediaUploadService = widget.mediaUploadService ?? MediaUploadService();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshMediaPreviewStates());
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

  Future<void> _refreshMediaPreviewStates() async {
    final avatarState = await _readAvatarPreviewState();
    final backgroundState = await _readBackgroundPreviewState();
    if (!mounted) return;
    setState(() {
      _avatarPreviewState = avatarState;
      _backgroundPreviewState = backgroundState;
    });
  }

  Future<void> _refreshAvatarPreviewState() async {
    final nextState = await _readAvatarPreviewState();
    if (!mounted) return;
    setState(() {
      _avatarPreviewState = nextState;
    });
  }

  Future<void> _refreshBackgroundPreviewState() async {
    final nextState = await _readBackgroundPreviewState();
    if (!mounted) return;
    setState(() {
      _backgroundPreviewState = nextState;
    });
  }

  Future<_SettingsMediaPreviewState> _readAvatarPreviewState() {
    return _readMediaPreviewState(
      loadPath: ImageUploadService.getAvatarPath,
      exists: ImageUploadService.avatarExists,
    );
  }

  Future<_SettingsMediaPreviewState> _readBackgroundPreviewState() {
    return _readMediaPreviewState(
      loadPath: ImageUploadService.getBackgroundPath,
      exists: ImageUploadService.backgroundExists,
    );
  }

  Future<_SettingsMediaPreviewState> _readMediaPreviewState({
    required Future<String?> Function() loadPath,
    required Future<bool> Function() exists,
  }) async {
    final mediaPath = await loadPath();
    if (mediaPath == null || mediaPath.trim().isEmpty) {
      return const _SettingsMediaPreviewState();
    }

    final hasMedia = await exists();
    if (!hasMedia) {
      return const _SettingsMediaPreviewState();
    }

    return _SettingsMediaPreviewState(
      mediaPath: mediaPath,
      hasMedia: true,
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
            fontSize: 20,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
          ),
        ),
        centerTitle: false,
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          final layout = _SettingsLayoutSpec.fromSize(
            MediaQuery.of(context).size,
          );
          final invisibleSettingHint = _resolveInvisibleSettingHint(
            settingsProvider,
          );
          final notificationSettingHint = _resolveNotificationSettingHint(
            settingsProvider,
          );
          final vibrationSettingHint = _resolveVibrationSettingHint(
            settingsProvider,
          );

          return Stack(
            children: [
              ListView(
                padding: EdgeInsets.fromLTRB(
                  layout.pageHorizontalPadding,
                  layout.topPadding,
                  layout.pageHorizontalPadding,
                  layout.bottomPadding,
                ),
                children: [
                  _buildSettingsOverviewCard(context, settingsProvider),
                  SizedBox(height: layout.sectionSpacing),
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
                  SizedBox(height: layout.sectionSpacing),
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
                  SizedBox(height: layout.sectionSpacing),
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
                  SizedBox(height: layout.sectionSpacing),
                  _buildSectionTitle('资料与展示', subtitle: '优先维护头像，背景等低频内容可按需调整'),
                  _buildSectionCard(
                    children: [
                      _buildAvatarManagementItem(context),
                    ],
                  ),
                  SizedBox(height: layout.sectionSpacing),
                  _buildSectionTitle('更多设置（低频）',
                      subtitle: '这些内容通常不用频繁修改，需要时再进入即可'),
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
                      _buildBackgroundManagementItem(context),
                    ],
                  ),
                  SizedBox(height: layout.sectionSpacing),
                  _buildSectionTitle('安全与举报', subtitle: '保护自己和他人的使用体验'),
                  _buildSectionCard(
                    children: [
                      _buildSettingItem(
                        context,
                        icon: Icons.flag_outlined,
                        title: '举报违规用户',
                        subtitle: '在聊天页面点击右上角菜单，选择「举报」进行投诉',
                        onTap: () => AppToast.show(
                          context,
                          '请在聊天页面通过右上角菜单举报对方',
                        ),
                      ),
                      _buildDivider(),
                      _buildSettingItem(
                        context,
                        icon: Icons.security_outlined,
                        title: '账号安全提示',
                        subtitle: '不要轻信陌生人的转账、链接等请求',
                        onTap: () => context.push('/legal/safety-tips'),
                      ),
                    ],
                  ),
                  SizedBox(height: layout.sectionSpacing),
                  _buildSectionTitle('关于与协议', subtitle: '查看产品说明、协议与隐私内容'),
                  _buildSectionCard(
                    children: [
                      _buildSettingItem(
                        context,
                        key: const Key('settings-about-item'),
                        icon: Icons.info_outlined,
                        title: '关于瞬聊',
                        subtitle: '查看产品介绍、版本信息与开发说明',
                        onTap: () => context.push('/about'),
                      ),
                      _buildDivider(),
                      _buildSettingItem(
                        context,
                        key: const Key('settings-privacy-policy-item'),
                        icon: Icons.privacy_tip_outlined,
                        title: '隐私政策',
                        subtitle: '说明我们如何收集、使用和保护你的数据',
                        onTap: () => context.push('/legal/privacy-policy'),
                      ),
                      _buildDivider(),
                      _buildSettingItem(
                        context,
                        key: const Key('settings-user-agreement-item'),
                        icon: Icons.description_outlined,
                        title: '用户协议',
                        subtitle: '查看使用规则、权责说明与服务条款',
                        onTap: () => context.push('/legal/user-agreement'),
                      ),
                    ],
                  ),
                  SizedBox(height: layout.sectionSpacing + 4),
                  _buildSectionTitle(
                    '账号操作',
                    subtitle: '先区分当前设备退出和不可恢复的账号注销，避免误触。',
                  ),
                  _buildAccountHintCard(
                    key: const Key('settings-account-actions-card'),
                    icon: Icons.manage_accounts_outlined,
                    title: '先确认你要离开的是当前设备还是整个账号',
                    description:
                        '退出登录只会清除这台设备上的登录状态，账号资料和好友关系会保留；注销账号会清除账号与会话数据，操作后无法恢复。',
                  ),
                  SizedBox(height: layout.isCompact ? 10 : 12),
                  _buildAccountActionCard(
                    cardKey: const Key('settings-logout-card'),
                    actionKey: const Key('settings-logout-button'),
                    icon: Icons.logout_rounded,
                    title: '退出登录',
                    badgeLabel: '仅当前设备',
                    description: '适合临时退出、换设备登录或排查问题使用，不会删除你的账号本身。',
                    onTap: () => _showLogoutDialog(context),
                  ),
                  SizedBox(height: layout.isCompact ? 10 : 12),
                  _buildAccountActionCard(
                    cardKey: const Key('settings-delete-account-card'),
                    actionKey: const Key('settings-delete-account-button'),
                    icon: Icons.delete_forever_outlined,
                    title: '注销账号',
                    badgeLabel: '不可恢复',
                    description: '仅在确认不再使用该账号时再操作，注销后资料与会话数据会一并清除。',
                    onTap: () => _showDeleteAccountDialog(context),
                    isDanger: true,
                  ),
                  SizedBox(height: layout.isCompact ? 12 : 14),
                  Center(
                    child: GestureDetector(
                      key: const ValueKey<String>(
                          'settings-debug-version-trigger'),
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
              ),
              if (_inlineFeedback != null)
                Positioned(
                  top: 8,
                  left: layout.pageHorizontalPadding,
                  right: layout.pageHorizontalPadding,
                  child: IgnorePointer(
                    ignoring: true,
                    child: _buildInlineFeedbackCard(_inlineFeedback!),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAvatarManagementItem(BuildContext context) {
    final summary = _resolveAvatarManagementSummary(_avatarPreviewState);
    return _buildSettingItem(
      context,
      key: const Key('settings-avatar-management-item'),
      icon: Icons.photo_outlined,
      title: '头像管理',
      subtitle: summary.itemSubtitle,
      badgeLabel: summary.itemBadgeLabel,
      badgeKey: const Key('settings-avatar-management-badge'),
      trailing: _buildAvatarManagementTrailing(context),
      onTap: () => _presentAvatarManagementSheet(context),
    );
  }

  Widget _buildBackgroundManagementItem(BuildContext context) {
    final summary =
        _resolveBackgroundManagementSummary(_backgroundPreviewState);
    return _buildSettingItem(
      context,
      key: const Key('settings-background-management-item'),
      icon: Icons.wallpaper_outlined,
      title: '背景管理',
      subtitle: summary.itemSubtitle,
      badgeLabel: summary.itemBadgeLabel,
      badgeKey: const Key('settings-background-management-badge'),
      trailing: _buildBackgroundManagementTrailing(context),
      onTap: () => _presentBackgroundManagementSheet(context),
    );
  }

  Widget _buildAvatarManagementTrailing(BuildContext context) {
    final layout = _SettingsLayoutSpec.fromSize(
      MediaQuery.of(context).size,
    );
    return Padding(
      padding: EdgeInsets.only(top: layout.isCompact ? 2 : 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAvatarPreviewSurface(
            key: const Key('settings-avatar-management-preview'),
            avatarPath: _avatarPreviewState.mediaPath,
            size: layout.isCompact ? 30 : 34,
            iconSize: layout.isCompact ? 16 : 18,
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textTertiary,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundManagementTrailing(BuildContext context) {
    final layout = _SettingsLayoutSpec.fromSize(
      MediaQuery.of(context).size,
    );
    return Padding(
      padding: EdgeInsets.only(top: layout.isCompact ? 2 : 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBackgroundPreviewSurface(
            key: const Key('settings-background-management-preview'),
            backgroundPath: _backgroundPreviewState.mediaPath,
            width: layout.isCompact ? 34 : 40,
            height: layout.isCompact ? 24 : 28,
            iconSize: layout.isCompact ? 15 : 16,
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textTertiary,
            size: 20,
          ),
        ],
      ),
    );
  }

  Future<void> _presentAvatarManagementSheet(BuildContext context) async {
    final avatarPreviewState = await _readAvatarPreviewState();
    final summary = _resolveAvatarManagementSummary(avatarPreviewState);
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (sheetContext) => _buildMediaManagementSheet(
        key: const Key('settings-avatar-sheet'),
        context: sheetContext,
        title: '头像管理',
        description: '',
        headerPreview: _buildAvatarManagementPreviewCard(
          avatarPreviewState,
          summary,
        ),
        replaceAction: _buildManagementItem(
          context,
          key: const Key('settings-avatar-replace-action'),
          icon: Icons.photo_camera_outlined,
          title: summary.replaceActionLabel,
          onTap: () => _replaceAvatar(sheetContext),
        ),
        deleteAction: avatarPreviewState.hasMedia
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
                    await _refreshAvatarPreviewState();
                    if (!mounted || !context.mounted) return;
                    _showInlineFeedback(
                      const _SettingsInlineFeedbackState(
                        icon: Icons.delete_outline,
                        title: '头像已恢复默认',
                        badgeLabel: '已清空',
                        description: '当前资料会回到默认头像，如需恢复识别度，可以稍后再重新上传。',
                      ),
                    );
                    AppFeedback.showToast(
                      context,
                      AppToastCode.deleted,
                      subject: '头像',
                    );
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
    final backgroundPreviewState = await _readBackgroundPreviewState();
    final summary = _resolveBackgroundManagementSummary(backgroundPreviewState);
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (sheetContext) => _buildMediaManagementSheet(
        key: const Key('settings-background-sheet'),
        context: sheetContext,
        title: '背景管理',
        description: '',
        headerPreview: _buildBackgroundManagementPreviewCard(
          backgroundPreviewState,
          summary,
        ),
        replaceAction: _buildManagementItem(
          context,
          key: const Key('settings-background-replace-action'),
          icon: Icons.wallpaper_outlined,
          title: summary.replaceActionLabel,
          onTap: () => _replaceBackground(sheetContext),
        ),
        deleteAction: backgroundPreviewState.hasMedia
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
                    await _refreshBackgroundPreviewState();
                    if (!mounted || !context.mounted) return;
                    _showInlineFeedback(
                      const _SettingsInlineFeedbackState(
                        icon: Icons.delete_outline,
                        title: '背景已恢复默认',
                        badgeLabel: '已清空',
                        description: '主页氛围已经回到默认状态，后续如果想重新区分，可以再上传新的背景。',
                      ),
                    );
                    AppFeedback.showToast(
                      context,
                      AppToastCode.deleted,
                      subject: '背景',
                    );
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
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.white05,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: isDanger ? AppColors.error : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
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

  Widget _buildAvatarManagementPreviewCard(
    _SettingsMediaPreviewState avatarPreviewState,
    _SettingsMediaManagementSummary summary,
  ) {
    return Container(
      key: const Key('settings-avatar-sheet-preview'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white08),
      ),
      child: Row(
        children: [
          _buildAvatarPreviewSurface(
            key: const Key('settings-avatar-sheet-avatar'),
            avatarPath: avatarPreviewState.mediaPath,
            size: 42,
            iconSize: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.previewStatusLabel,
                  key: const Key('settings-avatar-sheet-status'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: avatarPreviewState.hasMedia
                  ? AppColors.brandBlue.withValues(alpha: 0.14)
                  : AppColors.white08,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: avatarPreviewState.hasMedia
                    ? AppColors.brandBlue.withValues(alpha: 0.22)
                    : AppColors.white12,
              ),
            ),
            child: Text(
              summary.previewBadgeLabel,
              key: const Key('settings-avatar-sheet-badge'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w300,
                color: avatarPreviewState.hasMedia
                    ? AppColors.brandBlue
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundManagementPreviewCard(
    _SettingsMediaPreviewState backgroundPreviewState,
    _SettingsMediaManagementSummary summary,
  ) {
    return Container(
      key: const Key('settings-background-sheet-preview'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white08),
      ),
      child: Row(
        children: [
          _buildBackgroundPreviewSurface(
            key: const Key('settings-background-sheet-thumbnail'),
            backgroundPath: backgroundPreviewState.mediaPath,
            width: 54,
            height: 36,
            iconSize: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              summary.previewStatusLabel,
              key: const Key('settings-background-sheet-status'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: backgroundPreviewState.hasMedia
                  ? AppColors.brandBlue.withValues(alpha: 0.14)
                  : AppColors.white08,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: backgroundPreviewState.hasMedia
                    ? AppColors.brandBlue.withValues(alpha: 0.22)
                    : AppColors.white12,
              ),
            ),
            child: Text(
              summary.previewBadgeLabel,
              key: const Key('settings-background-sheet-badge'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w300,
                color: backgroundPreviewState.hasMedia
                    ? AppColors.brandBlue
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPreviewSurface({
    Key? key,
    required String? avatarPath,
    required double size,
    required double iconSize,
  }) {
    final previewImage = _buildMediaPreviewImageProvider(avatarPath);
    return Container(
      key: key,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.white08,
        border: Border.all(color: AppColors.white12),
      ),
      child: ClipOval(
        child: previewImage == null
            ? Center(
                child: Icon(
                  Icons.person_rounded,
                  size: iconSize,
                  color: AppColors.textTertiary,
                ),
              )
            : Image(
                image: previewImage,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Icon(
                      Icons.person_rounded,
                      size: iconSize,
                      color: AppColors.textTertiary,
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildBackgroundPreviewSurface({
    Key? key,
    required String? backgroundPath,
    required double width,
    required double height,
    required double iconSize,
  }) {
    final previewImage = _buildMediaPreviewImageProvider(backgroundPath);
    return Container(
      key: key,
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppColors.white08,
        border: Border.all(color: AppColors.white12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: previewImage == null
            ? Center(
                child: Icon(
                  Icons.wallpaper_rounded,
                  size: iconSize,
                  color: AppColors.textTertiary,
                ),
              )
            : Image(
                image: previewImage,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Icon(
                      Icons.wallpaper_rounded,
                      size: iconSize,
                      color: AppColors.textTertiary,
                    ),
                  );
                },
              ),
      ),
    );
  }

  ImageProvider<Object>? _buildMediaPreviewImageProvider(String? mediaRef) {
    if (mediaRef == null || mediaRef.trim().isEmpty) {
      return null;
    }

    final resolvedPath = _resolveDisplayMediaPath(mediaRef.trim());
    if (_isRemoteMediaReference(resolvedPath)) {
      return NetworkImage(resolvedPath);
    }

    return FileImage(_resolveLocalMediaFile(resolvedPath));
  }

  String _resolveDisplayMediaPath(String path) {
    return AppEnv.resolveMediaUrl(path);
  }

  File _resolveLocalMediaFile(String path) {
    if (path.startsWith('file://')) {
      return File.fromUri(Uri.parse(path));
    }
    return File(path);
  }

  static Widget _buildMediaManagementSheet({
    required Key key,
    required BuildContext context,
    required String title,
    required String description,
    required Widget replaceAction,
    Widget? headerPreview,
    Widget? deleteAction,
  }) {
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.76;
    return Container(
      key: key,
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
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (description.isNotEmpty) ...[
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
                if (headerPreview != null) ...[
                  const SizedBox(height: 12),
                  headerPreview,
                ],
                const SizedBox(height: 12),
                replaceAction,
                if (deleteAction != null) ...[
                  const SizedBox(height: 10),
                  deleteAction,
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

  Future<void> _replaceAvatar(BuildContext sheetContext) async {
    Navigator.pop(sheetContext);
    final imageFile = await ImageUploadService.pickAvatar(context);
    if (imageFile == null || !mounted) {
      return;
    }

    try {
      final mediaRef = await _mediaUploadService.uploadUserMedia(
        'avatar',
        imageFile,
      );
      await ImageUploadService.saveAvatarReference(
        mediaRef,
        cleanupLocalPath: imageFile.path,
      );
      await _refreshAvatarPreviewState();
      if (!mounted) {
        return;
      }
      _showInlineFeedback(
        _buildMediaUpdatedFeedback(
          icon: Icons.photo_camera_outlined,
          title: '头像已经更新',
          remoteBadgeLabel: '资料已刷新',
          remoteDescription: '新的头像已经走远端媒体链路保存，消息列表和个人页会优先回显最新资料。',
          localBadgeLabel: '资料已刷新',
          localDescription: '新的头像已经写回本地资料缓存，当前页面和“我的”页会继续保持同步。',
          mediaRef: mediaRef,
        ),
      );
      AppFeedback.showToast(
        context,
        AppToastCode.saved,
        subject: '头像',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showInlineFeedback(
        const _SettingsInlineFeedbackState(
          icon: Icons.photo_camera_outlined,
          title: '头像更新失败',
          badgeLabel: '稍后重试',
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

  Future<void> _replaceBackground(BuildContext sheetContext) async {
    Navigator.pop(sheetContext);
    final imageFile = await ImageUploadService.pickBackground(context);
    if (imageFile == null || !mounted) {
      return;
    }

    try {
      final mediaRef = await _mediaUploadService.uploadUserMedia(
        'background',
        imageFile,
      );
      await ImageUploadService.saveBackgroundReference(
        mediaRef,
        cleanupLocalPath: imageFile.path,
      );
      await _refreshBackgroundPreviewState();
      if (!mounted) {
        return;
      }
      _showInlineFeedback(
        _buildMediaUpdatedFeedback(
          icon: Icons.wallpaper_outlined,
          title: '背景已经更新',
          remoteBadgeLabel: '氛围已刷新',
          remoteDescription: '新的背景已经走远端媒体链路保存，别人进入主页时会优先看到最新封面。',
          localBadgeLabel: '氛围已刷新',
          localDescription: '新的背景已经写回本地资料缓存，当前主页氛围会继续保持最新状态。',
          mediaRef: mediaRef,
        ),
      );
      AppFeedback.showToast(
        context,
        AppToastCode.saved,
        subject: '背景',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showInlineFeedback(
        const _SettingsInlineFeedbackState(
          icon: Icons.wallpaper_outlined,
          title: '背景更新失败',
          badgeLabel: '稍后重试',
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

  _SettingsInlineFeedbackState _buildMediaUpdatedFeedback({
    required IconData icon,
    required String title,
    required String remoteBadgeLabel,
    required String remoteDescription,
    required String localBadgeLabel,
    required String localDescription,
    required String mediaRef,
  }) {
    final isRemoteReference = _isRemoteMediaReference(mediaRef);
    return _SettingsInlineFeedbackState(
      icon: icon,
      title: title,
      badgeLabel: isRemoteReference ? remoteBadgeLabel : localBadgeLabel,
      description: isRemoteReference ? remoteDescription : localDescription,
      isHealthy: true,
    );
  }

  bool _isRemoteMediaReference(String mediaRef) {
    final normalized = mediaRef.trim();
    return normalized.startsWith('http://') ||
        normalized.startsWith('https://') ||
        normalized.startsWith('avatar/') ||
        normalized.startsWith('background/');
  }

  _SettingsMediaManagementSummary _resolveAvatarManagementSummary(
    _SettingsMediaPreviewState previewState,
  ) {
    if (previewState.hasMedia) {
      return const _SettingsMediaManagementSummary(
        itemSubtitle: '当前头像已经同步到消息列表和个人主页，别人会优先看到这一版资料。',
        itemBadgeLabel: '已同步',
        previewStatusLabel: '当前头像已经同步',
        previewBadgeLabel: '展示中',
        replaceActionLabel: '重新上传头像',
      );
    }

    return const _SettingsMediaManagementSummary(
      itemSubtitle: '当前还在使用默认头像，补一个清晰头像会更容易识别。',
      itemBadgeLabel: '待补充',
      previewStatusLabel: '当前还在使用默认头像',
      previewBadgeLabel: '待补充',
      replaceActionLabel: '补一个头像',
    );
  }

  _SettingsMediaManagementSummary _resolveBackgroundManagementSummary(
    _SettingsMediaPreviewState previewState,
  ) {
    if (previewState.hasMedia) {
      return const _SettingsMediaManagementSummary(
        itemSubtitle: '当前背景已经生效在个人主页首屏，别人进入主页时会先看到这张封面。',
        itemBadgeLabel: '首屏已生效',
        previewStatusLabel: '当前背景已经生效',
        previewBadgeLabel: '首屏展示中',
        replaceActionLabel: '重新上传背景',
      );
    }

    return const _SettingsMediaManagementSummary(
      itemSubtitle: '当前还是默认背景，补一张更有辨识度的封面会更容易建立第一印象。',
      itemBadgeLabel: '待补充',
      previewStatusLabel: '当前还在使用默认背景',
      previewBadgeLabel: '待补充',
      replaceActionLabel: '补一张背景',
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

  Widget _buildPillBadge({
    Key? key,
    Key? textKey,
    required String label,
    required Color backgroundColor,
    required Color textColor,
    Color? borderColor,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: borderColor == null ? null : Border.all(color: borderColor),
      ),
      child: Text(
        key: textKey,
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w300,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildResponsiveHeader({
    required Widget title,
    required Widget badge,
    double spacing = 8,
    bool stackOnCompact = false,
  }) {
    final layout = _SettingsLayoutSpec.fromSize(
      MediaQuery.of(context).size,
    );
    if (layout.isTight || (stackOnCompact && layout.isCompact)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          SizedBox(height: spacing - 2),
          badge,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: title),
        SizedBox(width: spacing),
        badge,
      ],
    );
  }

  Widget _buildSettingsOverviewCard(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    final layout = _SettingsLayoutSpec.fromSize(
      MediaQuery.of(context).size,
    );
    final auth = context.watch<AuthProvider>();
    final hasPhone = (auth.phone ?? '').trim().isNotEmpty;
    final focusState = _resolveOverviewFocusState(
      auth: auth,
      settingsProvider: settingsProvider,
    );
    final invisibleSettingHint = _resolveInvisibleSettingHint(settingsProvider);
    final notificationRuntimeState = _resolveNotificationRuntimeState(
      settingsProvider,
    );
    final overviewActions = <Widget>[
      _buildOverviewAction(
        key: const Key('settings-overview-phone-action'),
        icon: Icons.phone_outlined,
        label: hasPhone ? '更新手机号' : '补手机号',
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
    ];
    final overviewDescription = layout.isTight
        ? '先看提醒、账号和展示状态即可'
        : layout.isCompact
            ? '把高频状态集中到首屏，先看提醒、账号和展示是否已经就绪'
            : '把高频状态集中放在前面，方便你快速确认账号、安全、展示和通知是否已经就绪';

    return Container(
      padding: EdgeInsets.all(layout.overviewPadding),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(layout.sectionCardRadius + 2),
        border: Border.all(color: AppColors.white08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '设置总览',
            style: TextStyle(
              fontSize: layout.isCompact ? 17 : 18,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: layout.isCompact ? 4 : 6),
          Text(
            overviewDescription,
            style: TextStyle(
              fontSize: layout.isTight ? 11.5 : (layout.isCompact ? 12 : 13),
              fontWeight: FontWeight.w300,
              color: AppColors.textTertiary.withValues(alpha: 0.9),
              height: layout.isCompact ? 1.35 : 1.45,
            ),
            maxLines: layout.isCompact ? 1 : null,
            overflow:
                layout.isCompact ? TextOverflow.ellipsis : TextOverflow.visible,
          ),
          SizedBox(height: layout.overviewGap),
          _buildOverviewFocusCard(focusState),
          SizedBox(height: layout.overviewGap),
          _buildDeviceStatusCard(settingsProvider),
          SizedBox(height: layout.overviewGap),
          _buildExperiencePresetCard(context, settingsProvider),
          SizedBox(height: layout.overviewGap),
          Wrap(
            spacing: layout.isCompact ? 6 : 8,
            runSpacing: layout.isTight ? 4 : (layout.isCompact ? 6 : 8),
            children: [
              _buildStatusChip(
                icon: Icons.phone_iphone_outlined,
                label: hasPhone ? '手机号已绑定' : '手机号待补全',
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
                icon: settingsProvider.invisibleMode
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                label: invisibleSettingHint.badgeLabel,
              ),
            ],
          ),
          SizedBox(height: layout.isCompact ? 10 : 12),
          if (layout.isCompact)
            Column(
              children: [
                for (var index = 0;
                    index < overviewActions.length;
                    index++) ...[
                  if (index > 0) SizedBox(height: layout.isTight ? 6 : 8),
                  SizedBox(
                    width: double.infinity,
                    child: overviewActions[index],
                  ),
                ],
              ],
            )
          else
            Row(
              children: [
                for (var index = 0;
                    index < overviewActions.length;
                    index++) ...[
                  if (index > 0) const SizedBox(width: 10),
                  Expanded(child: overviewActions[index]),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildOverviewFocusCard(_SettingsOverviewFocusState focusState) {
    final layout = _SettingsLayoutSpec.fromSize(
      MediaQuery.of(context).size,
    );
    final badgeBackground = focusState.isHealthy
        ? AppColors.brandBlue.withValues(alpha: 0.16)
        : AppColors.white12;
    final badgeTextColor =
        focusState.isHealthy ? AppColors.brandBlue : AppColors.textSecondary;

    return Container(
      key: const Key('settings-overview-focus-card'),
      padding: EdgeInsets.all(layout.isCompact ? 12 : 14),
      decoration: BoxDecoration(
        color: AppColors.white08,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: layout.isCompact ? 36 : 40,
            height: layout.isCompact ? 36 : 40,
            decoration: BoxDecoration(
              color: focusState.isHealthy
                  ? AppColors.brandBlue.withValues(alpha: 0.16)
                  : AppColors.white12,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              focusState.icon,
              size: layout.isCompact ? 18 : 20,
              color: focusState.isHealthy
                  ? AppColors.brandBlue
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildResponsiveHeader(
                  stackOnCompact: true,
                  title: Text(
                    focusState.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  badge: _buildPillBadge(
                    label: focusState.badgeLabel,
                    backgroundColor: badgeBackground,
                    textColor: badgeTextColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  focusState.subtitle,
                  style: TextStyle(
                    fontSize: layout.isCompact ? 11.5 : 12,
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
    final layout = _SettingsLayoutSpec.fromSize(
      MediaQuery.of(context).size,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final useCompactActionLayout = layout.isCompact ||
            (constraints.hasBoundedWidth && constraints.maxWidth < 120);
        return SizedBox(
          width: useCompactActionLayout ? double.infinity : null,
          child: InkWell(
            key: key,
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: useCompactActionLayout ? 9 : 12,
                vertical: useCompactActionLayout ? 8 : 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.white08,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.white12),
              ),
              child: Row(
                mainAxisSize: useCompactActionLayout
                    ? MainAxisSize.max
                    : MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: useCompactActionLayout ? 15 : 16,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: useCompactActionLayout ? 6 : 8),
                  Flexible(
                    fit: useCompactActionLayout ? FlexFit.tight : FlexFit.loose,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: useCompactActionLayout ? 11 : 12,
                        fontWeight: FontWeight.w300,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeviceStatusCard(SettingsProvider settingsProvider) {
    final layout = _SettingsLayoutSpec.fromSize(
      MediaQuery.of(context).size,
    );
    final invisibleSettingHint = _resolveInvisibleSettingHint(settingsProvider);
    final vibrationSettingHint = _resolveVibrationSettingHint(settingsProvider);
    final notificationRuntimeState = _resolveNotificationRuntimeState(
      settingsProvider,
    );
    final statusItems = <_SettingsDeviceStatusItem>[
      _SettingsDeviceStatusItem(
        key: const Key('settings-device-status-notification'),
        icon: notificationRuntimeState.icon,
        title: '消息通知',
        badgeLabel: notificationRuntimeState.badgeLabel,
        description: notificationRuntimeState.description,
        isHealthy: notificationRuntimeState.isHealthy,
      ),
      _SettingsDeviceStatusItem(
        key: const Key('settings-device-status-presence'),
        icon: settingsProvider.invisibleMode
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
        title: '展示状态',
        badgeLabel: invisibleSettingHint.badgeLabel,
        description: invisibleSettingHint.description,
        isHealthy: invisibleSettingHint.isHealthy,
      ),
      _SettingsDeviceStatusItem(
        key: const Key('settings-device-status-vibration'),
        icon: settingsProvider.vibrationEnabled
            ? Icons.vibration_outlined
            : Icons.do_not_disturb_on_outlined,
        title: '震动提醒',
        badgeLabel: vibrationSettingHint.badgeLabel,
        description: vibrationSettingHint.description,
        isHealthy: vibrationSettingHint.isHealthy,
      ),
    ];
    final shouldCondenseCompactStatusCard = layout.isCompact &&
        notificationRuntimeState.isHealthy &&
        invisibleSettingHint.isHealthy &&
        vibrationSettingHint.isHealthy;

    return Container(
      key: const Key('settings-device-status-card'),
      padding: EdgeInsets.all(layout.isCompact ? 12 : 14),
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
            layout.isCompact
                ? '先判断这台设备现在的通知、展示和提醒是否已经就绪。'
                : '不用逐项打开开关，也能先判断这台设备现在的通知、展示和提醒是否已经就绪。',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: AppColors.textTertiary.withValues(alpha: 0.92),
              height: 1.4,
            ),
            maxLines: layout.isCompact ? 1 : null,
            overflow:
                layout.isCompact ? TextOverflow.ellipsis : TextOverflow.visible,
          ),
          SizedBox(
            height: shouldCondenseCompactStatusCard
                ? 8
                : (layout.isCompact ? 10 : 12),
          ),
          if (layout.isCompact)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: statusItems
                  .map((item) => _buildCompactDeviceStatusChip(item))
                  .toList(),
            )
          else
            ...statusItems.asMap().entries.map(
                  (entry) => Padding(
                    padding: EdgeInsets.only(
                      bottom: entry.key == statusItems.length - 1 ? 0 : 10,
                    ),
                    child: _buildDeviceStatusRow(entry.value),
                  ),
                ),
          if (notificationRuntimeState.followUpDescription != null) ...[
            SizedBox(height: layout.isCompact ? 10 : 12),
            _buildNotificationRuntimeCard(
              context,
              notificationRuntimeState,
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

  Widget _buildCompactDeviceStatusChip(_SettingsDeviceStatusItem item) {
    return Container(
      key: item.key,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.white08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            item.icon,
            size: 14,
            color:
                item.isHealthy ? AppColors.textSecondary : AppColors.brandBlue,
          ),
          const SizedBox(width: 6),
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: item.isHealthy
                  ? AppColors.white12
                  : AppColors.brandBlue.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              item.badgeLabel,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w300,
                color: item.isHealthy
                    ? AppColors.textSecondary
                    : AppColors.brandBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationRuntimeCard(
    BuildContext context,
    _SettingsNotificationRuntimeState state,
  ) {
    final layout = _SettingsLayoutSpec.fromSize(
      MediaQuery.of(context).size,
    );
    final primaryActionButton = TextButton(
      key: const Key('settings-notification-runtime-action'),
      onPressed: () => _handleNotificationAction(state.actionType),
      style: TextButton.styleFrom(
        alignment: layout.isCompact ? Alignment.centerLeft : null,
        padding: EdgeInsets.symmetric(
          horizontal: layout.isCompact ? 9 : 12,
          vertical: layout.isCompact ? 7 : 10,
        ),
        foregroundColor: AppColors.brandBlue,
        backgroundColor: AppColors.brandBlue.withValues(alpha: 0.12),
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
    );
    final notificationCenterButton = TextButton.icon(
      key: const Key('settings-notification-center-action'),
      onPressed: () => context.push('/notifications'),
      style: TextButton.styleFrom(
        alignment: layout.isCompact ? Alignment.centerLeft : null,
        padding: EdgeInsets.symmetric(
          horizontal: layout.isCompact ? 9 : 12,
          vertical: layout.isCompact ? 7 : 10,
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
        NotificationPermissionGuidance.openNotificationCenterAction,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
    return Container(
      key: const Key('settings-notification-runtime-card'),
      padding: EdgeInsets.all(layout.isCompact ? 10 : 12),
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
            width: layout.isCompact ? 28 : 30,
            height: layout.isCompact ? 28 : 30,
            decoration: BoxDecoration(
              color: state.isHealthy
                  ? AppColors.white08
                  : AppColors.brandBlue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              state.icon,
              size: layout.isCompact ? 15 : 16,
              color: state.isHealthy
                  ? AppColors.textSecondary
                  : AppColors.brandBlue,
            ),
          ),
          SizedBox(width: layout.isCompact ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildResponsiveHeader(
                  stackOnCompact: true,
                  title: const Text(
                    '通知通道提示',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  badge: _buildPillBadge(
                    key: const Key('settings-notification-runtime-badge'),
                    label: state.badgeLabel,
                    backgroundColor: state.isHealthy
                        ? AppColors.white08
                        : AppColors.brandBlue.withValues(alpha: 0.16),
                    textColor: state.isHealthy
                        ? AppColors.textSecondary
                        : AppColors.brandBlue,
                  ),
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
                  maxLines: layout.isCompact ? 2 : null,
                  overflow: layout.isCompact
                      ? TextOverflow.ellipsis
                      : TextOverflow.visible,
                ),
                Selector<NotificationCenterProvider?,
                    _SettingsNotificationCenterDigestState?>(
                  selector: (context, notificationCenterProvider) =>
                      _resolveNotificationCenterDigest(
                    notificationCenterProvider,
                  ),
                  builder: (context, digest, child) {
                    if (digest == null) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: EdgeInsets.only(
                        top: layout.isCompact ? 8 : 10,
                      ),
                      child: _buildNotificationCenterDigestCard(digest),
                    );
                  },
                ),
                SizedBox(height: layout.isCompact ? 8 : 10),
                if (layout.isCompact)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: primaryActionButton,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: notificationCenterButton,
                      ),
                    ],
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      primaryActionButton,
                      notificationCenterButton,
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
    final layout = _SettingsLayoutSpec.fromSize(
      MediaQuery.of(context).size,
    );
    return Container(
      key: const Key('settings-notification-center-summary-card'),
      padding: EdgeInsets.all(layout.isCompact ? 9 : 10),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.white08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildResponsiveHeader(
            title: Text(
              state.title,
              key: const Key('settings-notification-center-summary-title'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
              ),
            ),
            badge: _buildPillBadge(
              key: const Key('settings-notification-center-summary-badge'),
              label: state.badgeLabel,
              backgroundColor: state.hasUnread
                  ? AppColors.brandBlue.withValues(alpha: 0.16)
                  : AppColors.white08,
              textColor: state.hasUnread
                  ? AppColors.brandBlue
                  : AppColors.textSecondary,
            ),
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
            maxLines: layout.isCompact ? 1 : null,
            overflow:
                layout.isCompact ? TextOverflow.ellipsis : TextOverflow.visible,
          ),
          if (state.sourceItems.isNotEmpty) ...[
            SizedBox(height: layout.isCompact ? 6 : 8),
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
                _buildResponsiveHeader(
                  title: Text(
                    state.title,
                    key: const Key('settings-inline-feedback-title'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  badge: _buildPillBadge(
                    label: state.badgeLabel,
                    textKey: const Key('settings-inline-feedback-badge'),
                    backgroundColor: state.isHealthy
                        ? AppColors.white12
                        : AppColors.brandBlue.withValues(alpha: 0.16),
                    textColor: state.isHealthy
                        ? AppColors.textSecondary
                        : AppColors.brandBlue,
                  ),
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
    final layout = _SettingsLayoutSpec.fromSize(
      MediaQuery.of(context).size,
    );
    final currentPresetState = _resolveExperiencePresetState(settingsProvider);
    final activePreset = settingsProvider.activeExperiencePreset;
    final presetOptions = _experiencePresetOptions;
    final compactSummary = layout.isCompact
        ? '按设备情况快速切到主入口、提醒更克制或展示收起的状态。'
        : currentPresetState.description;

    return Container(
      key: const Key('settings-experience-preset-card'),
      padding: EdgeInsets.all(layout.isCompact ? 12 : 14),
      decoration: BoxDecoration(
        color: AppColors.white08,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildResponsiveHeader(
            stackOnCompact: true,
            title: const Text(
              '设备模式预设',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
              ),
            ),
            badge: _buildPillBadge(
              key: const Key('settings-experience-preset-current-badge'),
              label: currentPresetState.badgeLabel,
              backgroundColor: currentPresetState.isHealthy
                  ? AppColors.white12
                  : AppColors.brandBlue.withValues(alpha: 0.16),
              textColor: currentPresetState.isHealthy
                  ? AppColors.textSecondary
                  : AppColors.brandBlue,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            compactSummary,
            key: const Key('settings-experience-preset-summary'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: AppColors.textTertiary.withValues(alpha: 0.92),
              height: 1.4,
            ),
            maxLines: layout.isCompact ? 2 : null,
            overflow:
                layout.isCompact ? TextOverflow.ellipsis : TextOverflow.visible,
          ),
          SizedBox(height: layout.isCompact ? 10 : 12),
          if (layout.isTight)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < presetOptions.length; index++) ...[
                  if (index > 0) const SizedBox(height: 8),
                  _buildExperiencePresetOption(
                    context,
                    option: presetOptions[index],
                    isActive: activePreset == presetOptions[index].preset,
                  ),
                ],
              ],
            )
          else if (layout.isCompact)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presetOptions.map((option) {
                return _buildExperiencePresetOption(
                  context,
                  option: option,
                  isActive: activePreset == option.preset,
                );
              }).toList(),
            )
          else
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
    final layout = _SettingsLayoutSpec.fromSize(
      MediaQuery.of(context).size,
    );
    final compactOptionWidth = ((MediaQuery.of(context).size.width -
                (layout.pageHorizontalPadding * 2) -
                (layout.overviewPadding * 2) -
                12) /
            2)
        .clamp(132.0, 144.0)
        .toDouble();
    final optionWidth = layout.isTight
        ? double.infinity
        : (layout.isCompact ? compactOptionWidth : null);
    return InkWell(
      key: option.key,
      onTap: () => _applyExperiencePreset(option.preset),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: optionWidth,
        padding: EdgeInsets.symmetric(
          horizontal: layout.isTight ? 7 : (layout.isCompact ? 8 : 12),
          vertical: layout.isTight ? 5 : (layout.isCompact ? 8 : 12),
        ),
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
              width: layout.isTight ? 26 : (layout.isCompact ? 28 : 32),
              height: layout.isTight ? 26 : (layout.isCompact ? 28 : 32),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.brandBlue.withValues(alpha: 0.16)
                    : AppColors.white08,
                borderRadius: BorderRadius.circular(
                    layout.isTight ? 9 : (layout.isCompact ? 10 : 11)),
              ),
              child: Icon(
                option.icon,
                size: layout.isTight ? 14 : (layout.isCompact ? 15 : 17),
                color: isActive ? AppColors.brandBlue : AppColors.textSecondary,
              ),
            ),
            SizedBox(width: layout.isTight ? 7 : (layout.isCompact ? 8 : 10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildResponsiveHeader(
                    stackOnCompact: false,
                    spacing: 6,
                    title: Text(
                      option.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    badge: _buildPillBadge(
                      label: isActive ? '当前' : option.badgeLabel,
                      backgroundColor: isActive
                          ? AppColors.brandBlue.withValues(alpha: 0.18)
                          : AppColors.white08,
                      textColor: isActive
                          ? AppColors.brandBlue
                          : AppColors.textSecondary,
                    ),
                  ),
                  if (!layout.isCompact) ...[
                    const SizedBox(height: 4),
                    Text(
                      option.description,
                      style: TextStyle(
                        fontSize: layout.isCompact ? 10.5 : 11,
                        fontWeight: FontWeight.w300,
                        color: AppColors.textTertiary.withValues(alpha: 0.9),
                        height: 1.35,
                      ),
                      maxLines: layout.isCompact ? 2 : null,
                      overflow: layout.isCompact
                          ? TextOverflow.ellipsis
                          : TextOverflow.visible,
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

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
  }) {
    final layout = _SettingsLayoutSpec.fromSize(
      MediaQuery.of(context).size,
    );
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: layout.isCompact ? 9 : 10,
        vertical: layout.isCompact ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: AppColors.white08,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: layout.isCompact ? 13 : 14,
            color: AppColors.textSecondary,
          ),
          SizedBox(width: layout.isCompact ? 5 : 6),
          Text(
            label,
            style: TextStyle(
              fontSize: layout.isCompact ? 11 : 12,
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
    return _buildToggleHintFromInlineFeedback(
      _buildInvisibleModeFeedback(settingsProvider.invisibleMode),
    );
  }

  _SettingsExperiencePresetState _resolveExperiencePresetState(
    SettingsProvider settingsProvider,
  ) {
    switch (settingsProvider.activeExperiencePreset) {
      case SettingsExperiencePreset.responsive:
        return const _SettingsExperiencePresetState(
          badgeLabel: '主入口',
          description: '通知、震动和展示都已经恢复，这台设备现在更适合作为主聊天入口。',
          isHealthy: true,
        );
      case SettingsExperiencePreset.balanced:
        return const _SettingsExperiencePresetState(
          badgeLabel: '提醒更克制',
          description: '通知继续保持在线，但震动已经收起，适合通勤或不想被频繁打断时使用。',
          isHealthy: true,
        );
      case SettingsExperiencePreset.quietObserve:
        return const _SettingsExperiencePresetState(
          badgeLabel: '展示已收起',
          description: '通知和震动已经收起，并同步切到了隐身状态，适合短暂离线或先观察。',
        );
      case null:
        return const _SettingsExperiencePresetState(
          badgeLabel: '手动调整中',
          description: '你已经手动组合了通知、隐身和展示设置；如果想快速回到稳定状态，可以直接使用下面的一键预设。',
        );
    }
  }

  List<_SettingsExperiencePresetOption> get _experiencePresetOptions => const [
        _SettingsExperiencePresetOption(
          key: Key('settings-preset-responsive'),
          preset: SettingsExperiencePreset.responsive,
          icon: Icons.flash_on_outlined,
          title: '在线回复',
          badgeLabel: '主入口',
          description: '通知、振动和正常展示全部打开，最适合作为主聊天入口。',
        ),
        _SettingsExperiencePresetOption(
          key: Key('settings-preset-balanced'),
          preset: SettingsExperiencePreset.balanced,
          icon: Icons.tune_outlined,
          title: '低干扰',
          badgeLabel: '提醒更克制',
          description: '保持消息在线，但收起部分打扰，更适合工作或通勤场景。',
        ),
        _SettingsExperiencePresetOption(
          key: Key('settings-preset-quiet-observe'),
          preset: SettingsExperiencePreset.quietObserve,
          icon: Icons.nightlight_round_outlined,
          title: '安静观察',
          badgeLabel: '展示已收起',
          description: '关闭通知和振动，并切到隐身状态，适合短暂离线或观察环境。',
        ),
      ];

  _SettingsToggleHint _resolveNotificationSettingHint(
    SettingsProvider settingsProvider,
  ) {
    final runtimeState = _resolveNotificationRuntimeState(settingsProvider);
    return _SettingsToggleHint(
      badgeLabel: runtimeState.badgeLabel,
      description: runtimeState.description,
      isHealthy: runtimeState.isHealthy,
    );
  }

  _SettingsToggleHint _resolveVibrationSettingHint(
    SettingsProvider settingsProvider,
  ) {
    return _buildToggleHintFromInlineFeedback(
      _buildVibrationFeedback(settingsProvider.vibrationEnabled),
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
        title: '手机号还没补全',
        subtitle: '补上后登录找回、异常排查和账号确认都会更顺手，也能减少后续联调歧义。',
        badgeLabel: '待补全',
      );
    }

    if (settingsProvider.notificationEnabled && !pushState.permissionGranted) {
      return const _SettingsOverviewFocusState(
        icon: Icons.notifications_paused_outlined,
        title: NotificationPermissionGuidance.title,
        subtitle: NotificationPermissionGuidance.settingsDescription,
        badgeLabel: NotificationPermissionGuidance.badgeLabel,
      );
    }

    if (!settingsProvider.notificationEnabled) {
      return const _SettingsOverviewFocusState(
        icon: Icons.notifications_off_outlined,
        title: '消息提醒当前已收起',
        subtitle: '新回复会继续留在通知中心；如果这台设备要承担主聊天入口，建议恢复通知。',
        badgeLabel: '提醒已收起',
      );
    }

    if (pushState.deviceToken == null) {
      return const _SettingsOverviewFocusState(
        icon: Icons.sync_outlined,
        title: '通知通道正在同步',
        subtitle: '系统权限已经打开，当前正在等待这台设备的通知通道重新就绪，稍后可以再次刷新确认。',
        badgeLabel: '通道同步中',
      );
    }

    if (settingsProvider.invisibleMode) {
      return const _SettingsOverviewFocusState(
        icon: Icons.visibility_off_outlined,
        title: '展示当前已切到隐身',
        subtitle: '如果你接下来准备正常使用匹配和聊天，可以恢复展示状态，避免曝光和到达率偏低。',
        badgeLabel: '展示已收起',
      );
    }

    return const _SettingsOverviewFocusState(
      icon: Icons.verified_outlined,
      title: '当前高频状态已经就绪',
      subtitle: '账号、通知和展示状态都比较完整，这台设备可以继续作为稳定聊天入口使用。',
      badgeLabel: '状态已就绪',
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
        badgeLabel: '提醒已收起',
        description: '新消息会保存在通知中心，但锁屏和后台提醒已经收起，适合主动查看型使用。',
        followUpDescription: '如果你希望这台设备继续承担主聊天入口，建议恢复通知并保持系统权限可用。',
        statusChipLabel: '提醒已收起',
        actionLabel: '恢复通知',
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
        badgeLabel: '通道同步中',
        description: '系统权限已开启，当前正在等待这台设备的通知通道重新就绪，稍后可以再次刷新确认。',
        followUpDescription: '如果你刚刚改过权限或切换过账号，可以手动刷新一次，确认这台设备已经重新就绪。',
        statusChipLabel: '通道同步中',
        actionLabel: '刷新状态',
        actionIcon: Icons.refresh_outlined,
        actionType: _SettingsNotificationAction.refreshRuntimeState,
      );
    }

    return const _SettingsNotificationRuntimeState(
      icon: Icons.notifications_active_outlined,
      badgeLabel: '通道已就绪',
      description: '系统权限和设备通道都已准备好，这台设备适合作为主聊天入口。',
      statusChipLabel: '通道已就绪',
      actionLabel: '收起通知',
      actionIcon: Icons.notifications_off_outlined,
      actionType: _SettingsNotificationAction.disableNotifications,
      isHealthy: true,
    );
  }

  _SettingsToggleHint _buildToggleHintFromInlineFeedback(
    _SettingsInlineFeedbackState feedback,
  ) {
    return _SettingsToggleHint(
      badgeLabel: feedback.badgeLabel,
      description: feedback.description,
      isHealthy: feedback.isHealthy,
    );
  }

  Widget _buildSectionTitle(String title, {String? subtitle}) {
    final layout = _SettingsLayoutSpec.fromSize(
      MediaQuery.of(context).size,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        layout.sectionTitleInset,
        0,
        layout.sectionTitleInset,
        layout.sectionTitleBottomSpacing,
      ),
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
              maxLines: layout.isCompact ? 1 : null,
              overflow: layout.isCompact
                  ? TextOverflow.ellipsis
                  : TextOverflow.visible,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    final layout = _SettingsLayoutSpec.fromSize(
      MediaQuery.of(context).size,
    );
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(layout.sectionCardRadius),
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
    final layout = _SettingsLayoutSpec.fromSize(
      MediaQuery.of(context).size,
    );
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: layout.itemHorizontalPadding,
          vertical: layout.itemVerticalPadding,
        ),
        child: Row(
          crossAxisAlignment: layout.isCompact
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Container(
              width: layout.leadingBoxSize,
              height: layout.leadingBoxSize,
              decoration: BoxDecoration(
                color: AppColors.white05,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: AppColors.textSecondary,
                size: layout.leadingIconSize,
              ),
            ),
            SizedBox(width: layout.isCompact ? 12 : 14),
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
                          style: TextStyle(
                            fontSize: layout.isCompact ? 14 : 15,
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
                        fontSize: layout.isCompact ? 11.5 : 12,
                        fontWeight: FontWeight.w300,
                        color: AppColors.textTertiary.withValues(alpha: 0.9),
                        height: 1.35,
                      ),
                      maxLines: layout.isCompact ? 2 : null,
                      overflow: layout.isCompact
                          ? TextOverflow.ellipsis
                          : TextOverflow.visible,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: layout.trailingGap),
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
    final layout = _SettingsLayoutSpec.fromSize(
      MediaQuery.of(context).size,
    );
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: layout.itemHorizontalPadding,
      ),
      height: 1,
      color: AppColors.white05,
    );
  }

  Widget _buildAccountActionCard({
    required Key cardKey,
    required Key actionKey,
    required IconData icon,
    required String title,
    required String badgeLabel,
    required String description,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    final layout = _SettingsLayoutSpec.fromSize(
      MediaQuery.of(context).size,
    );
    final cardColor =
        isDanger ? AppColors.error.withValues(alpha: 0.06) : AppColors.white05;
    final borderColor =
        isDanger ? AppColors.error.withValues(alpha: 0.18) : AppColors.white12;
    final iconColor = isDanger ? AppColors.error : AppColors.textSecondary;
    final badgeBackground =
        isDanger ? AppColors.error.withValues(alpha: 0.14) : AppColors.white08;
    final badgeTextColor = isDanger ? AppColors.error : AppColors.textSecondary;
    final leadingSize = layout.isCompact ? 34.0 : 38.0;

    return Material(
      key: cardKey,
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(layout.sectionCardRadius),
          border: Border.all(color: borderColor),
        ),
        child: InkWell(
          key: actionKey,
          borderRadius: BorderRadius.circular(layout.sectionCardRadius),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(layout.isCompact ? 14 : 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: leadingSize,
                  height: leadingSize,
                  decoration: BoxDecoration(
                    color: badgeBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: layout.isCompact ? 14 : 15,
                              fontWeight: FontWeight.w400,
                              color: isDanger
                                  ? AppColors.error
                                  : AppColors.textPrimary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          _buildPillBadge(
                            label: badgeLabel,
                            backgroundColor: badgeBackground,
                            textColor: badgeTextColor,
                            borderColor: borderColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: layout.isCompact ? 11.5 : 12,
                          fontWeight: FontWeight.w300,
                          color: AppColors.textTertiary.withValues(alpha: 0.92),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: isDanger ? AppColors.error : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
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
                                    '🙂';
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
    _showInlineFeedback(_buildInvisibleModeFeedback(enabled));
    AppFeedback.showToast(
      context,
      enabled ? AppToastCode.enabled : AppToastCode.disabled,
      subject: '闅愯韩妯″紡',
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
    _showInlineFeedback(_buildVibrationFeedback(enabled));
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

    _showInlineFeedback(_buildExperiencePresetFeedback(preset));
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
                description: '如果这次没有成功跳到系统设置，请稍后手动打开系统通知权限，再回到应用刷新状态。',
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
          badgeLabel: '通道同步中',
          description: '系统权限已开启，当前正在等待这台设备的通知通道重新就绪，稍后可以再次刷新确认。',
        ),
      _SettingsNotificationAction.disableNotifications =>
        const _SettingsInlineFeedbackState(
          icon: Icons.notifications_active_outlined,
          title: '通知已经恢复在线',
          badgeLabel: '通道已就绪',
          description: '系统权限和设备通道都可用，这台设备现在更适合作为主聊天入口。',
          isHealthy: true,
        ),
      _SettingsNotificationAction.enableNotifications =>
        const _SettingsInlineFeedbackState(
          icon: Icons.notifications_off_outlined,
          title: '通知已切到静默',
          badgeLabel: '提醒已收起',
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
          badgeLabel: '通道同步中',
          description: '系统通知权限已经打开，当前正在等待这台设备的通知通道重新就绪。',
        ),
      _SettingsNotificationAction.disableNotifications =>
        const _SettingsInlineFeedbackState(
          icon: Icons.notifications_active_outlined,
          title: '通知已经恢复在线',
          badgeLabel: '通道已就绪',
          description: '已检测到系统通知权限已恢复，这台设备现在更适合作为主聊天入口。',
          isHealthy: true,
        ),
      _SettingsNotificationAction.enableNotifications =>
        const _SettingsInlineFeedbackState(
          icon: Icons.notifications_off_outlined,
          title: '通知仍处于静默',
          badgeLabel: '提醒已收起',
          description: '系统通知权限虽然已经恢复，但应用内通知开关当前仍是关闭状态，新的提醒会继续留在通知中心。',
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
    final preview = body.isEmpty ? title : '$title / $body';
    if (preview.length <= 36) {
      return preview;
    }
    return '${preview.substring(0, 35)}...';
  }

  void _showInlineFeedback(_SettingsInlineFeedbackState state) {
    if (!mounted) return;
    setState(() {
      _inlineFeedback = state;
    });
  }

  void _disposeTextControllersWithDelay(
    Iterable<TextEditingController> controllers,
  ) {
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 280), () {
        for (final controller in controllers) {
          controller.dispose();
        }
      }),
    );
  }

  _SettingsInlineFeedbackState _buildAccountSavedFeedback({
    required IconData icon,
    required String title,
    required String badgeLabel,
    required String description,
  }) {
    return _SettingsInlineFeedbackState(
      icon: icon,
      title: title,
      badgeLabel: badgeLabel,
      description: description,
      isHealthy: true,
    );
  }

  _SettingsInlineFeedbackState _buildInvisibleModeFeedback(bool enabled) {
    return enabled
        ? const _SettingsInlineFeedbackState(
            icon: Icons.visibility_off_outlined,
            title: '展示已切到隐身',
            badgeLabel: '展示已收起',
            description: '在线可见和匹配曝光会更克制，适合短时观察；准备正常匹配时再切回。',
          )
        : const _SettingsInlineFeedbackState(
            icon: Icons.visibility_outlined,
            title: '展示已经恢复正常',
            badgeLabel: '展示已恢复',
            description: '在线可见和匹配曝光已恢复，当前更适合作为正常匹配和聊天入口。',
            isHealthy: true,
          );
  }

  _SettingsInlineFeedbackState _buildVibrationFeedback(bool enabled) {
    return enabled
        ? const _SettingsInlineFeedbackState(
            icon: Icons.vibration_outlined,
            title: '震动提醒已经恢复',
            badgeLabel: '提醒已恢复',
            description: '弱网和锁屏场景下更不容易错过关键消息，适合把这台设备当主聊天入口。',
            isHealthy: true,
          )
        : const _SettingsInlineFeedbackState(
            icon: Icons.do_not_disturb_on_outlined,
            title: '震动提醒已经收起',
            badgeLabel: '提醒已收起',
            description: '震动已经关闭，适合会议或通勤场景；建议配合通知状态一起观察是否会漏消息。',
          );
  }

  _SettingsInlineFeedbackState _buildExperiencePresetFeedback(
    SettingsExperiencePreset preset,
  ) {
    return switch (preset) {
      SettingsExperiencePreset.responsive => const _SettingsInlineFeedbackState(
          icon: Icons.flash_on_outlined,
          title: '体验预设已切到在线回复',
          badgeLabel: '主入口',
          description: '通知、振动和正常展示都已打开，这台设备现在更适合作为主聊天入口。',
          isHealthy: true,
        ),
      SettingsExperiencePreset.balanced => const _SettingsInlineFeedbackState(
          icon: Icons.tune_outlined,
          title: '体验预设已切到低干扰',
          badgeLabel: '提醒更克制',
          description: '你会继续在线接收消息，但提醒频率更克制，适合不想被频繁打断的时候使用。',
          isHealthy: true,
        ),
      SettingsExperiencePreset.quietObserve =>
        const _SettingsInlineFeedbackState(
          icon: Icons.nightlight_round_outlined,
          title: '体验预设已切到安静观察',
          badgeLabel: '展示已收起',
          description: '通知和振动已经关闭，并同步切到了隐身状态，适合短时离线或先观察环境。',
        ),
    };
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

  _SettingsSheetValidationState _resolvePhoneEditorValidation({
    required String currentPhone,
    required String nextPhone,
  }) {
    final normalizedNextPhone = nextPhone.trim();
    if (normalizedNextPhone.isEmpty) {
      return const _SettingsSheetValidationState(
        icon: Icons.phone_outlined,
        title: '输入新的手机号后再保存',
        description: '需要先输入 11 位手机号，本次修改才会同步到登录、验证码接收和账号找回。',
      );
    }

    final isValidPhone = RegExp(r'^\d{11}$').hasMatch(normalizedNextPhone);
    if (!isValidPhone) {
      return const _SettingsSheetValidationState(
        icon: Icons.phone_outlined,
        title: '还需要完整的 11 位手机号',
        description: '当前号码格式还不完整，先补齐后再保存，现有绑定号码不会被覆盖。',
      );
    }

    if (currentPhone.isNotEmpty && normalizedNextPhone == currentPhone) {
      return const _SettingsSheetValidationState(
        icon: Icons.info_outline,
        title: '当前号码未发生变化',
        description: '如果只是确认当前信息，无需重复保存；需要修改时换成新的常用号码即可。',
      );
    }

    return const _SettingsSheetValidationState(
      icon: Icons.check_circle_outline,
      title: '可以保存新手机号',
      description: '保存后会立即更新这台设备的登录、验证码接收和账号找回号码。',
      isReady: true,
    );
  }

  _SettingsSheetValidationState _resolvePasswordEditorValidation({
    required String currentPassword,
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    final normalizedOldPassword = oldPassword.trim();
    final normalizedNewPassword = newPassword.trim();
    final normalizedConfirmPassword = confirmPassword.trim();

    if (normalizedOldPassword.isEmpty &&
        normalizedNewPassword.isEmpty &&
        normalizedConfirmPassword.isEmpty) {
      return const _SettingsSheetValidationState(
        icon: Icons.lock_outline,
        title: '先完成旧密码校验',
        description: '需要先输入当前密码，再设置新的密码和确认内容，本次修改才会生效。',
      );
    }

    if (normalizedOldPassword != currentPassword) {
      return const _SettingsSheetValidationState(
        icon: Icons.lock_outline,
        title: '旧密码还未校验通过',
        description: '请先输入当前正确密码，再继续保存新密码，避免把这次修改误存进错误账号。',
      );
    }

    if (normalizedNewPassword.length < 6) {
      return const _SettingsSheetValidationState(
        icon: Icons.password_outlined,
        title: '新密码至少需要 6 位',
        description: '建议重新设置一个更稳妥的新密码，再继续保存。',
      );
    }

    if (normalizedNewPassword == currentPassword) {
      return const _SettingsSheetValidationState(
        icon: Icons.lock_reset_outlined,
        title: '新密码还没有变化',
        description: '如果要提升安全性，建议换成一个和当前不同的新密码。',
      );
    }

    if (normalizedConfirmPassword != normalizedNewPassword) {
      return const _SettingsSheetValidationState(
        icon: Icons.rule_folder_outlined,
        title: '两次输入的新密码还不一致',
        description: '再确认一次新密码，保持两次输入一致后才会允许保存。',
      );
    }

    return const _SettingsSheetValidationState(
      icon: Icons.check_circle_outline,
      title: '可以保存新密码',
      description: '保存后这台设备会立即改用新密码作为本地登录校验。',
      isReady: true,
    );
  }

  Future<void> _presentPhoneEditorSheet(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final controller = TextEditingController(text: authProvider.phone ?? '');
    final currentPhone = (authProvider.phone ?? '').trim();
    final phoneValidation = ValueNotifier<_SettingsSheetValidationState>(
      _resolvePhoneEditorValidation(
        currentPhone: currentPhone,
        nextPhone: controller.text,
      ),
    );
    void syncPhoneValidation() {
      phoneValidation.value = _resolvePhoneEditorValidation(
        currentPhone: currentPhone,
        nextPhone: controller.text,
      );
    }

    controller.addListener(syncPhoneValidation);
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
              child: ValueListenableBuilder<_SettingsSheetValidationState>(
                valueListenable: phoneValidation,
                builder: (context, validation, child) {
                  return SingleChildScrollView(
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
                          description:
                              authProvider.phone?.trim().isNotEmpty == true
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
                        const SizedBox(height: 12),
                        _buildAccountHintCard(
                          key: const Key('settings-phone-validation-card'),
                          icon: validation.icon,
                          title: validation.title,
                          description: validation.description,
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  backgroundColor: AppColors.white05,
                                  disabledBackgroundColor: AppColors.white05,
                                  disabledForegroundColor:
                                      AppColors.textDisabled,
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
                                onPressed: validation.isReady
                                    ? () {
                                        FocusScope.of(sheetContext).unfocus();
                                        Navigator.pop(sheetContext, true);
                                      }
                                    : null,
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  backgroundColor: AppColors.white12,
                                  disabledBackgroundColor: AppColors.white05,
                                  disabledForegroundColor:
                                      AppColors.textDisabled,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  '保存',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w300,
                                    color: validation.isReady
                                        ? AppColors.textPrimary
                                        : AppColors.textDisabled,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    controller.removeListener(syncPhoneValidation);
    phoneValidation.dispose();

    if (result == true && context.mounted) {
      final phone = controller.text.trim();
      await authProvider.updatePhone(phone);
      if (!context.mounted) return;
      _showInlineFeedback(
        _buildAccountSavedFeedback(
          icon: Icons.phone_outlined,
          title: '手机号已经更新',
          badgeLabel: '账号已刷新',
          description: '新的手机号已经写回当前账号资料，后续登录、验证码接收和账号找回都会以它为准。',
        ),
      );
      AppFeedback.showToast(context, AppToastCode.saved, subject: '手机号');
    }
    _disposeTextControllersWithDelay([controller]);
  }

  Future<void> _presentPasswordEditorSheet(BuildContext context) async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final currentPassword = StorageService.getLocalPassword();
    final passwordValidation = ValueNotifier<_SettingsSheetValidationState>(
      _resolvePasswordEditorValidation(
        currentPassword: currentPassword,
        oldPassword: oldController.text,
        newPassword: newController.text,
        confirmPassword: confirmController.text,
      ),
    );
    void syncPasswordValidation() {
      passwordValidation.value = _resolvePasswordEditorValidation(
        currentPassword: currentPassword,
        oldPassword: oldController.text,
        newPassword: newController.text,
        confirmPassword: confirmController.text,
      );
    }

    oldController.addListener(syncPasswordValidation);
    newController.addListener(syncPasswordValidation);
    confirmController.addListener(syncPasswordValidation);

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
              child: ValueListenableBuilder<_SettingsSheetValidationState>(
                valueListenable: passwordValidation,
                builder: (context, validation, child) {
                  return SingleChildScrollView(
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
                          decoration: const InputDecoration(
                            hintText: '输入新的密码，至少 6 位',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          key: const Key('settings-password-confirm-input'),
                          controller: confirmController,
                          obscureText: true,
                          decoration:
                              const InputDecoration(hintText: '再次确认新密码'),
                        ),
                        const SizedBox(height: 12),
                        _buildAccountHintCard(
                          key: const Key('settings-password-validation-card'),
                          icon: validation.icon,
                          title: validation.title,
                          description: validation.description,
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  backgroundColor: AppColors.white05,
                                  disabledBackgroundColor: AppColors.white05,
                                  disabledForegroundColor:
                                      AppColors.textDisabled,
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
                                onPressed: validation.isReady
                                    ? () {
                                        FocusScope.of(sheetContext).unfocus();
                                        Navigator.pop(sheetContext, true);
                                      }
                                    : null,
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  backgroundColor: AppColors.white12,
                                  disabledBackgroundColor: AppColors.white05,
                                  disabledForegroundColor:
                                      AppColors.textDisabled,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  '确认',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w300,
                                    color: validation.isReady
                                        ? AppColors.textPrimary
                                        : AppColors.textDisabled,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    oldController.removeListener(syncPasswordValidation);
    newController.removeListener(syncPasswordValidation);
    confirmController.removeListener(syncPasswordValidation);
    passwordValidation.dispose();

    if (result == true && context.mounted) {
      final oldPassword = oldController.text.trim();
      final newPassword = newController.text.trim();
      if (oldPassword == currentPassword && newPassword.length >= 6) {
        await StorageService.saveLocalPassword(newPassword);
        if (!context.mounted) return;
        _showInlineFeedback(
          _buildAccountSavedFeedback(
            icon: Icons.lock_outlined,
            title: '密码已经更新',
            badgeLabel: '安全已刷新',
            description: '新的本地密码已经写回当前安全设置，后续请优先使用新密码，避免和其他环境复用。',
          ),
        );
        AppFeedback.showToast(context, AppToastCode.saved, subject: '密码');
      }
    }
    _disposeTextControllersWithDelay([
      oldController,
      newController,
      confirmController,
    ]);
  }

  void _showLogoutDialog(BuildContext context) async {
    final confirm = await AppDialog.showConfirm(
      context,
      title: '退出登录',
      content: '这只会退出当前设备上的登录状态。\n你的账号资料、好友关系和聊天记录仍会保留，之后可以重新登录。',
      confirmText: '退出当前设备',
      isDanger: true,
    );

    if (confirm == true && context.mounted) {
      context.read<AuthProvider>().logout();
      context.go('/login');
    }
  }

  void _showDeleteAccountDialog(BuildContext context) async {
    final confirm = await AppDialog.showConfirm(
      context,
      title: '注销账号',
      content: '注销后将清除账号资料与会话数据，且无法恢复。\n如果只是暂时离开，建议使用“退出登录”。',
      confirmText: '确认注销',
      isDanger: true,
    );

    if (confirm == true && context.mounted) {
      await context.read<AuthProvider>().deleteAccount();
      if (context.mounted) context.go('/login');
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

class _SettingsMediaPreviewState {
  const _SettingsMediaPreviewState({
    this.mediaPath,
    this.hasMedia = false,
  });

  final String? mediaPath;
  final bool hasMedia;
}

class _SettingsSheetValidationState {
  const _SettingsSheetValidationState({
    required this.icon,
    required this.title,
    required this.description,
    this.isReady = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool isReady;
}

class _SettingsMediaManagementSummary {
  const _SettingsMediaManagementSummary({
    required this.itemSubtitle,
    required this.itemBadgeLabel,
    required this.previewStatusLabel,
    required this.previewBadgeLabel,
    required this.replaceActionLabel,
  });

  final String itemSubtitle;
  final String itemBadgeLabel;
  final String previewStatusLabel;
  final String previewBadgeLabel;
  final String replaceActionLabel;
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
