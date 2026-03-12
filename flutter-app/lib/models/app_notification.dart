enum AppNotificationType {
  message,
  friendRequest,
  friendAccepted,
  system,
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.threadId,
    this.requestId,
    this.userId,
    this.sourceKey,
  });

  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String? threadId;
  final String? requestId;
  final String? userId;
  final String? sourceKey;

  AppNotification copyWith({
    bool? isRead,
    String? title,
    String? body,
    DateTime? createdAt,
    String? threadId,
    String? requestId,
    String? userId,
    String? sourceKey,
  }) {
    return AppNotification(
      id: id,
      type: type,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      threadId: threadId ?? this.threadId,
      requestId: requestId ?? this.requestId,
      userId: userId ?? this.userId,
      sourceKey: sourceKey ?? this.sourceKey,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: AppNotificationType.values.firstWhere(
        (value) => value.name == json['type']?.toString(),
        orElse: () => AppNotificationType.system,
      ),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      isRead: json['isRead'] == true,
      threadId: json['threadId']?.toString(),
      requestId: json['requestId']?.toString(),
      userId: json['userId']?.toString(),
      sourceKey: json['sourceKey']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'body': body,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'threadId': threadId,
      'requestId': requestId,
      'userId': userId,
      'sourceKey': sourceKey,
    };
  }
}
