import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/chat_provider.dart';
import '../models/models.dart';
import 'app_toast.dart';
import 'dart:async';

class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key});

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 每秒更新倒计时
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.pureBlack,
        elevation: 0,
        title: const Text(
          '消息',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          final threads = chatProvider.threads.values.toList();
          
          if (threads.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '💬',
                    style: TextStyle(
                      fontSize: 64,
                      color: AppColors.textTertiary.withOpacity(0.3),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '暂无消息',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '去匹配页开始聊天吧',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            itemCount: threads.length,
            itemBuilder: (context, index) {
              final thread = threads[index];
              final messages = chatProvider.getMessages(thread.id);
              final lastMessage = messages.isNotEmpty ? messages.last : null;
              
              return Dismissible(
                key: Key(thread.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (direction) async {
                  final confirm = await AppDialog.showConfirm(
                    context,
                    title: '确定要删除这个对话吗？',
                    content: '删除后将无法恢复',
                    confirmText: '删除',
                    isDanger: true,
                  );
                  return confirm == true;
                },
                background: Container(
                  color: Colors.transparent,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: Icon(
                    Icons.delete_outline,
                    color: AppColors.error.withOpacity(0.5),
                    size: 28,
                  ),
                ),
                onDismissed: (_) {
                  chatProvider.deleteThread(thread.id);
                  AppToast.show(context, '对话已删除');
                },
                child: _ThreadItem(
                  thread: thread,
                  lastMessage: lastMessage,
                  onTap: () {
                    // 从消息页进入聊天，返回时应该回到消息页
                    context.push('/chat/${thread.id}').then((_) {
                      // 返回后切换到消息页
                      if (context.mounted) {
                        context.go('/main?tab=1');
                      }
                    });
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ThreadItem extends StatelessWidget {
  final ChatThread thread;
  final Message? lastMessage;
  final VoidCallback onTap;
  
  const _ThreadItem({
    required this.thread,
    required this.lastMessage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.white05),
          ),
        ),
        child: Row(
          children: [
            // 头像
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.white08,
                    border: Border.all(color: AppColors.white05, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '👤',
                      style: TextStyle(
                        fontSize: 28,
                        color: thread.hasUnlockedAvatar
                            ? AppColors.textPrimary 
                            : AppColors.textTertiary.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
                if (thread.unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Text(
                        thread.unreadCount > 99 ? '99+' : '${thread.unreadCount}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(width: 16),
            
            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.hasUnlockedNickname
                              ? thread.otherUser.nickname 
                              : '神秘人',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: thread.hasUnlockedNickname
                                ? AppColors.textPrimary
                                : AppColors.textTertiary,
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(lastMessage?.timestamp),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage?.content ?? '开始聊天吧',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w300,
                            color: thread.unreadCount > 0 
                                ? AppColors.textSecondary 
                                : AppColors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!thread.isFriend) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.favorite,
                                size: 10,
                                color: Colors.orange.shade400,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${thread.intimacyPoints}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.orange.shade400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTimeRemaining(thread.timeRemaining),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: thread.timeRemaining.inHours < 1 
                          ? AppColors.error 
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }

  String _formatTimeRemaining(Duration duration) {
    if (duration.isNegative) return '已过期';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '剩余 $hours小时${minutes}分钟';
  }
}
