import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../core/feedback/app_feedback.dart';
import '../core/ui/ui_tokens.dart';
import '../models/models.dart';
import '../providers/chat_provider.dart';
import '../providers/friend_provider.dart';
import '../providers/notification_center_provider.dart';
import '../utils/chat_delivery_state.dart';
import 'app_toast.dart';
import 'chat_delivery_status.dart';

class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key});

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesLayoutSpec {
  const _MessagesLayoutSpec({
    required this.isCompact,
    required this.searchOuterPadding,
    required this.searchContentPadding,
    required this.searchIconSize,
    required this.itemPadding,
    required this.avatarSize,
    required this.avatarTextSize,
    required this.avatarGap,
    required this.titleSize,
    required this.previewSize,
    required this.metaSize,
    required this.tagSpacing,
    required this.previewGap,
    required this.priorityTopSpacing,
  });

  final bool isCompact;
  final EdgeInsets searchOuterPadding;
  final EdgeInsets searchContentPadding;
  final double searchIconSize;
  final EdgeInsets itemPadding;
  final double avatarSize;
  final double avatarTextSize;
  final double avatarGap;
  final double titleSize;
  final double previewSize;
  final double metaSize;
  final double tagSpacing;
  final double previewGap;
  final double priorityTopSpacing;

  static _MessagesLayoutSpec fromSize(Size size) {
    final isCompact = size.width <= 390 || size.height <= 720;
    if (isCompact) {
      return const _MessagesLayoutSpec(
        isCompact: true,
        searchOuterPadding: EdgeInsets.fromLTRB(12, 6, 12, 2),
        searchContentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        searchIconSize: 17,
        itemPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        avatarSize: 50,
        avatarTextSize: 24,
        avatarGap: 11,
        titleSize: 14.5,
        previewSize: 13,
        metaSize: 10.5,
        tagSpacing: 6,
        previewGap: 4,
        priorityTopSpacing: 6,
      );
    }

    return const _MessagesLayoutSpec(
      isCompact: false,
      searchOuterPadding: EdgeInsets.fromLTRB(16, 8, 16, 4),
      searchContentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      searchIconSize: 18,
      itemPadding: UiTokens.cardPadding,
      avatarSize: 56,
      avatarTextSize: 28,
      avatarGap: 16,
      titleSize: 16,
      previewSize: 14,
      metaSize: 12,
      tagSpacing: 8,
      previewGap: 6,
      priorityTopSpacing: 8,
    );
  }
}

class _MessagesTabState extends State<MessagesTab> {
  static const Duration _threadRefreshInterval = Duration(seconds: 30);

