import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/app_notification.dart';
import '../providers/notification_center_provider.dart';

class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.pureBlack,
        elevation: 0,
        title: const Text(
          '通知中心',
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
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz),
                color: AppColors.cardBg,
                onSelected: (value) {
                  if (value == 'read_all') {
                    provider.markAllRead();
                  } else if (value == 'clear_all') {
                    provider.clearAll();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'read_all',
                    child: Text('全部已读'),
                  ),
                  PopupMenuItem<String>(
                    value: 'clear_all',
                    child: Text('清空通知'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationCenterProvider>(
        builder: (context, provider, child) {
          final items = provider.items;
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '🔔',
                    style: TextStyle(
                      fontSize: 64,
                      color: AppColors.textTertiary.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '暂无通知',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(
              color: AppColors.white05,
              height: 1,
              indent: 16,
              endIndent: 16,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                onTap: () async {
                  await provider.markRead(item.id);
                  if (!context.mounted) return;
                  _handleTap(context, item);
                },
                onLongPress: () => provider.remove(item.id),
                leading: _buildLeading(item),
                title: Text(
                  item.title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight:
                        item.isRead ? FontWeight.w300 : FontWeight.w500,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    item.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                trailing: item.isRead
                    ? Text(
                        _formatTime(item.createdAt),
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      )
                    : Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.brandBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLeading(AppNotification item) {
    final icon = switch (item.type) {
      AppNotificationType.message => Icons.chat_bubble_outline,
      AppNotificationType.friendRequest => Icons.person_add_outlined,
      AppNotificationType.friendAccepted => Icons.favorite_border,
      AppNotificationType.system => Icons.info_outline,
    };
    return CircleAvatar(
      backgroundColor: AppColors.white08,
      child: Icon(icon, color: AppColors.textPrimary, size: 20),
    );
  }

  void _handleTap(BuildContext context, AppNotification item) {
    if (item.threadId != null) {
      context.push('/chat/${item.threadId}');
      return;
    }

    if (item.type == AppNotificationType.friendRequest ||
        item.type == AppNotificationType.friendAccepted) {
      context.go('/main?tab=2');
      return;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    return '${time.month}/${time.day}';
  }
}
