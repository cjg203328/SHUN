class NotificationPermissionGuidance {
  const NotificationPermissionGuidance._();

  static const title = '系统通知未打开';
  static const badgeLabel = '待授权';
  static const settingsDescription = '应用通知已打开，但系统权限未授权。';
  static const settingsFollowUpDescription = '去系统设置打开通知权限后，回来再刷新一次。';
  static const notificationCenterDescription = '新消息仍会保存在通知中心，锁屏和后台提醒暂不生效。';
  static const chatDescription = '离开会话后，新消息仍会保存在通知中心，锁屏和后台提醒暂不生效。';
  static const openSystemSettingsAction = '去系统设置';
  static const openSettingsPageAction = '去设置处理';
  static const openNotificationCenterAction = '查看通知中心';

  static bool needsSystemPermission({
    required bool notificationEnabled,
    required bool permissionGranted,
  }) {
    return notificationEnabled && !permissionGranted;
  }
}
