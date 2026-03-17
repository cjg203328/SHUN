class User {
  final String id;
  final String uid;
  final String nickname;
  final String? avatar;
  final String distance;
  final String status;
  final bool isOnline; // 是否在线
  final bool hasLocationPermission; // 是否开启位置权限
  final DateTime? lastOnlineTime; // 最后在线时间

  User({
    required this.id,
    String? uid,
    required this.nickname,
    this.avatar,
    required this.distance,
    required this.status,
    this.isOnline = false,
    this.hasLocationPermission = false,
    this.lastOnlineTime,
  }) : uid = uid ?? id;

  // 复制用户并修改某些字段
  User copyWith({
    String? uid,
    bool? isOnline,
    bool? hasLocationPermission,
    DateTime? lastOnlineTime,
    String? distance,
  }) {
    return User(
      id: id,
      uid: uid ?? this.uid,
      nickname: nickname,
      avatar: avatar,
      distance: distance ?? this.distance,
      status: status,
      isOnline: isOnline ?? this.isOnline,
      hasLocationPermission:
          hasLocationPermission ?? this.hasLocationPermission,
      lastOnlineTime: lastOnlineTime ?? this.lastOnlineTime,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      uid: json['uid'],
      nickname: json['nickname'],
      avatar: json['avatar'],
      distance: json['distance'],
      status: json['status'],
      isOnline: json['isOnline'] ?? false,
      hasLocationPermission: json['hasLocationPermission'] ?? false,
      lastOnlineTime: json['lastOnlineTime'] != null
          ? DateTime.parse(json['lastOnlineTime'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'nickname': nickname,
      'avatar': avatar,
      'distance': distance,
      'status': status,
      'isOnline': isOnline,
      'hasLocationPermission': hasLocationPermission,
      'lastOnlineTime': lastOnlineTime?.toIso8601String(),
    };
  }
}

class Message {
  final String id;
  final String content;
  final bool isMe;
  final DateTime timestamp;
  final MessageStatus status; // 消息状态
  final MessageType type; // 消息类型
  final String? imagePath; // 图片路径（本地或网络）
  final bool isBurnAfterReading; // 是否阅后即焚
  final bool isRead; // 已读状态（对方已读/阅后即焚）
  final ImageQuality? imageQuality; // 图片质量

  Message({
    required this.id,
    required this.content,
    required this.isMe,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.type = MessageType.text,
    this.imagePath,
    this.isBurnAfterReading = false,
    this.isRead = false,
    this.imageQuality,
  });

  // 复制消息并修改某些字段
  Message copyWith({
    MessageStatus? status,
    bool? isRead,
  }) {
    return Message(
      id: id,
      content: content,
      isMe: isMe,
      timestamp: timestamp,
      status: status ?? this.status,
      type: type,
      imagePath: imagePath,
      isBurnAfterReading: isBurnAfterReading,
      isRead: isRead ?? this.isRead,
      imageQuality: imageQuality,
    );
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      content: json['content'],
      isMe: json['isMe'],
      timestamp: DateTime.parse(json['timestamp']),
      status: MessageStatus.values.firstWhere(
        (e) => e.toString() == 'MessageStatus.${json['status']}',
        orElse: () => MessageStatus.sent,
      ),
      type: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${json['type']}',
        orElse: () => MessageType.text,
      ),
      imagePath: json['imagePath'],
      isBurnAfterReading: json['isBurnAfterReading'] ?? false,
      isRead: json['isRead'] ?? false,
      imageQuality: json['imageQuality'] != null
          ? ImageQuality.values.firstWhere(
              (e) => e.toString() == 'ImageQuality.${json['imageQuality']}',
              orElse: () => ImageQuality.compressed,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'isMe': isMe,
      'timestamp': timestamp.toIso8601String(),
      'status': status.toString().split('.').last,
      'type': type.toString().split('.').last,
      'imagePath': imagePath,
      'isBurnAfterReading': isBurnAfterReading,
      'isRead': isRead,
      'imageQuality': imageQuality?.toString().split('.').last,
    };
  }
}

enum MessageStatus {
  sending, // 发送中
  sent, // 已发送
  failed, // 发送失败
}

enum MessageType {
  text, // 文本消息
  image, // 图片消息
}

enum ImageQuality {
  original, // 原图
  compressed, // 1080p压缩
}

class ChatThread {
  final String id;
  final User otherUser;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int intimacyPoints; // 亲密度分数
  final bool isFriend; // 是否已成为好友
  final bool isUnfollowed; // 是否被取关
  final int messagesSinceUnfollow; // 取关后发送的消息数
  ChatThread({
    required this.id,
    required this.otherUser,
    this.unreadCount = 0,
    required this.createdAt,
    required this.expiresAt,
    this.intimacyPoints = 0,
    this.isFriend = false,
    this.isUnfollowed = false,
    this.messagesSinceUnfollow = 0,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get timeRemaining => expiresAt.difference(DateTime.now());

  // 是否解锁头像
  bool get hasUnlockedAvatar => true;

  // 是否解锁昵称
  bool get hasUnlockedNickname => true;

  // 阶段一：解锁主页查看权限
  bool get hasUnlockedSignature => hasUnlockedProfile;

  // 阶段一：解锁主页（需要一定互动分和最短聊天时长）
  bool get hasUnlockedProfile =>
      intimacyPoints >= 40 &&
      DateTime.now().difference(createdAt).inMinutes >= 3;

  // 阶段一：同步解锁背景
  bool get hasUnlockedBackground => hasUnlockedProfile;

  // 图片消息权限：与主页解锁阶段保持一致
  bool get canSendImage => hasUnlockedProfile;

  // 阶段二：解锁互关权限 + 语音权限
  bool get canAddFriend =>
      intimacyPoints >= 140 &&
      DateTime.now().difference(createdAt).inMinutes >= 12;

  // 是否可以发送消息（取关后限制）
  bool get canSendMessage {
    if (!isUnfollowed) return true;
    return messagesSinceUnfollow < 3;
  }

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    return ChatThread(
      id: json['id'],
      otherUser: User.fromJson(json['otherUser']),
      unreadCount: json['unreadCount'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
      expiresAt: DateTime.parse(json['expiresAt']),
      intimacyPoints: json['intimacyPoints'] ?? 0,
      isFriend: json['isFriend'] ?? false,
      isUnfollowed: json['isUnfollowed'] ?? false,
      messagesSinceUnfollow: json['messagesSinceUnfollow'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'otherUser': otherUser.toJson(),
      'unreadCount': unreadCount,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'intimacyPoints': intimacyPoints,
      'isFriend': isFriend,
      'isUnfollowed': isUnfollowed,
      'messagesSinceUnfollow': messagesSinceUnfollow,
    };
  }
}

class Friend {
  final String id;
  final User user;
  final DateTime becameFriendAt;
  final String? remark; // 备注名
  final int chatCount; // 聊天次数
  final int totalMinutes; // 累计聊天时长（分钟）

  Friend({
    required this.id,
    required this.user,
    required this.becameFriendAt,
    this.remark,
    this.chatCount = 0,
    this.totalMinutes = 0,
  });

  String get displayName => remark ?? user.nickname;

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'],
      user: User.fromJson(json['user']),
      becameFriendAt: DateTime.parse(json['becameFriendAt']),
      remark: json['remark'],
      chatCount: json['chatCount'] ?? 0,
      totalMinutes: json['totalMinutes'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user.toJson(),
      'becameFriendAt': becameFriendAt.toIso8601String(),
      'remark': remark,
      'chatCount': chatCount,
      'totalMinutes': totalMinutes,
    };
  }
}

class FriendRequest {
  final String id;
  final User fromUser;
  final String? message;
  final DateTime createdAt;
  final FriendRequestStatus status;

  FriendRequest({
    required this.id,
    required this.fromUser,
    this.message,
    required this.createdAt,
    this.status = FriendRequestStatus.pending,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'],
      fromUser: User.fromJson(json['fromUser']),
      message: json['message'],
      createdAt: DateTime.parse(json['createdAt']),
      status: FriendRequestStatus.values.firstWhere(
        (e) => e.toString() == 'FriendRequestStatus.${json['status']}',
        orElse: () => FriendRequestStatus.pending,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUser': fromUser.toJson(),
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'status': status.toString().split('.').last,
    };
  }
}

enum FriendRequestStatus {
  pending,
  accepted,
  rejected,
}
