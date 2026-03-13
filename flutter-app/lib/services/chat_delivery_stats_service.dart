class ChatDeliveryStatEvent {
  const ChatDeliveryStatEvent({
    required this.code,
    required this.label,
    required this.timestamp,
    required this.isError,
    required this.tagLabel,
  });

  factory ChatDeliveryStatEvent.fromJson(Map<String, dynamic> json) {
    final code = json['code']?.toString() ?? 'unknown';
    final rawLabel = json['label']?.toString();
    final rawTagLabel = json['tagLabel']?.toString();

    return ChatDeliveryStatEvent(
      code: code,
      label: ChatDeliveryStatsService.labelForCode(code) ?? rawLabel ?? '未知事件',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      isError: json['isError'] == true,
      tagLabel:
          ChatDeliveryStatsService.tagLabelForCode(code) ?? rawTagLabel ?? '系统',
    );
  }

  final String code;
  final String label;
  final DateTime timestamp;
  final bool isError;
  final String tagLabel;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'code': code,
      'label': label,
      'timestamp': timestamp.toIso8601String(),
      'isError': isError,
      'tagLabel': tagLabel,
    };
  }
}

class ChatDeliveryStatsService {
  static const String retriesRequestedKey = 'retries_requested';
  static const String retriesSucceededKey = 'retries_succeeded';
  static const String retriesFailedKey = 'retries_failed';
  static const String textSucceededKey = 'text_succeeded';
  static const String textFailedKey = 'text_failed';
  static const String imageSucceededKey = 'image_succeeded';
  static const String imageFailedKey = 'image_failed';
  static const String imageReselectRequiredKey = 'image_reselect_required';
  static const int maxRecentEvents = 20;

  static String? labelForCode(String code) {
    switch (code) {
      case retriesRequestedKey:
        return '已发起重试';
      case retriesSucceededKey:
        return '重试成功，已送达';
      case retriesFailedKey:
        return '重试失败';
      case textSucceededKey:
        return '文本发送成功';
      case textFailedKey:
        return '文本发送失败';
      case imageSucceededKey:
        return '图片发送成功';
      case imageFailedKey:
        return '图片发送失败';
      case imageReselectRequiredKey:
        return '原图失效，需重选图片';
      default:
        return null;
    }
  }

  static String? tagLabelForCode(String code) {
    if (code.startsWith('retries_')) {
      return '重试';
    }
    if (code.startsWith('text_')) {
      return '文本';
    }
    if (code.startsWith('image_')) {
      return '图片';
    }
    return null;
  }

  final Map<String, int> _counters = <String, int>{
    retriesRequestedKey: 0,
    retriesSucceededKey: 0,
    retriesFailedKey: 0,
    textSucceededKey: 0,
    textFailedKey: 0,
    imageSucceededKey: 0,
    imageFailedKey: 0,
    imageReselectRequiredKey: 0,
  };
  final List<ChatDeliveryStatEvent> _recentEvents = <ChatDeliveryStatEvent>[];

  Map<String, int> get counters => Map<String, int>.unmodifiable(_counters);

  List<ChatDeliveryStatEvent> get recentEvents =>
      List<ChatDeliveryStatEvent>.unmodifiable(_recentEvents);

  bool get hasData =>
      _counters.values.any((value) => value > 0) || _recentEvents.isNotEmpty;

  void loadSnapshot(Object? rawSnapshot) {
    if (rawSnapshot is! Map) {
      return;
    }

    final countersSource = rawSnapshot['counters'];
    if (countersSource is Map) {
      _loadCounters(countersSource);
    } else {
      _loadCounters(rawSnapshot);
    }

    _recentEvents.clear();
    final rawEvents = rawSnapshot['recentEvents'];
    if (rawEvents is! List) {
      return;
    }

    for (final item in rawEvents) {
      if (item is! Map) {
        continue;
      }
      try {
        _recentEvents.add(
          ChatDeliveryStatEvent.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        );
      } catch (_) {}
    }

    _recentEvents
        .sort((left, right) => right.timestamp.compareTo(left.timestamp));
    if (_recentEvents.length > maxRecentEvents) {
      _recentEvents.removeRange(maxRecentEvents, _recentEvents.length);
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'counters': Map<String, int>.from(_counters),
      'recentEvents':
          _recentEvents.map((event) => event.toJson()).toList(growable: false),
    };
  }

  void clear() {
    for (final key in _counters.keys) {
      _counters[key] = 0;
    }
    _recentEvents.clear();
  }

  void recordRetryRequested() {
    _increment(retriesRequestedKey);
    _recordEvent(retriesRequestedKey);
  }

  void recordRetrySucceeded() {
    _increment(retriesSucceededKey);
    _recordEvent(retriesSucceededKey);
  }

  void recordRetryFailed() {
    _increment(retriesFailedKey);
    _recordEvent(retriesFailedKey, isError: true);
  }

  void recordTextSucceeded() {
    _increment(textSucceededKey);
    _recordEvent(textSucceededKey);
  }

  void recordTextFailed() {
    _increment(textFailedKey);
    _recordEvent(textFailedKey, isError: true);
  }

  void recordImageSucceeded() {
    _increment(imageSucceededKey);
    _recordEvent(imageSucceededKey);
  }

  void recordImageFailed() {
    _increment(imageFailedKey);
    _recordEvent(imageFailedKey, isError: true);
  }

  void recordImageReselectRequired() {
    _increment(imageReselectRequiredKey);
    _recordEvent(imageReselectRequiredKey, isError: true);
  }

  void _loadCounters(Map rawCounters) {
    for (final key in _counters.keys) {
      final value = rawCounters[key];
      if (value is int) {
        _counters[key] = value;
      } else if (value is num) {
        _counters[key] = value.toInt();
      }
    }
  }

  void _increment(String key) {
    _counters[key] = (_counters[key] ?? 0) + 1;
  }

  void _recordEvent(String code, {bool isError = false}) {
    _pushEvent(
      ChatDeliveryStatEvent(
        code: code,
        label: labelForCode(code) ?? '未知事件',
        timestamp: DateTime.now(),
        isError: isError,
        tagLabel: tagLabelForCode(code) ?? '系统',
      ),
    );
  }

  void _pushEvent(ChatDeliveryStatEvent event) {
    _recentEvents.insert(0, event);
    if (_recentEvents.length > maxRecentEvents) {
      _recentEvents.removeRange(maxRecentEvents, _recentEvents.length);
    }
  }
}
