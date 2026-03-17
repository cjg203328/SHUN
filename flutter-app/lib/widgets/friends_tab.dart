import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../core/feedback/app_feedback.dart';
import '../providers/auth_provider.dart';
import '../providers/friend_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/notification_center_provider.dart';
import '../models/models.dart';
import 'app_toast.dart';

class _FriendsLayoutSpec {
  const _FriendsLayoutSpec({
    required this.isCompact,
    required this.listHorizontalPadding,
    required this.listTopSpacing,
    required this.listBottomSpacing,
    required this.bannerHorizontalPadding,
    required this.bannerVerticalPadding,
    required this.bannerIconSize,
    required this.bannerTextSize,
    required this.bannerChevronSize,
    required this.emptyIconSize,
    required this.emptyIconBottomSpacing,
    required this.emptyPrimaryTextSize,
    required this.emptySecondaryTextSize,
    required this.itemHorizontalPadding,
    required this.itemVerticalPadding,
    required this.itemAvatarSize,
    required this.itemAvatarFontSize,
    required this.itemGap,
    required this.itemTitleSize,
    required this.itemSecondarySize,
    required this.itemMetaGap,
    required this.itemCornerRadius,
    required this.requestHorizontalPadding,
    required this.requestVerticalPadding,
    required this.requestAvatarSize,
    required this.requestAvatarFontSize,
    required this.requestTitleSize,
    required this.requestMessageSize,
    required this.requestButtonHorizontalPadding,
    required this.requestButtonVerticalPadding,
    required this.requestButtonFontSize,
  });

  final bool isCompact;
  final double listHorizontalPadding;
  final double listTopSpacing;
  final double listBottomSpacing;
  final double bannerHorizontalPadding;
  final double bannerVerticalPadding;
  final double bannerIconSize;
  final double bannerTextSize;
  final double bannerChevronSize;
  final double emptyIconSize;
  final double emptyIconBottomSpacing;
  final double emptyPrimaryTextSize;
  final double emptySecondaryTextSize;
  final double itemHorizontalPadding;
  final double itemVerticalPadding;
  final double itemAvatarSize;
  final double itemAvatarFontSize;
  final double itemGap;
  final double itemTitleSize;
  final double itemSecondarySize;
  final double itemMetaGap;
  final double itemCornerRadius;
  final double requestHorizontalPadding;
  final double requestVerticalPadding;
  final double requestAvatarSize;
  final double requestAvatarFontSize;
  final double requestTitleSize;
  final double requestMessageSize;
  final double requestButtonHorizontalPadding;
  final double requestButtonVerticalPadding;
  final double requestButtonFontSize;

  static _FriendsLayoutSpec fromConstraints(BoxConstraints constraints) {
    final isCompact =
        constraints.maxWidth <= 390 || constraints.maxHeight <= 720;
    if (isCompact) {
      return const _FriendsLayoutSpec(
        isCompact: true,
        listHorizontalPadding: 12,
        listTopSpacing: 12,
        listBottomSpacing: 16,
        bannerHorizontalPadding: 12,
        bannerVerticalPadding: 10,
        bannerIconSize: 15,
        bannerTextSize: 12,
        bannerChevronSize: 15,
        emptyIconSize: 52,
        emptyIconBottomSpacing: 20,
        emptyPrimaryTextSize: 15,
        emptySecondaryTextSize: 12,
        itemHorizontalPadding: 14,
        itemVerticalPadding: 12,
        itemAvatarSize: 48,
        itemAvatarFontSize: 24,
        itemGap: 12,
        itemTitleSize: 15,
        itemSecondarySize: 12,
        itemMetaGap: 3,
        itemCornerRadius: 16,
        requestHorizontalPadding: 14,
        requestVerticalPadding: 14,
        requestAvatarSize: 44,
        requestAvatarFontSize: 22,
        requestTitleSize: 14,
        requestMessageSize: 12,
        requestButtonHorizontalPadding: 14,
        requestButtonVerticalPadding: 8,
        requestButtonFontSize: 12,
      );
    }

    return const _FriendsLayoutSpec(
      isCompact: false,
      listHorizontalPadding: 16,
      listTopSpacing: 16,
      listBottomSpacing: 20,
      bannerHorizontalPadding: 14,
      bannerVerticalPadding: 12,
      bannerIconSize: 16,
      bannerTextSize: 13,
      bannerChevronSize: 16,
      emptyIconSize: 56,
      emptyIconBottomSpacing: 24,
      emptyPrimaryTextSize: 16,
      emptySecondaryTextSize: 13,
      itemHorizontalPadding: 18,
      itemVerticalPadding: 14,
      itemAvatarSize: 56,
      itemAvatarFontSize: 28,
      itemGap: 16,
      itemTitleSize: 16,
      itemSecondarySize: 13,
      itemMetaGap: 4,
      itemCornerRadius: 18,
      requestHorizontalPadding: 18,
      requestVerticalPadding: 16,
      requestAvatarSize: 48,
      requestAvatarFontSize: 24,
      requestTitleSize: 15,
      requestMessageSize: 13,
      requestButtonHorizontalPadding: 16,
      requestButtonVerticalPadding: 8,
      requestButtonFontSize: 13,
    );
  }
}

