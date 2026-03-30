import 'dart:async';

import 'package:flutter/foundation.dart';
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
import 'app_user_avatar.dart';
import 'chat_delivery_status.dart';

class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key, DateTime Function()? nowProvider})
      : nowProvider = nowProvider ?? DateTime.now;

  final DateTime Function() nowProvider;

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
  final ValueNotifier<int> _relativeTimeTick = ValueNotifier<int>(0);
  int _cachedThreadListRevision = -1;
  _MessagesThreadListViewData? _cachedThreadListViewData;
  final Map<String, _MessagesThreadSummaryCacheEntry> _threadSummaryViewCache =
      <String, _MessagesThreadSummaryCacheEntry>{};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_threadRefreshInterval, (_) {
      if (!mounted) return;
      _relativeTimeTick.value++;
    });
    _searchController.addListener(() {
      final q = _searchController.text.trim();
      if (q != _searchQuery) setState(() => _searchQuery = q);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _relativeTimeTick.dispose();
    _searchController.dispose();
    super.dispose();
  }

  _MessagesThreadListViewData _selectThreadListViewData(
    ChatProvider chatProvider,
  ) {
    final revision = chatProvider.threadListPresentationRevision;
    final cachedState = _cachedThreadListViewData;
    if (cachedState != null && _cachedThreadListRevision == revision) {
      return cachedState;
    }

    final viewData = _MessagesThreadListViewData(
      entries: chatProvider.sortedThreads
          .map(
            (thread) => _MessagesThreadListEntryViewData(
              threadId: thread.id,
              userId: thread.otherUser.id,
              nickname: thread.otherUser.nickname,
            ),
          )
          .toList(growable: false),
    );
    if (_threadSummaryViewCache.isNotEmpty) {
      final visibleThreadIds =
          viewData.entries.map((entry) => entry.threadId).toSet();
      _threadSummaryViewCache.removeWhere(
        (threadId, _) => !visibleThreadIds.contains(threadId),
      );
    }
    _cachedThreadListRevision = revision;
    _cachedThreadListViewData = viewData;
    return viewData;
  }

  _MessagesThreadSummaryViewData? _selectThreadSummaryViewData(
    ChatProvider chatProvider,
    String threadId,
    bool isFriend,
  ) {
    final snapshot = chatProvider.threadSummarySnapshot(threadId);
    if (snapshot == null) {
      _threadSummaryViewCache.remove(threadId);
      return null;
    }
    final cachedState = _threadSummaryViewCache[threadId];
    if (cachedState != null &&
        identical(cachedState.snapshot, snapshot) &&
        cachedState.isFriend == isFriend) {
      return cachedState.viewData;
    }

    final viewData = _MessagesThreadSummaryViewData.fromSnapshot(
      snapshot,
      isFriend: isFriend,
    );
    _threadSummaryViewCache[threadId] = _MessagesThreadSummaryCacheEntry(
      snapshot: snapshot,
      isFriend: isFriend,
      viewData: viewData,
    );
    return viewData;
  }

  @override
  Widget build(BuildContext context) {
    final layout = _MessagesLayoutSpec.fromSize(MediaQuery.of(context).size);
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
          Selector<NotificationCenterProvider, int>(
            selector: (context, provider) => provider.unreadCount,
            builder: (context, unreadCount, child) {
              return Stack(
                children: [
                  child!,
                  if (unreadCount > 0)
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
                          unreadCount > 99 ? '99+' : '$unreadCount',
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
            child: IconButton(
              icon: const Icon(Icons.notifications_none),
              onPressed: () => context.push('/notifications'),
            ),
          ),
        ],
      ),
      body: Column(
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
            child: Selector<ChatProvider, int>(
              selector: (context, chatProvider) =>
                  chatProvider.threadListPresentationRevision,
              builder: (context, _, child) {
                final listViewData = _selectThreadListViewData(
                  context.read<ChatProvider>(),
                );
                final normalizedQuery = _searchQuery.toLowerCase();
                final threads = _searchQuery.isEmpty
                    ? listViewData.entries
                    : listViewData.entries
                        .where(
                          (entry) => entry.nickname
                              .toLowerCase()
                              .contains(normalizedQuery),
                        )
                        .toList(growable: false);

                if (listViewData.isEmpty) {
                  return _EmptyMessagesState();
                }

                if (threads.isEmpty) {
                  return const Center(
                    child: Text(
                      '没有匹配的对话',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: threads.length,
                  itemBuilder: (context, index) {
                    final entry = threads[index];
                    return _ThreadListEntry(
                      index: index,
                      threadId: entry.threadId,
                      userId: entry.userId,
                      relativeTimeListenable: _relativeTimeTick,
                      nowProvider: widget.nowProvider,
                      selectSummary: _selectThreadSummaryViewData,
                      onShowThreadOptions: _showThreadOptions,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showThreadOptions(
    BuildContext context,
    String threadId,
    bool isPinned,
  ) {
    final chatProvider = context.read<ChatProvider>();
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
                  chatProvider.unpinThread(threadId);
                } else {
                  chatProvider.pinThread(threadId);
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
                  chatProvider.deleteThread(threadId);
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

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 260),
      vsync: this,
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

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
    return FadeTransition(opacity: _opacity, child: widget.child);
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

class _MessagesThreadListViewData {
  const _MessagesThreadListViewData({
    required this.entries,
  });

  final List<_MessagesThreadListEntryViewData> entries;

  bool get isEmpty => entries.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MessagesThreadListViewData &&
          listEquals(other.entries, entries);

  @override
  int get hashCode => Object.hashAll(entries);
}

class _MessagesThreadListEntryViewData {
  const _MessagesThreadListEntryViewData({
    required this.threadId,
    required this.userId,
    required this.nickname,
  });

  final String threadId;
  final String userId;
  final String nickname;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MessagesThreadListEntryViewData &&
          other.threadId == threadId &&
          other.userId == userId &&
          other.nickname == nickname;

  @override
  int get hashCode => Object.hash(threadId, userId, nickname);
}

class _MessagesThreadSummaryCacheEntry {
  const _MessagesThreadSummaryCacheEntry({
    required this.snapshot,
    required this.isFriend,
    required this.viewData,
  });

  final ChatThreadSummarySnapshot snapshot;
  final bool isFriend;
  final _MessagesThreadSummaryViewData viewData;
}

class _MessagesThreadSummarySelectorState {
  const _MessagesThreadSummarySelectorState({
    required this.summaryRevision,
    required this.isFriend,
  });

  final int summaryRevision;
  final bool isFriend;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MessagesThreadSummarySelectorState &&
          other.summaryRevision == summaryRevision &&
          other.isFriend == isFriend;

  @override
  int get hashCode => Object.hash(summaryRevision, isFriend);
}

class _MessagesMessageSummaryViewData {
  const _MessagesMessageSummaryViewData({
    required this.id,
    required this.content,
    required this.isMe,
    required this.timestamp,
    required this.status,
    required this.type,
    required this.imagePath,
    required this.isBurnAfterReading,
    required this.isRead,
    required this.imageQuality,
    required this.failureState,
  });

  factory _MessagesMessageSummaryViewData.fromSnapshot(
    ChatMessagePreviewSnapshot snapshot,
  ) {
    return _MessagesMessageSummaryViewData(
      id: snapshot.id,
      content: snapshot.content,
      isMe: snapshot.isMe,
      timestamp: snapshot.timestamp,
      status: snapshot.status,
      type: snapshot.type,
      imagePath: snapshot.imagePath,
      isBurnAfterReading: snapshot.isBurnAfterReading,
      isRead: snapshot.isRead,
      imageQuality: snapshot.imageQuality,
      failureState: snapshot.failureState,
    );
  }

  final String id;
  final String content;
  final bool isMe;
  final DateTime timestamp;
  final MessageStatus status;
  final MessageType type;
  final String? imagePath;
  final bool isBurnAfterReading;
  final bool isRead;
  final ImageQuality? imageQuality;
  final ChatDeliveryFailureState? failureState;

  Message toMessage() {
    return Message(
      id: id,
      content: content,
      isMe: isMe,
      timestamp: timestamp,
      status: status,
      type: type,
      imagePath: imagePath,
      isBurnAfterReading: isBurnAfterReading,
      isRead: isRead,
      imageQuality: imageQuality,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MessagesMessageSummaryViewData &&
          other.id == id &&
          other.content == content &&
          other.isMe == isMe &&
          other.timestamp == timestamp &&
          other.status == status &&
          other.type == type &&
          other.imagePath == imagePath &&
          other.isBurnAfterReading == isBurnAfterReading &&
          other.isRead == isRead &&
          other.imageQuality == imageQuality &&
          other.failureState == failureState;

  @override
  int get hashCode => Object.hash(
        id,
        content,
        isMe,
        timestamp,
        status,
        type,
        imagePath,
        isBurnAfterReading,
        isRead,
        imageQuality,
        failureState,
      );
}

class _MessagesThreadSummaryViewData {
  const _MessagesThreadSummaryViewData({
    required this.threadId,
    required this.userId,
    required this.nickname,
    required this.avatar,
    required this.isOnline,
    required this.unreadCount,
    required this.createdAt,
    required this.expiresAt,
    required this.intimacyPoints,
    required this.draft,
    required this.isFriend,
    required this.isPinned,
    required this.lastMessage,
    required this.deliveryState,
  });

  static _MessagesMessageSummaryViewData? _resolveLastMessage(
    ChatThreadSummarySnapshot snapshot,
  ) {
    final lastMessage = snapshot.lastMessage;
    if (lastMessage == null) {
      return null;
    }
    return _MessagesMessageSummaryViewData.fromSnapshot(lastMessage);
  }

  static ChatDeliveryStatusSpec _resolveDeliveryState(
    _MessagesMessageSummaryViewData? lastMessage,
  ) {
    if (lastMessage == null) {
      return const ChatDeliveryStatusSpec();
    }
    return resolveChatDeliveryStatus(
          lastMessage.toMessage(),
          failureState:
              lastMessage.failureState ?? ChatDeliveryFailureState.retryable,
        ) ??
        const ChatDeliveryStatusSpec();
  }

  factory _MessagesThreadSummaryViewData.fromSnapshot(
    ChatThreadSummarySnapshot snapshot, {
    required bool isFriend,
  }) {
    final lastMessage = _resolveLastMessage(snapshot);
    final deliveryState = _resolveDeliveryState(lastMessage);
    return _MessagesThreadSummaryViewData(
      threadId: snapshot.threadId,
      userId: snapshot.userId,
      nickname: snapshot.nickname,
      avatar: snapshot.avatar,
      isOnline: snapshot.isOnline,
      unreadCount: snapshot.unreadCount,
      createdAt: snapshot.createdAt,
      expiresAt: snapshot.expiresAt,
      intimacyPoints: snapshot.intimacyPoints,
      draft: snapshot.draft,
      isFriend: isFriend,
      isPinned: snapshot.isPinned,
      lastMessage: lastMessage,
      deliveryState: deliveryState,
    );
  }

  final String threadId;
  final String userId;
  final String nickname;
  final String? avatar;
  final bool isOnline;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int intimacyPoints;
  final String draft;
  final bool isFriend;
  final bool isPinned;
  final _MessagesMessageSummaryViewData? lastMessage;
  final ChatDeliveryStatusSpec deliveryState;

  bool get hasDraft => draft.trim().isNotEmpty;

  ChatDeliveryFailureState? get deliveryFailureState =>
      lastMessage?.failureState;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MessagesThreadSummaryViewData &&
          other.threadId == threadId &&
          other.userId == userId &&
          other.nickname == nickname &&
          other.avatar == avatar &&
          other.isOnline == isOnline &&
          other.unreadCount == unreadCount &&
          other.createdAt == createdAt &&
          other.expiresAt == expiresAt &&
          other.intimacyPoints == intimacyPoints &&
          other.draft == draft &&
          other.isFriend == isFriend &&
          other.isPinned == isPinned &&
          other.lastMessage == lastMessage;

  @override
  int get hashCode => Object.hash(
        threadId,
        userId,
        nickname,
        avatar,
        isOnline,
        unreadCount,
        createdAt,
        expiresAt,
        intimacyPoints,
        draft,
        isFriend,
        isPinned,
        lastMessage,
      );
}

class _ThreadListEntry extends StatelessWidget {
  const _ThreadListEntry({
    required this.index,
    required this.threadId,
    required this.userId,
    required this.relativeTimeListenable,
    required this.nowProvider,
    required this.selectSummary,
    required this.onShowThreadOptions,
  });

  final int index;
  final String threadId;
  final String userId;
  final ValueListenable<int> relativeTimeListenable;
  final DateTime Function() nowProvider;
  final _MessagesThreadSummaryViewData? Function(
    ChatProvider chatProvider,
    String threadId,
    bool isFriend,
  ) selectSummary;
  final void Function(
    BuildContext context,
    String threadId,
    bool isPinned,
  ) onShowThreadOptions;

  @override
  Widget build(BuildContext context) {
    return Selector2<ChatProvider, FriendProvider,
        _MessagesThreadSummarySelectorState>(
      selector: (context, chatProvider, friendProvider) =>
          _MessagesThreadSummarySelectorState(
        summaryRevision: chatProvider.threadSummaryRevision(threadId),
        isFriend: friendProvider.isFriend(userId) &&
            !friendProvider.isBlocked(userId),
      ),
      builder: (context, selection, child) {
        final viewData = selectSummary(
          context.read<ChatProvider>(),
          threadId,
          selection.isFriend,
        );
        if (viewData == null) {
          return const SizedBox.shrink();
        }

        return _AnimatedThreadEntry(
          index: index,
          child: Dismissible(
            key: Key(viewData.threadId),
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
                color: AppColors.error.withValues(alpha: 0.5),
                size: 28,
              ),
            ),
            onDismissed: (_) {
              context.read<ChatProvider>().deleteThread(viewData.threadId);
              AppFeedback.showToast(
                context,
                AppToastCode.deleted,
                subject: '对话',
              );
            },
            child: _ThreadItem(
              viewData: viewData,
              relativeTimeListenable: relativeTimeListenable,
              nowProvider: nowProvider,
              onTap: () {
                final routeThreadId =
                    context.read<ChatProvider>().routeThreadId(
                              threadId: viewData.threadId,
                              userId: viewData.userId,
                            ) ??
                        viewData.threadId;
                context.push('/chat/$routeThreadId').then((_) {
                  if (context.mounted) {
                    context.go('/main?tab=0');
                  }
                });
              },
              onLongPress: () => onShowThreadOptions(
                context,
                viewData.threadId,
                viewData.isPinned,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ThreadItem extends StatelessWidget {
  const _ThreadItem({
    required this.viewData,
    required this.relativeTimeListenable,
    required this.nowProvider,
    required this.onTap,
    this.onLongPress,
  });

  final _MessagesThreadSummaryViewData viewData;
  final ValueListenable<int> relativeTimeListenable;
  final DateTime Function() nowProvider;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final layout = _MessagesLayoutSpec.fromSize(MediaQuery.of(context).size);
    final showInlineIntimacy = !viewData.isFriend && !layout.isCompact;
    final showTrailingIntimacy = !viewData.isFriend && layout.isCompact;
    final moveUnreadBadgeToMetaRow =
        layout.isCompact && viewData.unreadCount > 0;
    final deliveryState = viewData.deliveryState;
    final showDeliveryBadge = !viewData.hasDraft &&
        deliveryState.hasBadge &&
        !deliveryState.isSuccessState;
    final lastMessage = viewData.lastMessage;
    final priority = _resolvePriorityState(viewData: viewData);
    final accentColor = priority?.color ??
        (viewData.unreadCount > 0
            ? AppColors.brandBlue.withValues(alpha: 0.2)
            : AppColors.white05);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        key: Key('messages-thread-item-${viewData.threadId}'),
        padding: layout.itemPadding,
        decoration: BoxDecoration(
          color: viewData.isPinned
              ? AppColors.white05
              : viewData.hasDraft
                  ? AppColors.warning.withValues(alpha: 0.04)
                  : (viewData.unreadCount > 0
                      ? AppColors.brandBlue.withValues(alpha: 0.035)
                      : null),
          gradient: viewData.isOnline && !viewData.isFriend
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
              viewData: viewData,
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
                              viewData.nickname,
                              style: TextStyle(
                                fontSize: layout.titleSize,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (viewData.isFriend)
                              _TinyTag(
                                label: '好友',
                                background:
                                    AppColors.brandBlue.withValues(alpha: 0.15),
                                foreground: AppColors.brandBlue,
                              ),
                            if (viewData.isPinned)
                              const Icon(
                                Icons.push_pin,
                                size: 12,
                                color: AppColors.textTertiary,
                              ),
                          ],
                        ),
                      ),
                      ValueListenableBuilder<int>(
                        valueListenable: relativeTimeListenable,
                        builder: (context, _, __) {
                          final currentTime = nowProvider();
                          return Text(
                            _formatTime(
                              viewData.lastMessage?.timestamp,
                              currentTime: currentTime,
                            ),
                            key: Key(
                              'messages-thread-last-time-${viewData.threadId}',
                            ),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: layout.metaSize,
                                    ),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: layout.previewGap),
                  Row(
                    children: [
                      Expanded(
                        child: viewData.hasDraft
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
                                      viewData.draft,
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
                                      (viewData.unreadCount > 0
                                          ? AppColors.textSecondary
                                          : AppColors.textTertiary),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      if (showDeliveryBadge) ...[
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
                          viewData.unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        _UnreadBadge(
                          threadId: viewData.threadId,
                          unreadCount: viewData.unreadCount,
                          fontSize: layout.metaSize - 1,
                        ),
                      ],
                    ],
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: relativeTimeListenable,
                    builder: (context, _, __) {
                      final currentTime = nowProvider();
                      final timeRemaining =
                          viewData.expiresAt.difference(currentTime);
                      final baseShowUrgencyHint = !viewData.isFriend &&
                          timeRemaining.inMinutes > 0 &&
                          timeRemaining.inMinutes <= 120;
                      final displayPriority = baseShowUrgencyHint &&
                              _shouldShowOnlinePriority(viewData)
                          ? null
                          : priority;
                      final showUrgencyHint =
                          baseShowUrgencyHint && displayPriority == null;
                      if (displayPriority == null && !showUrgencyHint) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding:
                            EdgeInsets.only(top: layout.priorityTopSpacing),
                        child: Wrap(
                          spacing: layout.tagSpacing,
                          runSpacing: 6,
                          children: [
                            if (displayPriority != null)
                              _TinyTag(
                                key: Key(
                                  'messages-thread-priority-${viewData.threadId}',
                                ),
                                label: displayPriority.label,
                                background: displayPriority.color.withValues(
                                  alpha: 0.14,
                                ),
                                foreground: displayPriority.color,
                              ),
                            if (showUrgencyHint)
                              _TinyTag(
                                key: Key(
                                  'messages-thread-expiring-${viewData.threadId}',
                                ),
                                label: '即将到期',
                                background:
                                    AppColors.error.withValues(alpha: 0.12),
                                foreground: AppColors.error,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (!viewData.isFriend) ...[
                    SizedBox(height: layout.previewGap),
                    ValueListenableBuilder<int>(
                      valueListenable: relativeTimeListenable,
                      builder: (context, _, __) {
                        final currentTime = nowProvider();
                        final timeRemaining =
                            viewData.expiresAt.difference(currentTime);
                        final isNearExpiry = timeRemaining.inHours < 2;
                        final timeColor = isNearExpiry
                            ? AppColors.error
                            : AppColors.textTertiary;
                        return Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: layout.metaSize,
                              color: timeColor,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _formatTimeRemaining(
                                  timeRemaining,
                                  compact: layout.isCompact,
                                ),
                                key: Key(
                                  'messages-thread-remaining-time-${viewData.threadId}',
                                ),
                                style: TextStyle(
                                  fontSize: layout.metaSize,
                                  fontWeight: FontWeight.w300,
                                  color: timeColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (moveUnreadBadgeToMetaRow) ...[
                              const SizedBox(width: 8),
                              _UnreadBadge(
                                threadId: viewData.threadId,
                                unreadCount: viewData.unreadCount,
                                fontSize: layout.metaSize - 1,
                              ),
                            ],
                            if (showTrailingIntimacy) ...[
                              const SizedBox(width: 8),
                              _buildIntimacyChip(layout),
                            ],
                          ],
                        );
                      },
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
    required _MessagesThreadSummaryViewData viewData,
  }) {
    if (viewData.deliveryFailureState ==
        ChatDeliveryFailureState.threadExpired) {
      return const _ThreadPriorityState(
        label: '会话已过期',
        color: AppColors.warning,
      );
    }
    if (viewData.deliveryFailureState ==
        ChatDeliveryFailureState.blockedRelation) {
      return const _ThreadPriorityState(
        label: '关系受限',
        color: AppColors.warning,
      );
    }
    if (viewData.deliveryFailureState ==
        ChatDeliveryFailureState.imageUploadTokenInvalid) {
      return const _ThreadPriorityState(
        label: '上传凭证失效',
        color: AppColors.warning,
      );
    }
    if (viewData.deliveryFailureState ==
        ChatDeliveryFailureState.networkIssue) {
      return const _ThreadPriorityState(
        label: '网络波动',
        color: AppColors.warning,
      );
    }
    if (viewData.deliveryFailureState ==
        ChatDeliveryFailureState.imageUploadPreparationFailed) {
      return const _ThreadPriorityState(
        label: '上传准备失败',
        color: AppColors.error,
      );
    }
    if (viewData.deliveryFailureState ==
        ChatDeliveryFailureState.imageUploadInterrupted) {
      return const _ThreadPriorityState(
        label: '上传中断',
        color: AppColors.error,
      );
    }
    if (viewData.deliveryFailureState ==
        ChatDeliveryFailureState.imageReselectRequired) {
      return const _ThreadPriorityState(
        label: '重选图片',
        color: AppColors.error,
      );
    }
    if (viewData.deliveryFailureState ==
        ChatDeliveryFailureState.retryUnavailable) {
      return const _ThreadPriorityState(
        label: '暂不可重试',
        color: AppColors.warning,
      );
    }
    if (viewData.deliveryState.actionType == ChatDeliveryAction.retry) {
      return const _ThreadPriorityState(
        label: '发送失败',
        color: AppColors.error,
      );
    }
    if (viewData.deliveryState.actionType == ChatDeliveryAction.showGuide) {
      if (viewData.deliveryState.guideFailureState ==
          ChatDeliveryFailureState.imageUploadFileTooLarge) {
        return const _ThreadPriorityState(
          label: '图片过大',
          color: AppColors.error,
        );
      }
      if (viewData.deliveryState.guideFailureState ==
          ChatDeliveryFailureState.imageUploadUnsupportedFormat) {
        return const _ThreadPriorityState(
          label: '格式异常',
          color: AppColors.error,
        );
      }
      return const _ThreadPriorityState(
        label: '发送前需要处理',
        color: AppColors.error,
      );
    }
    if (viewData.hasDraft) {
      return const _ThreadPriorityState(
        label: '草稿待发送',
        color: AppColors.warning,
      );
    }
    if (_shouldShowOnlinePriority(viewData)) {
      return const _ThreadPriorityState(
        label: '对方在线可聊',
        color: AppColors.success,
      );
    }
    return null;
  }

  bool _shouldShowOnlinePriority(_MessagesThreadSummaryViewData viewData) {
    return !viewData.isFriend &&
        viewData.isOnline &&
        viewData.unreadCount == 0 &&
        !viewData.hasDraft &&
        viewData.deliveryFailureState == null &&
        viewData.deliveryState.actionType == null;
  }

  String _formatTime(
    DateTime? time, {
    required DateTime currentTime,
  }) {
    if (time == null) return '';
    final diff = currentTime.difference(time);

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
      key: Key('messages-thread-intimacy-${viewData.threadId}'),
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
            '${viewData.intimacyPoints}',
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

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({
    required this.threadId,
    required this.unreadCount,
    required this.fontSize,
  });

  final String threadId;
  final int unreadCount;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('messages-thread-unread-$threadId'),
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
        unreadCount > 99 ? '99+' : '$unreadCount',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: AppColors.pureBlack,
        ),
      ),
    );
  }
}

class _ThreadAvatar extends StatelessWidget {
  const _ThreadAvatar({
    required this.viewData,
    required this.layout,
  });

  final _MessagesThreadSummaryViewData viewData;
  final _MessagesLayoutSpec layout;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          key: Key('messages-thread-avatar-${viewData.threadId}'),
          width: layout.avatarSize,
          height: layout.avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.white08,
            border: Border.all(
              color: viewData.isFriend
                  ? AppColors.brandBlue.withValues(alpha: 0.5)
                  : AppColors.white05,
              width: 2,
            ),
          ),
          child: AppUserAvatar(
            avatar: viewData.avatar,
            textStyle: TextStyle(
              fontSize: layout.avatarTextSize,
              color: AppColors.pureBlack,
            ),
          ),
        ),
        if (viewData.isOnline)
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
        if (viewData.unreadCount > 0)
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
                viewData.unreadCount > 99 ? '99+' : '${viewData.unreadCount}',
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
