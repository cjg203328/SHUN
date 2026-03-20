import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';
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
  late final List<Widget> _tabChildren;
  String _lastFriendSyncKey = '';
  bool _friendSyncQueued = false;
  Timer? _routeHintTimer;
  bool _showRouteSyncHint = false;
  String? _lastHandledEntryHintKey;
  int _lastHandledAuthEntryHintVersion = 0;
  static const int _tabCount = 4;

  @override
  void initState() {
    super.initState();
    _currentIndex = _sanitizeIndex(widget.initialIndex);
    _tabChildren = const <Widget>[
      MessagesTab(),
      MatchTab(),
      FriendsTab(),
      ProfileTab(),
    ];
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

  @override
  void dispose() {
    _routeHintTimer?.cancel();
    super.dispose();
  }

  int _sanitizeIndex(int index) => index.clamp(0, _tabCount - 1);

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

  String? _resolveRouteEntrySource() {
    try {
      return GoRouterState.of(context).uri.queryParameters['entry'];
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

  ({String key, String source})? _resolveEntryHintRequest({
    required String? routeEntrySource,
    required int authEntryHintVersion,
  }) {
    if (routeEntrySource != null && routeEntrySource.isNotEmpty) {
      if (authEntryHintVersion > _lastHandledAuthEntryHintVersion) {
        _lastHandledAuthEntryHintVersion = authEntryHintVersion;
        context.read<AuthProvider>().consumePendingEntryHintSource();
      }
      return (key: 'route:$routeEntrySource', source: routeEntrySource);
    }

    if (authEntryHintVersion <= _lastHandledAuthEntryHintVersion) {
      return null;
    }

    _lastHandledAuthEntryHintVersion = authEntryHintVersion;
    final pendingSource =
        context.read<AuthProvider>().consumePendingEntryHintSource();
    if (pendingSource == null || pendingSource.isEmpty) {
      return null;
    }

    return (
      key: 'auth:$authEntryHintVersion:$pendingSource',
      source: pendingSource,
    );
  }

  void _scheduleRouteEntryHint({
    required String? routeEntrySource,
    required int authEntryHintVersion,
  }) {
    final request = _resolveEntryHintRequest(
      routeEntrySource: routeEntrySource,
      authEntryHintVersion: authEntryHintVersion,
    );
    if (request == null || request.key == _lastHandledEntryHintKey) {
      return;
    }
    _lastHandledEntryHintKey = request.key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (request.source == 'login') {
        _showPostLoginSyncHint();
      }
    });
  }

  void _showPostLoginSyncHint() {
    _routeHintTimer?.cancel();
    setState(() {
      _showRouteSyncHint = true;
    });
    _routeHintTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() {
        _showRouteSyncHint = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final compactNav = screenSize.height < 760 || screenSize.width < 390;
    final navBlurSigma = compactNav ? 10.0 : 13.0;
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
    final pendingEntryHintVersion = context.select<AuthProvider, int>(
      (provider) => provider.pendingEntryHintVersion,
    );
    final friendSyncKey = context.select<FriendProvider, String>((provider) {
      final friendIds = provider.friends.keys.toList()..sort();
      return friendIds.join('|');
    });
    _scheduleFriendSync(friendSyncKey);
    _scheduleRouteEntryHint(
      routeEntrySource: _resolveRouteEntrySource(),
      authEntryHintVersion: pendingEntryHintVersion,
    );

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
              child: Stack(
                children: [
                  RepaintBoundary(
                    child: IndexedStack(
                      key: const Key('main-tab-stack'),
                      index: _currentIndex,
                      children: _tabChildren,
                    ),
                  ),
                  Positioned(
                    top: mediaQuery.padding.top + 12,
                    left: 14,
                    right: 14,
                    child: !_showRouteSyncHint
                        ? const SizedBox.shrink()
                        : IgnorePointer(
                            child: Container(
                              key: const Key('main-entry-sync-hint'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.pureBlack.withValues(alpha: 0.76),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.white12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.pureBlack
                                        .withValues(alpha: 0.18),
                                    blurRadius: 12,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      key: Key('main-entry-sync-spinner'),
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.brandBlue,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '已登录，首页正在同步资料、消息和通知',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w300,
                                        color: AppColors.textPrimary,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            RepaintBoundary(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: navBlurSigma,
                    sigmaY: navBlurSigma,
                  ),
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
    final iconColor =
        isSelected ? AppColors.textPrimary : AppColors.textTertiary;
    final labelColor =
        isSelected ? AppColors.textSecondary : AppColors.textTertiary;

    return GestureDetector(
      onTap: () => _selectTab(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (isSelected)
                Container(
                  width: iconSize * 1.8,
                  height: iconSize * 1.8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.brandBlue.withValues(alpha: 0.08),
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
          SizedBox(
            height: 4,
            child: Center(
              child: isSelected
                  ? Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: AppColors.brandBlue,
                        shape: BoxShape.circle,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
