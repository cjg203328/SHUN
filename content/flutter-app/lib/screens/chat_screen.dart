import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/chat_provider.dart';
import '../providers/friend_provider.dart';
import '../models/models.dart';
import '../widgets/app_toast.dart';
import '../core/feedback/app_feedback.dart';
import '../core/policy/feature_policy.dart';
import '../core/ui/ui_tokens.dart';
import '../utils/intimacy_system.dart';
import '../utils/image_helper.dart';
import '../utils/permission_manager.dart';
import '../services/screenshot_guard.dart';

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
  bool _isBurnAfterReadEnabled = false;

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
      _chatProvider?.setActiveThread(widget.threadId);

      // 进入会话即视为已查看，未读立即清零
      final thread = _chatProvider?.getThread(widget.threadId);
      if (thread != null) {
        _lastIntimacyPoints = thread.intimacyPoints;
        _lastMessageCount =
            _chatProvider?.getMessages(widget.threadId).length ?? 0;
        _chatProvider?.markAsRead(widget.threadId);
      }
    });
  }

  @override
  void dispose() {
    _chatProvider?.removeListener(_handleChatProviderChanged);
    _chatProvider?.clearActiveThread(widget.threadId);
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
      // 只要用户仍停留在当前会话页面，新增消息立刻按已读处理
      if ((thread?.unreadCount ?? 0) > 0) {
        _chatProvider?.markAsRead(widget.threadId);
      }
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
                    final isFriend =
                        friendProvider.isFriend(thread.otherUser.id);
                    final isBlocked =
                        friendProvider.isBlocked(thread.otherUser.id);
                    final canCall = FeaturePolicy.canVoiceCall(
                      thread: thread,
                      isFriend: isFriend,
                      isBlocked: isBlocked,
                    );
                    if (isBlocked) {
                      AppFeedback.showError(context, AppErrorCode.blocked);
                    } else if (canCall) {
                      _handleVoiceCall(context, thread.otherUser);
                    } else {
                      AppFeedback.showError(
                        context,
                        AppErrorCode.unlockRequired,
                        detail:
                            FeaturePolicy.stageTwoUnlockHint(thread, '语音通话'),
                      );
                    }
                  } else if (value == 'add_friend') {
                    final isFriend =
                        friendProvider.isFriend(thread.otherUser.id);
                    final isBlocked =
                        friendProvider.isBlocked(thread.otherUser.id);
                    final canMutualFollow = FeaturePolicy.canMutualFollow(
                      thread: thread,
                      isFriend: isFriend,
                      isBlocked: isBlocked,
                    );
                    if (isFriend) {
                      AppFeedback.showToast(
                        context,
                        AppToastCode.enabled,
                        subject: '互关',
                      );
                    } else if (isBlocked) {
                      AppFeedback.showError(context, AppErrorCode.blocked);
                    } else if (canMutualFollow) {
                      _showAddFriendDialog(context, thread.otherUser);
                    } else {
                      AppFeedback.showError(
                        context,
                        AppErrorCode.unlockRequired,
                        detail: FeaturePolicy.stageTwoUnlockHint(thread, '互关'),
                      );
                    }
                  } else if (value == 'profile') {
                    _showUserProfile(context, thread);
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
                  final isBlocked =
                      friendProvider.isBlocked(thread.otherUser.id);
                  final canCall = FeaturePolicy.canVoiceCall(
                    thread: thread,
                    isFriend: isFriend,
                    isBlocked: isBlocked,
                  );
                  final canAddFriend = FeaturePolicy.canMutualFollow(
                    thread: thread,
                    isFriend: isFriend,
                    isBlocked: isBlocked,
                  );

                  return [
                    PopupMenuItem(
                      value: 'profile',
                      child: _buildMenuItem(Icons.person_outline, '个人主页'),
                    ),
                    PopupMenuItem(
                      value: 'call',
                      child: _buildMenuItem(
                        Icons.phone_outlined,
                        isBlocked
                            ? '语音通话（需先解除拉黑）'
                            : canCall
                                ? '语音通话'
                                : '语音通话（互动后解锁）',
                      ),
                    ),
                    PopupMenuItem(
                      value: 'add_friend',
                      child: _buildMenuItem(
                        Icons.person_add_outlined,
                        isFriend
                            ? '已互关'
                            : canAddFriend
                                ? '添加好友'
                                : isBlocked
                                    ? '已拉黑（需先解除）'
                                    : '互关权限（互动后解锁）',
                      ),
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

              return Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(UiTokens.radiusSm),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 15,
                        color: AppColors.error.withValues(alpha: 0.78),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          remaining > 0
                              ? '对方已取关，还可发送$remaining条消息'
                              : '等待对方确认后可继续聊天',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w300,
                            color: AppColors.error.withValues(alpha: 0.88),
                          ),
                        ),
                      ),
                      if (remaining <= 0)
                        TextButton(
                          onPressed: () {
                            AppFeedback.showToast(
                              context,
                              AppToastCode.sent,
                              subject: '提醒',
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            '提醒',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.error.withValues(alpha: 0.88),
                            ),
                          ),
                        ),
                    ],
                  ),
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
                    top: 8,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: SafeArea(
                        bottom: false,
                        child: Center(
                          child: IntimacyChangeAnimation(
                            change: _intimacyChange,
                          ),
                        ),
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
              final canSendImage =
                  thread != null && FeaturePolicy.canSendImage(thread);

              return Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                decoration: BoxDecoration(
                  color: AppColors.pureBlack,
                  border: Border(top: BorderSide(color: AppColors.white05)),
                ),
                child: SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(UiTokens.radiusLg),
                      border: Border.all(color: AppColors.white08),
                      boxShadow: UiTokens.softShadow,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildImageAction(
                              canSend: canSend,
                              canSendImage: canSendImage,
                              thread: thread,
                            ),
                            const SizedBox(width: 10),
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
                            const SizedBox(width: 10),
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _hasText && canSend
                                    ? AppColors.textPrimary
                                    : AppColors.white05,
                                borderRadius:
                                    BorderRadius.circular(UiTokens.radiusSm),
                                border: Border.all(color: AppColors.white08),
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
                                        final content =
                                            _inputController.text.trim();
                                        if (content.isNotEmpty) {
                                          context
                                              .read<ChatProvider>()
                                              .sendMessage(
                                                widget.threadId,
                                                content,
                                              );
                                          _inputController.clear();
                                          setState(() {
                                            _hasText = false;
                                          });
                                        }
                                      },
                              ),
                            ),
                          ],
                        ),
                        AnimatedSwitcher(
                          duration: UiTokens.motionNormal,
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final offset = Tween<Offset>(
                              begin: const Offset(0, 0.18),
                              end: Offset.zero,
                            ).animate(animation);
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                  position: offset, child: child),
                            );
                          },
                          child: _isBurnAfterReadEnabled
                              ? Padding(
                                  key: const ValueKey('burn_hint_on'),
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.warning
                                                .withValues(alpha: 0.18),
                                            AppColors.warning
                                                .withValues(alpha: 0.1),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: AppColors.warning
                                              .withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.local_fire_department,
                                            size: 13,
                                            color: AppColors.warning,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            '已开启闪图，仅下一张图片生效',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w300,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox(
                                  key: ValueKey('burn_hint_off'),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndSendImage(bool canSend) async {
    if (!canSend) return;
    final thread = context.read<ChatProvider>().getThread(widget.threadId);
    if (thread == null) return;
    if (!FeaturePolicy.canSendImage(thread)) {
      AppFeedback.showError(
        context,
        AppErrorCode.unlockRequired,
        detail: FeaturePolicy.profileUnlockHint(thread, '图片消息'),
      );
      return;
    }

    final source = await ImageHelper.showImageSourceSelector(context);
    if (!mounted || source == null) return;

    bool hasPermission = false;
    if (source == ImageSource.camera) {
      if (!mounted) return;
      hasPermission = await PermissionManager.requestCameraPermission(
        context,
        purpose: '拍摄照片发送聊天图片',
      );
    } else {
      if (!mounted) return;
      hasPermission = await PermissionManager.requestPhotosPermission(
        context,
        purpose: '从相册选择图片发送聊天消息',
      );
    }
    if (!mounted) return;
    if (!hasPermission) {
      AppFeedback.showError(context, AppErrorCode.permissionDenied);
      return;
    }

    final imageFile = source == ImageSource.camera
        ? await ImageHelper.pickImageFromCamera()
        : await ImageHelper.pickImageFromGallery();
    if (!mounted || imageFile == null) return;

    final quality = await ImageHelper.showQualitySelector(context, imageFile);
    if (!mounted || quality == null) return;

    await context.read<ChatProvider>().sendImageMessage(
          widget.threadId,
          imageFile,
          quality,
          _isBurnAfterReadEnabled,
        );

    if (!mounted) return;
    AppFeedback.showToast(
      context,
      AppToastCode.sent,
      subject: _isBurnAfterReadEnabled ? '闪图（对方可看5秒）' : '图片',
    );

    if (_isBurnAfterReadEnabled) {
      setState(() {
        _isBurnAfterReadEnabled = false;
      });
    }
  }

  Widget _buildImageAction({
    required bool canSend,
    required bool canSendImage,
    required ChatThread? thread,
  }) {
    final canUseImage = canSend && canSendImage;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: UiTokens.motionNormal,
          curve: Curves.easeOutCubic,
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: canUseImage
                ? (_isBurnAfterReadEnabled
                    ? AppColors.warning.withValues(alpha: 0.18)
                    : AppColors.white08)
                : AppColors.white05,
            borderRadius: BorderRadius.circular(UiTokens.radiusSm),
            border: Border.all(
              color: _isBurnAfterReadEnabled
                  ? AppColors.warning.withValues(alpha: 0.5)
                  : AppColors.white08,
            ),
            boxShadow: _isBurnAfterReadEnabled
                ? [
                    BoxShadow(
                      color: AppColors.warning.withValues(alpha: 0.16),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: IconButton(
            icon: Icon(
              Icons.image_outlined,
              color: canUseImage
                  ? (_isBurnAfterReadEnabled
                      ? AppColors.warning
                      : AppColors.textSecondary)
                  : AppColors.textDisabled,
              size: 20,
            ),
            onPressed: canSend
                ? () {
                    if (!canSendImage && thread != null) {
                      AppFeedback.showError(
                        context,
                        AppErrorCode.unlockRequired,
                        detail: FeaturePolicy.profileUnlockHint(thread, '图片消息'),
                      );
                      return;
                    }
                    _pickAndSendImage(canSend);
                  }
                : null,
            tooltip: canSendImage ? '发送图片' : '继续互动后解锁图片',
          ),
        ),
        if (!canSendImage)
          Positioned(
            right: 9,
            top: 9,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.pureBlack.withValues(alpha: 0.76),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppColors.white12),
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 9,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        Positioned(
          right: -2,
          bottom: -2,
          child: InkWell(
            borderRadius: BorderRadius.circular(UiTokens.radiusSm),
            onTap: canSend
                ? () {
                    if (!canSendImage && thread != null) {
                      AppFeedback.showError(
                        context,
                        AppErrorCode.unlockRequired,
                        detail: FeaturePolicy.profileUnlockHint(thread, '闪图模式'),
                      );
                      return;
                    }
                    HapticFeedback.selectionClick();
                    setState(() {
                      _isBurnAfterReadEnabled = !_isBurnAfterReadEnabled;
                    });
                  }
                : null,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 1,
                end: _isBurnAfterReadEnabled ? 1.08 : 1,
              ),
              duration: UiTokens.motionNormal,
              curve: Curves.easeOutBack,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _isBurnAfterReadEnabled
                      ? AppColors.warning.withValues(alpha: 0.2)
                      : (canSendImage ? AppColors.cardBg : AppColors.white05),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isBurnAfterReadEnabled
                        ? AppColors.warning
                        : (canSendImage
                            ? AppColors.white12
                            : AppColors.textDisabled.withValues(alpha: 0.4)),
                    width: 1,
                  ),
                ),
                child: Icon(
                  canSendImage
                      ? Icons.local_fire_department
                      : Icons.lock_outline,
                  size: 13,
                  color: _isBurnAfterReadEnabled
                      ? AppColors.warning
                      : (canSendImage
                          ? AppColors.textTertiary
                          : AppColors.textDisabled),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getHeaderSubtitle(ChatThread thread, bool isFriend) {
    if (isFriend) {
      return thread.otherUser.isOnline ? '好友 · 在线' : '好友 · 私聊中';
    }

    final nextUnlock = FeaturePolicy.nextUnlockName(thread);
    if (nextUnlock == null) {
      return '聊得很投缘';
    }

    final pointsToNext = FeaturePolicy.pointsToNextUnlock(thread);
    return '轻聊中 · 距离解锁$nextUnlock还差$pointsToNext分';
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
        AppFeedback.showError(context, AppErrorCode.permissionDenied);
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
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (context) => _VoiceCallSheet(user: user),
    );
  }

  void _showAddFriendDialog(BuildContext context, User user) async {
    final controller = TextEditingController();

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
      AppFeedback.showToast(
        context,
        AppToastCode.sent,
        subject: '好友请求',
      );
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
      AppFeedback.showToast(
        context,
        AppToastCode.disabled,
        subject: '互关',
      );
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
      AppFeedback.showToast(
        context,
        AppToastCode.enabled,
        subject: '拉黑',
      );
      context.pop();
    }
  }

  void _showUserProfile(BuildContext context, ChatThread thread) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (sheetContext) => Consumer2<ChatProvider, FriendProvider>(
        builder: (sheetContext, chatProvider, friendProvider, child) {
          final currentThread = chatProvider.getThread(thread.id) ?? thread;
          final user = currentThread.otherUser;
          final isFriend = friendProvider.isFriend(user.id);
          final isBlocked = friendProvider.isBlocked(user.id);
          final canOpenFullProfile =
              FeaturePolicy.canOpenProfile(currentThread);
          final canFollow = FeaturePolicy.canMutualFollow(
            thread: currentThread,
            isFriend: isFriend,
            isBlocked: isBlocked,
          );

          final pointsToUnlock =
              FeaturePolicy.profilePointsRemaining(currentThread);
          final minutesToUnlock =
              FeaturePolicy.profileMinutesRemaining(currentThread);

          return Container(
            height: MediaQuery.of(sheetContext).size.height * 0.88,
            decoration: AppDialog.sheetDecoration(color: AppColors.pureBlack),
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
                            canOpenFullProfile
                                ? AppColors.white12
                                : AppColors.white08,
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
                          border:
                              Border.all(color: AppColors.pureBlack, width: 3),
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
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close,
                            color: AppColors.textPrimary),
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
                if (!canOpenFullProfile)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white05,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '继续互动后可查看完整主页\n还差$pointsToUnlock分${minutesToUnlock > 0 ? '，至少再聊$minutesToUnlock分钟' : ''}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w300,
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ),
                  )
                else ...[
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
                  const SizedBox(height: 14),
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
                        '主页已解锁：可查看背景、状态与基础资料。持续互动可解锁互关和语音通话。',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w300,
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (!isFriend && !isBlocked)
                          ? () {
                              if (canFollow) {
                                Navigator.pop(sheetContext);
                                _showAddFriendDialog(context, user);
                              } else {
                                AppFeedback.showError(
                                  context,
                                  AppErrorCode.unlockRequired,
                                  detail: FeaturePolicy.stageTwoUnlockHint(
                                    currentThread,
                                    '互关权限',
                                  ),
                                );
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: (!isFriend && !isBlocked)
                            ? (canFollow
                                ? AppColors.white12
                                : AppColors.white08)
                            : AppColors.white05,
                        foregroundColor: canFollow || (!isFriend && !isBlocked)
                            ? AppColors.textPrimary
                            : AppColors.textDisabled,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isFriend
                            ? '已互关'
                            : isBlocked
                                ? '已拉黑'
                                : canFollow
                                    ? '关注并互关'
                                    : '继续聊天解锁互关',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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
      AppFeedback.showToast(context, AppToastCode.saved, subject: '备注');
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
      decoration: AppDialog.sheetDecoration(color: AppColors.pureBlack),
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
              stream: Stream.periodic(const Duration(seconds: 1), (x) => x)
                  .asBroadcastStream(),
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
                    AppFeedback.showToast(
                      context,
                      AppToastCode.disabled,
                      subject: '通话',
                    );
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
    final canRecall = message.isMe &&
        message.status == MessageStatus.sent &&
        DateTime.now().difference(message.timestamp).inMinutes < 2;
    final isImage = message.type == MessageType.image;

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

          GestureDetector(
            onTap: isImage && message.status != MessageStatus.sending
                ? () => _handleImageTap(context)
                : null,
            onLongPress: message.status == MessageStatus.sending
                ? null
                : () async {
                    final action = await AppDialog.showMessageActions(
                      context,
                      isMe: message.isMe,
                      canRecall: canRecall,
                    );

                    if (action == 'copy') {
                      if (message.type != MessageType.text) {
                        if (!context.mounted) return;
                        AppFeedback.showError(
                          context,
                          AppErrorCode.notSupported,
                          detail: '图片消息暂不支持复制',
                        );
                        return;
                      }
                      await Clipboard.setData(
                          ClipboardData(text: message.content));
                      if (!context.mounted) return;
                      AppFeedback.showToast(context, AppToastCode.copied);
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
                        AppFeedback.showToast(
                          context,
                          AppToastCode.deleted,
                          subject: '消息',
                        );
                      }
                    }
                  },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: isImage
                  ? const EdgeInsets.all(6)
                  : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.of(context).size.width * (isImage ? 0.64 : 0.7),
              ),
              decoration: BoxDecoration(
                color: message.isMe
                    ? (message.status == MessageStatus.failed
                        ? AppColors.error.withValues(alpha: 0.2)
                        : const Color(0xAA4A4A4A))
                    : const Color(0xCC262626),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(UiTokens.radiusMd),
                  topRight: const Radius.circular(UiTokens.radiusMd),
                  bottomLeft: message.isMe
                      ? const Radius.circular(UiTokens.radiusMd)
                      : const Radius.circular(UiTokens.radiusXs),
                  bottomRight: message.isMe
                      ? const Radius.circular(UiTokens.radiusXs)
                      : const Radius.circular(UiTokens.radiusMd),
                ),
                border: Border.all(color: AppColors.white08),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isImage)
                    _buildImageContent(context)
                  else
                    Text(
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
                  if (message.isMe && message.status == MessageStatus.sent) ...[
                    SizedBox(height: isImage ? 8 : 6),
                    Text(
                      message.isRead ? '对方已读' : '对方未读',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w300,
                        color: message.isRead
                            ? AppColors.textTertiary.withValues(alpha: 0.8)
                            : AppColors.textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (message.isMe && message.status == MessageStatus.sending) ...[
            Container(
              margin: const EdgeInsets.only(left: 8, bottom: 10),
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
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

  bool get _isIncomingBurnUnread =>
      !message.isMe && message.isBurnAfterReading && !message.isRead;

  bool get _isIncomingBurnRead =>
      !message.isMe && message.isBurnAfterReading && message.isRead;

  Future<void> _handleImageTap(BuildContext context) async {
    if (_isIncomingBurnRead) {
      AppFeedback.showToast(context, AppToastCode.deleted, subject: '闪图');
      return;
    }

    final imagePath = message.imagePath;
    if (imagePath == null || imagePath.isEmpty) {
      AppFeedback.showError(
        context,
        AppErrorCode.invalidInput,
        detail: '图片不可用，请重新发送',
      );
      return;
    }

    final enableSecure = message.isBurnAfterReading;
    if (enableSecure) {
      await ScreenshotGuard.setSecure(true);
    }
    if (!context.mounted) return;

    try {
      await Navigator.of(context).push(
        PageRouteBuilder<void>(
          opaque: false,
          barrierColor: Colors.black,
          pageBuilder: (_, __, ___) => _ImagePreviewScreen(
            imagePath: imagePath,
            isBurnAfterReading: message.isBurnAfterReading,
          ),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
        ),
      );
    } finally {
      if (enableSecure) {
        await ScreenshotGuard.setSecure(false);
      }
      if (context.mounted && _isIncomingBurnUnread) {
        context.read<ChatProvider>().markImageAsRead(threadId, message.id);
      }
    }
  }

  Widget _buildImageContent(BuildContext context) {
    if (_isIncomingBurnUnread) {
      return _buildBurnLockedPlaceholder();
    }
    if (_isIncomingBurnRead) {
      return _buildBurnDestroyedPlaceholder();
    }

    final imagePath = message.imagePath;
    if (imagePath == null || imagePath.isEmpty) {
      return _buildImageMissingPlaceholder(
        width: 156,
        height: 188,
      );
    }
    final imageHeight = MediaQuery.of(context).size.width * 0.48;
    final imageWidth = imageHeight * 0.8;

    return ClipRRect(
      borderRadius: BorderRadius.circular(UiTokens.radiusSm),
      child: Stack(
        children: [
          _buildImageWidget(
            imagePath,
            imageHeight,
            imageWidth,
          ),
          if (message.isBurnAfterReading)
            Positioned(
              left: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      size: 12,
                      color: AppColors.warning,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '闪图',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(
    String imagePath,
    double imageHeight,
    double imageWidth,
  ) {
    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        width: imageWidth,
        height: imageHeight,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildImageMissingPlaceholder(
          width: imageWidth,
          height: imageHeight,
        ),
      );
    }

    return Image.file(
      File(imagePath),
      width: imageWidth,
      height: imageHeight,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildImageMissingPlaceholder(
        width: imageWidth,
        height: imageHeight,
      ),
    );
  }

  Widget _buildBurnLockedPlaceholder() {
    return Container(
      width: 172,
      height: 198,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.warning.withValues(alpha: 0.14),
            AppColors.warning.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(UiTokens.radiusSm),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_fire_department,
            size: 30,
            color: AppColors.warning,
          ),
          SizedBox(height: 10),
          Text(
            '点击查看闪图（5秒）',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBurnDestroyedPlaceholder() {
    return Container(
      width: 172,
      height: 88,
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(UiTokens.radiusSm),
        border: Border.all(color: AppColors.white12),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hide_image_outlined,
            size: 16,
            color: AppColors.textTertiary,
          ),
          SizedBox(width: 6),
          Text(
            '闪图已销毁',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageMissingPlaceholder({
    double? width,
    double? height,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white05,
          borderRadius: BorderRadius.circular(UiTokens.radiusSm),
          border: Border.all(color: AppColors.white08),
        ),
        child: const Center(
          child: Text(
            '图片不可用',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagePreviewScreen extends StatefulWidget {
  final String imagePath;
  final bool isBurnAfterReading;

  const _ImagePreviewScreen({
    required this.imagePath,
    required this.isBurnAfterReading,
  });

  @override
  State<_ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<_ImagePreviewScreen> {
  static const int _burnSeconds = 5;
  int _secondsLeft = _burnSeconds;

  @override
  void initState() {
    super.initState();
    if (widget.isBurnAfterReading) {
      _startBurnCountdown();
    }
  }

  void _startBurnCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !widget.isBurnAfterReading) return false;

      if (_secondsLeft <= 1) {
        Navigator.pop(context);
        return false;
      }

      setState(() {
        _secondsLeft -= 1;
      });
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isNetwork = widget.imagePath.startsWith('http');

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.94),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: isNetwork
                    ? Image.network(
                        widget.imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Text(
                          '图片不可用',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      )
                    : Image.file(
                        File(widget.imagePath),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Text(
                          '图片不可用',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
              ),
            ),
            Positioned(
              top: 8,
              right: 12,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (widget.isBurnAfterReading)
              Positioned(
                left: 0,
                right: 0,
                bottom: 22,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(UiTokens.radiusSm),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '闪图剩余 $_secondsLeft 秒',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
