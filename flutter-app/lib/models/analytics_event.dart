class AnalyticsEvent {
  const AnalyticsEvent({
    required this.id,
    required this.name,
    required this.createdAt,
    this.properties = const <String, dynamic>{},
    this.level = 'info',
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final Map<String, dynamic> properties;
  final String level;

  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) {
    return AnalyticsEvent(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      properties: (json['properties'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value),
          ) ??
          const <String, dynamic>{},
      level: json['level']?.toString() ?? 'info',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'properties': properties,
      'level': level,
    };
  }
}