  Timer? _timer;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_threadRefreshInterval, (_) {
      if (mounted) setState(() {});
    });
    _searchController.addListener(() {
      final q = _searchController.text.trim();
      if (q != _searchQuery) setState(() => _searchQuery = q);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.pureBlack,
        elevation: 0,
        title: const Text(
          '消息',
          key: Key('messages-tab-title'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
          ),
        ),
        centerTitle: false,
        actions: [
          Consumer<NotificationCenterProvider>(
            builder: (context, provider, child) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none),
                    onPressed: () => context.push('/notifications'),
                  ),
                  if (provider.unreadCount > 0)
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
                          provider.unreadCount > 99
                              ? '99+'
                              : '${provider.unreadCount}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.pureBlack,
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
      body: Consumer2<ChatProvider, FriendProvider>(
        builder: (context, chatProvider, friendProvider, child) {
          final layout =
              _MessagesLayoutSpec.fromSize(MediaQuery.of(context).size);
          final allThreads = chatProvider.sortedThreads;
          final threads = _searchQuery.isEmpty
              ? allThreads
              : allThreads
                  .where((t) => t.otherUser.nickname
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase()))
                  .toList();

          return Column(
            children: [
              Padding(
                padding: layout.searchOuterPadding,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: '搜索',
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textTertiary,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: layout.searchIconSize,
                      color: AppColors.textTertiary,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () => _searchController.clear(),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: AppColors.textTertiary,
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.white08,
                    contentPadding: layout.searchContentPadding,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: allThreads.isEmpty
                    ? _EmptyMessagesState()
                    : threads.isEmpty
                        ? const Center(
                            child: Text(
                              '没有匹配的对话',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: threads.length,
                            itemBuilder: (context, index) {
                              final thread = threads[index];
                              final messages =
                                  chatProvider.getMessages(thread.id);
                              final lastMessage =
                                  messages.isNotEmpty ? messages.last : null;
                              final draft = chatProvider.draftForThread(
                                thread.id,
                              );
                              final isFriend = friendProvider
                                      .isFriend(thread.otherUser.id) &&
                                  !friendProvider.isBlocked(
                                    thread.otherUser.id,
                                  );
                              final deliveryFailureState = lastMessage !=
                                          null &&
                                      lastMessage.status == MessageStatus.failed
                                  ? chatProvider.deliveryFailureStateFor(
                                      thread.id,
                                      lastMessage.id,
                                    )
                                  : null;
                              final deliveryState = lastMessage == null
                                  ? const ChatDeliveryStatusSpec()
                                  : (resolveChatDeliveryStatus(
                                        lastMessage,
                                        failureState: deliveryFailureState ??
                                            ChatDeliveryFailureState.retryable,
                                      ) ??
                                      const ChatDeliveryStatusSpec());

                              return _AnimatedThreadEntry(
                                index: index,
                                child: Dismissible(
                                  key: Key(thread.id),
                                  direction: DismissDirection.endToStart,
                                  confirmDismiss: (_) async {
                                    final confirm = await AppDialog.showConfirm(
                                      context,
                                      title: '确定要删除这段对话吗？',
                                      content: '删除后将无法恢复',
                                      confirmText: '删除',
                                      isDanger: true,
                                    );
                                    return confirm == true;
                                  },
                                  background: Container(
                                    color: Colors.transparent,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    child: Icon(
                                      Icons.delete_outline,
                                      color: AppColors.error.withValues(
                                        alpha: 0.5,
                                      ),
                                      size: 28,
                                    ),
                                  ),
                                  onDismissed: (_) {
                                    chatProvider.deleteThread(thread.id);
                                    AppFeedback.showToast(
                                      context,
                                      AppToastCode.deleted,
                                      subject: '对话',
                                    );
                                  },
                                  child: _ThreadItem(
                                    thread: thread,
                                    lastMessage: lastMessage,
                                    draft: draft,
                                    isFriend: isFriend,
                                    deliveryFailureState: deliveryFailureState,
                                    deliveryState: deliveryState,
                                    isPinned: chatProvider.isThreadPinned(
                                      thread.id,
                                    ),
                                    onTap: () {
                                      final routeThreadId =
                                          chatProvider.routeThreadId(
                                                threadId: thread.id,
                                                userId: thread.otherUser.id,
                                              ) ??
                                              thread.id;
                                      context
                                          .push('/chat/$routeThreadId')
                                          .then((
                                        _,
                                      ) {
                                        if (context.mounted) {
                                          context.go('/main?tab=0');
                                        }
                                      });
                                    },
                                    onLongPress: () => _showThreadOptions(
                                      context,
                                      thread,
                                      chatProvider,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showThreadOptions(
    BuildContext context,
    ChatThread thread,
    ChatProvider chatProvider,
  ) {
    final isPinned = chatProvider.isThreadPinned(thread.id);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AppOverlay.sheetAnimationStyle,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: AppOverlay.sheetBorderRadius,
        ),
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.white12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(
                isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: isPinned ? AppColors.brandBlue : AppColors.textSecondary,
                size: 20,
              ),
              title: Text(
                isPinned ? '取消置顶' : '置顶对话',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                if (isPinned) {
                  chatProvider.unpinThread(thread.id);
                } else {
                  chatProvider.pinThread(thread.id);
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppColors.error,
                size: 20,
              ),
              title: const Text(
                '删除对话',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: AppColors.error,
                ),
              ),
              onTap: () async {
                Navigator.of(context).pop();
                final confirm = await AppDialog.showConfirm(
                  context,
                  title: '确定要删除这段对话吗？',
                  content: '删除后将无法恢复',
                  confirmText: '删除',
                  isDanger: true,
                );
                if (confirm == true && context.mounted) {
                  chatProvider.deleteThread(thread.id);
                  AppFeedback.showToast(
                    context,
                    AppToastCode.deleted,
                    subject: '对话',
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedThreadEntry extends StatefulWidget {
  const _AnimatedThreadEntry({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_AnimatedThreadEntry> createState() => _AnimatedThreadEntryState();
}

class _AnimatedThreadEntryState extends State<_AnimatedThreadEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 260),
      vsync: this,
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // Stagger: max 8 items × 30ms = 240ms cap
    final delay = Duration(milliseconds: (widget.index.clamp(0, 8) * 30));
    Future.delayed(delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class _EmptyMessagesState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 56,
            color: AppColors.textTertiary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          Text(
            '还没有消息',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textTertiary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '去匹配一个人，开始聊聊吧',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ThreadItem extends StatelessWidget {
  const _ThreadItem({
    required this.thread,
    required this.lastMessage,
    required this.draft,
    required this.isFriend,
    required this.deliveryFailureState,
    required this.deliveryState,
    required this.onTap,
    this.onLongPress,
    this.isPinned = false,
  });

  final ChatThread thread;
  final Message? lastMessage;
  final String draft;
  final bool isFriend;
  final ChatDeliveryFailureState? deliveryFailureState;
  final ChatDeliveryStatusSpec deliveryState;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isPinned;

  @override
  Widget build(BuildContext context) {
    final isOnline = thread.otherUser.isOnline;
    final hasDraft = draft.trim().isNotEmpty;
    final layout = _MessagesLayoutSpec.fromSize(MediaQuery.of(context).size);
    final showInlineIntimacy = !isFriend && !layout.isCompact;
    final showTrailingIntimacy = !isFriend && layout.isCompact;
    final moveUnreadBadgeToMetaRow = layout.isCompact && thread.unreadCount > 0;
    final priority = _resolvePriorityState(
      hasDraft: hasDraft,
      isFriend: isFriend,
      deliveryFailureState: deliveryFailureState,
      deliveryState: deliveryState,
    );
    final showUrgencyHint = !isFriend &&
        thread.timeRemaining.inMinutes > 0 &&
        thread.timeRemaining.inMinutes <= 120;
    final accentColor = priority?.color ??
        (thread.unreadCount > 0
            ? AppColors.brandBlue.withValues(alpha: 0.2)
            : AppColors.white05);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        key: Key('messages-thread-item-${thread.id}'),
        padding: layout.itemPadding,
        decoration: BoxDecoration(
          color: isPinned
              ? AppColors.white05
              : hasDraft
                  ? AppColors.warning.withValues(alpha: 0.04)
                  : (thread.unreadCount > 0
                      ? AppColors.brandBlue.withValues(alpha: 0.035)
                      : null),
          gradient: isOnline && !isFriend
              ? LinearGradient(
                  colors: [
                    AppColors.brandBlue.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          border: Border(
            bottom: BorderSide(color: accentColor),
          ),
        ),
        child: Row(
          children: [
            _ThreadAvatar(
              thread: thread,
              isFriend: isFriend,
              isOnline: isOnline,
              layout: layout,
            ),
            SizedBox(width: layout.avatarGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: layout.tagSpacing,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              thread.otherUser.nickname,
                              style: TextStyle(
                                fontSize: layout.titleSize,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (isFriend)
                              _TinyTag(
                                label: '好友',
                                background:
                                    AppColors.brandBlue.withValues(alpha: 0.15),
                                foreground: AppColors.brandBlue,
                              ),
                            if (isPinned)
                              const Icon(
                                Icons.push_pin,
                                size: 12,
                                color: AppColors.textTertiary,
                              ),
                          ],
                        ),
                      ),
                      Text(
                        _formatTime(lastMessage?.timestamp),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: layout.metaSize,
                            ),
                      ),
                    ],
                  ),
                  SizedBox(height: layout.previewGap),
                  Row(
                    children: [
                      Expanded(
                        child: hasDraft
                            ? Row(
                                children: [
                                  _TinyTag(
                                    label: '草稿',
                                    background: AppColors.warning
                                        .withValues(alpha: 0.14),
                                    foreground: AppColors.warning,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      draft,
                                      style: TextStyle(
                                        fontSize: layout.previewSize,
                                        fontWeight: FontWeight.w300,
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                deliveryState.previewText ??
                                    lastMessage?.content ??
                                    '开始聊天吧',
                                style: TextStyle(
                                  fontSize: layout.previewSize,
                                  fontWeight: FontWeight.w300,
                                  color: deliveryState.previewColor ??
                                      (thread.unreadCount > 0
                                          ? AppColors.textSecondary
                                          : AppColors.textTertiary),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      if (!hasDraft && deliveryState.hasBadge) ...[
                        const SizedBox(width: 8),
                        ChatDeliveryBadge(
                          label: deliveryState.badgeLabel!,
                          color: deliveryState.badgeColor!,
                          icon: deliveryState.badgeIcon!,
                          emphasized: deliveryState.isSuccessState,
                        ),
                      ],
                      if (showInlineIntimacy) ...[
                        const SizedBox(width: 8),
                        _buildIntimacyChip(layout),
                      ],
                      if (!moveUnreadBadgeToMetaRow &&
                          thread.unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          key: Key('messages-thread-unread-${thread.id}'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          constraints: const BoxConstraints(minWidth: 18),
                          decoration: const BoxDecoration(
                            color: AppColors.brandBlue,
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          child: Text(
                            thread.unreadCount > 99
                                ? '99+'
                                : '${thread.unreadCount}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: layout.metaSize - 1,
                              fontWeight: FontWeight.w600,
                              color: AppColors.pureBlack,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (priority != null || showUrgencyHint) ...[
                    SizedBox(height: layout.priorityTopSpacing),
                    Wrap(
                      spacing: layout.tagSpacing,
                      runSpacing: 6,
                      children: [
                        if (priority != null)
                          _TinyTag(
                            key: Key('messages-thread-priority-${thread.id}'),
                            label: priority.label,
                            background: priority.color.withValues(alpha: 0.14),
                            foreground: priority.color,
                          ),
                        if (showUrgencyHint)
                          _TinyTag(
                            key: Key('messages-thread-expiring-${thread.id}'),
                            label: '即将到期',
                            background: AppColors.error.withValues(alpha: 0.12),
                            foreground: AppColors.error,
                          ),
                      ],
                    ),
                  ],
                  if (!isFriend) ...[
                    SizedBox(height: layout.previewGap),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: layout.metaSize,
                          color: thread.timeRemaining.inHours < 2
                              ? AppColors.error
                              : AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _formatTimeRemaining(
                              thread.timeRemaining,
                              compact: layout.isCompact,
                            ),
                            style: TextStyle(
                              fontSize: layout.metaSize,
                              fontWeight: FontWeight.w300,
                              color: thread.timeRemaining.inHours < 2
                                  ? AppColors.error
                                  : AppColors.textTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (moveUnreadBadgeToMetaRow) ...[
                          const SizedBox(width: 8),
                          Container(
                            key: Key('messages-thread-unread-${thread.id}'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            constraints: const BoxConstraints(minWidth: 18),
                            decoration: const BoxDecoration(
                              color: AppColors.brandBlue,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)),
                            ),
                            child: Text(
                              thread.unreadCount > 99
                                  ? '99+'
                                  : '${thread.unreadCount}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: layout.metaSize - 1,
                                fontWeight: FontWeight.w600,
                                color: AppColors.pureBlack,
                              ),
                            ),
                          ),
                        ],
                        if (showTrailingIntimacy) ...[
                          const SizedBox(width: 8),
                          _buildIntimacyChip(layout),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _ThreadPriorityState? _resolvePriorityState({
    required bool hasDraft,
    required bool isFriend,
    required ChatDeliveryFailureState? deliveryFailureState,
    required ChatDeliveryStatusSpec deliveryState,
  }) {
    if (hasDraft) {
      return const _ThreadPriorityState(
        label: '寰呭彂鑽夌',
        color: AppColors.warning,
      );
    }
    if (deliveryFailureState == ChatDeliveryFailureState.threadExpired) {
      return const _ThreadPriorityState(
        label: '会话过期',
        color: AppColors.warning,
      );
    }
    if (deliveryFailureState == ChatDeliveryFailureState.blockedRelation) {
      return const _ThreadPriorityState(
        label: '关系受限',
        color: AppColors.warning,
      );
    }
    if (deliveryFailureState ==
        ChatDeliveryFailureState.imageUploadTokenInvalid) {
      return const _ThreadPriorityState(
        label: '凭证失效',
        color: AppColors.warning,
      );
    }
    if (deliveryFailureState == ChatDeliveryFailureState.networkIssue) {
      return const _ThreadPriorityState(
        label: '网络波动',
        color: AppColors.warning,
      );
    }
    if (deliveryFailureState ==
        ChatDeliveryFailureState.imageUploadPreparationFailed) {
      return const _ThreadPriorityState(
        label: '上传失败',
        color: AppColors.error,
      );
    }
    if (deliveryFailureState ==
        ChatDeliveryFailureState.imageUploadInterrupted) {
      return const _ThreadPriorityState(
        label: '上传中断',
        color: AppColors.error,
      );
    }
    if (deliveryFailureState ==
        ChatDeliveryFailureState.imageReselectRequired) {
      return const _ThreadPriorityState(
        label: '重选图片',
        color: AppColors.error,
      );
    }
    if (deliveryFailureState == ChatDeliveryFailureState.retryUnavailable) {
      return const _ThreadPriorityState(
        label: '暂不可重试',
        color: AppColors.warning,
      );
    }
    if (deliveryState.actionType == ChatDeliveryAction.retry) {
      return const _ThreadPriorityState(
        label: '寤鸿浼樺厛澶勭悊',
        color: AppColors.error,
      );
    }
    if (deliveryState.actionType == ChatDeliveryAction.showGuide) {
      if (deliveryState.guideFailureState ==
          ChatDeliveryFailureState.imageUploadFileTooLarge) {
        return const _ThreadPriorityState(
          label: '图片过大',
          color: AppColors.error,
        );
      }
      if (deliveryState.guideFailureState ==
          ChatDeliveryFailureState.imageUploadUnsupportedFormat) {
        return const _ThreadPriorityState(
          label: '格式异常',
          color: AppColors.error,
        );
      }
      return const _ThreadPriorityState(
        label: '鍥剧墖闇€閲嶆柊閫夋嫨',
        color: AppColors.error,
      );
    }
    if (thread.unreadCount > 0) {
      return const _ThreadPriorityState(
        label: '鏈夋柊娑堟伅',
        color: AppColors.brandBlue,
      );
    }
    if (!isFriend && thread.otherUser.isOnline) {
      return const _ThreadPriorityState(
        label: '鐜板湪閫傚悎鍥炲',
        color: AppColors.success,
      );
    }
    return null;
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }

  String _formatTimeRemaining(
    Duration duration, {
    required bool compact,
  }) {
    if (duration.isNegative) return '已过期';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (compact) {
      return '剩$hours小时$minutes分';
    }
    return '剩余 $hours小时$minutes分钟';
  }

  Widget _buildIntimacyChip(_MessagesLayoutSpec layout) {
    return Container(
      key: Key('messages-thread-intimacy-${thread.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.favorite,
            size: layout.metaSize - 1,
            color: Colors.orange.shade400,
          ),
          const SizedBox(width: 3),
          Text(
            '${thread.intimacyPoints}',
            style: TextStyle(
              fontSize: layout.metaSize - 1,
              fontWeight: FontWeight.w500,
              color: Colors.orange.shade400,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadPriorityState {
  const _ThreadPriorityState({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;
}

class _ThreadAvatar extends StatelessWidget {
  const _ThreadAvatar({
    required this.thread,
    required this.isFriend,
    required this.isOnline,
    required this.layout,
  });

  final ChatThread thread;
  final bool isFriend;
  final bool isOnline;
  final _MessagesLayoutSpec layout;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: layout.avatarSize,
          height: layout.avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.white08,
            border: Border.all(
              color: isFriend
                  ? AppColors.brandBlue.withValues(alpha: 0.5)
                  : AppColors.white05,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              thread.otherUser.avatar ?? '👤',
              style: TextStyle(
                fontSize: layout.avatarTextSize,
                color: AppColors.pureBlack,
              ),
            ),
          ),
        ),
        if (isOnline)
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.pureBlack,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        if (thread.unreadCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              child: Text(
                thread.unreadCount > 99 ? '99+' : '${thread.unreadCount}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.pureBlack,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _TinyTag extends StatelessWidget {
  const _TinyTag({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: foreground,
        ),
      ),
    );
  }
}
