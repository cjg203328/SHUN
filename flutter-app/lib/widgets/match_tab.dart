import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/match_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/friend_provider.dart';
import '../models/models.dart';
import '../core/feedback/app_feedback.dart';
import '../utils/permission_manager.dart';
import 'app_user_avatar.dart';

class MatchTab extends StatefulWidget {
  const MatchTab({super.key});

  @override
  State<MatchTab> createState() => _MatchTabState();
}

class _MatchLayoutSpec {
  const _MatchLayoutSpec({
    required this.isCompact,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.titleSize,
    required this.titleLetterSpacing,
    required this.titleToSubtitleSpacing,
    required this.subtitleSize,
    required this.subtitleLetterSpacing,
    required this.subtitleToCountSpacing,
    required this.countHorizontalPadding,
    required this.countVerticalPadding,
    required this.countSize,
    required this.countUnitSpacing,
    required this.countUnitSize,
    required this.countToResetSpacing,
    required this.resetHintSize,
    required this.resetToStatusSpacing,
    required this.statusChipHorizontalPadding,
    required this.statusChipVerticalPadding,
    required this.statusChipIconSize,
    required this.statusChipIconSpacing,
    required this.statusChipTextSize,
    required this.headerToGuideSpacing,
    required this.guideHorizontalPadding,
    required this.guideVerticalPadding,
    required this.guideRadius,
    required this.guideIconSize,
    required this.guideIconSpacing,
    required this.guideTextSize,
    required this.guideToOrbSpacing,
    required this.orbSize,
    required this.orbShadowBlur,
    required this.orbShadowSpread,
    required this.orbToFeedbackSpacing,
    required this.feedbackGap,
    required this.buttonVerticalPadding,
    required this.buttonTextSize,
    required this.buttonToHelperSpacing,
    required this.helperTextSize,
    required this.helperToLocationSpacing,
    required this.locationHintSize,
  });

  final bool isCompact;
  final double horizontalPadding;
  final double verticalPadding;
  final double titleSize;
  final double titleLetterSpacing;
  final double titleToSubtitleSpacing;
  final double subtitleSize;
  final double subtitleLetterSpacing;
  final double subtitleToCountSpacing;
  final double countHorizontalPadding;
  final double countVerticalPadding;
  final double countSize;
  final double countUnitSpacing;
  final double countUnitSize;
  final double countToResetSpacing;
  final double resetHintSize;
  final double resetToStatusSpacing;
  final double statusChipHorizontalPadding;
  final double statusChipVerticalPadding;
  final double statusChipIconSize;
  final double statusChipIconSpacing;
  final double statusChipTextSize;
  final double headerToGuideSpacing;
  final double guideHorizontalPadding;
  final double guideVerticalPadding;
  final double guideRadius;
  final double guideIconSize;
  final double guideIconSpacing;
  final double guideTextSize;
  final double guideToOrbSpacing;
  final double orbSize;
  final double orbShadowBlur;
  final double orbShadowSpread;
  final double orbToFeedbackSpacing;
  final double feedbackGap;
  final double buttonVerticalPadding;
  final double buttonTextSize;
  final double buttonToHelperSpacing;
  final double helperTextSize;
  final double helperToLocationSpacing;
  final double locationHintSize;

