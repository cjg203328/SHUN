import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../utils/intimacy_system.dart';
import '../utils/image_helper.dart';

class ChatProvider extends ChangeNotifier {
  final Map<String, List<Message>> _messages = {};
  final Map<String, ChatThread> _threads = {};
  final Map<String, DateTime> _lastMessageTime = {}; // 记录最后消息时间
  final Map<String, bool> _deletedThreads = {}; // 软删除的会话
  
  Map<String, ChatThread> get threads {
    // 过滤掉已软删除的会话
    return Map.fromEntries(
      _threads.entries.where((entry) => !(_deletedThreads[entry.key] ?? false))
    );
  }
  
  List<Message> getMessages(String threadId) {
    return _messages[threadId] ?? [];
  }
  
  ChatThread? getThread(String threadId) {
    return _threads[threadId];
  }
  
  void addThread(ChatThread thread) {
    _threads[thread.id] = thread;
    _messages[thread.id] = [];
    notifyListeners();
  }
  
  void sendMessage(String threadId, String content) {
    final thread = _threads[threadId];
    if (thread == null) return;
    
    // 检查是否可以发送消息（取关限制）
    if (!thread.canSendMessage) {
      // 不能发送，需要对方确认
      return;
    }
    
    final messageId = const Uuid().v4();
    final message = Message(
      id: messageId,
      content: content,
      isMe: true,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      type: MessageType.text,
    );
    
    _messages[threadId]?.add(message);
    
    // 如果被取关，增加计数
    if (thread.isUnfollowed) {
      _updateThread(threadId, messagesSinceUnfollow: thread.messagesSinceUnfollow + 1);
    }
    
    notifyListeners();
    
    // 模拟发送（检测网络状态）
    _simulateSend(threadId, messageId, content);
  }
  
