import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/chat_provider.dart';
import '../providers/friend_provider.dart';
import '../models/models.dart';
import '../widgets/app_toast.dart';
import '../utils/intimacy_system.dart';
import '../utils/permission_manager.dart';

class ChatScreen extends StatefulWidget {
  final String threadId;

  const ChatScreen({super.key, required this.threadId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  ChatProvider? _chatProvider;
  int _lastIntimacyPoints = 0;
  int _lastMessageCount = 0;
  int _intimacyAnimationToken = 0;
  bool _showIntimacyChange = false;
  int _intimacyChange = 0;
  bool _hasText = false; // 添加状态追踪

  @override
  void initState() {
    super.initState();

    // 监听输入框变化
    _inputController.addListener(() {
      final hasText = _inputController.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() {
          _hasText = hasText;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatProvider = context.read<ChatProvider>();
      _chatProvider?.addListener(_handleChatProviderChanged);

      // 不要立即清零未读数，等用户滚动到底部或停留一段时间后再清零
      final thread = _chatProvider?.getThread(widget.threadId);
      if (thread != null) {
        _lastIntimacyPoints = thread.intimacyPoints;
        _lastMessageCount =
            _chatProvider?.getMessages(widget.threadId).length ?? 0;

        // 延迟1秒后清零未读数（给用户时间看到消息）
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _chatProvider?.markAsRead(widget.threadId);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _chatProvider?.removeListener(_handleChatProviderChanged);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleChatProviderChanged() {
    if (!mounted) return;

    final thread = _chatProvider?.getThread(widget.threadId);
    if (thread != null && thread.intimacyPoints != _lastIntimacyPoints) {
      final change = thread.intimacyPoints - _lastIntimacyPoints;
      _lastIntimacyPoints = thread.intimacyPoints;

      if (change > 0) {
        _intimacyAnimationToken += 1;
        final token = _intimacyAnimationToken;
        setState(() {
          _intimacyChange = change;
          _showIntimacyChange = true;
        });

        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted || token != _intimacyAnimationToken) return;
          setState(() {
            _showIntimacyChange = false;
          });
        });
      }
    }

    final messageCount =
        _chatProvider?.getMessages(widget.threadId).length ?? 0;
    if (messageCount != _lastMessageCount) {
      _lastMessageCount = messageCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToBottom();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.pureBlack,
        elevation: 0,
        toolbarHeight: 64,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Consumer2<ChatProvider, FriendProvider>(
          builder: (context, chatProvider, friendProvider, child) {
            final thread = chatProvider.getThread(widget.threadId);
            if (thread == null) return const SizedBox();

            final isFriend = friendProvider.isFriend(thread.otherUser.id);
            final displayName = thread.otherUser.nickname;

            return Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.white08,
                  ),
                  child: Center(
                    child: Text(
                      thread.otherUser.avatar ?? '👤',
                      style: const TextStyle(
                        fontSize: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w300,
                          color: thread.hasUnlockedNickname
                              ? AppColors.textPrimary
                              : AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getHeaderSubtitle(thread, isFriend),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w300,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          // 更多菜单
          Consumer2<ChatProvider, FriendProvider>(
            builder: (context, chatProvider, friendProvider, child) {
              final thread = chatProvider.getThread(widget.threadId);
              if (thread == null) return const SizedBox();

              return PopupMenuButton<String>(
                icon:
                    const Icon(Icons.more_horiz, color: AppColors.textPrimary),
                color: AppColors.cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                offset: const Offset(0, 50),
                onSelected: (value) {
                  if (value == 'call') {
                    _handleVoiceCall(context, thread.otherUser);
                  } else if (value == 'add_friend') {
                    _showAddFriendDialog(context, thread.otherUser);
                  } else if (value == 'profile') {
                    _showUserProfile(context, thread.otherUser);
                  } else if (value == 'remark') {
                    _showSetRemarkDialog(context, thread.otherUser.id);
                  } else if (value == 'unfollow') {
                    _showUnfollowDialog(context, thread);
                  } else if (value == 'block') {
                    _showBlockDialog(context, thread);
                  }
                },
                itemBuilder: (context) {
                  final isFriend = friendProvider.isFriend(thread.otherUser.id);
                  final isBlocked = friendProvider.isBlocked(thread.otherUser.id);
                  final canCall = isFriend || thread.canAddFriend;
                  final canAddFriend = !isFriend && !isBlocked && thread.canAddFriend;

                  return [
                    if (thread.hasUnlockedProfile)
                      PopupMenuItem(
                        value: 'profile',
                        child: _buildMenuItem(Icons.person_outline, '个人主页'),
                      ),
                    if (canCall)
                      PopupMenuItem(
                        value: 'call',
                        child: _buildMenuItem(Icons.phone_outlined, '语音通话'),
                      ),
                    if (canAddFriend)
                      PopupMenuItem(
                        value: 'add_friend',
                        child:
                            _buildMenuItem(Icons.person_add_outlined, '添加好友'),
                      ),
                    if (isFriend) ...[
                      PopupMenuItem(
                        value: 'remark',
                        child: _buildMenuItem(Icons.edit_outlined, '设置备注'),
                      ),
                      PopupMenuItem(
                        value: 'unfollow',
                        child: _buildMenuItem(
                            Icons.person_remove_outlined, '取关',
                            isDanger: true),
                      ),
                    ],
                    if (!isBlocked)
                      PopupMenuItem(
                        value: 'block',
                        child: _buildMenuItem(Icons.block_outlined, '拉黑',
                            isDanger: true),
                      ),
                  ];
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 取关提示横幅
          Consumer<ChatProvider>(
            builder: (context, chatProvider, child) {
              final thread = chatProvider.getThread(widget.threadId);
              if (thread == null || !thread.isUnfollowed) {
                return const SizedBox();
              }

              final remaining = 3 - thread.messagesSinceUnfollow;

              return Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.error.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        remaining > 0
                            ? '对方已取关，你还可以发送$remaining条消息'
                            : '等待对方确认继续聊天',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          color: AppColors.error.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                    if (remaining <= 0)
                      TextButton(
                        onPressed: () {
                          // 这里可以添加提醒对方的功能
                          AppToast.show(context, '已发送提醒');
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          '提醒',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.error.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // 消息列表
          Expanded(
            child: Stack(
              children: [
                Consumer<ChatProvider>(
                  builder: (context, chatProvider, child) {
                    final messages = chatProvider.getMessages(widget.threadId);

                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '👋',
                              style: TextStyle(
                                fontSize: 48,
                                color: AppColors.textTertiary
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '开始聊天吧',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.textTertiary,
                                  ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        return _MessageBubble(
                          message: messages[index],
                          threadId: widget.threadId,
                        );
                      },
                    );
                  },
                ),

                // 亲密度变化动画
                if (_showIntimacyChange)
                  Positioned(
                    top: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: IntimacyChangeAnimation(
                        change: _intimacyChange,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 输入区域
          Consumer<ChatProvider>(
            builder: (context, chatProvider, child) {
              final thread = chatProvider.getThread(widget.threadId);
              final canSend = thread?.canSendMessage ?? true;

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.pureBlack,
                  border: Border(
                    top: BorderSide(color: AppColors.white05),
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          maxLength: 300,
                          maxLines: null,
                          enabled: canSend,
                          decoration: InputDecoration(
                            hintText: canSend ? '说点什么...' : '无法发送消息',
                            counterText: '',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _hasText && canSend
                              ? AppColors.textPrimary
                              : AppColors.white05,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.arrow_upward,
                            color: _hasText && canSend
                                ? AppColors.pureBlack
                                : AppColors.textDisabled,
                          ),
                          onPressed: !_hasText || !canSend
                              ? null
                              : () {
                                  final content = _inputController.text.trim();
                                  if (content.isNotEmpty) {
                                    context.read<ChatProvider>().sendMessage(
                                          widget.threadId,
                                          content,
                                        );
                                    _inputController.clear();
                                    // 清空后自动更新状态
                                    setState(() {
                                      _hasText = false;
                                    });
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getHeaderSubtitle(ChatThread thread, bool isFriend) {
    if (isFriend) {
      return thread.otherUser.isOnline ? '好友 · 在线' : '好友 · 私聊中';
    }

    final nextUnlock = IntimacyUnlock.getNextUnlock(thread.intimacyPoints);
    if (nextUnlock == null) {
      return '聊得很投缘';
    }

    final pointsToNext = _getPointsToNextUnlock(thread.intimacyPoints);
    return '轻聊中 · 距离解锁$nextUnlock还差$pointsToNext分';
  }

  int _getPointsToNextUnlock(int points) {
    if (points < IntimacyUnlock.unlockProfile) {
      return IntimacyUnlock.unlockProfile - points;
    }
    if (points < IntimacyUnlock.canAddFriend) {
      return IntimacyUnlock.canAddFriend - points;
    }
    return 0;
  }

  Widget _buildMenuItem(IconData icon, String text, {bool isDanger = false}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDanger ? AppColors.error : AppColors.textSecondary,
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w300,
            color: isDanger ? AppColors.error : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  void _handleVoiceCall(BuildContext context, User user) async {
    final confirm = await AppDialog.showConfirm(
      context,
      title: '发起语音通话',
      content: '对方接听后将开始计时，通话时长不影响聊天倒计时',
      confirmText: '呼叫',
    );

    if (!context.mounted) return;
    if (confirm == true) {
      final hasPermission =
          await PermissionManager.requestMicrophonePermission(context);
      if (!context.mounted) return;
      if (!hasPermission) {
        AppToast.show(context, '未获得麦克风权限，无法发起语音', isError: true);
        return;
      }

      _showVoiceCallSheet(context, user);
    }
  }

  void _showVoiceCallSheet(BuildContext context, User user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => _VoiceCallSheet(user: user),
    );
  }

  void _showAddFriendDialog(BuildContext context, User user) async {
    final controller = TextEditingController();

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '添加好友',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  maxLength: 50,
                  decoration: const InputDecoration(
                    hintText: '写点什么吧（可选）',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppColors.white05,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '取消',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w300,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppColors.white12,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '发送',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w300,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!context.mounted) {
      controller.dispose();
      return;
    }
    if (result == true) {
      context.read<FriendProvider>().sendFriendRequest(
            user,
            controller.text.trim().isEmpty ? null : controller.text.trim(),
          );
      AppToast.show(context, '好友请求已发送');
    }

    controller.dispose();
  }

  void _showUnfollowDialog(BuildContext context, ChatThread thread) async {
    final confirm = await AppDialog.showConfirm(
      context,
      title: '确定要取关吗？',
      content: '取关后对方只能再发送3条消息，需要你确认后才能继续聊天',
      confirmText: '取关',
      isDanger: true,
    );

    if (confirm == true && context.mounted) {
      context.read<ChatProvider>().unfollowFriend(thread.id);
      context.read<FriendProvider>().removeFriend(thread.otherUser.id);
      AppToast.show(context, '已取关');
    }
  }

  void _showBlockDialog(BuildContext context, ChatThread thread) async {
    final confirm = await AppDialog.showConfirm(
      context,
      title: '确认拉黑该用户？',
      content: '拉黑后不会再匹配到TA，可在设置-黑名单中手动取消。',
      confirmText: '拉黑',
      isDanger: true,
    );

    if (confirm == true && context.mounted) {
      await context.read<FriendProvider>().blockUser(thread.otherUser.id);
      if (!context.mounted) return;
      context.read<ChatProvider>().deleteThread(thread.id);
      AppToast.show(context, '已拉黑');
      context.pop();
    }
  }

  void _showUserProfile(BuildContext context, User user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: AppColors.pureBlack,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.white12,
                        AppColors.white05,
                      ],
                    ),
                  ),
                  alignment: Alignment.bottomCenter,
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white08,
                      border: Border.all(color: AppColors.pureBlack, width: 3),
                    ),
                    child: Center(
                      child: Text(
                        user.avatar ?? '👤',
                        style: const TextStyle(fontSize: 42),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                children: [
                  Text(
                    user.nickname,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _buildProfileInfoCard(
                      title: '在线状态',
                      value: user.isOnline ? '在线中' : '最近在线',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildProfileInfoCard(
                      title: '距离',
                      value: user.distance,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white05,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  '主页内容已解锁，可查看背景与基本资料。后续将继续完善更多互动页签。',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfoCard({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w300,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showSetRemarkDialog(BuildContext context, String userId) async {
    final friend = context.read<FriendProvider>().getFriend(userId);
    final controller = TextEditingController(text: friend?.remark ?? '');

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '设置备注',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  maxLength: 20,
                  decoration: const InputDecoration(
                    hintText: '输入备注名',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppColors.white05,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '取消',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w300,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppColors.white12,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '保存',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w300,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!context.mounted) {
      controller.dispose();
      return;
    }
    if (result == true) {
      final remark = controller.text.trim();
      context.read<FriendProvider>().setRemark(
            userId,
            remark.isEmpty ? null : remark,
          );
      AppToast.show(context, '备注已保存');
    }

    controller.dispose();
  }
}

class _VoiceCallSheet extends StatefulWidget {
  final User user;

  const _VoiceCallSheet({required this.user});

  @override
  State<_VoiceCallSheet> createState() => _VoiceCallSheetState();
}

class _VoiceCallSheetState extends State<_VoiceCallSheet> {
  late final DateTime _startTime;
  bool _isMuted = false;
  bool _isSpeakerOn = true;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.pureBlack,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.white08,
                border: Border.all(color: AppColors.white12, width: 1),
              ),
              child: Center(
                child: Text(
                  widget.user.avatar ?? '👤',
                  style: const TextStyle(fontSize: 34),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.user.nickname,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w300,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<int>(
              stream:
                  Stream.periodic(const Duration(seconds: 1), (x) => x).asBroadcastStream(),
              initialData: 0,
              builder: (context, snapshot) {
                final elapsed = DateTime.now().difference(_startTime);
                final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
                final seconds =
                    (elapsed.inSeconds % 60).toString().padLeft(2, '0');
                return Text(
                  '通话中  $minutes:$seconds',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w300,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCallAction(
                  icon: _isMuted ? Icons.mic_off : Icons.mic_none,
                  label: _isMuted ? '已静音' : '静音',
                  onTap: () => setState(() => _isMuted = !_isMuted),
                ),
                const SizedBox(width: 16),
                _buildCallAction(
                  icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                  label: _isSpeakerOn ? '扬声器' : '听筒',
                  onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                ),
                const SizedBox(width: 16),
                _buildCallAction(
                  icon: Icons.call_end,
                  label: '挂断',
                  isDanger: true,
                  onTap: () {
                    Navigator.pop(context);
                    AppToast.show(context, '通话已结束');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Container(
        width: 78,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isDanger
              ? AppColors.error.withValues(alpha: 0.2)
              : AppColors.white08,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDanger ? AppColors.error : AppColors.textPrimary,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDanger ? AppColors.error : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final String threadId;

  const _MessageBubble({
    required this.message,
    required this.threadId,
  });

  @override
  Widget build(BuildContext context) {
    // 判断是否可以撤回（2分钟内）
    final canRecall = message.isMe &&
        message.status == MessageStatus.sent &&
        DateTime.now().difference(message.timestamp).inMinutes < 2;

    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment:
            message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 发送失败的感叹号（仅自己的消息）
          if (message.isMe && message.status == MessageStatus.failed) ...[
            GestureDetector(
              onTap: () {
                // 点击重新发送
                context
                    .read<ChatProvider>()
                    .resendMessage(threadId, message.id);
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8, bottom: 12),
                child: Icon(
                  Icons.error_outline,
                  size: 20,
                  color: AppColors.error,
                ),
              ),
            ),
          ],

          // 消息气泡
          GestureDetector(
            onLongPress: message.status == MessageStatus.sending
                ? null
                : () async {
                    final action = await AppDialog.showMessageActions(
                      context,
                      isMe: message.isMe,
                      canRecall: canRecall,
                    );

                    if (action == 'copy') {
                      await Clipboard.setData(
                          ClipboardData(text: message.content));
                      if (!context.mounted) return;
                      AppToast.show(context, '已复制');
                    } else if (action == 'recall') {
                      if (!context.mounted) return;
                      final confirm = await AppDialog.showConfirm(
                        context,
                        title: '确定要撤回这条消息吗？',
                        confirmText: '撤回',
                        isDanger: true,
                      );

                      if (!context.mounted) return;
                      if (confirm == true) {
                        context
                            .read<ChatProvider>()
                            .recallMessage(threadId, message.id);
                        AppToast.show(context, '已撤回');
                      }
                    }
                  },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              decoration: BoxDecoration(
                color: message.isMe
                    ? (message.status == MessageStatus.failed
                        ? AppColors.error.withValues(alpha: 0.2)
                        : const Color(0x99464646))
                    : const Color(0xCC282828),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: message.isMe
                      ? const Radius.circular(18)
                      : const Radius.circular(4),
                  bottomRight: message.isMe
                      ? const Radius.circular(4)
                      : const Radius.circular(18),
                ),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.3,
                  color: message.status == MessageStatus.failed
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ),

          // 发送中的加载动画（仅自己的消息）
          if (message.isMe && message.status == MessageStatus.sending) ...[
            Container(
              margin: const EdgeInsets.only(left: 8, bottom: 12),
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
