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
  static const int unlockAvatar = 20;        // 20分解锁头像
  static const int unlockNickname = 50;      // 50分解锁昵称
  static const int unlockSignature = 100;    // 100分解锁个人签名
  static const int unlockProfile = 150;      // 150分解锁主页
  static const int unlockBackground = 200;   // 200分解锁主页背景
  static const int canAddFriend = 250;       // 250分可以互关（约35分钟）
  
  /// 获取下一个解锁项
  static String? getNextUnlock(int points) {
    if (points < unlockAvatar) return '头像';
    if (points < unlockNickname) return '昵称';
    if (points < unlockSignature) return '个人签名';
    if (points < unlockProfile) return '主页';
    if (points < unlockBackground) return '主页背景';
    if (points < canAddFriend) return '互关权限';
    return null;
  }
  
  /// 获取解锁进度百分比
  static double getProgress(int points) {
    if (points >= canAddFriend) return 1.0;
    return points / canAddFriend;
  }
  
  /// 获取当前等级
  static IntimacyLevel getLevel(int points) {
    if (points >= 200) return IntimacyLevel.bestFriend;
    if (points >= 150) return IntimacyLevel.closeFriend;
    if (points >= 100) return IntimacyLevel.friend;
    if (points >= 50) return IntimacyLevel.acquaintance;
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
    return 5;
  }
  
  /// 接收消息获得的亲密度
  static int receiveMessage(String content) {
    return sendMessage(content);
  }
  
  /// 连续对话奖励（5分钟内互动）
  static int continuousChat() {
    return 3;
  }
  
  /// 深夜聊天奖励（23:00-6:00）
  static int lateNightChat() {
    final hour = DateTime.now().hour;
    if (hour >= 23 || hour < 6) return 2;
    return 0;
  }
  
  /// 首次对话奖励
  static int firstChat() {
    return 10;
  }
}

/// 亲密度变化动画组件
class IntimacyChangeAnimation extends StatefulWidget {
  final int change;
  final VoidCallback? onComplete;
  
  const IntimacyChangeAnimation({
    super.key,
    required this.change,
    this.onComplete,
  });

  @override
  State<IntimacyChangeAnimation> createState() => _IntimacyChangeAnimationState();
}

class _IntimacyChangeAnimationState extends State<IntimacyChangeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -1),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
      ),
    );

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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.favorite,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                '+${widget.change}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 亲密度进度条组件
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
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.favorite,
                    size: 16,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    level.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              if (nextUnlock != null)
                Text(
                  '距离解锁$nextUnlock还需${_getPointsToNext(points)}分',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white54,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Stack(
          children: [
            // 背景
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // 进度
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.shade300,
                      Colors.orange.shade600,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  int _getPointsToNext(int points) {
    if (points < IntimacyUnlock.unlockAvatar) {
      return IntimacyUnlock.unlockAvatar - points;
    }
    if (points < IntimacyUnlock.unlockNickname) {
      return IntimacyUnlock.unlockNickname - points;
    }
    if (points < IntimacyUnlock.unlockSignature) {
      return IntimacyUnlock.unlockSignature - points;
    }
    if (points < IntimacyUnlock.unlockProfile) {
      return IntimacyUnlock.unlockProfile - points;
    }
    if (points < IntimacyUnlock.unlockBackground) {
      return IntimacyUnlock.unlockBackground - points;
    }
    if (points < IntimacyUnlock.canAddFriend) {
      return IntimacyUnlock.canAddFriend - points;
    }
    return 0;
  }
}

