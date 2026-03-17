class NotificationPermissionGuidance {
  const NotificationPermissionGuidance._();

  static const title = '系统通知权限还没打开';
  static const badgeLabel = '待授权';
  static const settingsDescription = '应用内通知已打开，但系统权限还没放行，锁屏和后台提醒依然可能缺失。';
  static const settingsFollowUpDescription =
      '去系统设置打开通知权限后，再回来点一次刷新状态，这台设备才会真正进入可触达状态。';
  static const notificationCenterDescription = '新的消息仍会保存在通知中心，但锁屏和后台提醒暂时不会生效。';
  static const chatDescription = '离开当前会话后，新消息仍会保存在通知中心，但锁屏和后台提醒暂时不会生效。';
  static const openSystemSettingsAction = '去系统设置';
  static const openSettingsPageAction = '去设置页处理';
  static const openNotificationCenterAction = '查看通知中心';

  static bool needsSystemPermission({
    required bool notificationEnabled,
    required bool permissionGranted,
  }) {
    return notificationEnabled && !permissionGranted;
  }
}
