import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/analytics_event.dart';
import 'storage_service.dart';

class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  final List<AnalyticsEvent> _events = <AnalyticsEvent>[];

  List<AnalyticsEvent> get events => List.unmodifiable(_events);

  Future<void> init() async {
    _load();
    await track('app_initialized');
  }

  Future<void> track(
    String name, {
    Map<String, dynamic> properties = const <String, dynamic>{},
    String level = 'info',
  }) async {
    final event = AnalyticsEvent(
      id: const Uuid().v4(),
      name: name,
      createdAt: DateTime.now(),
      properties: properties,
      level: level,
    );
    _events.insert(0, event);
    if (_events.length > 200) {
      _events.removeRange(200, _events.length);
    }
    await _persist();
    debugPrint('[analytics][$level] $name ${jsonEncode(properties)}');
  }

  Future<void> trackScreenView(String screenName) {
    return track('screen_view', properties: {'screen': screenName});
  }

  Future<void> captureError(
    Object error,
    StackTrace stackTrace, {
    String? hint,
  }) {
    return track(
      'app_error',
      level: 'error',
      properties: {
        'error': error.toString(),
        'stack': stackTrace.toString(),
        if (hint != null) 'hint': hint,
      },
    );
  }

  Future<void> clearSession() async {
    _events.clear();
    await StorageService.clearAnalyticsState();
  }

  void _load() {
    _events.clear();
    final raw = StorageService.getAnalyticsState();
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final item in decoded) {
        if (item is! Map) continue;
        _events.add(
          AnalyticsEvent.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    await StorageService.saveAnalyticsState(
      jsonEncode(_events.map((item) => item.toJson()).toList(growable: false)),
    );
  }
}