  static _MatchLayoutSpec fromConstraints(BoxConstraints constraints) {
    final isCompact =
        constraints.maxHeight <= 720 || constraints.maxWidth <= 390;
    if (isCompact) {
      return const _MatchLayoutSpec(
        isCompact: true,
        horizontalPadding: 18,
        verticalPadding: 22,
        titleSize: 24,
        titleLetterSpacing: 6,
        titleToSubtitleSpacing: 12,
        subtitleSize: 13,
        subtitleLetterSpacing: 1.2,
        subtitleToCountSpacing: 24,
        countHorizontalPadding: 24,
        countVerticalPadding: 14,
        countSize: 48,
        countUnitSpacing: 10,
        countUnitSize: 16,
        countToResetSpacing: 6,
        resetHintSize: 11,
        resetToStatusSpacing: 12,
        statusChipHorizontalPadding: 12,
        statusChipVerticalPadding: 8,
        statusChipIconSize: 14,
        statusChipIconSpacing: 6,
        statusChipTextSize: 11,
        headerToGuideSpacing: 14,
        guideHorizontalPadding: 12,
        guideVerticalPadding: 10,
        guideRadius: 12,
        guideIconSize: 16,
        guideIconSpacing: 8,
        guideTextSize: 11,
        guideToOrbSpacing: 24,
        orbSize: 164,
        orbShadowBlur: 30,
        orbShadowSpread: 10,
        orbToFeedbackSpacing: 20,
        feedbackGap: 14,
        buttonVerticalPadding: 14,
        buttonTextSize: 14,
        buttonToHelperSpacing: 8,
        helperTextSize: 11,
        helperToLocationSpacing: 6,
        locationHintSize: 11,
      );
    }

    return const _MatchLayoutSpec(
      isCompact: false,
      horizontalPadding: 20,
      verticalPadding: 40,
      titleSize: 28,
      titleLetterSpacing: 8,
      titleToSubtitleSpacing: 16,
      subtitleSize: 14,
      subtitleLetterSpacing: 2,
      subtitleToCountSpacing: 48,
      countHorizontalPadding: 32,
      countVerticalPadding: 20,
      countSize: 56,
      countUnitSpacing: 12,
      countUnitSize: 18,
      countToResetSpacing: 8,
      resetHintSize: 12,
      resetToStatusSpacing: 16,
      statusChipHorizontalPadding: 14,
      statusChipVerticalPadding: 9,
      statusChipIconSize: 15,
      statusChipIconSpacing: 7,
      statusChipTextSize: 12,
      headerToGuideSpacing: 18,
      guideHorizontalPadding: 14,
      guideVerticalPadding: 12,
      guideRadius: 14,
      guideIconSize: 18,
      guideIconSpacing: 10,
      guideTextSize: 12,
      guideToOrbSpacing: 42,
      orbSize: 200,
      orbShadowBlur: 44,
      orbShadowSpread: 14,
      orbToFeedbackSpacing: 34,
      feedbackGap: 18,
      buttonVerticalPadding: 16,
      buttonTextSize: 15,
      buttonToHelperSpacing: 10,
      helperTextSize: 12,
      helperToLocationSpacing: 8,
      locationHintSize: 12,
    );
  }
}

