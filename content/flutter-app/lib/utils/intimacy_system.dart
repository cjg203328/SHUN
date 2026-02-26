import 'package:flutter/material.dart';

/// 亲密度等级
enum IntimacyLevel {
  stranger(0, '陌生人', '刚刚认识'),
  acquaintance(1, '初识', '开始了解'),
  friend(2, '熟悉', '渐入佳境'),
  closeFriend(3, '亲密', '无话不谈'),
  bestFriend(4, '挚友', '心有灵犀');

  final int level;
  final String name;
  final String description;

  const IntimacyLevel(this.level, this.name, this.description);
}

/// 亲密度解锁内容
class IntimacyUnlock {
  static const int unlockProfile = 40; // 阶段一：主页权限
  static const int canAddFriend = 140; // 阶段二：互关+语音

  /// 获取下一个解锁项
  static String? getNextUnlock(int points) {
    if (points < unlockProfile) return '主页权限';
    if (points < canAddFriend) return '互关与语音';
    return null;
  }

  /// 获取解锁进度百分比
  static double getProgress(int points) {
    if (points >= canAddFriend) return 1.0;
    return points / canAddFriend;
  }

  /// 获取当前等级
  static IntimacyLevel getLevel(int points) {
    if (points >= canAddFriend) return IntimacyLevel.bestFriend;
    if (points >= unlockProfile) return IntimacyLevel.closeFriend;
    if (points >= 20) return IntimacyLevel.friend;
    if (points >= 8) return IntimacyLevel.acquaintance;
    return IntimacyLevel.stranger;
  }
}

/// 亲密度计算规则
class IntimacyCalculator {
  /// 发送消息获得的亲密度
  static int sendMessage(String content) {
    final length = content.length;
    if (length < 5) return 1;
    if (length < 20) return 2;
    if (length < 50) return 3;
    return 4;
  }

  /// 接收消息获得的亲密度
  static int receiveMessage(String content) {
    return sendMessage(content);
  }

  /// 连续对话奖励（5分钟内互动）
  static int continuousChat() {
    return 1;
  }

  /// 深夜聊天奖励（23:00-6:00）
  static int lateNightChat() {
    final hour = DateTime.now().hour;
    if (hour >= 23 || hour < 6) return 2;
    return 0;
  }

  /// 首次对话奖励
  static int firstChat() {
    return 6;
  }
}

/// 亲密度变化动画组件（高级渐变设计）
class IntimacyChangeAnimation extends StatefulWidget {
  final int change;
  final VoidCallback? onComplete;

  const IntimacyChangeAnimation({
    super.key,
    required this.change,
    this.onComplete,
  });

  @override
  State<IntimacyChangeAnimation> createState() =>
      _IntimacyChangeAnimationState();
}

class _IntimacyChangeAnimationState extends State<IntimacyChangeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_controller);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -1.5),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.5, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 70,
      ),
    ]).animate(_controller);

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF8A65),
                  Color(0xFFFF7043),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF7043).withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.favorite,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  '+${widget.change}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 亲密度进度条组件（高级渐变设计，参考Soul）
class IntimacyProgressBar extends StatelessWidget {
  final int points;
  final bool showLabel;

  const IntimacyProgressBar({
    super.key,
    required this.points,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final progress = IntimacyUnlock.getProgress(points);
    final level = IntimacyUnlock.getLevel(points);
    final nextUnlock = IntimacyUnlock.getNextUnlock(points);

    // 根据等级选择渐变色
    final gradientColors = _getGradientColors(level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 左侧：等级标签
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors[0].withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getLevelIcon(level),
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      level.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // 右侧：进度提示
              if (nextUnlock != null)
                Text(
                  '再聊${_getPointsToNext(points)}分解锁$nextUnlock',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                    color: Colors.white.withValues(alpha: 0.5),
                    letterSpacing: 0.3,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // 进度条容器
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              // 进度条
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors[1].withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
              ),

              // 光晕效果
              if (progress > 0)
                Positioned(
                  right: 0,
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 12,
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.6),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 底部进度数值
        if (showLabel) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                level.description,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w300,
                  color: Colors.white.withValues(alpha: 0.4),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '$points/${IntimacyUnlock.canAddFriend}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // 根据等级获取渐变色
  List<Color> _getGradientColors(IntimacyLevel level) {
    switch (level) {
      case IntimacyLevel.stranger:
        return [
          const Color(0xFF9E9E9E), // 灰色
          const Color(0xFF757575),
        ];
      case IntimacyLevel.acquaintance:
        return [
          const Color(0xFF64B5F6), // 蓝色
          const Color(0xFF42A5F5),
        ];
      case IntimacyLevel.friend:
        return [
          const Color(0xFFBA68C8), // 紫色
          const Color(0xFFAB47BC),
        ];
      case IntimacyLevel.closeFriend:
        return [
          const Color(0xFFFF8A65), // 橙色
          const Color(0xFFFF7043),
        ];
      case IntimacyLevel.bestFriend:
        return [
          const Color(0xFFFF6B9D), // 粉红色
          const Color(0xFFFF5252),
        ];
    }
  }

  // 根据等级获取图标
  IconData _getLevelIcon(IntimacyLevel level) {
    switch (level) {
      case IntimacyLevel.stranger:
        return Icons.person_outline;
      case IntimacyLevel.acquaintance:
        return Icons.waving_hand;
      case IntimacyLevel.friend:
        return Icons.favorite_border;
      case IntimacyLevel.closeFriend:
        return Icons.favorite;
      case IntimacyLevel.bestFriend:
        return Icons.auto_awesome;
    }
  }

  int _getPointsToNext(int points) {
    if (points < IntimacyUnlock.unlockProfile) {
      return IntimacyUnlock.unlockProfile - points;
    }
    if (points < IntimacyUnlock.canAddFriend) {
      return IntimacyUnlock.canAddFriend - points;
    }
    return 0;
  }
}