  Future<void> _simulateSend(String threadId, String messageId, String content) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final messages = _messages[threadId];
    if (messages != null) {
      final index = messages.indexWhere((msg) => msg.id == messageId);
      if (index != -1) {
        // 模拟网络检测（90%成功率）
        final isSuccess = DateTime.now().millisecond % 10 != 0;
        
        messages[index] = messages[index].copyWith(
          status: isSuccess ? MessageStatus.sent : MessageStatus.failed,
        );
        notifyListeners();
        
        // 如果发送成功，增加亲密度并触发自动回复
        if (isSuccess) {
          _addIntimacy(threadId, content, true);
          _mockReply(threadId);
        }
      }
    }
  }
  
  /// 增加亲密度
  void _addIntimacy(String threadId, String content, bool isSend) {
    final thread = _threads[threadId];
    if (thread == null || thread.isFriend) return;
    
    int points = 0;
    
    // 基础分数
    if (isSend) {
      points += IntimacyCalculator.sendMessage(content);
    } else {
      points += IntimacyCalculator.receiveMessage(content);
    }
    
    // 首次对话奖励
    if (thread.intimacyPoints == 0) {
      points += IntimacyCalculator.firstChat();
    }
    
    // 连续对话奖励（5分钟内互动）
    final lastTime = _lastMessageTime[threadId];
    if (lastTime != null) {
      final diff = DateTime.now().difference(lastTime);
      if (diff.inMinutes < 5) {
        points += IntimacyCalculator.continuousChat();
      }
    }
    
    // 深夜聊天奖励
    points += IntimacyCalculator.lateNightChat();
    
    // 更新最后消息时间
    _lastMessageTime[threadId] = DateTime.now();
    
    // 更新亲密度
    final newPoints = thread.intimacyPoints + points;
    _updateThread(threadId, intimacyPoints: newPoints);
  }
  
  void resendMessage(String threadId, String messageId) {
    final messages = _messages[threadId];
    if (messages != null) {
      final index = messages.indexWhere((msg) => msg.id == messageId);
      if (index != -1) {
        final content = messages[index].content;
        messages[index] = messages[index].copyWith(
          status: MessageStatus.sending,
        );
        notifyListeners();
        
        // 重新发送
        _simulateSend(threadId, messageId, content);
      }
    }
  }
  
  Future<void> _mockReply(String threadId) async {
    await Future.delayed(const Duration(seconds: 2));
    
    final replies = [
      '你好呀',
      '在的',
      '嗯嗯',
      '哈哈哈',
      '是啊',
      '我也是',
      '有点',
      '还好吧',
      '确实',
      '对对对',
    ];
    
    final content = replies[DateTime.now().second % replies.length];
    
    final reply = Message(
      id: const Uuid().v4(),
      content: content,
      isMe: false,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
      type: MessageType.text,
    );
    
    _messages[threadId]?.add(reply);
    
    // 增加亲密度
    _addIntimacy(threadId, content, false);
    
    // 增加未读数
    _updateThread(threadId, unreadCount: (_threads[threadId]?.unreadCount ?? 0) + 1);
    
    notifyListeners();
  }
  
  void markAsRead(String threadId) {
    _updateThread(threadId, unreadCount: 0);
  }
  
  void markAsFriend(String threadId) {
    _updateThread(threadId, isFriend: true);
  }
  
  /// 取关好友
  void unfollowFriend(String threadId) {
    _updateThread(threadId, 
      isFriend: false, 
      isUnfollowed: true,
      messagesSinceUnfollow: 0,
    );
  }
  
  /// 确认继续聊天（取关后）
  void confirmChat(String threadId) {
    _updateThread(threadId, 
      isUnfollowed: false,
      messagesSinceUnfollow: 0,
    );
  }
  
  /// 统一更新Thread的方法
  void _updateThread(String threadId, {
    int? unreadCount,
    int? intimacyPoints,
    bool? isFriend,
    bool? isUnfollowed,
    int? messagesSinceUnfollow,
  }) {
    final thread = _threads[threadId];
    if (thread == null) return;
    
    _threads[threadId] = ChatThread(
      id: thread.id,
      otherUser: thread.otherUser,
      unreadCount: unreadCount ?? thread.unreadCount,
      createdAt: thread.createdAt,
      expiresAt: thread.expiresAt,
      intimacyPoints: intimacyPoints ?? thread.intimacyPoints,
      isFriend: isFriend ?? thread.isFriend,
      isUnfollowed: isUnfollowed ?? thread.isUnfollowed,
      messagesSinceUnfollow: messagesSinceUnfollow ?? thread.messagesSinceUnfollow,
    );
    notifyListeners();
  }
  
  void deleteThread(String threadId) {
    // 软删除：标记为已删除，但保留数据
    _deletedThreads[threadId] = true;
    notifyListeners();
  }
  
  /// 恢复已删除的会话（当对方发送新消息时）
  void restoreThread(String threadId) {
    _deletedThreads[threadId] = false;
    notifyListeners();
  }
  
  /// 发送图片消息
  Future<void> sendImageMessage(
    String threadId,
    File imageFile,
    ImageQuality quality,
    bool isBurnAfterReading,
  ) async {
    final thread = _threads[threadId];
    if (thread == null) return;
    
    // 检查是否可以发送消息（取关限制）
    if (!thread.canSendMessage) {
      return;
    }
    
    try {
      // 压缩图片
      final compressedImage = await ImageHelper.compressImage(imageFile, quality);
      
      final messageId = const Uuid().v4();
      final message = Message(
        id: messageId,
        content: '[图片]',
        isMe: true,
        timestamp: DateTime.now(),
        status: MessageStatus.sending,
        type: MessageType.image,
        imagePath: compressedImage.path,
        isBurnAfterReading: isBurnAfterReading,
        imageQuality: quality,
      );
      
      _messages[threadId]?.add(message);
      
      // 如果被取关，增加计数
      if (thread.isUnfollowed) {
        _updateThread(threadId, messagesSinceUnfollow: thread.messagesSinceUnfollow + 1);
      }
      
      notifyListeners();
      
      // 模拟发送
      _simulateSendImage(threadId, messageId);
    } catch (e) {
      print('发送图片失败: $e');
    }
  }
  
  Future<void> _simulateSendImage(String threadId, String messageId) async {
    await Future.delayed(const Duration(seconds: 1));
    
    final messages = _messages[threadId];
    if (messages != null) {
      final index = messages.indexWhere((msg) => msg.id == messageId);
      if (index != -1) {
        // 模拟网络检测（95%成功率）
        final isSuccess = DateTime.now().millisecond % 20 != 0;
        
        messages[index] = messages[index].copyWith(
          status: isSuccess ? MessageStatus.sent : MessageStatus.failed,
        );
        notifyListeners();
        
        // 如果发送成功，增加亲密度
        if (isSuccess) {
          _addIntimacy(threadId, '[图片]', true);
        }
      }
    }
  }
  
  /// 标记图片为已读（阅后即焚）
  void markImageAsRead(String threadId, String messageId) {
    final messages = _messages[threadId];
    if (messages != null) {
      final index = messages.indexWhere((msg) => msg.id == messageId);
      if (index != -1) {
        final message = messages[index];
        if (message.isBurnAfterReading && !message.isRead) {
          messages[index] = message.copyWith(isRead: true);
          notifyListeners();
          
          // 3秒后删除消息
          Future.delayed(const Duration(seconds: 3), () {
            final currentMessages = _messages[threadId];
            if (currentMessages != null) {
              currentMessages.removeWhere((msg) => msg.id == messageId);
              notifyListeners();
            }
          });
        }
      }
    }
  }
  
  void recallMessage(String threadId, String messageId) {
    final messages = _messages[threadId];
    if (messages != null) {
      messages.removeWhere((msg) => msg.id == messageId);
      notifyListeners();
    }
  }
}

