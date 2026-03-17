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
  static const int _tabCount = 4;

  @override
  void initState() {
    super.initState();
    _currentIndex = _sanitizeIndex(widget.initialIndex);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncCurrentIndexFromRoute();
  }

  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _currentIndex = _sanitizeIndex(widget.initialIndex);
      _syncCurrentIndexFromRoute();
    }
  }

  int _sanitizeIndex(int index) => index.clamp(0, _tabCount - 1);

  Widget _buildTab(int index) {
    return switch (index) {
      0 => const MessagesTab(),
      1 => const MatchTab(),
      2 => const FriendsTab(),
      _ => const ProfileTab(),
    };
  }

  void _syncCurrentIndexFromRoute() {
    final routeIndex = _resolveRouteIndex();
    if (routeIndex != null && routeIndex != _currentIndex) {
      _currentIndex = routeIndex;
    }
  }

  int? _resolveRouteIndex() {
    try {
      final tab = GoRouterState.of(context).uri.queryParameters['tab'];
      if (tab == null) {
        return null;
      }
      return _sanitizeIndex(int.tryParse(tab) ?? widget.initialIndex);
    } catch (_) {
      return null;
    }
  }

  void _selectTab(int index, {bool syncRoute = true}) {
    final safeIndex = _sanitizeIndex(index);
    if (_currentIndex == safeIndex) return;

    setState(() {
      _currentIndex = safeIndex;
    });

    if (syncRoute && mounted) {
      context.go('/main?tab=$safeIndex');
    }
  }

  void _scheduleFriendSync(String nextSyncKey) {
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
    final compactNav = screenSize.height < 760 || screenSize.width < 390;
    final iconSize = compactNav ? 21.0 : 23.0;
    final labelSize = compactNav ? 11.0 : 12.0;

    final unreadCount = context.select<ChatProvider, int>(
      (provider) => provider.threads.values.fold<int>(
        0,
        (sum, thread) => sum + thread.unreadCount,
      ),
    );
    final pendingCount = context.select<FriendProvider, int>(
      (provider) => provider.pendingRequestCount,
    );
    final friendSyncKey = context.select<FriendProvider, String>((provider) {
      final friendIds = provider.friends.keys.toList()..sort();
      return friendIds.join('|');
    });
    _scheduleFriendSync(friendSyncKey);

    return PopScope<void>(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentIndex != 0) {
          _selectTab(0);
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: RepaintBoundary(
                child: Stack(
                  key: const Key('main-tab-stack'),
                  children: List<Widget>.generate(
                    _tabCount,
                    (index) => Positioned.fill(
                      child: Visibility(
                        visible: _currentIndex == index,
                        maintainAnimation: true,
                        maintainState: true,
                        child: TickerMode(
                          enabled: _currentIndex == index,
                          child: RepaintBoundary(
                            child: AnimatedOpacity(
                              opacity: _currentIndex == index ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              child: _buildTab(index),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            RepaintBoundary(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.pureBlack.withValues(alpha: 0.82),
                      border: const Border(
                        top: BorderSide(color: AppColors.white08, width: 0.5),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: compactNav ? 8.0 : 16.0,
                          vertical: compactNav ? 6.0 : 8.0,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildNavItem(
                                0,
                                '消息',
                                Icons.chat_bubble_outline_rounded,
                                Icons.chat_bubble_rounded,
                                badgeCount: unreadCount,
                                iconSize: iconSize,
                                labelSize: labelSize,
                              ),
                            ),
                            Expanded(
                              child: _buildNavItem(
                                1,
                                '匹配',
                                Icons.bolt_outlined,
                                Icons.bolt,
                                iconSize: iconSize + 3,
                                labelSize: labelSize,
                              ),
                            ),
                            Expanded(
                              child: _buildNavItem(
                                2,
                                '好友',
                                Icons.people_outline_rounded,
                                Icons.people_rounded,
                                badgeCount: pendingCount,
                                iconSize: iconSize,
                                labelSize: labelSize,
                              ),
                            ),
                            Expanded(
                              child: _buildNavItem(
                                3,
                                '我的',
                                Icons.person_outline_rounded,
                                Icons.person_rounded,
                                iconSize: iconSize,
                                labelSize: labelSize,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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
    IconData outlineIcon,
    IconData filledIcon, {
    int badgeCount = 0,
    required double iconSize,
    required double labelSize,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => _selectTab(index),
      behavior: HitTestBehavior.opaque,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: isSelected ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) {
          final dy = -4.0 * t;
          final iconColor = Color.lerp(
            AppColors.textTertiary,
            AppColors.textPrimary,
            t,
          )!;
          final labelColor = Color.lerp(
            AppColors.textTertiary,
            AppColors.textSecondary,
            t,
          )!;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.translate(
                offset: Offset(0, dy),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // glow behind icon when selected
                    if (t > 0.01)
                      Container(
                        width: iconSize * 1.8,
                        height: iconSize * 1.8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              AppColors.brandBlue.withValues(alpha: 0.08 * t),
                        ),
                      ),
                    Icon(
                      isSelected ? filledIcon : outlineIcon,
                      color: iconColor,
                      size: iconSize,
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        right: -10,
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
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: labelSize,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w300,
                  color: labelColor,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              // liquid dot indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: isSelected ? 4 : 0,
                height: isSelected ? 4 : 0,
                decoration: BoxDecoration(
                  color: AppColors.brandBlue,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
