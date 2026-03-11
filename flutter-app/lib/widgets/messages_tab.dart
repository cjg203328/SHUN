import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../core/feedback/app_feedback.dart';
import '../core/ui/ui_tokens.dart';
import '../providers/chat_provider.dart';
import '../providers/notification_center_provider.dart';
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
  static const Duration _threadRefreshInterval = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    // 会话剩余时长只需分钟级刷新，避免每秒触发整页重建
    _timer = Timer.periodic(_threadRefreshInterval, (_) {
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
        actions: [
          Consumer<NotificationCenterProvider>(
            builder: (context, provider, child) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none),
                    onPressed: () => context.push('/notifications'),
                  ),
                  if (provider.unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          provider.unreadCount > 99
                              ? '99+'
                              : '${provider.unreadCount}',
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
              );
            },
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          final threads = chatProvider.sortedThreads;

          if (threads.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '💬',
                    style: TextStyle(
                      fontSize: 64,
                      color: AppColors.textTertiary.withValues(alpha: 0.3),
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
                    color: AppColors.error.withValues(alpha: 0.5),
                    size: 28,
                  ),
                ),
                onDismissed: (_) {
                  chatProvider.deleteThread(thread.id);
                  AppFeedback.showToast(
                    context,
                    AppToastCode.deleted,
                    subject: '对话',
                  );
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
    final isOnline = thread.otherUser.isOnline;
    final isFriend = thread.isFriend;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: UiTokens.cardPadding,
        decoration: BoxDecoration(
          // 在线陌生人：微妙的渐变背景吸引注意
          gradient: isOnline && !isFriend
              ? LinearGradient(
                  colors: [
                    AppColors.brandBlue.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
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
                    // 好友：蓝色边框
                    border: Border.all(
                      color: isFriend
                          ? AppColors.brandBlue.withValues(alpha: 0.5)
                          : AppColors.white05,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      thread.otherUser.avatar ?? '👤',
                      style: const TextStyle(
                        fontSize: 28,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),

                // 在线状态绿点
                if (isOnline)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50), // 绿色
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.pureBlack,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF4CAF50).withValues(alpha: 0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),

                // 未读数角标
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
                        thread.unreadCount > 99
                            ? '99+'
                            : '${thread.unreadCount}',
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
                        child: Row(
                          children: [
                            // 昵称
                            Text(
                              thread.otherUser.nickname,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),

                            // 好友标签
                            if (isFriend)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.brandBlue
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '好友',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.brandBlue,
                                  ),
                                ),
                              ),

                            // 在线标识（仅陌生人显示）
                            if (isOnline && !isFriend)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '在线',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF4CAF50),
                                  ),
                                ),
                              ),
                          ],
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
                      if (lastMessage != null &&
                          lastMessage!.isMe &&
                          lastMessage!.status == MessageStatus.sent &&
                          !lastMessage!.isBurnAfterReading) ...[
                        const SizedBox(width: 8),
                        Text(
                          lastMessage!.isRead ? '对方已读' : '对方未读',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w300,
                            color: lastMessage!.isRead
                                ? AppColors.textTertiary.withValues(alpha: 0.7)
                                : AppColors.textSecondary
                                    .withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                      if (!isFriend) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
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

                  // 倒计时（仅陌生人显示）
                  if (!isFriend) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: thread.timeRemaining.inHours < 3
                              ? AppColors.error
                              : AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTimeRemaining(thread.timeRemaining),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w300,
                            color: thread.timeRemaining.inHours < 3
                                ? AppColors.error
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
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
    return '剩余 $hours小时$minutes分钟';
  }
}
