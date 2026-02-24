import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/match_provider.dart';
import '../providers/chat_provider.dart';
import '../models/models.dart';
import '../utils/permission_manager.dart';
import 'app_toast.dart';

class MatchTab extends StatefulWidget {
  const MatchTab({super.key});

  @override
  State<MatchTab> createState() => _MatchTabState();
}

class _MatchTabState extends State<MatchTab> with SingleTickerProviderStateMixin {
  late AnimationController _orbController;
  final TextEditingController _greetingController = TextEditingController();
  String? _selectedQuickGreeting;
  
  final List<String> _quickGreetings = ['嗨', '你好', '在吗', '聊聊', '失眠了', '晚安'];

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<MatchProvider>(
          builder: (context, matchProvider, child) {
            return Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 顶部情感化文案 + 次数显示
                      _buildHeader(matchProvider),
                      
                      const SizedBox(height: 60),
                      
                      // 光球或匹配卡片
                      if (matchProvider.matchedUser == null)
                        _buildMatchOrb(matchProvider)
                      else
                        _buildMatchedCard(matchProvider),
                      
                      const SizedBox(height: 60),
                      
                      // 按钮
                      if (matchProvider.matchedUser == null)
                        _buildMatchButton(matchProvider)
                      else
                        _buildActionButtons(matchProvider),
                    ],
                  ),
                ),
              ),
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
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
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
            color: AppColors.textTertiary.withOpacity(0.6),
            letterSpacing: 2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
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
                colors: provider.isMatching ? [
                  AppColors.textPrimary.withOpacity(0.15),
                  AppColors.textPrimary.withOpacity(0.08),
                  AppColors.textPrimary.withOpacity(0.03),
                ] : [
                  AppColors.textPrimary.withOpacity(0.08),
                  AppColors.textPrimary.withOpacity(0.03),
                  AppColors.textPrimary.withOpacity(0.01),
                ],
              ),
              boxShadow: provider.isMatching ? [
                BoxShadow(
                  color: AppColors.textPrimary.withOpacity(0.15 * _orbController.value),
                  blurRadius: 60,
                  spreadRadius: 20,
                ),
              ] : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildMatchedCard(MatchProvider provider) {
    final user = provider.matchedUser!;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.white08),
      ),
      child: Column(
        children: [
          // 头像
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.white08,
              border: Border.all(color: AppColors.white05, width: 2),
            ),
            child: const Center(
              child: Text('👤', style: TextStyle(fontSize: 48)),
            ),
          ),
          
          const SizedBox(height: 24),
          
          Text(
            '匿名',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.white08,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.white12),
            ),
            child: Text(
              user.status,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            user.distance,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          
          const SizedBox(height: 32),
          
          // 招呼语区域
          _buildGreetingSection(),
        ],
      ),
    );
  }

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
            if (_greetingController.text.isEmpty && _selectedQuickGreeting == null)
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
            children: _quickGreetings.map((greeting) {
              final isSelected = _selectedQuickGreeting == greeting;
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedQuickGreeting = greeting;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppColors.white12 
                        : AppColors.white05,
                    border: Border.all(
                      color: isSelected 
                          ? AppColors.white20 
                          : AppColors.white08,
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
          if (_greetingController.text.isEmpty)
            const SizedBox(height: 20),
          
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
    if (provider.isMatching) {
      buttonText = '取消';
    } else if (provider.matchCount <= 0) {
      buttonText = '今日已用完';
    } else {
      buttonText = '开始匹配';
    }
    
    return Center(
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: provider.matchCount <= 0
              ? null
              : () async {
                  if (provider.isMatching) {
                    // 取消匹配
                    provider.cancelMatch();
                  } else {
                    // 开始匹配前请求位置权限（首次或缓存清除后会弹窗）
                    final hasPermission = await PermissionManager.requestLocationPermission(context);
                    
                    // 不管有没有位置权限都可以匹配（位置不是强依赖）
                    provider.startMatch();
                    
                    if (!hasPermission && mounted) {
                      // 没有位置权限，提示用户（但不阻止匹配）
                      AppToast.show(context, '未开启位置，将随机匹配用户');
                    }
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: provider.isMatching
                ? AppColors.white12
                : provider.matchCount > 0 
                    ? AppColors.textPrimary 
                    : AppColors.white05,
            foregroundColor: provider.isMatching
                ? AppColors.textPrimary
                : AppColors.pureBlack,
          ),
          child: Text(buttonText),
        ),
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
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: AppColors.white12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            child: const Text(
              '算了',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w300,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: () {
              // 发送招呼，不再消耗次数（已在匹配成功时消耗）
              final thread = ChatThread(
                id: provider.matchedUser!.id,
                otherUser: provider.matchedUser!,
                createdAt: DateTime.now(),
                expiresAt: DateTime.now().add(const Duration(hours: 24)),
                intimacyPoints: 0, // 初始亲密度为0
              );
              
              context.read<ChatProvider>().addThread(thread);
              context.read<ChatProvider>().sendMessage(thread.id, greeting);
              
              provider.clearMatchedUser();
              
              // 从匹配页进入聊天，返回时应该回到匹配页
              context.push('/chat/${thread.id}').then((_) {
                if (context.mounted) {
                  context.go('/main?tab=0');
                }
              });
            },
            child: const Text('发送'),
          ),
        ),
      ],
    );
  }
}
