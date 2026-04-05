class NotificationPermissionGuidance {
  const NotificationPermissionGuidance._();

  static const title = '系统通知未打开';
  static const badgeLabel = '待授权';
  static const settingsDescription = '新消息仍会留在通知中心，系统提醒暂不可用。';
  static const settingsFollowUpDescription = '去系统设置打开后，回来就会恢复提醒。';
  static const notificationCenterDescription = '新消息会先留在这里，锁屏和后台提醒暂不可用。';
  static const chatDescription = '离开会话后，新消息会先留在通知中心，锁屏和后台提醒暂不可用。';
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
