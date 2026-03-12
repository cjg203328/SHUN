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

class MatchTab extends StatefulWidget {
  const MatchTab({super.key});

  @override
  State<MatchTab> createState() => _MatchTabState();
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

  static const List<String> _defaultQuickGreetings = ['嗨，你好', '晚上好呀', '想聊聊吗', '今天过得怎么样', '刚好看到你', '想认识一下你'];

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orbController.dispose();
    _greetingController.dispose();
    _greetingBannerTimer?.cancel();
    super.dispose();
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
      unawaited(provider.startMatch(excludedUserIds: blockedUserIds));

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
        final thread = await chatProvider.ensureDirectThreadForUser(matchedUser);
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
      body: SafeArea(
        child: Consumer<MatchProvider>(
          builder: (context, matchProvider, child) {
            // 匹配成功后显示全屏卡片
            if (matchProvider.matchedUser != null) {
              return _buildFullScreenMatchCard(matchProvider);
            }

            // 未匹配时显示匹配界面
            return LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 80,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 顶部情感化文案 + 次数显示
                        _buildHeader(matchProvider),

                        const SizedBox(height: 18),

                        _buildMatchingGuide(matchProvider),

                        const SizedBox(height: 42),

                        // 光球
                        _buildMatchOrb(matchProvider),

                        const SizedBox(height: 34),

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          child: _showGreetingBanner
                              ? _buildGreetingFeedback()
                              : const SizedBox(height: 0),
                        ),

                        SizedBox(height: _showGreetingBanner ? 18 : 0),

                        // 按钮
                        _buildMatchButton(matchProvider),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(MatchProvider provider) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 主标题
        Text(
          '瞬间',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w200,
            color: AppColors.textPrimary,
            letterSpacing: 8,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // 副标题
        Text(
          '此刻有人也在等待相遇',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w300,
            color: AppColors.textTertiary,
            letterSpacing: 2,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 48),

        // 次数显示区域
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${provider.matchCount}',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w200,
                  color: AppColors.textPrimary,
                  height: 1,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '次',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textSecondary,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // 说明文字
        Text(
          provider.matchCount > 0 ? '今日剩余机会' : '明日 9:00 重置',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w300,
            color: AppColors.textTertiary.withValues(alpha: 0.6),
            letterSpacing: 2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMatchingGuide(MatchProvider provider) {
    final tips = provider.matchCount <= 0
        ? const ['今日次数已用完', '明天会自动恢复', '可以先去消息页回复已有对话']
        : provider.isMatching
            ? const ['正在为你筛选合适的人', '保持网络稳定', '不想等了可随时取消']
            : const ['点击下方开始匹配', '匹配成功后先发一句话', '回复率会更高'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.white08),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.tips_and_updates_outlined,
            size: 18,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tips.join(' · '),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w300,
                color: AppColors.textTertiary.withValues(alpha: 0.92),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchOrb(MatchProvider provider) {
    return Center(
      child: AnimatedBuilder(
        animation: _orbController,
        builder: (context, child) {
          return Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: provider.isMatching
                    ? [
                        AppColors.textPrimary.withValues(alpha: 0.15),
                        AppColors.textPrimary.withValues(alpha: 0.08),
                        AppColors.textPrimary.withValues(alpha: 0.03),
                      ]
                    : [
                        AppColors.textPrimary.withValues(alpha: 0.08),
                        AppColors.textPrimary.withValues(alpha: 0.03),
                        AppColors.textPrimary.withValues(alpha: 0.01),
                      ],
              ),
              boxShadow: provider.isMatching
                  ? [
                      BoxShadow(
                        color: AppColors.textPrimary
                            .withValues(alpha: 0.15 * _orbController.value),
                        blurRadius: 60,
                        spreadRadius: 20,
                      ),
                    ]
                  : null,
            ),
          );
        },
      ),
    );
  }

  // 全屏匹配成功卡片（一屏展示，无需滚动）
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
                        blurRadius: 20,
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
                      child: Center(
                        child: Text(
                          user.avatar ?? '👤',
                          style: const TextStyle(fontSize: 40),
                        ),
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
          '先发一句轻松的开场白',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w300,
            color: AppColors.textPrimary,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          user.isOnline
              ? '对方现在在线，简短一点更容易立刻收到回复。'
              : '先留下一句舒服的话，等 TA 回来时会第一眼看到。',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w300,
            color: AppColors.textTertiary.withValues(alpha: 0.9),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.white05,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.white08),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '建议别太正式，像“嗨，今天过得怎么样”这种最自然。',
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
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _greetingController,
            maxLength: 25,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: '或者自己写一句更像你的开场白...',
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

  Widget _buildMatchButton(MatchProvider provider) {
    String buttonText;
    String helperText;
    if (_isPreparingMatch) {
      buttonText = '准备中...';
      helperText = '正在检查权限并准备本轮候选人';
    } else if (provider.isMatching) {
      buttonText = '取消匹配';
      helperText = '如果不想继续等待，可以随时取消，本次不会额外扣次数';
    } else if (provider.matchCount <= 0) {
      buttonText = '今日已用完';
      helperText = '明日 9:00 会自动恢复匹配次数';
    } else {
      buttonText = '开始匹配';
      helperText = '匹配到人后，先发一句简短问候，回复率通常更高';
    }

    final showLocationTip =
        PermissionManager.getSessionLocationPermission() == false;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: provider.matchCount <= 0 || _isPreparingMatch
                ? null
                : () => _handleMatchButtonPressed(provider),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: _isPreparingMatch
                  ? AppColors.white08
                  : provider.isMatching
                      ? AppColors.white12
                      : provider.matchCount > 0
                          ? AppColors.textPrimary
                          : AppColors.white05,
              foregroundColor: provider.isMatching
                  ? AppColors.textPrimary
                  : AppColors.pureBlack,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              buttonText,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w300,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          helperText,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w300,
            color: AppColors.textTertiary.withValues(alpha: 0.88),
            height: 1.45,
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        ),
        if (showLocationTip) ...[
          const SizedBox(height: 8),
          const Text(
            '未开启位置也可以匹配，我们会优先为你安排随机相遇',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: AppColors.textTertiary,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildGreetingFeedback() {
    return Container(
      key: ValueKey<String>('greeting_$_recentThreadId'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white08,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.white12, width: 0.6),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.mark_chat_read_outlined,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '已向 $_recentNickname 发送招呼',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: _recentThreadId == null
                ? null
                : _openRecentChat,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brandBlue,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
            child: const Text('去聊天'),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchedUserHint(User user) {
    final hint = user.isOnline
        ? '对方现在在线，建议直接发一句轻松的开场白，通常更容易接上话。'
        : '对方当前不在线，留一句自然一点的话，回来后会先看到你的消息。';

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
            color: user.isOnline
                ? AppColors.success
                : AppColors.textTertiary,
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
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              // 关闭卡片，不再消耗次数（已在匹配成功时消耗）
              provider.clearMatchedUser();
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.white12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '算了',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w300,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: () => _sendGreetingAndBackToMatch(provider, greeting),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '发送',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w300,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
