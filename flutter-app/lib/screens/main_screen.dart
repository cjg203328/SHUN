import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/chat_provider.dart';
import '../providers/friend_provider.dart';
import '../widgets/match_tab.dart';
import '../widgets/messages_tab.dart';
import '../widgets/friends_tab.dart';
import '../widgets/profile_tab.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;

  final List<Widget> _tabs = const [
    MatchTab(),
    MessagesTab(),
    FriendsTab(),
    ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
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
    final itemHorizontalPadding = compactNav ? 14.0 : 20.0;
    final itemVerticalPadding = compactNav ? 6.0 : 8.0;
    final itemRadius = compactNav ? 10.0 : 12.0;
    final iconSize = compactNav ? 22.0 : 24.0;
    final labelSize = compactNav ? 11.0 : 12.0;
    final labelGap = compactNav ? 3.0 : 4.0;

    return Scaffold(
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(navRadius),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: navBlur, sigmaY: navBlur),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.pureBlack.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(navRadius),
                        border:
                            Border.all(color: AppColors.white08, width: 0.7),
                      ),
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: navVerticalPadding),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildNavItem(
                              0,
                              '匹配',
                              Icons.whatshot_outlined,
                              horizontalPadding: itemHorizontalPadding,
                              verticalPadding: itemVerticalPadding,
                              radius: itemRadius,
                              iconSize: iconSize,
                              labelSize: labelSize,
                              labelGap: labelGap,
                            ),
                            _buildNavItem(
                              1,
                              '消息',
                              Icons.chat_bubble_outline,
                              badgeCount: context.watch<ChatProvider>().threads
                                  .values
                                  .fold<int>(0, (sum, thread) => sum + thread.unreadCount),
                              horizontalPadding: itemHorizontalPadding,
                              verticalPadding: itemVerticalPadding,
                              radius: itemRadius,
                              iconSize: iconSize,
                              labelSize: labelSize,
                              labelGap: labelGap,
                            ),
                            _buildNavItem(
                              2,
                              '好友',
                              Icons.people_outline,
                              badgeCount:
                                  context.watch<FriendProvider>().pendingRequestCount,
                              horizontalPadding: itemHorizontalPadding,
                              verticalPadding: itemVerticalPadding,
                              radius: itemRadius,
                              iconSize: iconSize,
                              labelSize: labelSize,
                              labelGap: labelGap,
                            ),
                            _buildNavItem(
                              3,
                              '我的',
                              Icons.person_outline,
                              horizontalPadding: itemHorizontalPadding,
                              verticalPadding: itemVerticalPadding,
                              radius: itemRadius,
                              iconSize: iconSize,
                              labelSize: labelSize,
                              labelGap: labelGap,
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
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.white05 : Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
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
                          color: Colors.white,
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
                fontWeight: FontWeight.w300,
                color:
                    isSelected ? AppColors.textPrimary : AppColors.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
