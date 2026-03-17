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

class _NotificationCenterLayoutSpec {
  const _NotificationCenterLayoutSpec({
    required this.isCompact,
    required this.pagePadding,
    required this.bannerSpacing,
    required this.filterSpacing,
    required this.filterRunSpacing,
    required this.filterHorizontalPadding,
    required this.filterVerticalPadding,
    required this.tilePadding,
    required this.tileGap,
    required this.leadingSize,
    required this.leadingIconSize,
    required this.titleSize,
    required this.bodySize,
    required this.metaSize,
  });

  final bool isCompact;
  final EdgeInsets pagePadding;
  final double bannerSpacing;
  final double filterSpacing;
  final double filterRunSpacing;
  final double filterHorizontalPadding;
  final double filterVerticalPadding;
  final EdgeInsets tilePadding;
  final double tileGap;
  final double leadingSize;
  final double leadingIconSize;
  final double titleSize;
  final double bodySize;
  final double metaSize;

  static _NotificationCenterLayoutSpec fromSize(Size size) {
    final isCompact = size.width <= 390 || size.height <= 720;
    if (isCompact) {
      return const _NotificationCenterLayoutSpec(
        isCompact: true,
        pagePadding: EdgeInsets.fromLTRB(12, 8, 12, 20),
        bannerSpacing: 10,
        filterSpacing: 6,
        filterRunSpacing: 6,
        filterHorizontalPadding: 9,
        filterVerticalPadding: 6,
        tilePadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        tileGap: 10,
        leadingSize: 38,
        leadingIconSize: 18,
        titleSize: 13.5,
        bodySize: 11.5,
        metaSize: 10.5,
      );
    }

    return const _NotificationCenterLayoutSpec(
      isCompact: false,
      pagePadding: EdgeInsets.fromLTRB(16, 12, 16, 24),
      bannerSpacing: 12,
      filterSpacing: 8,
      filterRunSpacing: 8,
      filterHorizontalPadding: 10,
      filterVerticalPadding: 7,
      tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      tileGap: 12,
      leadingSize: 40,
      leadingIconSize: 20,
      titleSize: 14,
      bodySize: 12,
      metaSize: 12,
    );
  }
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
    final layout = _NotificationCenterLayoutSpec.fromSize(
      MediaQuery.of(context).size,
    );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.pureBlack,
        elevation: 0,
        title: const Text(
          '通知中心',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
          ),
        ),
        centerTitle: false,
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
            padding: layout.pagePadding,
            children: [
              if (showPermissionNotice) ...[
                NotificationPermissionNoticeCard(
                  key: const Key('notification-center-permission-banner'),
                  description: NotificationPermissionGuidance
                      .notificationCenterDescription,
                  actionLabel:
                      NotificationPermissionGuidance.openSettingsPageAction,
                  compact: layout.isCompact,
                  actionKey: const Key(
                    'notification-center-permission-action',
                  ),
                  onActionPressed: () => context.push('/settings'),
                ),
                SizedBox(height: layout.bannerSpacing),
              ],
              if (items.isNotEmpty) ...[
                _buildFilterBar(layout),
                SizedBox(height: layout.bannerSpacing),
              ],
              if (filteredItems.isEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    top: showPermissionNotice
                        ? (layout.isCompact ? 28 : 40)
                        : (layout.isCompact ? 88 : 120),
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
                    _buildNotificationTile(
                      context,
                      provider,
                      entry.value,
                      layout,
                    ),
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

  Widget _buildFilterBar(_NotificationCenterLayoutSpec layout) {
    return Wrap(
      spacing: layout.filterSpacing,
      runSpacing: layout.filterRunSpacing,
      children: NotificationCenterSourceFilter.values
          .map((filter) => _buildFilterChip(filter, layout))
          .toList(),
    );
  }

  Widget _buildFilterChip(
    NotificationCenterSourceFilter filter,
    _NotificationCenterLayoutSpec layout,
  ) {
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
        padding: EdgeInsets.symmetric(
          horizontal: layout.filterHorizontalPadding,
          vertical: layout.filterVerticalPadding,
        ),
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
              size: layout.isCompact ? 12 : 13,
              color: selected ? AppColors.brandBlue : AppColors.textSecondary,
            ),
            SizedBox(width: layout.isCompact ? 5 : 6),
            Text(
              label,
              style: TextStyle(
                fontSize: layout.isCompact ? 11.5 : 12,
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
    _NotificationCenterLayoutSpec layout,
  ) {
    return InkWell(
      key: Key('notification-center-item-${item.id}'),
      onTap: () async {
        await provider.markRead(item.id);
        if (!context.mounted) return;
        _handleTap(context, item);
      },
      onLongPress: () => provider.remove(item.id),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: layout.tilePadding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLeading(item, layout),
            SizedBox(width: layout.tileGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: layout.titleSize,
                            color: AppColors.textPrimary,
                            fontWeight:
                                item.isRead ? FontWeight.w300 : FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      item.isRead
                          ? Text(
                              _formatTime(item.createdAt),
                              style: TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: layout.metaSize,
                              ),
                            )
                          : Container(
                              width: layout.isCompact ? 8 : 10,
                              height: layout.isCompact ? 8 : 10,
                              decoration: const BoxDecoration(
                                color: AppColors.brandBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                    ],
                  ),
                  SizedBox(height: layout.isCompact ? 4 : 6),
                  Text(
                    item.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: layout.bodySize,
                      height: 1.35,
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

  Widget _buildLeading(
    AppNotification item,
    _NotificationCenterLayoutSpec layout,
  ) {
    final icon = switch (item.type) {
      AppNotificationType.message => Icons.chat_bubble_outline,
      AppNotificationType.friendRequest => Icons.person_add_outlined,
      AppNotificationType.friendAccepted => Icons.favorite_border,
      AppNotificationType.system => Icons.info_outline,
    };
    return Container(
      width: layout.leadingSize,
      height: layout.leadingSize,
      decoration: const BoxDecoration(
        color: AppColors.white08,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: AppColors.textPrimary,
        size: layout.leadingIconSize,
      ),
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
