import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/chat_provider.dart';
import '../providers/friend_provider.dart';
import '../widgets/friends_tab.dart';
import '../widgets/match_tab.dart';
import '../widgets/messages_tab.dart';
import '../widgets/profile_tab.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  String _lastFriendSyncKey = '';
  bool _friendSyncQueued = false;

  final List<Widget> _tabs = const [
    MatchTab(),
    MessagesTab(),
    FriendsTab(),
    ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _tabs.length - 1);
  }

  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _currentIndex = widget.initialIndex.clamp(0, _tabs.length - 1);
    }
  }

  void _selectTab(int index, {bool syncRoute = true}) {
    final safeIndex = index.clamp(0, _tabs.length - 1);
    if (_currentIndex == safeIndex) return;

    setState(() {
      _currentIndex = safeIndex;
    });

    if (syncRoute && mounted) {
      context.go('/main?tab=$safeIndex');
    }
  }

  void _scheduleFriendSync(
    ChatProvider chatProvider,
    FriendProvider friendProvider,
  ) {
    final friendIds = friendProvider.friends.keys.toList()..sort();
    final nextSyncKey = friendIds.join('|');
    if (_friendSyncQueued || _lastFriendSyncKey == nextSyncKey) {
      return;
    }
    _friendSyncQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _friendSyncQueued = false;
      if (!mounted) return;
      final latestFriendIds =
          context.read<FriendProvider>().friends.keys.toSet();
      final latestSyncKey = latestFriendIds.toList()..sort();
      _lastFriendSyncKey = latestSyncKey.join('|');
      context.read<ChatProvider>().syncFriendRelationships(latestFriendIds);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final safeBottom = mediaQuery.padding.bottom;
    final compactNav = screenSize.height < 760 || screenSize.width < 390;
    final horizontalInset = (screenSize.width * 0.028).clamp(8.0, 14.0);
    final bottomInset = safeBottom > 0 ? 4.0 : 8.0;
    final navRadius = compactNav ? 18.0 : 20.0;
    final navBlur = compactNav ? 14.0 : 18.0;
    final navVerticalPadding = compactNav ? 6.0 : 8.0;
    final itemHorizontalPadding = compactNav ? 12.0 : 18.0;
    final itemVerticalPadding = compactNav ? 6.0 : 8.0;
    final itemRadius = compactNav ? 11.0 : 14.0;
    final iconSize = compactNav ? 21.0 : 24.0;
    final labelSize = compactNav ? 11.0 : 12.0;
    final labelGap = compactNav ? 3.0 : 4.0;
    final chatProvider = context.watch<ChatProvider>();
    final friendProvider = context.watch<FriendProvider>();
    _scheduleFriendSync(chatProvider, friendProvider);
    final unreadCount = chatProvider.threads.values.fold<int>(
      0,
      (sum, thread) => sum + thread.unreadCount,
    );
    final pendingCount = friendProvider.pendingRequestCount;

    return PopScope<void>(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentIndex != 0) {
          _selectTab(0);
        }
      },
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: _currentIndex,
          children: _tabs,
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalInset,
              0,
              horizontalInset,
              bottomInset,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: _buildNavFocusStrip(compactNav),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(navRadius),
                    child: BackdropFilter(
                      filter:
                          ImageFilter.blur(sigmaX: navBlur, sigmaY: navBlur),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.pureBlack.withValues(alpha: 0.46),
                          borderRadius: BorderRadius.circular(navRadius),
                          border: Border.all(
                            color: AppColors.white08,
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.pureBlack.withValues(alpha: 0.18),
                              blurRadius: compactNav ? 14 : 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: compactNav ? 6 : 8,
                            vertical: navVerticalPadding,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildNavItem(
                                  0,
                                  '匹配',
                                  Icons.whatshot_outlined,
                                  horizontalPadding: itemHorizontalPadding,
                                  verticalPadding: itemVerticalPadding,
                                  radius: itemRadius,
                                  iconSize: iconSize,
                                  labelSize: labelSize,
                                  labelGap: labelGap,
                                  isPrimary: true,
                                ),
                              ),
                              Expanded(
                                child: _buildNavItem(
                                  1,
                                  '消息',
                                  Icons.chat_bubble_outline,
                                  badgeCount: unreadCount,
                                  horizontalPadding: itemHorizontalPadding,
                                  verticalPadding: itemVerticalPadding,
                                  radius: itemRadius,
                                  iconSize: iconSize,
                                  labelSize: labelSize,
                                  labelGap: labelGap,
                                  isPrimary: true,
                                ),
                              ),
                              Expanded(
                                child: _buildNavItem(
                                  2,
                                  '好友',
                                  Icons.people_outline,
                                  badgeCount: pendingCount,
                                  horizontalPadding: compactNav ? 10 : 14,
                                  verticalPadding: itemVerticalPadding,
                                  radius: itemRadius,
                                  iconSize: iconSize,
                                  labelSize: labelSize,
                                  labelGap: labelGap,
                                ),
                              ),
                              Expanded(
                                child: _buildNavItem(
                                  3,
                                  '我的',
                                  Icons.person_outline,
                                  horizontalPadding: itemHorizontalPadding,
                                  verticalPadding: itemVerticalPadding,
                                  radius: itemRadius,
                                  iconSize: iconSize,
                                  labelSize: labelSize,
                                  labelGap: labelGap,
                                  isPrimary: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavFocusStrip(bool compactNav) {
    final title = switch (_currentIndex) {
      0 => '主路径：开始匹配',
      1 => '主路径：查看消息',
      2 => '辅助路径：处理好友关系',
      _ => '主路径：管理我的资料',
    };

    final subtitle = switch (_currentIndex) {
      0 => '现在就去遇见新的人，匹配成功后优先发一句问候。',
      1 => '先回复正在等你的人，别让高意向对话冷下来。',
      2 => '这里集中处理好友申请、关系确认和社交连接。',
      _ => '头像、背景、设置和账号信息都从这里进入。',
    };

    final icon = switch (_currentIndex) {
      0 => Icons.flash_on_outlined,
      1 => Icons.mark_chat_unread_outlined,
      2 => Icons.group_outlined,
      _ => Icons.person_2_outlined,
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Container(
        key: ValueKey<int>(_currentIndex),
        padding: EdgeInsets.symmetric(
          horizontal: compactNav ? 12 : 14,
          vertical: compactNav ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: AppColors.white05,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.white08),
        ),
        child: Row(
          children: [
            Container(
              width: compactNav ? 34 : 38,
              height: compactNav ? 34 : 38,
              decoration: BoxDecoration(
                color: AppColors.white08,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.textPrimary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textTertiary.withValues(alpha: 0.92),
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

  Widget _buildNavItem(
    int index,
    String label,
    IconData icon, {
    int badgeCount = 0,
    required double horizontalPadding,
    required double verticalPadding,
    required double radius,
    required double iconSize,
    required double labelSize,
    required double labelGap,
    bool isPrimary = false,
  }) {
    final isSelected = _currentIndex == index;
    final selectedColor =
        isPrimary ? AppColors.textPrimary : AppColors.textSecondary;

    return GestureDetector(
      onTap: () => _selectTab(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.white08 : Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          border: isSelected
              ? Border.all(color: AppColors.white12, width: 0.8)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: isSelected ? 26 : 0,
              height: 2,
              margin: EdgeInsets.only(bottom: isSelected ? 6 : 0),
              decoration: BoxDecoration(
                color: isPrimary ? AppColors.brandBlue : AppColors.textTertiary,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isSelected ? selectedColor : AppColors.textTertiary,
                  size: iconSize,
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -8,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: labelGap),
            Text(
              label,
              style: TextStyle(
                fontSize: labelSize,
                fontWeight: isSelected ? FontWeight.w400 : FontWeight.w300,
                color: isSelected ? selectedColor : AppColors.textTertiary,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