class _UidSearchSheet extends StatefulWidget {
  const _UidSearchSheet({
    required this.authUid,
  });

  final String? authUid;

  @override
  State<_UidSearchSheet> createState() => _UidSearchSheetState();
}

class _UidSearchSheetState extends State<_UidSearchSheet> {
  final TextEditingController _uidController = TextEditingController();
  User? _resultUser;
  String? _feedback;

  @override
  void dispose() {
    _uidController.dispose();
    super.dispose();
  }

  Future<void> _searchUser() async {
    final query = _uidController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _feedback = '请输入 UID 后搜索';
        _resultUser = null;
      });
      return;
    }

    final found = await context.read<FriendProvider>().searchUserByUidRemote(
          query,
          excludeUid: widget.authUid,
        );
    if (!mounted) return;

    setState(() {
      _resultUser = found;
      _feedback = found == null ? '未找到该 UID，请检查后重试' : null;
    });
  }

  Future<void> _copyUid() async {
    final authUid = widget.authUid;
    if (authUid == null) return;

    await Clipboard.setData(ClipboardData(text: authUid));
    if (!mounted) return;

    AppFeedback.showToast(
      context,
      AppToastCode.copied,
    );
  }

  Future<void> _sendRequest() async {
    final user = _resultUser;
    if (user == null) return;

    await context.read<FriendProvider>().sendFriendRequestRemote(user, '你好');
    if (!mounted) return;

    AppFeedback.showToast(
      context,
      AppToastCode.sent,
      subject: '好友请求',
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final layout = _FriendsLayoutSpec.fromConstraints(
      BoxConstraints.tight(MediaQuery.of(context).size),
    );
    final authUid = widget.authUid;
    final resultUser = _resultUser;
    final buttonVerticalPadding = layout.isCompact ? 12.0 : 10.0;
    final cardSpacing = layout.isCompact ? 12.0 : 14.0;

    final searchButton = TextButton(
      key: const Key('friends-uid-search-submit'),
      onPressed: _searchUser,
      style: TextButton.styleFrom(
        backgroundColor: AppColors.white12,
        padding: EdgeInsets.symmetric(
          horizontal: 18,
          vertical: buttonVerticalPadding,
        ),
        minimumSize: layout.isCompact ? const Size.fromHeight(44) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: const Text(
        '搜索',
        style: TextStyle(color: AppColors.textPrimary),
      ),
    );

    final sendRequestButton = TextButton(
      key: const Key('friends-uid-search-send-request'),
      onPressed: _sendRequest,
      style: TextButton.styleFrom(
        backgroundColor: AppColors.brandBlue.withValues(alpha: 0.2),
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: buttonVerticalPadding,
        ),
        minimumSize: layout.isCompact ? const Size.fromHeight(44) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: const Text(
        '发送请求',
        style: TextStyle(color: AppColors.brandBlue),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        key: const Key('friends-uid-search-sheet'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        decoration: AppDialog.sheetDecoration(),
        padding: EdgeInsets.fromLTRB(
          layout.listHorizontalPadding,
          layout.listTopSpacing,
          layout.listHorizontalPadding,
          layout.listBottomSpacing,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'UID 找好友',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: layout.isCompact ? 6 : 8),
                Text(
                  '更适合添加已经认识的人，减少误搜与打扰。',
                  style: TextStyle(
                    fontSize: layout.isCompact ? 12 : 13,
                    color: AppColors.textTertiary,
                  ),
                ),
                SizedBox(height: cardSpacing),
                Container(
                  padding: EdgeInsets.all(layout.isCompact ? 12 : 14),
                  decoration: BoxDecoration(
                    color: AppColors.white05,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.white08),
                  ),
                  child: layout.isCompact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authUid == null
                                  ? '你的 UID 生成中'
                                  : '我的 UID：$authUid',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: authUid == null ? null : _copyUid,
                                child: const Text('复制'),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Text(
                                authUid == null
                                    ? '你的 UID 生成中'
                                    : '我的 UID：$authUid',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: authUid == null ? null : _copyUid,
                              child: const Text('复制'),
                            ),
                          ],
                        ),
                ),
                SizedBox(height: cardSpacing),
                if (layout.isCompact) ...[
                  TextField(
                    key: const Key('friends-uid-search-input'),
                    controller: _uidController,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 16,
                    decoration: const InputDecoration(
                      hintText: '请输入对方 UID',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: searchButton),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('friends-uid-search-input'),
                          controller: _uidController,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 16,
                          decoration: const InputDecoration(
                            hintText: '请输入对方 UID',
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      searchButton,
                    ],
                  ),
                ],
                if (_feedback != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _feedback!,
                    key: const Key('friends-uid-search-feedback'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
                if (resultUser != null) ...[
                  SizedBox(height: cardSpacing),
                  Container(
                    key: const Key('friends-uid-search-result-card'),
                    padding: EdgeInsets.all(layout.isCompact ? 14 : 12),
                    decoration: BoxDecoration(
                      color: AppColors.white05,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.white08),
                    ),
                    child: layout.isCompact
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.white08,
                                    ),
                                    child: Center(
                                      child: Text(
                                        resultUser.avatar ?? '👤',
                                        style: const TextStyle(
                                          fontSize: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          resultUser.nickname,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w300,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'UID：${resultUser.uid}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textTertiary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          resultUser.status,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: sendRequestButton,
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.white08,
                                ),
                                child: Center(
                                  child: Text(
                                    resultUser.avatar ?? '👤',
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      resultUser.nickname,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'UID：${resultUser.uid}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              sendRequestButton,
                            ],
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
                    key: const Key('friends-notifications-action'),
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
          IconButton(
            key: const Key('friends-search-action'),
            icon: const Icon(Icons.search_outlined),
            onPressed: () {
              _showUidSearchSheet(context);
            },
          ),
          // 好友请求入口
          Consumer<FriendProvider>(
            builder: (context, friendProvider, child) {
              final count = friendProvider.pendingRequestCount;
              return Stack(
                children: [
                  IconButton(
                    key: const Key('friends-requests-action'),
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _FriendsLayoutSpec.fromConstraints(constraints);
          return Consumer<FriendProvider>(
            builder: (context, friendProvider, child) {
              final friends = friendProvider.friendList;
              final pendingCount = friendProvider.pendingRequestCount;

              if (friends.isEmpty) {
                return Column(
                  children: [
                    if (pendingCount > 0)
                      _PendingRequestsBanner(
                        count: pendingCount,
                        onTap: () => _showFriendRequests(context),
                        layout: layout,
                      ),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            layout.listHorizontalPadding,
                            layout.listTopSpacing,
                            layout.listHorizontalPadding,
                            layout.listBottomSpacing,
                          ),
                          child: Container(
                            key: const Key('friends-empty-state'),
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: layout.itemHorizontalPadding,
                              vertical: layout.isCompact ? 24 : 32,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.white05,
                              borderRadius: BorderRadius.circular(
                                layout.itemCornerRadius,
                              ),
                              border: Border.all(color: AppColors.white08),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: layout.emptyIconSize,
                                  color: AppColors.textTertiary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                                SizedBox(height: layout.emptyIconBottomSpacing),
                                Text(
                                  '暂无好友',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        fontSize: layout.emptyPrimaryTextSize,
                                        color: AppColors.textTertiary,
                                      ),
                                ),
                                SizedBox(height: layout.isCompact ? 8 : 10),
                                Text(
                                  '持续互动并达到阶段二后可互关',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontSize: layout.emptySecondaryTextSize,
                                      ),
                                ),
                                SizedBox(height: layout.isCompact ? 6 : 8),
                                Text(
                                  '也可以通过UID主动搜索交友',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontSize: layout.emptySecondaryTextSize,
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

              return Column(
                children: [
                  if (pendingCount > 0)
                    _PendingRequestsBanner(
                      count: pendingCount,
                      onTap: () => _showFriendRequests(context),
                      layout: layout,
                    ),
                  Expanded(
                    child: ListView.builder(
                      key: const Key('friends-list'),
                      padding: EdgeInsets.fromLTRB(
                        layout.listHorizontalPadding,
                        layout.listTopSpacing,
                        layout.listHorizontalPadding,
                        layout.listBottomSpacing,
                      ),
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == friends.length - 1 ? 0 : 8,
                          ),
                          child: _FriendItem(
                            friend: friend,
                            layout: layout,
                            onTap: () async {
                              final chatProvider = context.read<ChatProvider>();
                              final thread =
                                  await chatProvider.ensureDirectThreadForUser(
                                friend.user,
                                isFriend: true,
                              );
                              if (!context.mounted) return;
                              final routeThreadId = chatProvider.routeThreadId(
                                    threadId: thread.id,
                                    userId: friend.user.id,
                                  ) ??
                                  thread.id;
                              context.push('/chat/$routeThreadId').then((_) {
                                if (context.mounted) {
                                  context.go('/main?tab=2');
                                }
                              });
                            },
                            onLongPress: () {
                              _showFriendOptions(context, friend);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showUidSearchSheet(BuildContext context) {
    final authUid = context.read<AuthProvider?>()?.uid;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (_) => _UidSearchSheet(authUid: authUid),
    );

    /*
    final authUid = context.read<AuthProvider>().uid;
    final layout = _FriendsLayoutSpec.fromConstraints(
      BoxConstraints.tight(MediaQuery.of(context).size),
    );
    final uidController = TextEditingController();
    User? resultUser;
    String? feedback;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final buttonVerticalPadding = layout.isCompact ? 12.0 : 10.0;
          final cardSpacing = layout.isCompact ? 12.0 : 14.0;

          final searchButton = TextButton(
            key: const Key('friends-uid-search-submit'),
            onPressed: () async {
              final query = uidController.text.trim();
              if (query.isEmpty) {
                setSheetState(() {
                  feedback = '请输入UID后搜索';
                  resultUser = null;
                });
                return;
              }
              final found =
                  await context.read<FriendProvider>().searchUserByUidRemote(
                        query,
                        excludeUid: authUid,
                      );
              if (!sheetContext.mounted) return;
              setSheetState(() {
                resultUser = found;
                feedback = found == null ? '未找到该UID，请检查后重试' : null;
              });
            },
            style: TextButton.styleFrom(
              backgroundColor: AppColors.white12,
              padding: EdgeInsets.symmetric(
                horizontal: 18,
                vertical: buttonVerticalPadding,
              ),
              minimumSize: layout.isCompact ? const Size.fromHeight(44) : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              '搜索',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          );

          final sendRequestButton = TextButton(
            key: const Key('friends-uid-search-send-request'),
            onPressed: () async {
              final user = resultUser;
              if (user == null) return;
              await context
                  .read<FriendProvider>()
                  .sendFriendRequestRemote(user, '你好');
              if (!sheetContext.mounted) return;
              AppFeedback.showToast(
                sheetContext,
                AppToastCode.sent,
                subject: '好友请求',
              );
              Navigator.pop(sheetContext);
            },
            style: TextButton.styleFrom(
              backgroundColor: AppColors.brandBlue.withValues(alpha: 0.2),
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: buttonVerticalPadding,
              ),
              minimumSize: layout.isCompact ? const Size.fromHeight(44) : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              '发请求',
              style: TextStyle(color: AppColors.brandBlue),
            ),
          );

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Container(
              key: const Key('friends-uid-search-sheet'),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.78,
              ),
              decoration: AppDialog.sheetDecoration(),
              padding: EdgeInsets.fromLTRB(
                layout.listHorizontalPadding,
                layout.listTopSpacing,
                layout.listHorizontalPadding,
                layout.listBottomSpacing,
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'UID找好友',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: layout.isCompact ? 6 : 8),
                      Text(
                        '更适合添加已经认识的人，减少误搜与打扰。',
                        style: TextStyle(
                          fontSize: layout.isCompact ? 12 : 13,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      SizedBox(height: cardSpacing),
                      Container(
                        padding: EdgeInsets.all(layout.isCompact ? 12 : 14),
                        decoration: BoxDecoration(
                          color: AppColors.white05,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.white08),
                        ),
                        child: layout.isCompact
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    authUid == null
                                        ? '你的UID生成中'
                                        : '我的UID：$authUid',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: authUid == null
                                          ? null
                                          : () async {
                                              await Clipboard.setData(
                                                ClipboardData(text: authUid),
                                              );
                                              if (!sheetContext.mounted) return;
                                              AppFeedback.showToast(
                                                sheetContext,
                                                AppToastCode.copied,
                                              );
                                            },
                                      child: const Text('复制'),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      authUid == null
                                          ? '你的UID生成中'
                                          : '我的UID：$authUid',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: authUid == null
                                        ? null
                                        : () async {
                                            await Clipboard.setData(
                                              ClipboardData(text: authUid),
                                            );
                                            if (!sheetContext.mounted) return;
                                            AppFeedback.showToast(
                                              sheetContext,
                                              AppToastCode.copied,
                                            );
                                          },
                                    child: const Text('复制'),
                                  ),
                                ],
                              ),
                      ),
                      SizedBox(height: cardSpacing),
                      if (layout.isCompact) ...[
                        TextField(
                          key: const Key('friends-uid-search-input'),
                          controller: uidController,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 16,
                          decoration: const InputDecoration(
                            hintText: '请输入对方UID',
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(width: double.infinity, child: searchButton),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: const Key('friends-uid-search-input'),
                                controller: uidController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                maxLength: 16,
                                decoration: const InputDecoration(
                                  hintText: '请输入对方UID',
                                  counterText: '',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            searchButton,
                          ],
                        ),
                      ],
                      if (feedback != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          feedback!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                      if (resultUser != null) ...[
                        SizedBox(height: cardSpacing),
                        Container(
                          key: const Key('friends-uid-search-result-card'),
                          padding: EdgeInsets.all(layout.isCompact ? 14 : 12),
                          decoration: BoxDecoration(
                            color: AppColors.white05,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.white08),
                          ),
                          child: layout.isCompact
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppColors.white08,
                                          ),
                                          child: Center(
                                            child: Text(
                                              resultUser!.avatar ?? '👤',
                                              style: const TextStyle(
                                                fontSize: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                resultUser!.nickname,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  color: AppColors.textPrimary,
                                                  fontWeight: FontWeight.w300,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'UID：${resultUser!.uid}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textTertiary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                resultUser!.status,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: sendRequestButton,
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.white08,
                                      ),
                                      child: Center(
                                        child: Text(
                                          resultUser!.avatar ?? '👤',
                                          style: const TextStyle(fontSize: 20),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            resultUser!.nickname,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w300,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'UID：${resultUser!.uid}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textTertiary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    sendRequestButton,
                                  ],
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ).whenComplete(uidController.dispose);
    */
  }

  void _showFriendRequests(BuildContext context) {
    final layout = _FriendsLayoutSpec.fromConstraints(
      BoxConstraints.tight(MediaQuery.of(context).size),
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (context) => Container(
        key: const Key('friends-options-sheet'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        decoration: AppDialog.sheetDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                layout.listHorizontalPadding,
                layout.listTopSpacing,
                layout.listHorizontalPadding - 4,
                layout.isCompact ? 8 : 12,
              ),
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
                    padding: EdgeInsets.fromLTRB(
                      layout.listHorizontalPadding,
                      0,
                      layout.listHorizontalPadding,
                      layout.listBottomSpacing,
                    ),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == requests.length - 1 ? 0 : 8,
                        ),
                        child: _FriendRequestItem(
                          request: requests[index],
                          layout: layout,
                        ),
                      );
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
    final layout = _FriendsLayoutSpec.fromConstraints(
      BoxConstraints.tight(MediaQuery.of(context).size),
    );
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        decoration: AppDialog.sheetDecoration(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: layout.isCompact ? 12 : 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionItem(
                  context,
                  icon: Icons.edit_outlined,
                  text: '设置备注',
                  key: const Key('friends-option-remark'),
                  onTap: () => Navigator.pop(context, 'remark'),
                ),
                _buildActionItem(
                  context,
                  icon: Icons.person_outline,
                  text: '查看主页',
                  key: const Key('friends-option-profile'),
                  onTap: () => Navigator.pop(context, 'profile'),
                ),
                _buildActionItem(
                  context,
                  icon: Icons.delete_outline,
                  text: '删除好友',
                  key: const Key('friends-option-delete'),
                  onTap: () => Navigator.pop(context, 'delete'),
                  isDanger: true,
                ),
                _buildActionItem(
                  context,
                  icon: Icons.person_remove_outlined,
                  text: '取关',
                  key: const Key('friends-option-unfollow'),
                  onTap: () => Navigator.pop(context, 'unfollow'),
                  isDanger: true,
                ),
                _buildActionItem(
                  context,
                  icon: Icons.block_outlined,
                  text: '拉黑',
                  key: const Key('friends-option-block'),
                  onTap: () => Navigator.pop(context, 'block'),
                  isDanger: true,
                ),
                _buildActionItem(
                  context,
                  icon: Icons.flag_outlined,
                  text: '举报',
                  key: const Key('friends-option-report'),
                  onTap: () => Navigator.pop(context, 'report'),
                  isDanger: true,
                ),
                const SizedBox(height: 8),
                _buildActionItem(
                  context,
                  icon: Icons.close,
                  text: '取消',
                  key: const Key('friends-option-cancel'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
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
          chatProvider.unfollowFriend(thread.id);
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
        context.read<ChatProvider>().handleFriendRemoved(friend.id);
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
        context.read<ChatProvider>().handleUserBlocked(friend.id);
        if (!context.mounted) return;
        AppFeedback.showToast(context, AppToastCode.enabled, subject: '拉黑');
      }
    } else if (action == 'report' && context.mounted) {
      context.push(
        '/report/user/${friend.user.id}?name=${Uri.encodeComponent(friend.displayName)}',
      );
    }
  }

  void _showFriendProfile(BuildContext context, Friend friend) {
    final layout = _FriendsLayoutSpec.fromConstraints(
      BoxConstraints.tight(MediaQuery.of(context).size),
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (context) => Container(
        key: const Key('friends-profile-sheet'),
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: AppDialog.sheetDecoration(color: AppColors.pureBlack),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      height: layout.isCompact ? 188 : 210,
                      width: double.infinity,
                      decoration: const BoxDecoration(
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
                      padding: EdgeInsets.only(
                        bottom: layout.isCompact ? 14 : 18,
                      ),
                      child: Container(
                        width: layout.isCompact ? 76 : 88,
                        height: layout.isCompact ? 76 : 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.white08,
                          border: Border.all(
                            color: AppColors.pureBlack,
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            friend.user.avatar ?? '👤',
                            style: TextStyle(
                              fontSize: layout.isCompact ? 34 : 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    layout.listHorizontalPadding,
                    layout.isCompact ? 14 : 16,
                    layout.listHorizontalPadding,
                    layout.listBottomSpacing,
                  ),
                  child: Column(
                    children: [
                      Text(
                        friend.displayName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: layout.isCompact ? 19 : 21,
                          fontWeight: FontWeight.w300,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (friend.remark != null) ...[
                        SizedBox(height: layout.isCompact ? 6 : 8),
                        Text(
                          '昵称：${friend.user.nickname}',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: layout.isCompact ? 12 : 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      SizedBox(height: layout.isCompact ? 12 : 14),
                      Container(
                        key: const Key('friends-profile-identity-card'),
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: layout.isCompact ? 12 : 14,
                          vertical: layout.isCompact ? 12 : 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white05,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.white08),
                        ),
                        child: Column(
                          children: [
                            _buildProfileMetaRow(
                              label: 'UID',
                              value: friend.user.uid,
                              isCompact: layout.isCompact,
                            ),
                            if (friend.remark != null) ...[
                              const SizedBox(height: 10),
                              _buildProfileMetaRow(
                                label: '昵称',
                                value: friend.user.nickname,
                                isCompact: layout.isCompact,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (layout.isCompact)
                        Column(
                          key: const Key('friends-profile-stats'),
                          children: [
                            _buildInfoCard(
                              '累计聊天',
                              '${friend.chatCount} 次',
                              key: const Key('friends-profile-chat-card'),
                              isCompact: true,
                            ),
                            const SizedBox(height: 10),
                            _buildInfoCard(
                              '总时长',
                              '${friend.totalMinutes} 分钟',
                              key: const Key('friends-profile-duration-card'),
                              isCompact: true,
                            ),
                          ],
                        )
                      else
                        Row(
                          key: const Key('friends-profile-stats'),
                          children: [
                            Expanded(
                              child: _buildInfoCard(
                                '累计聊天',
                                '${friend.chatCount} 次',
                                key: const Key('friends-profile-chat-card'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildInfoCard(
                                '总时长',
                                '${friend.totalMinutes} 分钟',
                                key: const Key('friends-profile-duration-card'),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 10),
                      _buildInfoCard(
                        '状态',
                        friend.user.status,
                        key: const Key('friends-profile-status-card'),
                        isCompact: layout.isCompact,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileMetaRow({
    required String label,
    required String value,
    required bool isCompact,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: isCompact ? 42 : 48,
          child: Text(
            label,
            style: TextStyle(
              fontSize: isCompact ? 12 : 13,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isCompact ? 13 : 14,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    String title,
    String value, {
    Key? key,
    bool isCompact = false,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 14,
        vertical: isCompact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(isCompact ? 10 : 12),
        border: Border.all(color: AppColors.white08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isCompact ? 11 : 12,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isCompact ? 13 : 14,
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
    Key? key,
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return InkWell(
      key: key,
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

class _PendingRequestsBanner extends StatelessWidget {
  const _PendingRequestsBanner({
    required this.count,
    required this.onTap,
    required this.layout,
  });

  final int count;
  final VoidCallback onTap;
  final _FriendsLayoutSpec layout;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        key: const Key('friends-pending-banner'),
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: layout.bannerHorizontalPadding,
          vertical: layout.bannerVerticalPadding,
        ),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(layout.itemCornerRadius),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.person_add_outlined,
              size: layout.bannerIconSize,
              color: AppColors.warning,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$count 条好友请求待处理',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: layout.bannerTextSize,
                  fontWeight: FontWeight.w400,
                  color: AppColors.warning,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: layout.bannerChevronSize,
              color: AppColors.warning,
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendItem extends StatelessWidget {
  final Friend friend;
  final _FriendsLayoutSpec layout;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FriendItem({
    required this.friend,
    required this.layout,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        key: Key('friends-item-${friend.id}'),
        padding: EdgeInsets.symmetric(
          horizontal: layout.itemHorizontalPadding,
          vertical: layout.itemVerticalPadding,
        ),
        decoration: BoxDecoration(
          color: AppColors.white05,
          borderRadius: BorderRadius.circular(layout.itemCornerRadius),
          border: Border.all(color: AppColors.white08),
        ),
        child: Row(
          children: [
            // 头像
            Container(
              width: layout.itemAvatarSize,
              height: layout.itemAvatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.white08,
                border: Border.all(
                  color: AppColors.brandBlue.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  friend.user.avatar ?? '👤',
                  style: TextStyle(
                    fontSize: layout.itemAvatarFontSize,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),

            SizedBox(width: layout.itemGap),

            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.displayName,
                    maxLines: layout.isCompact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: layout.itemTitleSize,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (friend.remark != null) ...[
                    SizedBox(height: layout.itemMetaGap),
                    Text(
                      '昵称：${friend.user.nickname}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: layout.itemSecondarySize,
                        fontWeight: FontWeight.w300,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                  SizedBox(height: layout.itemMetaGap),
                  Text(
                    'UID：${friend.user.uid}',
                    maxLines: layout.isCompact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: layout.itemSecondarySize,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),

            // 箭头
            Icon(
              Icons.chevron_right,
              color: AppColors.textDisabled,
              size: layout.isCompact ? 18 : 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendRequestItem extends StatelessWidget {
  final FriendRequest request;
  final _FriendsLayoutSpec layout;

  const _FriendRequestItem({
    required this.request,
    required this.layout,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: layout.requestAvatarSize,
      height: layout.requestAvatarSize,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.white08,
      ),
      child: Center(
        child: Text(
          request.fromUser.avatar ?? '👤',
          style: TextStyle(fontSize: layout.requestAvatarFontSize),
        ),
      ),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          request.fromUser.nickname,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: layout.requestTitleSize,
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary,
          ),
        ),
        if (request.message != null) ...[
          const SizedBox(height: 4),
          Text(
            request.message!,
            style: TextStyle(
              fontSize: layout.requestMessageSize,
              fontWeight: FontWeight.w300,
              color: AppColors.textTertiary,
            ),
            maxLines: layout.isCompact ? 2 : 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    final rejectButton = TextButton(
      key: Key('friends-request-reject-${request.id}'),
      onPressed: () async {
        await context
            .read<FriendProvider>()
            .rejectFriendRequestRemote(request.id);
        if (!context.mounted) return;
        AppFeedback.showToast(
          context,
          AppToastCode.disabled,
          subject: '好友请求',
        );
      },
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: layout.requestButtonHorizontalPadding,
          vertical: layout.requestButtonVerticalPadding,
        ),
        backgroundColor: AppColors.white05,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        minimumSize: Size.zero,
      ),
      child: Text(
        '拒绝',
        style: TextStyle(
          fontSize: layout.requestButtonFontSize,
          color: AppColors.textSecondary,
        ),
      ),
    );

    final acceptButton = TextButton(
      key: Key('friends-request-accept-${request.id}'),
      onPressed: () async {
        final userId = request.fromUser.id;
        await context
            .read<FriendProvider>()
            .acceptFriendRequestRemote(request.id);
        if (!context.mounted) return;
        context.read<ChatProvider>().handleFriendAccepted(userId);
        if (!context.mounted) return;
        AppFeedback.showToast(
          context,
          AppToastCode.enabled,
          subject: '互关',
        );
      },
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: layout.requestButtonHorizontalPadding,
          vertical: layout.requestButtonVerticalPadding,
        ),
        backgroundColor: AppColors.brandBlue.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        minimumSize: Size.zero,
      ),
      child: Text(
        '接受',
        style: TextStyle(
          fontSize: layout.requestButtonFontSize,
          color: AppColors.brandBlue,
        ),
      ),
    );

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        rejectButton,
        acceptButton,
      ],
    );

    return Container(
      key: Key('friends-request-item-${request.id}'),
      padding: EdgeInsets.symmetric(
        horizontal: layout.requestHorizontalPadding,
        vertical: layout.requestVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(layout.itemCornerRadius),
        border: Border.all(color: AppColors.white08),
      ),
      child: layout.isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    avatar,
                    const SizedBox(width: 10),
                    Expanded(child: content),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: actions,
                ),
              ],
            )
          : Row(
              children: [
                avatar,
                const SizedBox(width: 12),
                Expanded(child: content),
                const SizedBox(width: 12),
                actions,
              ],
            ),
    );
  }
}
