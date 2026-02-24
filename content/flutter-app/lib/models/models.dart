class User {
  final String id;
  final String nickname;
  final String? avatar;
  final String distance;
  final String status;
  
  User({
    required this.id,
    required this.nickname,
    this.avatar,
    required this.distance,
    required this.status,
  });
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      nickname: json['nickname'],
      avatar: json['avatar'],
      distance: json['distance'],
      status: json['status'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'avatar': avatar,
      'distance': distance,
      'status': status,
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
  final bool isRead; // 是否已读（用于阅后即焚）
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
  sending,  // 发送中
  sent,     // 已发送
  failed,   // 发送失败
}

enum MessageType {
  text,     // 文本消息
  image,    // 图片消息
}

enum ImageQuality {
  original,    // 原图
  compressed,  // 1080p压缩
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
  bool get hasUnlockedAvatar => intimacyPoints >= 20;
  
  // 是否解锁昵称
  bool get hasUnlockedNickname => intimacyPoints >= 50;
  
  // 是否解锁个人签名
  bool get hasUnlockedSignature => intimacyPoints >= 100;
  
  // 是否解锁主页
  bool get hasUnlockedProfile => intimacyPoints >= 150;
  
  // 是否解锁主页背景
  bool get hasUnlockedBackground => intimacyPoints >= 200;
  
  // 是否可以互关
  bool get canAddFriend => intimacyPoints >= 250;
  
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