class _MatchTabState extends State<MatchTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _orbController;
  final TextEditingController _greetingController = TextEditingController();
  String? _selectedQuickGreeting;
  Timer? _greetingBannerTimer;
  String? _recentThreadId;
  String _recentNickname = '';
  bool _showGreetingBanner = false;
  bool _isPreparingMatch = false;

  static const List<String> _defaultQuickGreetings = [
    '嗨，你好',
    '晚上好呀',
    '想聊聊吗',
    '今天过得怎么样',
    '刚好看到你',
    '想认识一下你'
  ];

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
      value: 0.65,
    );
  }

  @override
  void dispose() {
    _orbController.dispose();
    _greetingController.dispose();
    _greetingBannerTimer?.cancel();
    super.dispose();
  }

  void _syncOrbAnimation(bool shouldAnimate) {
    if (shouldAnimate) {
      if (!_orbController.isAnimating) {
        _orbController.repeat(reverse: true);
      }
      return;
    }

    if (_orbController.isAnimating) {
      _orbController.stop();
    }
    if (_orbController.value != 0.65) {
      _orbController.value = 0.65;
    }
  }

  void _showGreetingSentFeedback(ChatThread thread) {
    _greetingBannerTimer?.cancel();
    final canonicalThreadId = context.read<ChatProvider>().routeThreadId(
              threadId: thread.id,
              userId: thread.otherUser.id,
            ) ??
        thread.id;
    setState(() {
      _recentThreadId = canonicalThreadId;
      _recentNickname = thread.otherUser.nickname;
      _showGreetingBanner = true;
    });

    _greetingBannerTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() {
        _showGreetingBanner = false;
      });
    });
  }

  void _openRecentChat() {
    final recentThreadId = _recentThreadId;
    if (recentThreadId == null) return;
    final canonicalThreadId = context.read<ChatProvider>().routeThreadId(
              threadId: recentThreadId,
            ) ??
        recentThreadId;
    context.push('/chat/$canonicalThreadId');
  }

  Future<void> _handleMatchButtonPressed(MatchProvider provider) async {
    if (_isPreparingMatch) return;
    if (provider.matchCount <= 0) return;

    if (provider.isMatching) {
      provider.cancelMatch();
      return;
    }

    setState(() {
      _isPreparingMatch = true;
    });

    try {
      await PermissionManager.requestLocationPermission(context);
      if (!mounted) return;

      final blockedUserIds = context.read<FriendProvider>().blockedUserIds;
      await provider.startMatch(excludedUserIds: blockedUserIds);
      if (!mounted) return;
      final failureMessage = provider.lastFailureMessage;
      if (failureMessage != null && failureMessage.isNotEmpty) {
        AppFeedback.showError(
          context,
          AppErrorCode.unknown,
          detail: failureMessage,
        );
      }

      // 刷新按钮下方提示，避免反复弹窗覆盖主操作区
      setState(() {});
    } finally {
      if (mounted) {
        setState(() {
          _isPreparingMatch = false;
        });
      }
    }
  }

  void _sendGreetingAndBackToMatch(MatchProvider provider, String greeting) {
    final matchedUser = provider.matchedUser;
    if (matchedUser == null) return;

    // 先回到匹配页，保证用户可立即开始下一次匹配
    provider.clearMatchedUser();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final chatProvider = context.read<ChatProvider>();
      unawaited(() async {
        final thread =
            await chatProvider.ensureDirectThreadForUser(matchedUser);
        if (!mounted) return;
        final queued = chatProvider.sendMessage(thread.id, greeting);
        if (queued) {
          _showGreetingSentFeedback(thread);
        } else {
          AppFeedback.showError(context, AppErrorCode.sendFailed);
        }
      }());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.pureBlack,
        elevation: 0,
        title: const Text(
          '匹配',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, size: 22),
            color: AppColors.textSecondary,
            tooltip: '历史对话',
            onPressed: () => context.go('/main?tab=0'),
          ),
        ],
      ),
      body: Consumer<MatchProvider>(
        builder: (context, matchProvider, child) {
          _syncOrbAnimation(matchProvider.isMatching);
          // 匹配成功后显示全屏卡片（带入场动画）
          if (matchProvider.matchedUser != null) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: _buildScrollableMatchCard(matchProvider),
            );
          }

          // 未匹配时显示匹配界面
          return LayoutBuilder(
            builder: (context, constraints) {
              final layout = _MatchLayoutSpec.fromConstraints(constraints);
              final shouldShowGuideCard =
                  _shouldShowMatchingGuide(matchProvider);
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: layout.horizontalPadding,
                  vertical: layout.verticalPadding,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        (constraints.maxHeight - (layout.verticalPadding * 2))
                            .clamp(0.0, double.infinity),
                  ),
                  child: Column(
                    mainAxisAlignment: layout.isCompact
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 顶部情感化文案 + 次数显示
                      _buildHeader(matchProvider, layout),

                      SizedBox(
                        height: shouldShowGuideCard
                            ? layout.headerToGuideSpacing
                            : (layout.isCompact ? 10 : 14),
                      ),

                      if (shouldShowGuideCard)
                        _buildMatchingGuide(matchProvider, layout),

                      SizedBox(
                        height: shouldShowGuideCard
                            ? layout.guideToOrbSpacing
                            : (layout.isCompact ? 18 : 28),
                      ),

                      // 光球
                      _buildMatchOrb(matchProvider, layout),

                      SizedBox(height: layout.orbToFeedbackSpacing),

                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        child: _showGreetingBanner
                            ? _buildGreetingFeedback()
                            : const SizedBox(height: 0),
                      ),

                      SizedBox(
                        height: _showGreetingBanner ? layout.feedbackGap : 0,
                      ),

                      // 按钮
                      _buildMatchButton(matchProvider, layout),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader(MatchProvider provider, _MatchLayoutSpec layout) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 次数显示区域
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: layout.countHorizontalPadding,
            vertical: layout.countVerticalPadding,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${provider.matchCount}',
                style: TextStyle(
                  fontSize: layout.countSize,
                  fontWeight: FontWeight.w200,
                  color: AppColors.textPrimary,
                  height: 1,
                ),
              ),
              SizedBox(width: layout.countUnitSpacing),
              Text(
                '次',
                style: TextStyle(
                  fontSize: layout.countUnitSize,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textSecondary,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: layout.countToResetSpacing),

        // 说明文字
        Text(
          provider.matchCount > 0 ? '今日剩余机会' : '明日 9:00 重置',
          style: TextStyle(
            fontSize: layout.resetHintSize,
            fontWeight: FontWeight.w300,
            color: AppColors.textTertiary.withValues(alpha: 0.6),
            letterSpacing: 2,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: layout.resetToStatusSpacing),
        _buildStatusChip(provider, layout),
      ],
    );
  }

  Widget _buildStatusChip(MatchProvider provider, _MatchLayoutSpec layout) {
    final failureMessage = provider.lastFailureMessage;
    final isFailureState = !provider.isMatching &&
        provider.matchCount > 0 &&
        failureMessage != null &&
        failureMessage.isNotEmpty;
    final bool locationSkipped =
        PermissionManager.getSessionLocationPermission() == false;

    IconData icon;
    String label;
    Color tint;

    if (_isPreparingMatch) {
      icon = Icons.tune_rounded;
      label = '正在准备本轮匹配';
      tint = AppColors.textPrimary.withValues(alpha: 0.92);
    } else if (provider.isMatching) {
      icon = Icons.radar_rounded;
      label = '优先寻找当前在线的人';
      tint = AppColors.textPrimary.withValues(alpha: 0.92);
    } else if (isFailureState) {
      icon = Icons.error_outline_rounded;
      label = '建议先检查服务环境';
      tint = AppColors.error.withValues(alpha: 0.96);
    } else if (provider.matchCount <= 0) {
      icon = Icons.schedule_rounded;
      label = '今日机会已用完';
      tint = AppColors.warning.withValues(alpha: 0.92);
    } else if (locationSkipped) {
      icon = Icons.near_me_outlined;
      label = '未开位置也能继续匹配';
      tint = AppColors.textSecondary.withValues(alpha: 0.9);
    } else {
      icon = Icons.play_arrow_rounded;
      label = '可开始匹配';
      tint = AppColors.textPrimary.withValues(alpha: 0.92);
    }

    final background = isFailureState
        ? AppColors.error.withValues(alpha: 0.1)
        : AppColors.white08;
    final border = isFailureState
        ? AppColors.error.withValues(alpha: 0.22)
        : AppColors.white12;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: layout.isCompact ? 240 : 320,
      ),
      child: AnimatedContainer(
        key: const Key('match-status-chip'),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: layout.statusChipHorizontalPadding,
          vertical: layout.statusChipVerticalPadding,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: layout.statusChipIconSize, color: tint),
            SizedBox(width: layout.statusChipIconSpacing),
            Flexible(
              child: Text(
                label,
                maxLines: layout.isCompact ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: layout.statusChipTextSize,
                  fontWeight: FontWeight.w300,
                  color: tint,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowMatchingGuide(MatchProvider provider) {
    final failureMessage = provider.lastFailureMessage;
    final hasFailureMessage =
        failureMessage != null && failureMessage.trim().isNotEmpty;
    return _isPreparingMatch ||
        provider.isMatching ||
        provider.matchCount <= 0 ||
        hasFailureMessage;
  }

  Widget _buildMatchingGuide(MatchProvider provider, _MatchLayoutSpec layout) {
    final failureMessage = provider.lastFailureMessage;
    final isFailureState = !provider.isMatching &&
        provider.matchCount > 0 &&
        failureMessage != null &&
        failureMessage.isNotEmpty;
    final tips = provider.matchCount <= 0
        ? const ['今日次数已用完', '明天会自动恢复', '可以先去消息页回复已有对话']
        : provider.isMatching
            ? const ['正在为你筛选合适的人', '保持网络稳定', '不想等了可随时取消']
            : isFailureState
                ? <String>[
                    failureMessage,
                    '先检查服务状态',
                    '准备好后再开始匹配',
                  ]
                : const ['点击下方开始匹配', '匹配成功后先发一句话', '回复率会更高'];

    return AnimatedContainer(
      key: const Key('match-guide-card'),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: layout.guideHorizontalPadding,
        vertical: layout.guideVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: isFailureState
            ? AppColors.error.withValues(alpha: 0.07)
            : AppColors.white05,
        borderRadius: BorderRadius.circular(layout.guideRadius),
        border: Border.all(
          color: isFailureState
              ? AppColors.error.withValues(alpha: 0.20)
              : AppColors.white08,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              isFailureState
                  ? Icons.error_outline_rounded
                  : Icons.tips_and_updates_outlined,
              size: layout.guideIconSize,
              color: isFailureState
                  ? AppColors.error.withValues(alpha: 0.85)
                  : AppColors.textTertiary,
            ),
          ),
          SizedBox(width: layout.guideIconSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: tips.asMap().entries.map((entry) {
                final isFirst = entry.key == 0;
                return Padding(
                  padding: EdgeInsets.only(top: isFirst ? 0 : 5),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: isFirst && isFailureState
                          ? layout.guideTextSize + 0.5
                          : layout.guideTextSize,
                      fontWeight: isFirst && isFailureState
                          ? FontWeight.w400
                          : FontWeight.w300,
                      color: isFailureState
                          ? (isFirst
                              ? AppColors.error.withValues(alpha: 0.95)
                              : AppColors.error.withValues(alpha: 0.65))
                          : AppColors.textTertiary.withValues(alpha: 0.92),
                      height: 1.4,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchOrb(MatchProvider provider, _MatchLayoutSpec layout) {
    return Center(
      child: AnimatedBuilder(
        animation: _orbController,
        builder: (context, child) {
          final t = _orbController.value; // 0.35 ~ 1.0 breathing
          final isMatching = provider.isMatching;

          // Core orb scale: gentle breath 0.96 → 1.0
          final scale = isMatching ? (0.96 + 0.04 * t) : 1.0;

          // Outer ring pulse opacity
          final ringOpacity = isMatching ? (0.04 + 0.10 * t) : 0.0;
          final ringScale = isMatching ? (1.0 + 0.18 * t) : 1.0;

          // Glow brightness
          final glowAlpha = isMatching ? (0.18 * t) : 0.06;

          return SizedBox(
            width: layout.orbSize * 1.5,
            height: layout.orbSize * 1.5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outermost diffuse ring
                Transform.scale(
                  scale: ringScale * 1.18,
                  child: Container(
                    width: layout.orbSize,
                    height: layout.orbSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.brandBlue
                            .withValues(alpha: ringOpacity * 0.5),
                        width: 1,
                      ),
                    ),
                  ),
                ),
                // Middle ring
                Transform.scale(
                  scale: ringScale * 1.06,
                  child: Container(
                    width: layout.orbSize,
                    height: layout.orbSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.brandBlue
                            .withValues(alpha: ringOpacity * 0.8),
                        width: 0.8,
                      ),
                    ),
                  ),
                ),
                // Core orb
                Transform.scale(
                  scale: scale,
                  child: Container(
                    width: layout.orbSize,
                    height: layout.orbSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.2, -0.3),
                        radius: 0.85,
                        colors: isMatching
                            ? [
                                AppColors.brandBlue
                                    .withValues(alpha: 0.22 * t + 0.06),
                                AppColors.textPrimary
                                    .withValues(alpha: 0.10 * t + 0.03),
                                AppColors.textPrimary.withValues(alpha: 0.02),
                              ]
                            : [
                                AppColors.textPrimary.withValues(alpha: 0.10),
                                AppColors.textPrimary.withValues(alpha: 0.04),
                                AppColors.textPrimary.withValues(alpha: 0.01),
                              ],
                      ),
                      border: Border.all(
                        color: isMatching
                            ? AppColors.brandBlue
                                .withValues(alpha: 0.20 + 0.10 * t)
                            : AppColors.white12,
                        width: isMatching ? 1.2 : 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isMatching
                              ? AppColors.brandBlue.withValues(alpha: glowAlpha)
                              : AppColors.textPrimary.withValues(alpha: 0.04),
                          blurRadius:
                              layout.orbShadowBlur * (isMatching ? t : 0.4),
                          spreadRadius: layout.orbShadowSpread *
                              (isMatching ? t * 0.5 : 0),
                        ),
                      ],
                    ),
                    child: isMatching
                        ? Center(
                            child: Icon(
                              Icons.radar_rounded,
                              size: layout.orbSize * 0.22,
                              color: AppColors.brandBlue
                                  .withValues(alpha: 0.4 + 0.3 * t),
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 全屏匹配成功卡片（一屏展示，无需滚动）
  Widget _buildScrollableMatchCard(MatchProvider provider) {
    final user = provider.matchedUser!;
    final isOnline = user.isOnline;
    final hasLocation = user.hasLocationPermission;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact =
            constraints.maxHeight <= 760 || constraints.maxWidth <= 390;
        final horizontalPadding = isCompact ? 18.0 : 24.0;
        final topPadding = isCompact ? 16.0 : 20.0;
        final sectionGap = isCompact ? 18.0 : 24.0;
        final contentMaxWidth = isCompact ? 420.0 : 460.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            topPadding,
            horizontalPadding,
            isCompact ? 12.0 : 16.0,
          ),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentMaxWidth),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                '匹配成功',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w300,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 2,
                                ),
                              ),
                              if (isOnline) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.success
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: AppColors.success,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'TA在线',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: sectionGap),
                          Container(
                            key: const Key('match-result-card'),
                            padding: EdgeInsets.all(isCompact ? 20 : 24),
                            decoration: BoxDecoration(
                              color: AppColors.cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isOnline
                                    ? AppColors.success.withValues(alpha: 0.2)
                                    : AppColors.white08,
                              ),
                            ),
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      key: const Key('match-result-avatar'),
                                      width: isCompact ? 74 : 80,
                                      height: isCompact ? 74 : 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.white08,
                                        border: Border.all(
                                          color: isOnline
                                              ? AppColors.success
                                                  .withValues(alpha: 0.3)
                                              : AppColors.white05,
                                          width: 2,
                                        ),
                                      ),
                                      child: AppUserAvatar(
                                        avatar: user.avatar,
                                        textStyle: TextStyle(
                                          fontSize: isCompact ? 36 : 40,
                                        ),
                                      ),
                                    ),
                                    if (isOnline)
                                      Positioned(
                                        right: 4,
                                        bottom: 4,
                                        child: Container(
                                          width: 16,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            color: AppColors.success,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppColors.cardBg,
                                              width: 3,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  user.nickname,
                                  style: TextStyle(
                                    fontSize: isCompact ? 17 : 18,
                                    fontWeight: FontWeight.w300,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'UID 在主页解锁并互关后可见',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w300,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.white08,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        user.status,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w300,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    if (hasLocation)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.location_on,
                                            size: 14,
                                            color: AppColors.textTertiary,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            user.distance,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w300,
                                              color: AppColors.textTertiary,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: isCompact ? 18 : 24),
                          _buildCompactGreetingSection(user),
                          const SizedBox(height: 12),
                          _buildMatchedUserHint(user),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: _buildActionButtons(provider),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ignore: unused_element
  Widget _buildFullScreenMatchCard(MatchProvider provider) {
    final user = provider.matchedUser!;
    final isOnline = user.isOnline;
    final hasLocation = user.hasLocationPermission;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          // 顶部标题
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '匹配成功',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textSecondary,
                  letterSpacing: 2,
                ),
              ),
              if (isOnline) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'TA在线',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 32),

          // 用户信息卡片（紧凑版）
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isOnline
                    ? AppColors.success.withValues(alpha: 0.2)
                    : AppColors.white08,
              ),
              // 在线用户：微妙的发光效果
              boxShadow: isOnline
                  ? [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.1),
                        blurRadius: 14,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                // 头像
                Stack(
                  children: [
                    Container(
                      key: const Key('match-result-avatar'),
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.white08,
                        border: Border.all(
                          color: isOnline
                              ? AppColors.success.withValues(alpha: 0.3)
                              : AppColors.white05,
                          width: 2,
                        ),
                      ),
                      child: AppUserAvatar(
                        avatar: user.avatar,
                        textStyle: TextStyle(fontSize: 40),
                      ),
                    ),
                    // 在线绿点
                    if (isOnline)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.cardBg,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // 昵称
                Text(
                  user.nickname,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 6),
                const Text(
                  'UID在主页解锁并互关后可见',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textTertiary,
                  ),
                ),

                const SizedBox(height: 12),

                // 状态和距离
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.white08,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        user.status,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w300,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    // 只有在线且有位置权限才显示距离
                    if (hasLocation) ...[
                      const SizedBox(width: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            user.distance,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w300,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 招呼语区域（紧凑版）
          Expanded(
            child: _buildCompactGreetingSection(user),
          ),

          const SizedBox(height: 12),
          _buildMatchedUserHint(user),
          const SizedBox(height: 16),

          // 底部按钮
          _buildActionButtons(provider),
        ],
      ),
    );
  }

  // 紧凑版招呼语区域（一屏展示）
  Widget _buildCompactGreetingSection(User user) {
    final quickGreetings = _resolveQuickGreetings(user);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '发一句招呼',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w300,
            color: AppColors.textPrimary,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 14),
        if (_greetingController.text.isEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quickGreetings.map((greeting) {
              final isSelected = _selectedQuickGreeting == greeting;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedQuickGreeting = greeting;
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.white12 : AppColors.white05,
                    border: Border.all(
                      color: isSelected ? AppColors.white20 : AppColors.white08,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    greeting,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        if (_selectedQuickGreeting == null) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _greetingController,
            maxLength: 25,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: '也可以自己写一句',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
              counterStyle: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              suffixIcon: _greetingController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                      onPressed: () {
                        setState(() {
                          _greetingController.clear();
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
        ],
        if (_selectedQuickGreeting != null) ...[
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _selectedQuickGreeting = null;
                });
              },
              child: const Text(
                '换成自定义',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textTertiary,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<String> _resolveQuickGreetings(User user) {
    final scenarioGreetings = user.isOnline
        ? const [
            '嗨，刚好刷到你',
            '晚上好呀',
            '想聊聊你现在在做什么',
            '看起来你也还没睡',
            '可以认识一下吗',
            '今天过得怎么样',
          ]
        : const [
            '先给你留个言',
            '等你看到时回我就好',
            '你好呀，想认识一下你',
            '晚点有空可以聊聊',
            '看到你状态挺有意思',
            '祝你今晚好梦',
          ];

    final mergedGreetings = <String>{
      ...scenarioGreetings,
      ..._defaultQuickGreetings,
    };

    return mergedGreetings.take(6).toList();
  }

  // ignore: unused_element
  Widget _buildGreetingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '打个招呼',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w300,
                color: AppColors.textPrimary,
                letterSpacing: 1,
              ),
            ),
            if (_greetingController.text.isEmpty &&
                _selectedQuickGreeting == null)
              Text(
                '选一个或自己写',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textTertiary,
                  letterSpacing: 1,
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),

        // 快捷语（仅在未自定义时显示）
        if (_greetingController.text.isEmpty)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _defaultQuickGreetings.map((greeting) {
              final isSelected = _selectedQuickGreeting == greeting;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedQuickGreeting = greeting;
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.white12 : AppColors.white05,
                    border: Border.all(
                      color: isSelected ? AppColors.white20 : AppColors.white08,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    greeting,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w300,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

        // 自定义输入提示（仅在未选择快捷语时显示）
        if (_selectedQuickGreeting == null) ...[
          if (_greetingController.text.isEmpty) const SizedBox(height: 20),

          if (_greetingController.text.isEmpty)
            GestureDetector(
              onTap: () {
                // 聚焦到输入框
                FocusScope.of(context).requestFocus(FocusNode());
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.white08, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '或者自己写点什么',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        color: AppColors.textTertiary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // 自定义输入框
          TextField(
            controller: _greetingController,
            maxLength: 25,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '写点什么...',
              counterStyle: Theme.of(context).textTheme.bodySmall,
              suffixIcon: _greetingController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                      onPressed: () {
                        setState(() {
                          _greetingController.clear();
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
        ],

        // 已选择快捷语时，显示切换按钮
        if (_selectedQuickGreeting != null) ...[
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _selectedQuickGreeting = null;
                });
              },
              child: Text(
                '换成自定义',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textTertiary,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMatchButton(MatchProvider provider, _MatchLayoutSpec layout) {
    String buttonText;
    String? helperText;
    final bool isIdle =
        !_isPreparingMatch && !provider.isMatching && provider.matchCount > 0;

    if (_isPreparingMatch) {
      buttonText = '准备中';
      helperText = '正在准备本轮候选人';
    } else if (provider.isMatching) {
      buttonText = '取消';
      helperText = '不想等了可随时取消，本次不会扣次数';
    } else if (provider.matchCount <= 0) {
      buttonText = '今日已用完';
      helperText = '明日 9:00 自动恢复';
    } else {
      buttonText = '开始匹配';
      helperText = null;
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height:
              layout.buttonVerticalPadding * 2 + layout.buttonTextSize * 1.4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: isIdle
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFE8E8E8),
                        Color(0xFFFFFFFF),
                      ],
                    )
                  : null,
              boxShadow: isIdle
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFFFFFF).withValues(alpha: 0.12),
                        blurRadius: 14,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: ElevatedButton(
              key: const Key('match-primary-action'),
              onPressed: provider.matchCount <= 0 || _isPreparingMatch
                  ? null
                  : () => _handleMatchButtonPressed(provider),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.symmetric(
                    vertical: layout.buttonVerticalPadding),
                backgroundColor: isIdle
                    ? Colors.transparent
                    : _isPreparingMatch
                        ? AppColors.white08
                        : provider.isMatching
                            ? AppColors.white12
                            : AppColors.white05,
                foregroundColor: isIdle
                    ? AppColors.pureBlack
                    : provider.isMatching
                        ? AppColors.textPrimary
                        : AppColors.textDisabled,
                disabledBackgroundColor: AppColors.white05,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: provider.isMatching
                      ? BorderSide(
                          color: AppColors.white20,
                          width: 0.5,
                        )
                      : BorderSide.none,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isPreparingMatch) ...[
                    SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.textTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                  ],
                  Text(
                    buttonText,
                    style: TextStyle(
                      fontSize: layout.buttonTextSize,
                      fontWeight: isIdle ? FontWeight.w500 : FontWeight.w300,
                      letterSpacing: isIdle ? 2 : 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (helperText != null) ...[
          SizedBox(height: layout.buttonToHelperSpacing),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              helperText,
              key: ValueKey(helperText),
              style: TextStyle(
                fontSize: layout.helperTextSize,
                fontWeight: FontWeight.w300,
                color: AppColors.textTertiary.withValues(alpha: 0.75),
                height: 1.45,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGreetingFeedback() {
    return Container(
      key: ValueKey<String>('greeting_$_recentThreadId'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.brandBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.brandBlue.withValues(alpha: 0.18),
          width: 0.6,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.brandBlue.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_chat_read_outlined,
              size: 15,
              color: AppColors.brandBlue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '招呼已发出',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.brandBlue.withValues(alpha: 0.9),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '已向 $_recentNickname 发送招呼',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textTertiary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _recentThreadId == null ? null : _openRecentChat,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brandBlue,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              backgroundColor: AppColors.brandBlue.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              '去聊',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchedUserHint(User user) {
    final hint = user.isOnline ? 'TA 在线，适合直接发消息。' : 'TA 当前不在线，消息会先留在这里。';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: user.isOnline
              ? AppColors.success.withValues(alpha: 0.18)
              : AppColors.white08,
        ),
      ),
      child: Row(
        children: [
          Icon(
            user.isOnline ? Icons.bolt_outlined : Icons.schedule_outlined,
            size: 16,
            color: user.isOnline ? AppColors.success : AppColors.textTertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hint,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w300,
                color: AppColors.textTertiary.withValues(alpha: 0.92),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(MatchProvider provider) {
    final greeting = _greetingController.text.trim().isNotEmpty
        ? _greetingController.text.trim()
        : _selectedQuickGreeting ?? '你好';

    return Row(
      key: const Key('match-result-actions'),
      children: [
        SizedBox(
          height: 52,
          width: 52,
          child: OutlinedButton(
            onPressed: () => provider.clearMatchedUser(),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: const BorderSide(color: AppColors.white12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Icon(
              Icons.close_rounded,
              size: 20,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE0E0E0), Color(0xFFFFFFFF)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFFFFF).withValues(alpha: 0.10),
                    blurRadius: 14,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () =>
                    _sendGreetingAndBackToMatch(provider, greeting),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  backgroundColor: Colors.transparent,
                  foregroundColor: AppColors.pureBlack,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send_rounded, size: 16),
                    SizedBox(width: 8),
                    Text(
                      '发送招呼',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
