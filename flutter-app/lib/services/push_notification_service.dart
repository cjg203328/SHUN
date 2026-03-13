import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/notification_center_provider.dart';
import 'analytics_service.dart';
import 'storage_service.dart';

class PushRuntimeState {
  const PushRuntimeState({
    required this.notificationsEnabled,
    required this.permissionGranted,
    this.deviceToken,
    this.lastSyncedAt,
  });

  final bool notificationsEnabled;
  final bool permissionGranted;
  final String? deviceToken;
  final DateTime? lastSyncedAt;

  PushRuntimeState copyWith({
    bool? notificationsEnabled,
    bool? permissionGranted,
    String? deviceToken,
    DateTime? lastSyncedAt,
  }) {
    return PushRuntimeState(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      deviceToken: deviceToken ?? this.deviceToken,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  factory PushRuntimeState.fromJson(Map<String, dynamic> json) {
    return PushRuntimeState(
      notificationsEnabled: json['notificationsEnabled'] == true,
      permissionGranted: json['permissionGranted'] == true,
      deviceToken: json['deviceToken']?.toString(),
      lastSyncedAt: DateTime.tryParse(json['lastSyncedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notificationsEnabled': notificationsEnabled,
      'permissionGranted': permissionGranted,
      'deviceToken': deviceToken,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
    };
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  PushRuntimeState _state = const PushRuntimeState(
    notificationsEnabled: true,
    permissionGranted: false,
  );

  PushRuntimeState get state => _state;

  Future<void> initialize({required bool notificationsEnabled}) async {
    _load();
    await syncSettings(notificationsEnabled: notificationsEnabled);
    await AnalyticsService.instance.track(
      'push_initialized',
      properties: {
        'enabled': _state.notificationsEnabled,
        'permissionGranted': _state.permissionGranted,
      },
    );
  }

  Future<void> syncSettings({required bool notificationsEnabled}) async {
    final permissionGranted = await _readPermissionGranted();
    final deviceToken = notificationsEnabled && permissionGranted
        ? _buildStubDeviceToken()
        : null;

    _state = _state.copyWith(
      notificationsEnabled: notificationsEnabled,
      permissionGranted: permissionGranted,
      deviceToken: deviceToken,
      lastSyncedAt: DateTime.now(),
    );

    if (notificationsEnabled && !permissionGranted) {
      await NotificationCenterProvider.instance.addSystemNotification(
        title: '系统通知未开启',
        body: '你已打开应用内通知开关，但系统通知权限尚未授予。',
        sourceKey: 'push-permission-missing',
      );
    }

    if (!notificationsEnabled) {
      await NotificationCenterProvider.instance.addSystemNotification(
        title: '系统通知已关闭',
        body: '你已关闭消息通知，新的消息仍会保存在通知中心。',
        sourceKey: 'push-disabled',
      );
    }

    await _persist();
    await AnalyticsService.instance.track(
      'push_settings_synced',
      properties: {
        'enabled': notificationsEnabled,
        'permissionGranted': permissionGranted,
        'hasDeviceToken': deviceToken != null,
      },
    );
  }

  Future<void> refreshPermissionState() async {
    await syncSettings(notificationsEnabled: _state.notificationsEnabled);
  }

  Future<void> clearSession() async {
    _state = const PushRuntimeState(
      notificationsEnabled: true,
      permissionGranted: false,
    );
    await StorageService.clearPushRuntimeState();
  }

  Future<bool> _readPermissionGranted() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  String _buildStubDeviceToken() {
    final uid = StorageService.getUid() ?? 'guest';
    final deviceId = StorageService.getDeviceId() ?? 'device';
    return 'stub_push_${uid}_$deviceId';
  }

  void _load() {
    final raw = StorageService.getPushRuntimeState();
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      _state = PushRuntimeState.fromJson(decoded);
    } catch (_) {}
  }

  Future<void> _persist() async {
    await StorageService.savePushRuntimeState(jsonEncode(_state.toJson()));
  }

  @visibleForTesting
  void debugSetState(PushRuntimeState state) {
    _state = state;
  }
}
