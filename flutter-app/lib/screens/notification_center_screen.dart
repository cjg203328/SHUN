import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/app_notification.dart';
import '../providers/chat_provider.dart';
import '../providers/notification_center_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/notification_permission_guidance.dart';
import '../widgets/notification_permission_notice_card.dart';

enum NotificationCenterSourceFilter {
  all,
  message,
  friend,
  system,
  ;

  static NotificationCenterSourceFilter fromQuery(String? value) {
    return NotificationCenterSourceFilter.values.firstWhere(
      (filter) => filter.name == value,
      orElse: () => NotificationCenterSourceFilter.all,
    );
  }
}

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({
    super.key,
    this.initialFilter = NotificationCenterSourceFilter.all,
  });

  final NotificationCenterSourceFilter initialFilter;

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  late NotificationCenterSourceFilter _selectedFilter;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
  }

  @override
  void didUpdateWidget(covariant NotificationCenterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilter != widget.initialFilter) {
      _selectedFilter = widget.initialFilter;
    }
  }

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
          final filteredItems = items
              .where((item) => _matchesFilter(item, _selectedFilter))
              .toList();
          final settingsProvider = Provider.of<SettingsProvider?>(context);
          final showPermissionNotice = settingsProvider != null &&
              NotificationPermissionGuidance.needsSystemPermission(
                notificationEnabled: settingsProvider.notificationEnabled,
                permissionGranted:
                    settingsProvider.pushRuntimeState.permissionGranted,
              );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              if (showPermissionNotice) ...[
                NotificationPermissionNoticeCard(
                  key: const Key('notification-center-permission-banner'),
                  description: NotificationPermissionGuidance
                      .notificationCenterDescription,
                  actionLabel:
                      NotificationPermissionGuidance.openSettingsPageAction,
                  actionKey: const Key(
                    'notification-center-permission-action',
                  ),
                  onActionPressed: () => context.push('/settings'),
                ),
                const SizedBox(height: 12),
              ],
              if (items.isNotEmpty) ...[
                _buildFilterBar(),
                const SizedBox(height: 12),
              ],
              if (filteredItems.isEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    top: showPermissionNotice ? 40 : 120,
                  ),
                  child: _buildEmptyState(
                    context,
                    hasAnyItems: items.isNotEmpty,
                  ),
                )
              else
                ...filteredItems.asMap().entries.expand((entry) {
                  final isLast = entry.key == filteredItems.length - 1;
                  return <Widget>[
                    _buildNotificationTile(context, provider, entry.value),
                    if (!isLast)
                      Divider(
                        color: AppColors.white05,
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                      ),
                  ];
                }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          NotificationCenterSourceFilter.values.map(_buildFilterChip).toList(),
    );
  }

  Widget _buildFilterChip(NotificationCenterSourceFilter filter) {
    final selected = _selectedFilter == filter;
    final label = switch (filter) {
      NotificationCenterSourceFilter.all => '全部',
      NotificationCenterSourceFilter.message => '消息',
      NotificationCenterSourceFilter.friend => '好友',
      NotificationCenterSourceFilter.system => '系统',
    };
    final icon = switch (filter) {
      NotificationCenterSourceFilter.all => Icons.inbox_outlined,
      NotificationCenterSourceFilter.message => Icons.chat_bubble_outline,
      NotificationCenterSourceFilter.friend => Icons.person_add_outlined,
      NotificationCenterSourceFilter.system => Icons.info_outline,
    };

    return InkWell(
      key: Key('notification-center-filter-${filter.name}'),
      onTap: () {
        if (_selectedFilter == filter) return;
        setState(() {
          _selectedFilter = filter;
        });
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandBlue.withValues(alpha: 0.14)
              : AppColors.white05,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.brandBlue.withValues(alpha: 0.22)
                : AppColors.white08,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? AppColors.brandBlue : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w300,
                color: selected ? AppColors.brandBlue : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required bool hasAnyItems,
  }) {
    final emptyTitle =
        hasAnyItems && _selectedFilter != NotificationCenterSourceFilter.all
            ? switch (_selectedFilter) {
                NotificationCenterSourceFilter.all => '暂无通知',
                NotificationCenterSourceFilter.message => '当前没有消息提醒',
                NotificationCenterSourceFilter.friend => '当前没有好友相关提醒',
                NotificationCenterSourceFilter.system => '当前没有系统提醒',
              }
            : '暂无通知';

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
            emptyTitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textTertiary,
                ),
          ),
        ],
      ),
    );
  }

  bool _matchesFilter(
    AppNotification item,
    NotificationCenterSourceFilter filter,
  ) {
    return switch (filter) {
      NotificationCenterSourceFilter.all => true,
      NotificationCenterSourceFilter.message =>
        item.type == AppNotificationType.message,
      NotificationCenterSourceFilter.friend =>
        item.type == AppNotificationType.friendRequest ||
            item.type == AppNotificationType.friendAccepted,
      NotificationCenterSourceFilter.system =>
        item.type == AppNotificationType.system,
    };
  }

  Widget _buildNotificationTile(
    BuildContext context,
    NotificationCenterProvider provider,
    AppNotification item,
  ) {
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
          fontWeight: item.isRead ? FontWeight.w300 : FontWeight.w500,
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
      final chatProvider = context.read<ChatProvider>();
      final canonicalThreadId = chatProvider.routeThreadId(
        threadId: item.threadId,
        userId: item.userId,
      );
      if (canonicalThreadId != null) {
        context.push('/chat/$canonicalThreadId');
      }
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
