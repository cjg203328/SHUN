import '../models/models.dart';

class ChatService {
  static const List<String> _mockReplies = [
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

  bool canSendText(ChatThread thread) => thread.canSendMessage;

  bool canSendImage(ChatThread thread) =>
      thread.canSendMessage && thread.canSendImage;

  String getMockReply() {
    return _mockReplies[DateTime.now().second % _mockReplies.length];
  }
}
