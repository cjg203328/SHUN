import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../core/feedback/app_feedback.dart';
import '../providers/friend_provider.dart';
import '../providers/chat_provider.dart';
import '../models/models.dart';
import 'app_toast.dart';

class FriendsTab extends StatelessWidget {
  const FriendsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.pureBlack,
        elevation: 0,
        title: const Text(
          '好友',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        actions: [
          // 好友请求入口
          Consumer<FriendProvider>(
            builder: (context, friendProvider, child) {
              final count = friendProvider.pendingRequestCount;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.person_add_outlined),
                    onPressed: () {
                      _showFriendRequests(context);
                    },
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<FriendProvider>(
        builder: (context, friendProvider, child) {
          final friends = friendProvider.friendList;

          if (friends.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '👥',
                    style: TextStyle(
                      fontSize: 64,
                      color: AppColors.textTertiary.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '暂无好友',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '持续互动并达到阶段二后可互关',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              return _FriendItem(
                friend: friend,
                onTap: () {
                  // 创建好友聊天会话（无时间限制）
                  final thread = ChatThread(
                    id: friend.id,
                    otherUser: friend.user,
                    createdAt: DateTime.now(),
                    expiresAt: DateTime.now().add(const Duration(days: 365)),
                    intimacyPoints: 250, // 好友默认满亲密度
                    isFriend: true,
                  );

                  context.read<ChatProvider>().addThread(thread);
                  // 从好友页进入聊天，返回时应该回到好友页
                  context.push('/chat/${thread.id}').then((_) {
                    if (context.mounted) {
                      context.go('/main?tab=2');
                    }
                  });
                },
                onLongPress: () {
                  _showFriendOptions(context, friend);
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showFriendRequests(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: AppDialog.sheetDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Text(
                    '好友请求',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Consumer<FriendProvider>(
                builder: (context, friendProvider, child) {
                  final requests = friendProvider.pendingRequests;

                  if (requests.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text(
                          '暂无好友请求',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textTertiary,
                                  ),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      return _FriendRequestItem(request: requests[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFriendOptions(BuildContext context, Friend friend) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (context) => Container(
        decoration: AppDialog.sheetDecoration(),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionItem(
                context,
                icon: Icons.edit_outlined,
                text: '设置备注',
                onTap: () => Navigator.pop(context, 'remark'),
              ),
              _buildActionItem(
                context,
                icon: Icons.person_outline,
                text: '查看主页',
                onTap: () => Navigator.pop(context, 'profile'),
              ),
              _buildActionItem(
                context,
                icon: Icons.delete_outline,
                text: '删除好友',
                onTap: () => Navigator.pop(context, 'delete'),
                isDanger: true,
              ),
              _buildActionItem(
                context,
                icon: Icons.person_remove_outlined,
                text: '取关',
                onTap: () => Navigator.pop(context, 'unfollow'),
                isDanger: true,
              ),
              _buildActionItem(
                context,
                icon: Icons.block_outlined,
                text: '拉黑',
                onTap: () => Navigator.pop(context, 'block'),
                isDanger: true,
              ),
              const SizedBox(height: 8),
              _buildActionItem(
                context,
                icon: Icons.close,
                text: '取消',
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );

    if (action == 'remark' && context.mounted) {
      _showSetRemarkDialog(context, friend);
    } else if (action == 'profile' && context.mounted) {
      _showFriendProfile(context, friend);
    } else if (action == 'unfollow' && context.mounted) {
      final confirm = await AppDialog.showConfirm(
        context,
        title: '确定要取关吗？',
        content: '取关后对方只能再发送3条消息，需要你确认后才能继续聊天',
        confirmText: '取关',
        isDanger: true,
      );

      if (confirm == true && context.mounted) {
        context.read<FriendProvider>().removeFriend(friend.id);
        // 如果有聊天会话，也要更新
        final chatProvider = context.read<ChatProvider>();
        final thread = chatProvider.getThread(friend.id);
        if (thread != null) {
          chatProvider.unfollowFriend(friend.id);
        }
        AppFeedback.showToast(
          context,
          AppToastCode.disabled,
          subject: '互关',
        );
      }
    } else if (action == 'delete' && context.mounted) {
      final confirm = await AppDialog.showConfirm(
        context,
        title: '确定要删除好友吗？',
        content: '删除后将无法恢复',
        confirmText: '删除',
        isDanger: true,
      );

      if (confirm == true && context.mounted) {
        context.read<FriendProvider>().removeFriend(friend.id);
        AppFeedback.showToast(context, AppToastCode.deleted, subject: '好友');
      }
    } else if (action == 'block' && context.mounted) {
      final confirm = await AppDialog.showConfirm(
        context,
        title: '确认拉黑该好友？',
        content: '拉黑后不会再匹配到TA，可在设置-黑名单中手动取消。',
        confirmText: '拉黑',
        isDanger: true,
      );

      if (confirm == true && context.mounted) {
        await context.read<FriendProvider>().blockUser(friend.id);
        if (!context.mounted) return;
        AppFeedback.showToast(context, AppToastCode.enabled, subject: '拉黑');
      }
    }
  }

  void _showFriendProfile(BuildContext context, Friend friend) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: AppDialog.sheetDecoration(color: AppColors.pureBlack),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: 210,
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
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white08,
                      border: Border.all(color: AppColors.pureBlack, width: 3),
                    ),
                    child: Center(
                      child: Text(
                        friend.user.avatar ?? '👤',
                        style: const TextStyle(fontSize: 40),
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
            const SizedBox(height: 16),
            Text(
              friend.displayName,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w300,
                color: AppColors.textPrimary,
              ),
            ),
            if (friend.remark != null) ...[
              const SizedBox(height: 6),
              Text(
                '昵称：${friend.user.nickname}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _buildInfoCard('累计聊天', '${friend.chatCount} 次'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInfoCard('总时长', '${friend.totalMinutes} 分钟'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildInfoCard('状态', friend.user.status),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }

  void _showSetRemarkDialog(BuildContext context, Friend friend) async {
    final controller = TextEditingController(text: friend.remark ?? '');

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: AppDialog.sheetDecoration(),
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
                  autofocus: true,
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

    if (result == true && context.mounted) {
      final remark = controller.text.trim();
      context.read<FriendProvider>().setRemark(
            friend.id,
            remark.isEmpty ? null : remark,
          );
      AppFeedback.showToast(context, AppToastCode.saved, subject: '备注');
    }

    controller.dispose();
  }

  Widget _buildActionItem(
    BuildContext context, {
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDanger ? AppColors.error : AppColors.textSecondary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  color: isDanger ? AppColors.error : AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendItem extends StatelessWidget {
  final Friend friend;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FriendItem({
    required this.friend,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.white05),
          ),
        ),
        child: Row(
          children: [
            // 头像
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.white08,
                border: Border.all(
                    color: AppColors.brandBlue.withValues(alpha: 0.3),
                    width: 2),
              ),
              child: Center(
                child: Text(
                  friend.user.avatar ?? '👤',
                  style: const TextStyle(
                    fontSize: 28,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (friend.remark != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '昵称：${friend.user.nickname}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w300,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 箭头
            const Icon(
              Icons.chevron_right,
              color: AppColors.textDisabled,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendRequestItem extends StatelessWidget {
  final FriendRequest request;

  const _FriendRequestItem({required this.request});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.white05),
        ),
      ),
      child: Row(
        children: [
          // 头像
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.white08,
            ),
            child: Center(
              child: Text(
                request.fromUser.avatar ?? '👤',
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.fromUser.nickname,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (request.message != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    request.message!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 12),

          // 按钮
          Row(
            children: [
              TextButton(
                onPressed: () {
                  context
                      .read<FriendProvider>()
                      .rejectFriendRequest(request.id);
                  AppFeedback.showToast(
                    context,
                    AppToastCode.disabled,
                    subject: '好友请求',
                  );
                },
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  backgroundColor: AppColors.white05,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: Size.zero,
                ),
                child: const Text(
                  '拒绝',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  context
                      .read<FriendProvider>()
                      .acceptFriendRequest(request.id);
                  AppFeedback.showToast(
                    context,
                    AppToastCode.enabled,
                    subject: '互关',
                  );
                },
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  backgroundColor: AppColors.brandBlue.withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: Size.zero,
                ),
                child: const Text(
                  '接受',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.brandBlue,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
