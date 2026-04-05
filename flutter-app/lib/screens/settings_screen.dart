import 'dart:async';
import 'package:flutter/foundation.dart' show listEquals;
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
import '../services/media_upload_service.dart';
import '../services/storage_service.dart';
import '../utils/media_preview_state_resolver.dart';
import '../utils/notification_permission_guidance.dart';
import '../utils/permission_manager.dart';
import '../widgets/settings_media_management_preview_card.dart';
import '../widgets/settings_media_preview_surface.dart';
import '../widgets/app_toast.dart';
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
  final ValueNotifier<_SettingsInlineFeedbackState?> _inlineFeedbackNotifier =
      ValueNotifier<_SettingsInlineFeedbackState?>(null);
  Timer? _inlineFeedbackTimer;
  final ValueNotifier<_SettingsMediaPreviewState> _avatarPreviewStateNotifier =
      ValueNotifier<_SettingsMediaPreviewState>(
    const _SettingsMediaPreviewState(),
  );
  final ValueNotifier<_SettingsMediaPreviewState>
      _backgroundPreviewStateNotifier =
      ValueNotifier<_SettingsMediaPreviewState>(
    const _SettingsMediaPreviewState(),
  );
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
    _inlineFeedbackTimer?.cancel();
    _inlineFeedbackNotifier.dispose();
    _avatarPreviewStateNotifier.dispose();
    _backgroundPreviewStateNotifier.dispose();
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
    final handledRecovery = await settingsProvider
        .refreshPushRuntimeStateAfterSystemSettingsReturn();
    if (!mounted || !handledRecovery) return;
    _showInlineFeedback(
      _buildNotificationResumeInlineFeedback(settingsProvider),
    );
  }

  Future<void> _refreshMediaPreviewStates() async {
    final avatarState = await _readAvatarPreviewState();
    final backgroundState = await _readBackgroundPreviewState();
    if (!mounted) return;
    _avatarPreviewStateNotifier.value = avatarState;
    _backgroundPreviewStateNotifier.value = backgroundState;
  }

  Future<void> _refreshAvatarPreviewState() async {
    final nextState = await _readAvatarPreviewState();
    if (!mounted) return;
    _avatarPreviewStateNotifier.value = nextState;
  }

  Future<void> _refreshBackgroundPreviewState() async {
    final nextState = await _readBackgroundPreviewState();
    if (!mounted) return;
    _backgroundPreviewStateNotifier.value = nextState;
  }

  Future<_SettingsMediaPreviewState> _readAvatarPreviewState() {
    return _readMediaPreviewState(loadPath: ImageUploadService.getAvatarPath);
  }

  Future<_SettingsMediaPreviewState> _readBackgroundPreviewState() {
    return _readMediaPreviewState(
      loadPath: ImageUploadService.getBackgroundPath,
    );
  }

  Future<_SettingsMediaPreviewState> _readMediaPreviewState({
    required Future<String?> Function() loadPath,
  }) async {
    final resolvedState = resolveMediaPreviewState(await loadPath());
    return _SettingsMediaPreviewState(
      mediaPath: resolvedState.mediaPath,
      hasMedia: resolvedState.hasMedia,
      isRemote: resolvedState.isRemote,
    );
  }

  _SettingsViewData _selectSettingsViewData(SettingsProvider settingsProvider) {
    final pushState = settingsProvider.pushRuntimeState;
    return _SettingsViewData(
      invisibleMode: settingsProvider.invisibleMode,
      notificationEnabled: settingsProvider.notificationEnabled,
      vibrationEnabled: settingsProvider.vibrationEnabled,
      pushPermissionGranted: pushState.permissionGranted,
      pushHasDeviceToken: pushState.deviceToken != null,
    );
  }

  _SettingsInvisibleModeItemViewData _selectInvisibleModeItemViewData(
    SettingsProvider settingsProvider,
  ) {
    final hint = _resolveInvisibleSettingHintForValue(
      settingsProvider.invisibleMode,
    );
    return _SettingsInvisibleModeItemViewData(
      invisibleMode: settingsProvider.invisibleMode,
      badgeLabel: hint.badgeLabel,
      description: hint.description,
      isHealthy: hint.isHealthy,
    );
  }

  _SettingsNotificationItemViewData _selectNotificationItemViewData(
    SettingsProvider settingsProvider,
  ) {
    final pushState = settingsProvider.pushRuntimeState;
    final runtimeState = _resolveNotificationRuntimeStateForValues(
      notificationEnabled: settingsProvider.notificationEnabled,
      pushPermissionGranted: pushState.permissionGranted,
      pushHasDeviceToken: pushState.deviceToken != null,
    );
    return _SettingsNotificationItemViewData(
      notificationEnabled: settingsProvider.notificationEnabled,
      badgeLabel: runtimeState.badgeLabel,
      description: runtimeState.description,
      isHealthy: runtimeState.isHealthy,
    );
  }

  _SettingsVibrationItemViewData _selectVibrationItemViewData(
    SettingsProvider settingsProvider,
  ) {
    final hint = _resolveVibrationSettingHintForValue(
      settingsProvider.vibrationEnabled,
    );
    return _SettingsVibrationItemViewData(
      vibrationEnabled: settingsProvider.vibrationEnabled,
      badgeLabel: hint.badgeLabel,
      description: hint.description,
      isHealthy: hint.isHealthy,
    );
  }

  _SettingsBlockedUsersSheetViewData _selectBlockedUsersSheetViewData(
    FriendProvider friendProvider,
    ChatProvider chatProvider,
  ) {
    final blockedIds = friendProvider.blockedUserIds.toList()..sort();
    return _SettingsBlockedUsersSheetViewData(
      rows: blockedIds.map((userId) {
        final friend = friendProvider.getFriend(userId);
        final thread = chatProvider.getThread(userId);
        return _SettingsBlockedUserRowViewData(
          userId: userId,
          displayName:
              friend?.displayName ?? thread?.otherUser.nickname ?? userId,
          avatar: friend?.user.avatar ?? thread?.otherUser.avatar ?? '🙂',
        );
      }).toList(growable: false),
    );
  }

  _SettingsOverviewFocusViewData _selectOverviewFocusViewData(
    AuthProvider authProvider,
    SettingsProvider settingsProvider,
  ) {
    final pushState = settingsProvider.pushRuntimeState;
    return _SettingsOverviewFocusViewData(
      hasPhone: (authProvider.phone ?? '').trim().isNotEmpty,
      invisibleMode: settingsProvider.invisibleMode,
      notificationEnabled: settingsProvider.notificationEnabled,
      pushPermissionGranted: pushState.permissionGranted,
      pushHasDeviceToken: pushState.deviceToken != null,
    );
  }

  _SettingsExperiencePresetViewData _selectExperiencePresetViewData(
    SettingsProvider settingsProvider,
  ) {
    return _SettingsExperiencePresetViewData(
      invisibleMode: settingsProvider.invisibleMode,
      notificationEnabled: settingsProvider.notificationEnabled,
      vibrationEnabled: settingsProvider.vibrationEnabled,
    );
  }

  _SettingsOverviewNotificationRuntimeViewData
      _selectOverviewNotificationRuntimeViewData(
    SettingsProvider settingsProvider,
  ) {
    final pushState = settingsProvider.pushRuntimeState;
    return _SettingsOverviewNotificationRuntimeViewData(
      notificationEnabled: settingsProvider.notificationEnabled,
      pushPermissionGranted: pushState.permissionGranted,
      pushHasDeviceToken: pushState.deviceToken != null,
    );
  }

  _SettingsNotificationRuntimeState _selectNotificationRuntimeState(
    SettingsProvider settingsProvider,
  ) {
    return _resolveNotificationRuntimeState(
      _selectSettingsViewData(settingsProvider),
    );
  }

  _SettingsDeviceStatusItem _selectNotificationStatusItem(
    SettingsProvider settingsProvider,
  ) {
    final runtimeState = _selectNotificationRuntimeState(settingsProvider);
    return _SettingsDeviceStatusItem(
      key: const Key('settings-device-status-notification'),
      icon: runtimeState.icon,
      title: '消息通知',
      badgeLabel: runtimeState.badgeLabel,
      description: runtimeState.description,
      isHealthy: runtimeState.isHealthy,
    );
  }

  _SettingsDeviceStatusItem _selectPresenceStatusItem(
    SettingsProvider settingsProvider,
  ) {
    final invisibleMode = settingsProvider.invisibleMode;
    final invisibleSettingHint =
        _resolveInvisibleSettingHintForValue(invisibleMode);
    return _SettingsDeviceStatusItem(
      key: const Key('settings-device-status-presence'),
      icon: invisibleMode
          ? Icons.visibility_off_outlined
          : Icons.visibility_outlined,
      title: '展示状态',
      badgeLabel: invisibleSettingHint.badgeLabel,
      description: invisibleSettingHint.description,
      isHealthy: invisibleSettingHint.isHealthy,
    );
  }

  _SettingsDeviceStatusItem _selectVibrationStatusItem(
    SettingsProvider settingsProvider,
  ) {
    final vibrationEnabled = settingsProvider.vibrationEnabled;
    final vibrationSettingHint =
        _resolveVibrationSettingHintForValue(vibrationEnabled);
    return _SettingsDeviceStatusItem(
      key: const Key('settings-device-status-vibration'),
      icon: vibrationEnabled
          ? Icons.vibration_outlined
          : Icons.do_not_disturb_on_outlined,
      title: '震动提醒',
      badgeLabel: vibrationSettingHint.badgeLabel,
      description: vibrationSettingHint.description,
      isHealthy: vibrationSettingHint.isHealthy,
    );
  }

  _SettingsAccountSecurityViewData _selectAccountSecurityViewData(
    AuthProvider authProvider,
  ) {
    return _SettingsAccountSecurityViewData(
      phone: authProvider.phone,
      uid: authProvider.uid,
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = _SettingsLayoutSpec.fromSize(
      MediaQuery.of(context).size,
    );
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
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              layout.pageHorizontalPadding,
              layout.topPadding,
              layout.pageHorizontalPadding,
              layout.bottomPadding,
            ),
            children: [
              _buildSettingsOverviewCard(context),
              SizedBox(height: layout.sectionSpacing),
              _buildSectionTitle('账号与安全'),
              Selector<AuthProvider, _SettingsAccountSecurityViewData>(
                selector: (context, authProvider) =>
                    _selectAccountSecurityViewData(authProvider),
                builder: (context, viewData, child) {
                  return _buildSectionCard(
                    children: [
                      _buildSettingItem(
                        context,
                        key: const Key('settings-phone-item'),
                        icon: Icons.phone_outlined,
                        title: '手机号',
                        subtitle: '登录与找回',
                        trailing: Text(
                          viewData.phone ?? '未绑定',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        onTap: () => _presentPhoneEditorSheet(context),
                      ),
                      _buildDivider(),
                      _buildSettingItem(
                        context,
                        icon: Icons.badge_outlined,
                        title: '账号 UID',
                        subtitle: '用于加好友和确认账号',
                        trailing: Text(
                          viewData.uid ?? '生成中',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textTertiary,
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
                        subtitle: '更新登录密码',
                        onTap: () => _presentPasswordEditorSheet(context),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: layout.sectionSpacing),
              _buildSectionTitle('隐私与展示'),
              Selector<SettingsProvider, _SettingsInvisibleModeItemViewData>(
                selector: (context, settingsProvider) =>
                    _selectInvisibleModeItemViewData(settingsProvider),
                builder: (context, viewData, child) {
                  return _buildSectionCard(
                    children: [
                      _buildSettingItem(
                        context,
                        key: const Key('settings-invisible-mode-item'),
                        icon: Icons.visibility_off_outlined,
                        title: '隐身模式',
                        subtitle: '开启后，活跃状态和匹配曝光会更低调',
                        helperText: viewData.description,
                        badgeLabel: viewData.badgeLabel,
                        badgeKey: const Key('settings-invisible-mode-badge'),
                        badgeHighlight: !viewData.isHealthy,
                        trailing: Switch(
                          value: viewData.invisibleMode,
                          onChanged: _updateInvisibleMode,
                          activeColor: AppColors.brandBlue,
                        ),
                        onTap: null,
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: layout.sectionSpacing),
              _buildSectionTitle('通知与提醒'),
              Selector<SettingsProvider, _SettingsNotificationItemViewData>(
                selector: (context, settingsProvider) =>
                    _selectNotificationItemViewData(settingsProvider),
                builder: (context, viewData, child) {
                  return _buildSectionCard(
                    children: [
                      _buildSettingItem(
                        context,
                        key: const Key('settings-notification-item'),
                        icon: Icons.notifications_outlined,
                        title: '消息通知',
                        subtitle: '关闭后，不再收到新消息提醒',
                        helperText: viewData.description,
                        badgeLabel: viewData.badgeLabel,
                        badgeKey: const Key('settings-notification-badge'),
                        badgeHighlight: !viewData.isHealthy,
                        trailing: Switch(
                          value: viewData.notificationEnabled,
                          onChanged: _updateNotificationEnabled,
                          activeColor: AppColors.brandBlue,
                        ),
                        onTap: null,
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: layout.sectionSpacing),
              _buildSectionTitle('资料与展示'),
              _buildSectionCard(
                children: [
                  _buildAvatarManagementItem(context),
                ],
              ),
              SizedBox(height: layout.sectionSpacing),
              _buildSectionTitle('更多设置'),
              Selector<SettingsProvider, _SettingsVibrationItemViewData>(
                selector: (context, settingsProvider) =>
                    _selectVibrationItemViewData(settingsProvider),
                builder: (context, viewData, child) {
                  return _buildSectionCard(
                    children: [
                      _buildSettingItem(
                        context,
                        key: const Key('settings-blocked-users-item'),
                        icon: Icons.block_outlined,
                        title: '黑名单',
                        subtitle: '管理不想再接触的人',
                        onTap: () => _showBlockedUsers(context),
                      ),
                      _buildDivider(),
                      _buildSettingItem(
                        context,
                        key: const Key('settings-vibration-item'),
                        icon: Icons.vibration_outlined,
                        title: '震动提醒',
                        subtitle: '收到消息时用震动提醒',
                        helperText: viewData.description,
                        badgeLabel: viewData.badgeLabel,
                        badgeKey: const Key('settings-vibration-badge'),
                        badgeHighlight: !viewData.isHealthy,
                        trailing: Switch(
                          value: viewData.vibrationEnabled,
                          onChanged: _updateVibrationEnabled,
                          activeColor: AppColors.brandBlue,
                        ),
                        onTap: null,
                      ),
                      _buildDivider(),
                      _buildBackgroundManagementItem(context),
                    ],
                  );
                },
              ),
              SizedBox(height: layout.sectionSpacing),
              _buildSectionTitle('设备模式'),
              Selector<SettingsProvider, _SettingsExperiencePresetViewData>(
                selector: (context, settingsProvider) =>
                    _selectExperiencePresetViewData(settingsProvider),
                builder: (context, viewData, child) {
                  return _buildExperiencePresetCard(context, viewData);
                },
              ),
              SizedBox(height: layout.sectionSpacing),
              _buildSectionTitle('安全与举报'),
              _buildSectionCard(
                children: [
                  _buildSettingItem(
                    context,
                    icon: Icons.flag_outlined,
                    title: '举报违规用户',
                    subtitle: '在聊天页右上角处理',
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
                    subtitle: '查看风险提醒',
                    onTap: () => context.push('/legal/safety-tips'),
                  ),
                ],
              ),
              SizedBox(height: layout.sectionSpacing),
              _buildSectionTitle('关于与协议'),
              _buildSectionCard(
                children: [
                  _buildSettingItem(
                    context,
                    key: const Key('settings-about-item'),
                    icon: Icons.info_outlined,
                    title: '关于瞬聊',
                    subtitle: '版本信息',
                    onTap: () => context.push('/about'),
                  ),
                  _buildDivider(),
                  _buildSettingItem(
                    context,
                    key: const Key('settings-privacy-policy-item'),
                    icon: Icons.privacy_tip_outlined,
                    title: '隐私政策',
                    subtitle: '数据与隐私',
                    onTap: () => context.push('/legal/privacy-policy'),
                  ),
                  _buildDivider(),
                  _buildSettingItem(
                    context,
                    key: const Key('settings-user-agreement-item'),
                    icon: Icons.description_outlined,
                    title: '用户协议',
                    subtitle: '规则与条款',
                    onTap: () => context.push('/legal/user-agreement'),
                  ),
                ],
              ),
              SizedBox(height: layout.sectionSpacing + 4),
              _buildSectionTitle('账号操作'),
              Container(
                key: const Key('settings-account-actions-card'),
                child: Column(
                  children: [
                    _buildAccountActionCard(
                      cardKey: const Key('settings-logout-card'),
                      actionKey: const Key('settings-logout-button'),
                      icon: Icons.logout_rounded,
                      title: '退出登录',
                      badgeLabel: '仅当前设备',
                      description: '只退出当前设备，资料仍保留。',
                      onTap: () => _showLogoutDialog(context),
                    ),
                    SizedBox(height: layout.isCompact ? 10 : 12),
                    _buildAccountActionCard(
                      cardKey: const Key('settings-delete-account-card'),
                      actionKey: const Key('settings-delete-account-button'),
                      icon: Icons.delete_forever_outlined,
                      title: '注销账号',
                      badgeLabel: '不可恢复',
                      description: '清除账号和会话数据，且不可恢复。',
                      onTap: () => _showDeleteAccountDialog(context),
                      isDanger: true,
                    ),
                  ],
                ),
              ),
              SizedBox(height: layout.isCompact ? 12 : 14),
              Center(
                child: Text(
                  'V1.0.4',
                  key: const Key('settings-version-label'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textDisabled,
                  ),
                ),
              ),
            ],
          ),
          ValueListenableBuilder<_SettingsInlineFeedbackState?>(
            valueListenable: _inlineFeedbackNotifier,
            builder: (context, inlineFeedback, child) {
              return Positioned(
                top: 8,
                left: layout.pageHorizontalPadding,
                right: layout.pageHorizontalPadding,
                child: IgnorePointer(
                  ignoring: true,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    reverseDuration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final offsetAnimation = Tween<Offset>(
                        begin: const Offset(0, -0.06),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                          reverseCurve: Curves.easeInCubic,
                        ),
                      );
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: offsetAnimation,
                          child: child,
                        ),
                      );
                    },
                    child: inlineFeedback == null
                        ? const SizedBox.shrink()
                        : KeyedSubtree(
                            key: ValueKey<String>(
                              '${inlineFeedback.title}-${inlineFeedback.badgeLabel}-${inlineFeedback.description}-${inlineFeedback.isHealthy}',
                            ),
                            child: _buildInlineFeedbackCard(inlineFeedback),
                          ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarManagementItem(BuildContext context) {
    return ValueListenableBuilder<_SettingsMediaPreviewState>(
      valueListenable: _avatarPreviewStateNotifier,
      builder: (context, avatarPreviewState, child) {
        final effectiveAvatarPreviewState =
            _normalizePreviewStateSync(avatarPreviewState);
        final summary =
            _resolveAvatarManagementSummary(effectiveAvatarPreviewState);
        return _buildSettingItem(
          context,
          key: const Key('settings-avatar-management-item'),
          icon: Icons.photo_outlined,
          title: '头像管理',
          subtitle: summary.itemSubtitle,
          badgeLabel: summary.itemBadgeLabel,
          badgeKey: const Key('settings-avatar-management-badge'),
          trailing: _buildAvatarManagementTrailing(
            context,
            effectiveAvatarPreviewState,
          ),
          onTap: () => _presentAvatarManagementSheet(context),
        );
      },
    );
  }

  Widget _buildBackgroundManagementItem(BuildContext context) {
    return ValueListenableBuilder<_SettingsMediaPreviewState>(
      valueListenable: _backgroundPreviewStateNotifier,
      builder: (context, backgroundPreviewState, child) {
        final effectiveBackgroundPreviewState =
            _normalizePreviewStateSync(backgroundPreviewState);
        final summary = _resolveBackgroundManagementSummary(
            effectiveBackgroundPreviewState);
        return _buildSettingItem(
          context,
          key: const Key('settings-background-management-item'),
          icon: Icons.wallpaper_outlined,
          title: '背景管理',
          subtitle: summary.itemSubtitle,
          badgeLabel: summary.itemBadgeLabel,
          badgeKey: const Key('settings-background-management-badge'),
          trailing: _buildBackgroundManagementTrailing(
            context,
            effectiveBackgroundPreviewState,
          ),
          onTap: () => _presentBackgroundManagementSheet(context),
        );
      },
    );
  }

  Widget _buildAvatarManagementTrailing(
    BuildContext context,
    _SettingsMediaPreviewState avatarPreviewState,
  ) {
    final layout = _SettingsLayoutSpec.fromSize(
      MediaQuery.of(context).size,
    );
    return Padding(
      padding: EdgeInsets.only(top: layout.isCompact ? 2 : 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SettingsMediaPreviewSurface(
            key: const Key('settings-avatar-management-preview'),
            mediaPath: avatarPreviewState.mediaPath,
            width: layout.isCompact ? 30 : 34,
            height: layout.isCompact ? 30 : 34,
            iconSize: layout.isCompact ? 16 : 18,
            fallbackIcon: Icons.person_rounded,
            isCircular: true,
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

  Widget _buildBackgroundManagementTrailing(
    BuildContext context,
    _SettingsMediaPreviewState backgroundPreviewState,
  ) {
    final layout = _SettingsLayoutSpec.fromSize(
      MediaQuery.of(context).size,
    );
    return Padding(
      padding: EdgeInsets.only(top: layout.isCompact ? 2 : 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SettingsMediaPreviewSurface(
            key: const Key('settings-background-management-preview'),
            mediaPath: backgroundPreviewState.mediaPath,
            width: layout.isCompact ? 34 : 40,
            height: layout.isCompact ? 24 : 28,
            iconSize: layout.isCompact ? 15 : 16,
            fallbackIcon: Icons.wallpaper_rounded,
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
    final avatarPreviewState =
        _normalizePreviewStateSync(await _readAvatarPreviewState());
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
                        description: '当前资料已恢复默认头像。',
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
    final backgroundPreviewState =
        _normalizePreviewStateSync(await _readBackgroundPreviewState());
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
                        description: '当前主页已恢复默认背景。',
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
    return SettingsMediaManagementPreviewCard(
      key: const Key('settings-avatar-sheet-preview'),
      leadingGap: 9,
      leading: SettingsMediaPreviewSurface(
        key: const Key('settings-avatar-sheet-avatar'),
        mediaPath: avatarPreviewState.mediaPath,
        width: 42,
        height: 42,
        iconSize: 18,
        fallbackIcon: Icons.person_rounded,
        isCircular: true,
      ),
      statusLabel: summary.previewStatusLabel,
      statusKey: const Key('settings-avatar-sheet-status'),
      badgeLabel: summary.previewBadgeLabel,
      badgeKey: const Key('settings-avatar-sheet-badge'),
      hasMedia: avatarPreviewState.hasMedia,
    );
  }

  Widget _buildBackgroundManagementPreviewCard(
    _SettingsMediaPreviewState backgroundPreviewState,
    _SettingsMediaManagementSummary summary,
  ) {
    return SettingsMediaManagementPreviewCard(
      key: const Key('settings-background-sheet-preview'),
      leading: SettingsMediaPreviewSurface(
        key: const Key('settings-background-sheet-thumbnail'),
        mediaPath: backgroundPreviewState.mediaPath,
        width: 54,
        height: 36,
        iconSize: 16,
        fallbackIcon: Icons.wallpaper_rounded,
      ),
      statusLabel: summary.previewStatusLabel,
      statusKey: const Key('settings-background-sheet-status'),
      badgeLabel: summary.previewBadgeLabel,
      badgeKey: const Key('settings-background-sheet-badge'),
      hasMedia: backgroundPreviewState.hasMedia,
    );
  }

  _SettingsMediaPreviewState _normalizePreviewStateSync(
    _SettingsMediaPreviewState previewState,
  ) {
    final resolvedState = resolveMediaPreviewState(previewState.mediaPath);
    return _SettingsMediaPreviewState(
      mediaPath: resolvedState.mediaPath,
      hasMedia: resolvedState.hasMedia,
      isRemote: resolvedState.isRemote,
    );
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
      final uploadResult = await _mediaUploadService.uploadUserMediaWithStatus(
        'avatar',
        imageFile,
      );
      await ImageUploadService.saveAvatarReference(
        uploadResult.mediaRef,
        cleanupLocalPath: imageFile.path,
      );
      await _refreshAvatarPreviewState();
      if (!mounted) {
        return;
      }
      _showInlineFeedback(
        _buildMediaUpdatedFeedback(
          icon: Icons.photo_camera_outlined,
          result: uploadResult,
          successTitle: '头像已经更新',
          successBadgeLabel: '资料已刷新',
          successDescription: '新头像已保存，消息列表和个人页会优先显示最新资料。',
          localTitle: '头像已保存在本机',
          localDescription: '当前页和“我的”页会先显示这张头像，联网后会继续同步到服务器。',
          deferredTitle: '头像已更新，远端同步未完成',
          deferredDescription: '当前设备已经显示新头像，网络恢复后会继续同步到服务器。',
        ),
      );
      _showMediaUploadToast(subject: '头像', result: uploadResult);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showInlineFeedback(
        const _SettingsInlineFeedbackState(
          icon: Icons.photo_camera_outlined,
          title: '头像更新失败',
          badgeLabel: '未保存',
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

  Future<void> _replaceBackground(BuildContext sheetContext) async {
    Navigator.pop(sheetContext);
    final imageFile = await ImageUploadService.pickBackground(context);
    if (imageFile == null || !mounted) {
      return;
    }

    try {
      final uploadResult = await _mediaUploadService.uploadUserMediaWithStatus(
        'background',
        imageFile,
      );
      await ImageUploadService.saveBackgroundReference(
        uploadResult.mediaRef,
        cleanupLocalPath: imageFile.path,
      );
      await _refreshBackgroundPreviewState();
      if (!mounted) {
        return;
      }
      _showInlineFeedback(
        _buildMediaUpdatedFeedback(
          icon: Icons.wallpaper_outlined,
          result: uploadResult,
          successTitle: '背景已经更新',
          successBadgeLabel: '氛围已刷新',
          successDescription: '新背景已保存，别人进入主页时会优先看到最新封面。',
          localTitle: '背景已保存在本机',
          localDescription: '当前主页会先显示这张背景，联网后会继续同步到服务器。',
          deferredTitle: '背景已更新，远端同步未完成',
          deferredDescription: '当前设备已经显示新背景，网络恢复后会继续同步到服务器。',
        ),
      );
      _showMediaUploadToast(subject: '背景', result: uploadResult);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showInlineFeedback(
        const _SettingsInlineFeedbackState(
          icon: Icons.wallpaper_outlined,
          title: '背景更新失败',
          badgeLabel: '未保存',
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

  _SettingsInlineFeedbackState _buildMediaUpdatedFeedback({
    required IconData icon,
    required UserMediaUploadResult result,
    required String successTitle,
    required String successBadgeLabel,
    required String successDescription,
    required String localTitle,
    required String localDescription,
    required String deferredTitle,
    required String deferredDescription,
  }) {
    if (result.remoteSucceeded) {
      return _SettingsInlineFeedbackState(
        icon: icon,
        title: successTitle,
        badgeLabel: successBadgeLabel,
        description: successDescription,
        isHealthy: true,
      );
    }

    if (result.localOnly) {
      return _SettingsInlineFeedbackState(
        icon: icon,
        title: localTitle,
        badgeLabel: '本机已更新',
        description: localDescription,
        isHealthy: true,
      );
    }

    return _SettingsInlineFeedbackState(
      icon: icon,
      title: deferredTitle,
      badgeLabel: '待联网同步',
      description: deferredDescription,
      isHealthy: false,
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

  _SettingsMediaManagementSummary _resolveAvatarManagementSummary(
    _SettingsMediaPreviewState previewState,
  ) {
    if (previewState.hasMedia) {
      if (!previewState.isRemote) {
        return const _SettingsMediaManagementSummary(
          itemSubtitle: '当前设备会先显示这张头像。',
          itemBadgeLabel: '本机预览中',
          previewStatusLabel: '头像已保存在本机',
          previewBadgeLabel: '待联网同步',
          replaceActionLabel: '更换头像',
        );
      }

      return const _SettingsMediaManagementSummary(
        itemSubtitle: '会同步显示到主页和消息列表。',
        itemBadgeLabel: '已同步',
        previewStatusLabel: '头像已同步',
        previewBadgeLabel: '展示中',
        replaceActionLabel: '更换头像',
      );
    }

    return const _SettingsMediaManagementSummary(
      itemSubtitle: '当前是默认头像。',
      itemBadgeLabel: '待补充',
      previewStatusLabel: '正在使用默认头像',
      previewBadgeLabel: '待补充',
      replaceActionLabel: '上传头像',
    );
  }

  _SettingsMediaManagementSummary _resolveBackgroundManagementSummary(
    _SettingsMediaPreviewState previewState,
  ) {
    if (previewState.hasMedia) {
      if (!previewState.isRemote) {
        return const _SettingsMediaManagementSummary(
          itemSubtitle: '当前主页会先显示这张背景。',
          itemBadgeLabel: '本机预览中',
          previewStatusLabel: '背景已保存在本机',
          previewBadgeLabel: '待联网同步',
          replaceActionLabel: '更换背景',
        );
      }

      return const _SettingsMediaManagementSummary(
        itemSubtitle: '会显示在主页首屏。',
        itemBadgeLabel: '首屏已生效',
        previewStatusLabel: '背景已生效',
        previewBadgeLabel: '首屏展示中',
        replaceActionLabel: '更换背景',
      );
    }

    return const _SettingsMediaManagementSummary(
      itemSubtitle: '当前是默认背景。',
      itemBadgeLabel: '待补充',
      previewStatusLabel: '正在使用默认背景',
      previewBadgeLabel: '待补充',
      replaceActionLabel: '上传背景',
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

  Widget _buildSettingsOverviewCard(BuildContext context) {
    final layout = _SettingsLayoutSpec.fromSize(
      MediaQuery.of(context).size,
    );

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
            '当前设备',
            style: TextStyle(
              fontSize: layout.isCompact ? 17 : 18,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: layout.overviewGap),
          Selector2<AuthProvider, SettingsProvider,
              _SettingsOverviewFocusViewData>(
            selector: (context, authProvider, settingsProvider) =>
                _selectOverviewFocusViewData(authProvider, settingsProvider),
            builder: (context, viewData, child) {
              return _buildOverviewFocusCard(
                _resolveOverviewFocusState(viewData: viewData),
              );
            },
          ),
          SizedBox(height: layout.overviewGap),
          _buildDeviceStatusCard(context),
          SizedBox(height: layout.isCompact ? 10 : 12),
          if (layout.isCompact)
            Column(
              children: [
                Selector<AuthProvider, _SettingsAccountSecurityViewData>(
                  selector: (context, authProvider) =>
                      _selectAccountSecurityViewData(authProvider),
                  builder: (context, viewData, child) {
                    return SizedBox(
                      width: double.infinity,
                      child: _buildOverviewAction(
                        key: const Key('settings-overview-phone-action'),
                        icon: Icons.phone_outlined,
                        label: viewData.hasPhone ? '更新手机号' : '补手机号',
                        onTap: () => _presentPhoneEditorSheet(context),
                      ),
                    );
                  },
                ),
                SizedBox(height: layout.isTight ? 6 : 8),
                SizedBox(
                  width: double.infinity,
                  child: _buildOverviewAction(
                    key: const Key('settings-overview-uid-action'),
                    icon: Icons.badge_outlined,
                    label: '复制 UID',
                    onTap: () => _copyUid(context),
                  ),
                ),
                SizedBox(height: layout.isTight ? 6 : 8),
                Selector<SettingsProvider,
                    _SettingsOverviewNotificationRuntimeViewData>(
                  selector: (context, settingsProvider) =>
                      _selectOverviewNotificationRuntimeViewData(
                    settingsProvider,
                  ),
                  builder: (context, viewData, child) {
                    final runtimeState =
                        _resolveNotificationRuntimeStateForValues(
                      notificationEnabled: viewData.notificationEnabled,
                      pushPermissionGranted: viewData.pushPermissionGranted,
                      pushHasDeviceToken: viewData.pushHasDeviceToken,
                    );
                    return SizedBox(
                      width: double.infinity,
                      child: _buildOverviewAction(
                        key: const Key(
                          'settings-overview-notification-action',
                        ),
                        icon: runtimeState.actionIcon,
                        label: runtimeState.actionLabel,
                        onTap: () => _handleNotificationAction(
                          runtimeState.actionType,
                        ),
                      ),
                    );
                  },
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child:
                      Selector<AuthProvider, _SettingsAccountSecurityViewData>(
                    selector: (context, authProvider) =>
                        _selectAccountSecurityViewData(authProvider),
                    builder: (context, viewData, child) {
                      return _buildOverviewAction(
                        key: const Key('settings-overview-phone-action'),
                        icon: Icons.phone_outlined,
                        label: viewData.hasPhone ? '更新手机号' : '补手机号',
                        onTap: () => _presentPhoneEditorSheet(context),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildOverviewAction(
                    key: const Key('settings-overview-uid-action'),
                    icon: Icons.badge_outlined,
                    label: '复制 UID',
                    onTap: () => _copyUid(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Selector<SettingsProvider,
                      _SettingsOverviewNotificationRuntimeViewData>(
                    selector: (context, settingsProvider) =>
                        _selectOverviewNotificationRuntimeViewData(
                      settingsProvider,
                    ),
                    builder: (context, viewData, child) {
                      final runtimeState =
                          _resolveNotificationRuntimeStateForValues(
                        notificationEnabled: viewData.notificationEnabled,
                        pushPermissionGranted: viewData.pushPermissionGranted,
                        pushHasDeviceToken: viewData.pushHasDeviceToken,
                      );
                      return _buildOverviewAction(
                        key: const Key(
                          'settings-overview-notification-action',
                        ),
                        icon: runtimeState.actionIcon,
                        label: runtimeState.actionLabel,
                        onTap: () => _handleNotificationAction(
                          runtimeState.actionType,
                        ),
                      );
                    },
                  ),
                ),
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

  Widget _buildDeviceStatusCard(BuildContext context) {
    final layout = _SettingsLayoutSpec.fromSize(
      MediaQuery.of(context).size,
    );

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
            '设备状态',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: layout.isCompact ? 10 : 12),
          if (layout.isCompact)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Selector<SettingsProvider, _SettingsDeviceStatusItem>(
                  selector: (context, settingsProvider) =>
                      _selectNotificationStatusItem(settingsProvider),
                  builder: (context, item, child) {
                    return _buildCompactDeviceStatusChip(item);
                  },
                ),
                Selector<SettingsProvider, _SettingsDeviceStatusItem>(
                  selector: (context, settingsProvider) =>
                      _selectPresenceStatusItem(settingsProvider),
                  builder: (context, item, child) {
                    return _buildCompactDeviceStatusChip(item);
                  },
                ),
                Selector<SettingsProvider, _SettingsDeviceStatusItem>(
                  selector: (context, settingsProvider) =>
                      _selectVibrationStatusItem(settingsProvider),
                  builder: (context, item, child) {
                    return _buildCompactDeviceStatusChip(item);
                  },
                ),
              ],
            )
          else
            Column(
              children: [
                Selector<SettingsProvider, _SettingsDeviceStatusItem>(
                  selector: (context, settingsProvider) =>
                      _selectNotificationStatusItem(settingsProvider),
                  builder: (context, item, child) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildDeviceStatusRow(item),
                    );
                  },
                ),
                Selector<SettingsProvider, _SettingsDeviceStatusItem>(
                  selector: (context, settingsProvider) =>
                      _selectPresenceStatusItem(settingsProvider),
                  builder: (context, item, child) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildDeviceStatusRow(item),
                    );
                  },
                ),
                Selector<SettingsProvider, _SettingsDeviceStatusItem>(
                  selector: (context, settingsProvider) =>
                      _selectVibrationStatusItem(settingsProvider),
                  builder: (context, item, child) {
                    return _buildDeviceStatusRow(item);
                  },
                ),
              ],
            ),
          Selector<SettingsProvider, _SettingsNotificationRuntimeState>(
            selector: (context, settingsProvider) =>
                _selectNotificationRuntimeState(settingsProvider),
            builder: (context, notificationRuntimeState, child) {
              if (notificationRuntimeState.followUpDescription == null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: EdgeInsets.only(top: layout.isCompact ? 10 : 12),
                child: _buildNotificationRuntimeCard(
                  context,
                  notificationRuntimeState,
                ),
              );
            },
          ),
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
    _SettingsExperiencePresetViewData viewData,
  ) {
    final layout = _SettingsLayoutSpec.fromSize(
      MediaQuery.of(context).size,
    );
    final currentPresetState = _resolveExperiencePresetState(
      viewData.activeExperiencePreset,
    );
    final activePreset = viewData.activeExperiencePreset;
    final presetOptions = _experiencePresetOptions;

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
              '设备模式',
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
          if (!layout.isCompact) ...[
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
          ],
          SizedBox(height: layout.isCompact ? 8 : 12),
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
      onTap: isActive ? null : () => _applyExperiencePreset(option.preset),
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

  _SettingsToggleHint _resolveInvisibleSettingHintForValue(bool invisibleMode) {
    return _buildToggleHintFromInlineFeedback(
      _buildInvisibleModeFeedback(invisibleMode),
    );
  }

  _SettingsExperiencePresetState _resolveExperiencePresetState(
    SettingsExperiencePreset? activePreset,
  ) {
    switch (activePreset) {
      case SettingsExperiencePreset.responsive:
        return const _SettingsExperiencePresetState(
          badgeLabel: '主入口',
          description: '通知、震动和展示都已打开。',
          isHealthy: true,
        );
      case SettingsExperiencePreset.balanced:
        return const _SettingsExperiencePresetState(
          badgeLabel: '提醒更克制',
          description: '通知保持在线，震动已收起。',
          isHealthy: true,
        );
      case SettingsExperiencePreset.quietObserve:
        return const _SettingsExperiencePresetState(
          badgeLabel: '展示已收起',
          description: '通知和震动已收起，并切到隐身。',
        );
      case null:
        return const _SettingsExperiencePresetState(
          badgeLabel: '手动调整中',
          description: '当前为手动组合设置。',
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
          description: '通知、震动和展示都打开。',
        ),
        _SettingsExperiencePresetOption(
          key: Key('settings-preset-balanced'),
          preset: SettingsExperiencePreset.balanced,
          icon: Icons.tune_outlined,
          title: '低干扰',
          badgeLabel: '提醒更克制',
          description: '消息保持在线，提醒更克制。',
        ),
        _SettingsExperiencePresetOption(
          key: Key('settings-preset-quiet-observe'),
          preset: SettingsExperiencePreset.quietObserve,
          icon: Icons.nightlight_round_outlined,
          title: '安静观察',
          badgeLabel: '展示已收起',
          description: '关闭通知和震动，并切到隐身。',
        ),
      ];

  _SettingsToggleHint _resolveVibrationSettingHintForValue(
    bool vibrationEnabled,
  ) {
    return _buildToggleHintFromInlineFeedback(
      _buildVibrationFeedback(vibrationEnabled),
    );
  }

  _SettingsOverviewFocusState _resolveOverviewFocusState({
    required _SettingsOverviewFocusViewData viewData,
  }) {
    if (!viewData.hasPhone) {
      return const _SettingsOverviewFocusState(
        icon: Icons.phone_outlined,
        title: '手机号还没补全',
        subtitle: '补全后可用于登录和找回。',
        badgeLabel: '待补全',
      );
    }

    if (viewData.notificationEnabled && !viewData.pushPermissionGranted) {
      return const _SettingsOverviewFocusState(
        icon: Icons.notifications_paused_outlined,
        title: NotificationPermissionGuidance.title,
        subtitle: NotificationPermissionGuidance.settingsDescription,
        badgeLabel: NotificationPermissionGuidance.badgeLabel,
      );
    }

    if (!viewData.notificationEnabled) {
      return const _SettingsOverviewFocusState(
        icon: Icons.notifications_off_outlined,
        title: '消息提醒当前已收起',
        subtitle: '新回复仍会留在通知中心。',
        badgeLabel: '提醒已收起',
      );
    }

    if (!viewData.pushHasDeviceToken) {
      return const _SettingsOverviewFocusState(
        icon: Icons.sync_outlined,
        title: '通知同步中',
        subtitle: '提醒会在通道恢复后回来。',
        badgeLabel: '通道同步中',
      );
    }

    if (viewData.invisibleMode) {
      return const _SettingsOverviewFocusState(
        icon: Icons.visibility_off_outlined,
        title: '展示当前已切到隐身',
        subtitle: '需要时可恢复展示状态。',
        badgeLabel: '展示已收起',
      );
    }

    return const _SettingsOverviewFocusState(
      icon: Icons.verified_outlined,
      title: '当前高频状态已经就绪',
      subtitle: '账号、通知和展示都已就绪。',
      badgeLabel: '状态已就绪',
      isHealthy: true,
    );
  }

  _SettingsNotificationRuntimeState _resolveNotificationRuntimeStateForValues({
    required bool notificationEnabled,
    required bool pushPermissionGranted,
    required bool pushHasDeviceToken,
  }) {
    return _resolveNotificationRuntimeState(
      _SettingsViewData(
        invisibleMode: false,
        notificationEnabled: notificationEnabled,
        vibrationEnabled: false,
        pushPermissionGranted: pushPermissionGranted,
        pushHasDeviceToken: pushHasDeviceToken,
      ),
    );
  }

  _SettingsNotificationRuntimeState _resolveNotificationRuntimeState(
    _SettingsViewData viewData,
  ) {
    if (!viewData.notificationEnabled) {
      return const _SettingsNotificationRuntimeState(
        icon: Icons.notifications_off_outlined,
        badgeLabel: '提醒已收起',
        description: '新消息仍会保存在通知中心。',
        followUpDescription: '主设备可恢复通知。',
        statusChipLabel: '提醒已收起',
        actionLabel: '恢复通知',
        actionIcon: Icons.notifications_active_outlined,
        actionType: _SettingsNotificationAction.enableNotifications,
      );
    }

    if (!viewData.pushPermissionGranted) {
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

    if (!viewData.pushHasDeviceToken) {
      return const _SettingsNotificationRuntimeState(
        icon: Icons.sync_outlined,
        badgeLabel: '通道同步中',
        description: '提醒会在通道恢复后回来。',
        followUpDescription: '刚改过权限时可手动刷新。',
        statusChipLabel: '通道同步中',
        actionLabel: '刷新状态',
        actionIcon: Icons.refresh_outlined,
        actionType: _SettingsNotificationAction.refreshRuntimeState,
      );
    }

    return const _SettingsNotificationRuntimeState(
      icon: Icons.notifications_active_outlined,
      badgeLabel: '通道已就绪',
      description: '新消息会正常提醒。',
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
      builder: (sheetContext) => Selector2<FriendProvider, ChatProvider,
          _SettingsBlockedUsersSheetViewData>(
        selector: (context, friendProvider, chatProvider) =>
            _selectBlockedUsersSheetViewData(friendProvider, chatProvider),
        builder: (context, viewData, child) {
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
                      blockedCount: viewData.rows.length,
                    ),
                    const SizedBox(height: 14),
                    _buildBlockedUsersSummaryCard(viewData.rows.length),
                    const SizedBox(height: 14),
                    Expanded(
                      child: viewData.rows.isEmpty
                          ? _buildBlockedUsersEmptyState()
                          : ListView.separated(
                              key: const Key('settings-blocked-users-list'),
                              padding: EdgeInsets.zero,
                              itemCount: viewData.rows.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final row = viewData.rows[index];
                                '🙂';

                                return _buildBlockedUserRow(
                                  context,
                                  friendProvider:
                                      context.read<FriendProvider>(),
                                  userId: row.userId,
                                  displayName: row.displayName,
                                  avatar: row.avatar,
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
                      ? '解除拉黑后，会话和关系会恢复，是否重新联系由你决定。'
                      : '需要收拢关系边界时，可在聊天或好友页继续拉黑。',
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
              '后续如果遇到不想继续接触的人，可以从聊天或好友入口直接拉黑。',
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
                  '不会再出现在匹配、好友请求和主动联系里。',
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
                  description: '会话和关系已恢复。',
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
            title: NotificationPermissionGuidance.title,
            badgeLabel: '待授权',
            description: NotificationPermissionGuidance.settingsDescription,
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
    if (settingsProvider.activeExperiencePreset == preset) {
      return;
    }
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
                description: '未跳转到系统设置，请手动打开通知权限。',
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
              description: '处理完权限后返回应用即可。',
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
    final runtimeState = _resolveNotificationRuntimeState(
      _selectSettingsViewData(settingsProvider),
    );
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
          title: '通知同步中',
          badgeLabel: '通道同步中',
          description: '提醒会在通道就绪后恢复。',
        ),
      _SettingsNotificationAction.disableNotifications =>
        const _SettingsInlineFeedbackState(
          icon: Icons.notifications_active_outlined,
          title: '通知已在线',
          badgeLabel: '通道已就绪',
          description: '新消息会正常提醒。',
          isHealthy: true,
        ),
      _SettingsNotificationAction.enableNotifications =>
        const _SettingsInlineFeedbackState(
          icon: Icons.notifications_off_outlined,
          title: '通知已静默',
          badgeLabel: '提醒已收起',
          description: '新消息仍会保存在通知中心。',
        ),
    };
  }

  _SettingsInlineFeedbackState _buildNotificationResumeInlineFeedback(
    SettingsProvider settingsProvider,
  ) {
    final runtimeState = _resolveNotificationRuntimeState(
      _selectSettingsViewData(settingsProvider),
    );
    return switch (runtimeState.actionType) {
      _SettingsNotificationAction.openSystemSettings =>
        const _SettingsInlineFeedbackState(
          icon: Icons.notifications_paused_outlined,
          title: '通知权限仍待授权',
          badgeLabel: NotificationPermissionGuidance.badgeLabel,
          description: '返回后仍未检测到系统通知权限。',
        ),
      _SettingsNotificationAction.refreshRuntimeState =>
        const _SettingsInlineFeedbackState(
          icon: Icons.sync_outlined,
          title: '通知恢复中',
          badgeLabel: '通道同步中',
          description: '提醒会在通道恢复后回来。',
        ),
      _SettingsNotificationAction.disableNotifications =>
        const _SettingsInlineFeedbackState(
          icon: Icons.notifications_active_outlined,
          title: '通知已在线',
          badgeLabel: '通道已就绪',
          description: '新消息会重新正常提醒。',
          isHealthy: true,
        ),
      _SettingsNotificationAction.enableNotifications =>
        const _SettingsInlineFeedbackState(
          icon: Icons.notifications_off_outlined,
          title: '通知仍静默',
          badgeLabel: '提醒已收起',
          description: '系统权限已恢复，当前仍保持静默。',
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
      title: unreadCount > 0 ? '还有 $unreadCount 条未读提醒' : '保留最近一条提醒',
      badgeLabel: unreadCount > 0 ? '未读 $unreadCount' : '最近提醒',
      description: unreadCount > 0
          ? '最新：${_buildNotificationCenterPreview(latestItem)}'
          : '最近：${_buildNotificationCenterPreview(latestItem)}',
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

  void _showInlineFeedback(
    _SettingsInlineFeedbackState state, {
    Duration duration = const Duration(milliseconds: 2400),
  }) {
    if (!mounted) return;
    _inlineFeedbackTimer?.cancel();
    _inlineFeedbackNotifier.value = state;
    _inlineFeedbackTimer = Timer(duration, () {
      if (!mounted) return;
      _inlineFeedbackNotifier.value = null;
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
            description: '在线可见和匹配曝光会更克制，需要时再切回。',
          )
        : const _SettingsInlineFeedbackState(
            icon: Icons.visibility_outlined,
            title: '展示已经恢复正常',
            badgeLabel: '展示已恢复',
            description: '在线可见和匹配曝光已恢复，适合正常匹配和聊天。',
            isHealthy: true,
          );
  }

  _SettingsInlineFeedbackState _buildVibrationFeedback(bool enabled) {
    return enabled
        ? const _SettingsInlineFeedbackState(
            icon: Icons.vibration_outlined,
            title: '震动提醒已经恢复',
            badgeLabel: '提醒已恢复',
            description: '弱网和锁屏场景下更不容易错过消息。',
            isHealthy: true,
          )
        : const _SettingsInlineFeedbackState(
            icon: Icons.do_not_disturb_on_outlined,
            title: '震动提醒已经收起',
            badgeLabel: '提醒已收起',
            description: '震动已关闭，适合会议或通勤场景。',
          );
  }

  _SettingsInlineFeedbackState _buildExperiencePresetFeedback(
    SettingsExperiencePreset preset,
  ) {
    return switch (preset) {
      SettingsExperiencePreset.responsive => const _SettingsInlineFeedbackState(
          icon: Icons.flash_on_outlined,
          title: '已切到在线回复',
          badgeLabel: '主入口',
          description: '通知、震动和展示都已打开，适合作为主聊天入口。',
          isHealthy: true,
        ),
      SettingsExperiencePreset.balanced => const _SettingsInlineFeedbackState(
          icon: Icons.tune_outlined,
          title: '已切到低干扰',
          badgeLabel: '提醒更克制',
          description: '会继续在线收消息，但提醒更克制。',
          isHealthy: true,
        ),
      SettingsExperiencePreset.quietObserve =>
        const _SettingsInlineFeedbackState(
          icon: Icons.nightlight_round_outlined,
          title: '已切到安静观察',
          badgeLabel: '展示已收起',
          description: '通知和震动已关闭，并切到隐身状态。',
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
          badgeLabel: '生成中',
          description: '账号标识还在准备中，等生成后再复制。',
        ),
      );
      AppFeedback.showError(
        context,
        AppErrorCode.invalidInput,
        detail: 'UID生成中，稍后再试',
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: uid));
    if (!context.mounted) return;
    _showInlineFeedback(
      const _SettingsInlineFeedbackState(
        icon: Icons.badge_outlined,
        title: 'UID 已复制',
        badgeLabel: '可复制',
        description: '现在可以把 UID 发给好友或另一台设备。',
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
        title: '输入新手机号后再保存',
        description: '先输入 11 位手机号。',
      );
    }

    final isValidPhone = RegExp(r'^\d{11}$').hasMatch(normalizedNextPhone);
    if (!isValidPhone) {
      return const _SettingsSheetValidationState(
        icon: Icons.phone_outlined,
        title: '还需要完整的 11 位手机号',
        description: '补齐后再保存。',
      );
    }

    if (currentPhone.isNotEmpty && normalizedNextPhone == currentPhone) {
      return const _SettingsSheetValidationState(
        icon: Icons.info_outline,
        title: '当前号码未发生变化',
        description: '号码未变化，无需保存。',
      );
    }

    return const _SettingsSheetValidationState(
      icon: Icons.check_circle_outline,
      title: '可以保存新手机号',
      description: '保存后会更新登录和找回号码。',
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
        description: '先输入当前密码。',
      );
    }

    if (normalizedOldPassword != currentPassword) {
      return const _SettingsSheetValidationState(
        icon: Icons.lock_outline,
        title: '旧密码还未校验通过',
        description: '请先输入正确的当前密码。',
      );
    }

    if (normalizedNewPassword.length < 6) {
      return const _SettingsSheetValidationState(
        icon: Icons.password_outlined,
        title: '新密码至少需要 6 位',
        description: '新密码至少 6 位。',
      );
    }

    if (normalizedNewPassword == currentPassword) {
      return const _SettingsSheetValidationState(
        icon: Icons.lock_reset_outlined,
        title: '新密码还没有变化',
        description: '请换成不同的新密码。',
      );
    }

    if (normalizedConfirmPassword != normalizedNewPassword) {
      return const _SettingsSheetValidationState(
        icon: Icons.rule_folder_outlined,
        title: '两次新密码还不一致',
        description: '保持一致后再保存。',
      );
    }

    return const _SettingsSheetValidationState(
      icon: Icons.check_circle_outline,
      title: '可以保存新密码',
      description: '保存后这台设备会改用新密码。',
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAccountSheetHeader(
                      title: '修改手机号',
                      description: '用于登录和找回账号。',
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
                          ? '更新后改用新号码登录和找回。'
                          : '补全后可用于找回和确认账号。',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('settings-phone-input'),
                      controller: controller,
                      keyboardType: TextInputType.phone,
                      maxLength: 11,
                      autofocus: false,
                      decoration: const InputDecoration(
                        hintText: '输入新的 11 位手机号',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<_SettingsSheetValidationState>(
                      valueListenable: phoneValidation,
                      builder: (context, validation, child) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      backgroundColor: AppColors.white05,
                                      disabledBackgroundColor:
                                          AppColors.white05,
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
                                            FocusScope.of(sheetContext)
                                                .unfocus();
                                            Navigator.pop(sheetContext, true);
                                          }
                                        : null,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      backgroundColor: AppColors.white12,
                                      disabledBackgroundColor:
                                          AppColors.white05,
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
                        );
                      },
                    ),
                  ],
                ),
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
          title: '手机号已更新',
          badgeLabel: '已同步',
          description: '当前账号已切到新手机号。',
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAccountSheetHeader(
                      title: '修改密码',
                      description: '建议定期更换。',
                      badgeLabel: '账号安全',
                    ),
                    const SizedBox(height: 14),
                    _buildAccountHintCard(
                      key: const Key('settings-password-hint-card'),
                      icon: Icons.lock_clock_outlined,
                      title: '本地安全校验',
                      description: '先校验旧密码，再保存新密码。',
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
                        hintText: '输入新密码，至少 6 位',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const Key('settings-password-confirm-input'),
                      controller: confirmController,
                      obscureText: true,
                      decoration: const InputDecoration(hintText: '再次确认新密码'),
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<_SettingsSheetValidationState>(
                      valueListenable: passwordValidation,
                      builder: (context, validation, child) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAccountHintCard(
                              key: const Key(
                                'settings-password-validation-card',
                              ),
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
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      backgroundColor: AppColors.white05,
                                      disabledBackgroundColor:
                                          AppColors.white05,
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
                                            FocusScope.of(
                                              sheetContext,
                                            ).unfocus();
                                            Navigator.pop(sheetContext, true);
                                          }
                                        : null,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      backgroundColor: AppColors.white12,
                                      disabledBackgroundColor:
                                          AppColors.white05,
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
                        );
                      },
                    ),
                  ],
                ),
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
            title: '密码已更新',
            badgeLabel: '已保存',
            description: '请改用新密码登录。',
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
      content: '只退出当前设备，聊天记录仍保留。',
      confirmText: '确认退出',
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
      content: '会清除账号资料和会话数据，且无法恢复。',
      confirmText: '确认注销',
      isDanger: true,
    );

    if (confirm == true && context.mounted) {
      await context.read<AuthProvider>().deleteAccount();
      if (context.mounted) context.go('/login');
    }
  }
}

class _SettingsViewData {
  const _SettingsViewData({
    required this.invisibleMode,
    required this.notificationEnabled,
    required this.vibrationEnabled,
    required this.pushPermissionGranted,
    required this.pushHasDeviceToken,
  });

  final bool invisibleMode;
  final bool notificationEnabled;
  final bool vibrationEnabled;
  final bool pushPermissionGranted;
  final bool pushHasDeviceToken;

  SettingsExperiencePreset? get activeExperiencePreset {
    if (notificationEnabled && vibrationEnabled && !invisibleMode) {
      return SettingsExperiencePreset.responsive;
    }

    if (notificationEnabled && !vibrationEnabled && !invisibleMode) {
      return SettingsExperiencePreset.balanced;
    }

    if (!notificationEnabled && !vibrationEnabled && invisibleMode) {
      return SettingsExperiencePreset.quietObserve;
    }

    return null;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _SettingsViewData &&
            other.invisibleMode == invisibleMode &&
            other.notificationEnabled == notificationEnabled &&
            other.vibrationEnabled == vibrationEnabled &&
            other.pushPermissionGranted == pushPermissionGranted &&
            other.pushHasDeviceToken == pushHasDeviceToken;
  }

  @override
  int get hashCode => Object.hash(
        invisibleMode,
        notificationEnabled,
        vibrationEnabled,
        pushPermissionGranted,
        pushHasDeviceToken,
      );
}

class _SettingsInvisibleModeItemViewData {
  const _SettingsInvisibleModeItemViewData({
    required this.invisibleMode,
    required this.badgeLabel,
    required this.description,
    required this.isHealthy,
  });

  final bool invisibleMode;
  final String badgeLabel;
  final String description;
  final bool isHealthy;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _SettingsInvisibleModeItemViewData &&
            other.invisibleMode == invisibleMode &&
            other.badgeLabel == badgeLabel &&
            other.description == description &&
            other.isHealthy == isHealthy;
  }

  @override
  int get hashCode => Object.hash(
        invisibleMode,
        badgeLabel,
        description,
        isHealthy,
      );
}

class _SettingsNotificationItemViewData {
  const _SettingsNotificationItemViewData({
    required this.notificationEnabled,
    required this.badgeLabel,
    required this.description,
    required this.isHealthy,
  });

  final bool notificationEnabled;
  final String badgeLabel;
  final String description;
  final bool isHealthy;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _SettingsNotificationItemViewData &&
            other.notificationEnabled == notificationEnabled &&
            other.badgeLabel == badgeLabel &&
            other.description == description &&
            other.isHealthy == isHealthy;
  }

  @override
  int get hashCode => Object.hash(
        notificationEnabled,
        badgeLabel,
        description,
        isHealthy,
      );
}

class _SettingsVibrationItemViewData {
  const _SettingsVibrationItemViewData({
    required this.vibrationEnabled,
    required this.badgeLabel,
    required this.description,
    required this.isHealthy,
  });

  final bool vibrationEnabled;
  final String badgeLabel;
  final String description;
  final bool isHealthy;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _SettingsVibrationItemViewData &&
            other.vibrationEnabled == vibrationEnabled &&
            other.badgeLabel == badgeLabel &&
            other.description == description &&
            other.isHealthy == isHealthy;
  }

  @override
  int get hashCode => Object.hash(
        vibrationEnabled,
        badgeLabel,
        description,
        isHealthy,
      );
}

class _SettingsBlockedUsersSheetViewData {
  const _SettingsBlockedUsersSheetViewData({
    required this.rows,
  });

  final List<_SettingsBlockedUserRowViewData> rows;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _SettingsBlockedUsersSheetViewData &&
            listEquals(other.rows, rows);
  }

  @override
  int get hashCode => Object.hashAll(rows);
}

class _SettingsBlockedUserRowViewData {
  const _SettingsBlockedUserRowViewData({
    required this.userId,
    required this.displayName,
    required this.avatar,
  });

  final String userId;
  final String displayName;
  final String avatar;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _SettingsBlockedUserRowViewData &&
            other.userId == userId &&
            other.displayName == displayName &&
            other.avatar == avatar;
  }

  @override
  int get hashCode => Object.hash(userId, displayName, avatar);
}

class _SettingsAccountSecurityViewData {
  const _SettingsAccountSecurityViewData({
    required this.phone,
    required this.uid,
  });

  final String? phone;
  final String? uid;

  bool get hasPhone => (phone ?? '').trim().isNotEmpty;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _SettingsAccountSecurityViewData &&
            other.phone == phone &&
            other.uid == uid;
  }

  @override
  int get hashCode => Object.hash(phone, uid);
}

class _SettingsOverviewFocusViewData {
  const _SettingsOverviewFocusViewData({
    required this.hasPhone,
    required this.invisibleMode,
    required this.notificationEnabled,
    required this.pushPermissionGranted,
    required this.pushHasDeviceToken,
  });

  final bool hasPhone;
  final bool invisibleMode;
  final bool notificationEnabled;
  final bool pushPermissionGranted;
  final bool pushHasDeviceToken;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _SettingsOverviewFocusViewData &&
            other.hasPhone == hasPhone &&
            other.invisibleMode == invisibleMode &&
            other.notificationEnabled == notificationEnabled &&
            other.pushPermissionGranted == pushPermissionGranted &&
            other.pushHasDeviceToken == pushHasDeviceToken;
  }

  @override
  int get hashCode => Object.hash(
        hasPhone,
        invisibleMode,
        notificationEnabled,
        pushPermissionGranted,
        pushHasDeviceToken,
      );
}

class _SettingsExperiencePresetViewData {
  const _SettingsExperiencePresetViewData({
    required this.invisibleMode,
    required this.notificationEnabled,
    required this.vibrationEnabled,
  });

  final bool invisibleMode;
  final bool notificationEnabled;
  final bool vibrationEnabled;

  SettingsExperiencePreset? get activeExperiencePreset {
    if (notificationEnabled && vibrationEnabled && !invisibleMode) {
      return SettingsExperiencePreset.responsive;
    }

    if (notificationEnabled && !vibrationEnabled && !invisibleMode) {
      return SettingsExperiencePreset.balanced;
    }

    if (!notificationEnabled && !vibrationEnabled && invisibleMode) {
      return SettingsExperiencePreset.quietObserve;
    }

    return null;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _SettingsExperiencePresetViewData &&
            other.invisibleMode == invisibleMode &&
            other.notificationEnabled == notificationEnabled &&
            other.vibrationEnabled == vibrationEnabled;
  }

  @override
  int get hashCode =>
      Object.hash(invisibleMode, notificationEnabled, vibrationEnabled);
}

class _SettingsOverviewNotificationRuntimeViewData {
  const _SettingsOverviewNotificationRuntimeViewData({
    required this.notificationEnabled,
    required this.pushPermissionGranted,
    required this.pushHasDeviceToken,
  });

  final bool notificationEnabled;
  final bool pushPermissionGranted;
  final bool pushHasDeviceToken;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _SettingsOverviewNotificationRuntimeViewData &&
            other.notificationEnabled == notificationEnabled &&
            other.pushPermissionGranted == pushPermissionGranted &&
            other.pushHasDeviceToken == pushHasDeviceToken;
  }

  @override
  int get hashCode => Object.hash(
        notificationEnabled,
        pushPermissionGranted,
        pushHasDeviceToken,
      );
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

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _SettingsDeviceStatusItem &&
            other.key == key &&
            other.icon == icon &&
            other.title == title &&
            other.badgeLabel == badgeLabel &&
            other.description == description &&
            other.isHealthy == isHealthy;
  }

  @override
  int get hashCode => Object.hash(
        key,
        icon,
        title,
        badgeLabel,
        description,
        isHealthy,
      );
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
    this.isRemote = false,
  });

  final String? mediaPath;
  final bool hasMedia;
  final bool isRemote;
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

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _SettingsNotificationRuntimeState &&
            other.icon == icon &&
            other.badgeLabel == badgeLabel &&
            other.description == description &&
            other.statusChipLabel == statusChipLabel &&
            other.actionLabel == actionLabel &&
            other.actionIcon == actionIcon &&
            other.actionType == actionType &&
            other.followUpDescription == followUpDescription &&
            other.isHealthy == isHealthy;
  }

  @override
  int get hashCode => Object.hash(
        icon,
        badgeLabel,
        description,
        statusChipLabel,
        actionLabel,
        actionIcon,
        actionType,
        followUpDescription,
        isHealthy,
      );
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
