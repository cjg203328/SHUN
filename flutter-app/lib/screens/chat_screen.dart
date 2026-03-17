import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/chat_provider.dart';
import '../providers/friend_provider.dart';
import '../providers/settings_provider.dart';
import '../models/models.dart';
import '../widgets/app_toast.dart';
import '../core/feedback/app_feedback.dart';
import '../core/policy/feature_policy.dart';
import '../core/ui/ui_tokens.dart';
import '../utils/chat_delivery_state.dart';
import '../utils/chat_outgoing_delivery_feedback.dart';
import '../utils/intimacy_system.dart';
import '../utils/image_helper.dart';
import '../utils/notification_permission_guidance.dart';
import '../utils/permission_manager.dart';
import '../services/screenshot_guard.dart';
import '../widgets/chat_delivery_status.dart';
import '../widgets/notification_permission_notice_card.dart';

class ChatScreen extends StatefulWidget {
  final String threadId;

  const ChatScreen({super.key, required this.threadId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatComposerLayoutSpec {
  const _ChatComposerLayoutSpec({
    required this.isCompact,
    required this.outerPadding,
    required this.innerPadding,
    required this.controlSize,
    required this.controlGap,
    required this.fieldHorizontalPadding,
    required this.fieldVerticalPadding,
    required this.statusTopPadding,
    required this.chipSpacing,
    required this.chipRunSpacing,
  });

  final bool isCompact;
  final EdgeInsets outerPadding;
  final EdgeInsets innerPadding;
  final double controlSize;
  final double controlGap;
  final double fieldHorizontalPadding;
  final double fieldVerticalPadding;
  final double statusTopPadding;
  final double chipSpacing;
  final double chipRunSpacing;

  static _ChatComposerLayoutSpec fromSize(Size size) {
    final isCompact = size.width <= 390 || size.height <= 720;
    if (isCompact) {
      return const _ChatComposerLayoutSpec(
        isCompact: true,
        outerPadding: EdgeInsets.fromLTRB(12, 6, 12, 8),
        innerPadding: EdgeInsets.fromLTRB(9, 9, 9, 6),
        controlSize: 44,
        controlGap: 8,
        fieldHorizontalPadding: 15,
        fieldVerticalPadding: 12,
        statusTopPadding: 7,
        chipSpacing: 6,
        chipRunSpacing: 6,
      );
    }

    return const _ChatComposerLayoutSpec(
      isCompact: false,
      outerPadding: EdgeInsets.fromLTRB(14, 8, 14, 10),
      innerPadding: EdgeInsets.fromLTRB(10, 10, 10, 6),
      controlSize: 48,
      controlGap: 10,
      fieldHorizontalPadding: 18,
      fieldVerticalPadding: 14,
      statusTopPadding: 8,
      chipSpacing: 8,
      chipRunSpacing: 8,
    );
  }
}

class _ChatScreenState extends State<ChatScreen> {
  static const int _messageMaxLength = 300;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  ChatProvider? _chatProvider;
  bool _chatProviderListenerAttached = false;
  Timer? _intimacyHideTimer;
  int _lastIntimacyPoints = 0;
  int _lastMessageCount = 0;
  int _intimacyAnimationToken = 0;
  bool _showIntimacyChange = false;
  int _intimacyChange = 0;
  final Map<String, OutgoingDeliveryObservation> _deliveryStateSnapshot =
      <String, OutgoingDeliveryObservation>{};
  bool _hasText = false; // 添加状态追踪
  bool _isBurnAfterReadEnabled = false;
  bool _scrollToBottomQueued = false;
  bool _canonicalRouteSyncQueued = false;

  @override
  void initState() {
    super.initState();

    // 监听输入框变化
    _inputController.addListener(() {
      _chatProvider?.saveDraft(widget.threadId, _inputController.text);
      final hasText = _inputController.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() {
          _hasText = hasText;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bindChatProvider();
      _activateCurrentThread();
    });
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.threadId == widget.threadId) {
      return;
    }
    _persistDraftForThread(oldWidget.threadId);
    _chatProvider?.clearActiveThread(oldWidget.threadId);
    _resetTransientComposerStateForThreadChange();
    _activateCurrentThread();
  }

  @override
  void dispose() {
    _intimacyHideTimer?.cancel();
    if (_chatProviderListenerAttached) {
      _chatProvider?.removeListener(_handleChatProviderChanged);
      _chatProviderListenerAttached = false;
    }
    _persistDraftForThread(widget.threadId);
    _chatProvider?.clearActiveThread(widget.threadId);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _bindChatProvider() {
    _chatProvider ??= context.read<ChatProvider>();
    if (_chatProviderListenerAttached) {
      return;
    }
    _chatProvider?.addListener(_handleChatProviderChanged);
    _chatProviderListenerAttached = true;
  }

  void _activateCurrentThread() {
    _chatProvider?.setActiveThread(widget.threadId);
    _hydrateDraftForThread(widget.threadId);
    final thread = _chatProvider?.getThread(widget.threadId);
    _lastIntimacyPoints = thread?.intimacyPoints ?? 0;
    _lastMessageCount = _chatProvider?.getMessages(widget.threadId).length ?? 0;
    _captureDeliverySnapshot(widget.threadId);
    _scheduleCanonicalRouteSync();
  }

  void _persistDraftForThread(String threadId) {
    _chatProvider?.saveDraft(threadId, _inputController.text);
  }

  void _hydrateDraftForThread(String threadId) {
    final draft = _chatProvider?.draftForThread(threadId) ?? '';
    if (_inputController.text == draft) {
      return;
    }
    _inputController.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
  }

  void _resetTransientComposerStateForThreadChange() {
    _intimacyHideTimer?.cancel();
    _intimacyAnimationToken += 1;
    _showIntimacyChange = false;
    _intimacyChange = 0;
    _deliveryStateSnapshot.clear();
    _isBurnAfterReadEnabled = false;
    _scrollToBottomQueued = false;
  }

  void _captureDeliverySnapshot(String threadId) {
    final messages = _chatProvider?.getMessages(threadId) ?? const <Message>[];
    _deliveryStateSnapshot
      ..clear()
      ..addAll(captureOutgoingDeliverySnapshot(messages));
  }

  OutgoingDeliveryFeedback? _resolveOutgoingDeliveryFeedback(
    List<Message> messages,
  ) {
    final resolution = resolveOutgoingDeliveryFeedback(
      messages: messages,
      previousSnapshot: _deliveryStateSnapshot,
    );
    _deliveryStateSnapshot
      ..clear()
      ..addAll(resolution.snapshot);
    return resolution.feedback;
  }

  void _showOutgoingDeliveryFeedback(OutgoingDeliveryFeedback feedback) {
    if (!mounted) {
      return;
    }
    AppToast.show(
      context,
      feedback.message,
      isError: feedback.isError,
    );
  }

  void _scrollToBottom() {
    if (!mounted || !_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scheduleScrollToBottom() {
    if (_scrollToBottomQueued) {
      return;
    }
    _scrollToBottomQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottomQueued = false;
      _scrollToBottom();
    });
  }

  void _scheduleCanonicalRouteSync() {
    final canonicalThreadId = _chatProvider?.canonicalThreadId(widget.threadId);
    if (!mounted ||
        canonicalThreadId == null ||
        canonicalThreadId == widget.threadId ||
        _canonicalRouteSyncQueued) {
      return;
    }
    _canonicalRouteSyncQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _canonicalRouteSyncQueued = false;
      if (!mounted) return;
      final latestCanonicalThreadId =
          _chatProvider?.canonicalThreadId(widget.threadId);
      if (latestCanonicalThreadId == null ||
          latestCanonicalThreadId == widget.threadId) {
        return;
      }
      final router = GoRouter.maybeOf(context);
      if (router == null) {
        return;
      }
      router.replace('/chat/$latestCanonicalThreadId');
    });
  }

  void _handleChatProviderChanged() {
    if (!mounted) return;

    final thread = _chatProvider?.getThread(widget.threadId);
    final messages =
        _chatProvider?.getMessages(widget.threadId) ?? const <Message>[];
    final deliveryFeedback = _resolveOutgoingDeliveryFeedback(messages);
    _scheduleCanonicalRouteSync();
    if (thread != null && thread.intimacyPoints != _lastIntimacyPoints) {
      final change = thread.intimacyPoints - _lastIntimacyPoints;
      _lastIntimacyPoints = thread.intimacyPoints;

      if (change > 0) {
        _intimacyHideTimer?.cancel();
        _intimacyAnimationToken += 1;
        final token = _intimacyAnimationToken;
        setState(() {
          _intimacyChange = change;
          _showIntimacyChange = true;
        });

        _intimacyHideTimer = Timer(const Duration(seconds: 2), () {
          if (!mounted || token != _intimacyAnimationToken) return;
          setState(() {
            _showIntimacyChange = false;
          });
        });
      }
    }

    final messageCount = messages.length;
    if (messageCount != _lastMessageCount) {
      _lastMessageCount = messageCount;
      // 只要用户仍停留在当前会话页面，新增消息立刻按已读处理
      if ((thread?.unreadCount ?? 0) > 0) {
        _chatProvider?.markAsRead(widget.threadId);
      }
      _scheduleScrollToBottom();
    }
    if (deliveryFeedback != null) {
      _showOutgoingDeliveryFeedback(deliveryFeedback);
    }
  }

  void _sendCurrentMessage(bool canSend) {
    if (!canSend) return;

    final content = _inputController.text.trim();
    if (content.isEmpty) return;

    final queued = context.read<ChatProvider>().sendMessage(
          widget.threadId,
          content,
        );

    if (queued) {
      _inputController.clear();
      context.read<ChatProvider>().clearDraft(widget.threadId);
      setState(() {
        _hasText = false;
      });
      _scheduleScrollToBottom();
      return;
    }

    AppFeedback.showError(
      context,
      AppErrorCode.sendFailed,
      detail: '消息没有发出去，你可以稍后重试。',
    );
  }

  Widget _buildEmptyConversationState(ChatThread? thread) {
    final title = thread == null ? '会话暂不可用' : '现在发第一句，会更容易聊起来';
    final subtitle = thread == null
        ? '请返回消息列表后重新进入这个会话。'
        : thread.otherUser.isOnline
            ? '对方此刻在线，适合先发一句轻松自然的问候。'
            : '对方暂时不在线，留一句舒服的话，回来时会先看到。';
    final suggestions = thread == null
        ? const <String>['返回上一页', '重新进入会话']
        : thread.otherUser.isOnline
            ? const <String>['嗨，刚好看到你', '你现在在忙什么', '想和你聊两句']
            : const <String>['先给你留个言', '等你看到时回我就好', '想认识一下你'];

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(UiTokens.radiusLg),
            border: Border.all(color: AppColors.white08),
            boxShadow: UiTokens.softShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.white08,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  thread?.otherUser.isOnline == true
                      ? Icons.waving_hand_rounded
                      : Icons.mark_chat_unread_outlined,
                  color: AppColors.textPrimary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textTertiary.withValues(alpha: 0.9),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: suggestions.map((item) {
                  final canApplySuggestion = thread != null;

                  return GestureDetector(
                    onTap: !canApplySuggestion
                        ? null
                        : () {
                            _inputController.text = item;
                            _inputController.selection =
                                TextSelection.fromPosition(
                              TextPosition(offset: item.length),
                            );
                            setState(() {
                              _hasText = true;
                            });
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: canApplySuggestion
                            ? AppColors.white08
                            : AppColors.white05,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.white08),
                      ),
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          color: canApplySuggestion
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposerStatus({
    required ChatThread? thread,
    required bool canSend,
    required bool canSendImage,
  }) {
    String text;
    IconData icon;
    Color accent;
    final inputLength = _inputController.text.characters.length;
    final hasDraft = inputLength > 0;
    final remaining = _messageMaxLength - inputLength;
    final counterAccent = remaining <= 20
        ? AppColors.warning
        : remaining <= 60
            ? AppColors.textSecondary
            : AppColors.textTertiary;

    if (!canSend) {
      text = '当前无法继续发送消息，等待对方确认后再继续。';
      icon = Icons.lock_outline;
      accent = AppColors.error;
    } else if (!canSendImage) {
      text = thread == null
          ? '当前会话还没准备好。'
          : FeaturePolicy.profileUnlockHint(thread, '图片消息');
      icon = Icons.image_not_supported_outlined;
      accent = AppColors.textTertiary;
    } else {
      text = _hasText ? '准备好了就发送，简短自然一点更容易收到回复。' : '支持文字与图片消息，先发一句简单的开场白吧。';
      icon = Icons.tips_and_updates_outlined;
      accent = AppColors.textTertiary;
    }

    if (canSend && hasDraft) {
      text = canSendImage ? '草稿已保存，发送后会自动清空。' : '草稿已保存，继续互动后可解锁图片。';
      icon = Icons.edit_note_outlined;
      accent = canSendImage ? AppColors.brandBlue : AppColors.textTertiary;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: accent.withValues(alpha: 0.9)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w300,
                color: accent.withValues(alpha: 0.92),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: UiTokens.motionFast,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: counterAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: counterAccent.withValues(alpha: 0.18),
              ),
            ),
            child: Text(
              '$inputLength/$_messageMaxLength',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: counterAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposerCapabilityChips({
    required ChatThread? thread,
    required bool canSend,
    required bool canSendImage,
    required _ChatComposerLayoutSpec layout,
  }) {
    final chips = <Widget>[
      _buildComposerCapabilityChip(
        icon: canSend ? Icons.chat_bubble_outline_rounded : Icons.lock_outline,
        label: canSend ? '文字可发送' : '等待确认后继续发送',
        color: canSend ? AppColors.textSecondary : AppColors.error,
      ),
      _buildComposerCapabilityChip(
        icon: canSendImage
            ? Icons.image_outlined
            : Icons.image_not_supported_outlined,
        label: canSendImage
            ? '图片已解锁'
            : thread == null
                ? '图片暂不可用'
                : '图片待解锁',
        color: canSendImage ? AppColors.brandBlue : AppColors.textTertiary,
      ),
    ];

    if (_isBurnAfterReadEnabled) {
      chips.add(
        _buildComposerCapabilityChip(
          icon: Icons.local_fire_department,
          label: '本张将作为闪图发送',
          color: AppColors.warning,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: layout.statusTopPadding),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          key: const Key('chat-composer-capability-row'),
          spacing: layout.chipSpacing,
          runSpacing: layout.chipRunSpacing,
          children: chips,
        ),
      ),
    );
  }

  Widget _buildComposerCapabilityChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withValues(alpha: 0.92)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: color.withValues(alpha: 0.94),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationPermissionBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: NotificationPermissionNoticeCard(
        key: const Key('chat-notification-permission-banner'),
        description: NotificationPermissionGuidance.chatDescription,
        actionLabel: NotificationPermissionGuidance.openSettingsPageAction,
        actionKey: const Key('chat-notification-permission-action'),
        onActionPressed: () => context.push('/settings'),
        secondaryActionLabel:
            NotificationPermissionGuidance.openNotificationCenterAction,
        secondaryActionKey: const Key('chat-notification-center-action'),
        onSecondaryActionPressed: () => context.push('/notifications'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider?>(context);
    final showNotificationPermissionBanner = settingsProvider != null &&
        NotificationPermissionGuidance.needsSystemPermission(
          notificationEnabled: settingsProvider.notificationEnabled,
          permissionGranted:
              settingsProvider.pushRuntimeState.permissionGranted,
        );
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
          if (showNotificationPermissionBanner)
            _buildNotificationPermissionBanner(),
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
                    final thread = chatProvider.getThread(widget.threadId);
                    final messages = chatProvider.getMessages(widget.threadId);

                    if (messages.isEmpty) {
                      return _buildEmptyConversationState(thread);
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
              final composerLayout =
                  _ChatComposerLayoutSpec.fromSize(MediaQuery.of(context).size);

              return Container(
                padding: composerLayout.outerPadding,
                decoration: BoxDecoration(
                  color: AppColors.pureBlack,
                  border: Border(top: BorderSide(color: AppColors.white05)),
                ),
                child: SafeArea(
                  top: false,
                  child: Container(
                    key: const Key('chat-composer-shell'),
                    padding: composerLayout.innerPadding,
                    decoration: BoxDecoration(
                      color: AppColors.cardBg.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(UiTokens.radiusLg),
                      border: Border.all(color: AppColors.white08),
                      boxShadow: UiTokens.softShadow,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildComposerCapabilityChips(
                          thread: thread,
                          canSend: canSend,
                          canSendImage: canSendImage,
                          layout: composerLayout,
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildImageAction(
                              canSend: canSend,
                              canSendImage: canSendImage,
                              thread: thread,
                            ),
                            SizedBox(width: composerLayout.controlGap),
                            Expanded(
                              child: TextField(
                                key: const Key('chat-composer-input'),
                                controller: _inputController,
                                maxLength: _messageMaxLength,
                                maxLines: null,
                                textInputAction: TextInputAction.send,
                                enabled: canSend,
                                onSubmitted: (_) =>
                                    _sendCurrentMessage(canSend),
                                decoration: InputDecoration(
                                  hintText: canSend ? '输入你想说的话...' : '当前无法发送消息',
                                  counterText: '',
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal:
                                        composerLayout.fieldHorizontalPadding,
                                    vertical:
                                        composerLayout.fieldVerticalPadding,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: composerLayout.controlGap),
                            Container(
                              width: composerLayout.controlSize,
                              height: composerLayout.controlSize,
                              decoration: BoxDecoration(
                                color: _hasText && canSend
                                    ? AppColors.textPrimary
                                    : AppColors.white05,
                                borderRadius:
                                    BorderRadius.circular(UiTokens.radiusSm),
                                border: Border.all(color: AppColors.white08),
                              ),
                              child: IconButton(
                                key: const Key('chat-composer-send-button'),
                                icon: Icon(
                                  Icons.arrow_upward,
                                  color: _hasText && canSend
                                      ? AppColors.pureBlack
                                      : AppColors.textDisabled,
                                ),
                                onPressed: !_hasText || !canSend
                                    ? null
                                    : () => _sendCurrentMessage(canSend),
                              ),
                            ),
                          ],
                        ),
                        _buildComposerStatus(
                          thread: thread,
                          canSend: canSend,
                          canSendImage: canSendImage,
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
    final startedThreadId = widget.threadId;
    final burnAfterReadEnabled = _isBurnAfterReadEnabled;
    final thread = _resolveImageThreadForSend(
      startedThreadId,
      showFeedback: true,
    );
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
    if (!mounted || widget.threadId != startedThreadId || source == null) {
      return;
    }

    bool hasPermission = false;
    if (source == ImageSource.camera) {
      if (!mounted || widget.threadId != startedThreadId) return;
      hasPermission = await PermissionManager.requestCameraPermission(
        context,
        purpose: '拍摄照片发送聊天图片',
      );
    } else {
      if (!mounted || widget.threadId != startedThreadId) return;
      hasPermission = await PermissionManager.requestPhotosPermission(
        context,
        purpose: '从相册选择图片发送聊天消息',
      );
    }
    if (!mounted || widget.threadId != startedThreadId) return;
    if (!hasPermission) {
      AppFeedback.showError(context, AppErrorCode.permissionDenied);
      return;
    }
    if (_resolveImageThreadForSend(startedThreadId, showFeedback: true) ==
        null) {
      return;
    }

    final imageFile = source == ImageSource.camera
        ? await ImageHelper.pickImageFromCamera()
        : await ImageHelper.pickImageFromGallery();
    if (!mounted || widget.threadId != startedThreadId || imageFile == null) {
      return;
    }
    if (_resolveImageThreadForSend(startedThreadId, showFeedback: true) ==
        null) {
      return;
    }

    final quality = await ImageHelper.showQualitySelector(context, imageFile);
    if (!mounted || widget.threadId != startedThreadId || quality == null) {
      return;
    }
    if (_resolveImageThreadForSend(startedThreadId, showFeedback: true) ==
        null) {
      return;
    }

    final queued = await context.read<ChatProvider>().sendImageMessage(
          startedThreadId,
          imageFile,
          quality,
          burnAfterReadEnabled,
        );

    if (!mounted || widget.threadId != startedThreadId) return;
    if (!queued) {
      if (_resolveImageThreadForSend(startedThreadId, showFeedback: true) !=
          null) {
        AppFeedback.showError(context, AppErrorCode.sendFailed);
      }
      return;
    }
    AppFeedback.showToast(
      context,
      AppToastCode.sent,
      subject: burnAfterReadEnabled ? '闪图（对方可看5秒）' : '图片',
    );

    if (burnAfterReadEnabled) {
      setState(() {
        _isBurnAfterReadEnabled = false;
      });
    }
  }

  ChatThread? _resolveImageThreadForSend(
    String threadId, {
    required bool showFeedback,
  }) {
    final chatProvider = context.read<ChatProvider>();
    final visibleThread = chatProvider.threads[threadId];
    if (visibleThread == null) {
      if (showFeedback) {
        final rawThread = chatProvider.getThread(threadId);
        final detail =
            rawThread != null && !rawThread.isFriend && rawThread.isExpired
                ? '当前会话已过期，请返回消息列表重新进入'
                : '当前会话不可用，请返回消息列表重新进入';
        AppFeedback.showError(
          context,
          AppErrorCode.invalidInput,
          detail: detail,
        );
      }
      return null;
    }
    if (!FeaturePolicy.canSendImage(visibleThread)) {
      if (showFeedback) {
        AppFeedback.showError(
          context,
          AppErrorCode.unlockRequired,
          detail: FeaturePolicy.profileUnlockHint(visibleThread, '鍥剧墖娑堟伅'),
        );
      }
      return null;
    }
    return visibleThread;
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
      await context.read<FriendProvider>().sendFriendRequestRemote(
            user,
            controller.text.trim().isEmpty ? null : controller.text.trim(),
          );
      if (!context.mounted) {
        controller.dispose();
        return;
      }
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
      context.read<ChatProvider>().handleUserBlocked(thread.otherUser.id);
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
          final canShowPublicUid = canOpenFullProfile && isFriend;
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
                      const SizedBox(height: 6),
                      Text(
                        canShowPublicUid ? 'UID：${user.uid}' : 'UID在主页解锁并互关后可见',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          color: AppColors.textTertiary,
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

class _MessageBubble extends StatefulWidget {
  final Message message;
  final String threadId;

  const _MessageBubble({
    required this.message,
    required this.threadId,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  OverlayEntry? _burnOverlayEntry;
  bool _burnPreviewActive = false;
  bool _consumingBurn = false;
  bool get _showLegacyDeliveryFallback => false;

  Message get message => widget.message;

  @override
  void dispose() {
    _burnOverlayEntry?.remove();
    _burnOverlayEntry = null;
    _burnPreviewActive = false;
    ScreenshotGuard.setSecure(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canRecall = context
        .read<ChatProvider>()
        .canRecallMessage(widget.threadId, message.id);
    final deliveryFailureState = context
        .read<ChatProvider>()
        .deliveryFailureStateFor(widget.threadId, message.id);
    final isImage = message.type == MessageType.image;
    final isBurnImage = isImage && message.isBurnAfterReading;
    final deliverySpec = resolveChatDeliveryStatus(
      message,
      failureState: deliveryFailureState,
    );

    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment:
            message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 发送失败的感叹号（仅自己的消息）
          if (_showLegacyDeliveryFallback &&
              message.isMe &&
              message.status == MessageStatus.failed) ...[
            GestureDetector(
              onTap: () async {
                if (isImage) {
                  final imageResent = await context
                      .read<ChatProvider>()
                      .resendImageMessage(widget.threadId, message.id);
                  if (!context.mounted) return;
                  if (imageResent) {
                    return;
                  }
                  AppFeedback.showError(
                    context,
                    AppErrorCode.invalidInput,
                    detail: '图片发送失败，原图失效后请重新选择图片再发送。',
                  );
                } else {
                  final resent = context
                      .read<ChatProvider>()
                      .resendMessage(widget.threadId, message.id);
                  if (resent) {
                    return;
                  }
                  AppFeedback.showError(
                    context,
                    AppErrorCode.sendFailed,
                    detail: '消息暂时无法重试，请稍后再发一条。',
                  );
                }
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8, bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.refresh,
                      size: 14,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '重试',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: AppColors.error.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          GestureDetector(
            onTap: isImage && message.status != MessageStatus.sending
                ? () {
                    if (isBurnImage) {
                      AppToast.show(
                        context,
                        message.isRead ? '闪图已销毁' : '长按查看闪图（最多5秒）',
                      );
                      return;
                    }
                    _handleImageTap(context);
                  }
                : null,
            onLongPressStart:
                isBurnImage && message.status != MessageStatus.sending
                    ? (_) => _handleBurnLongPressStart(context)
                    : null,
            onLongPressEnd:
                isBurnImage && message.status != MessageStatus.sending
                    ? (_) => _consumeBurnImage(context)
                    : null,
            onLongPressCancel:
                isBurnImage && message.status != MessageStatus.sending
                    ? () => _consumeBurnImage(context)
                    : null,
            onLongPress: isBurnImage || message.status == MessageStatus.sending
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
                        ClipboardData(text: message.content),
                      );
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
                        final recalled = context
                            .read<ChatProvider>()
                            .recallMessage(widget.threadId, message.id);
                        if (!context.mounted) return;
                        if (recalled) {
                          AppFeedback.showToast(
                            context,
                            AppToastCode.deleted,
                            subject: '消息',
                          );
                        } else {
                          AppFeedback.showError(
                            context,
                            AppErrorCode.notSupported,
                            detail: '消息只能在发送后2分钟内撤回',
                          );
                        }
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
                        : AppColors.white20)
                    : AppColors.white12,
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
                    color: AppColors.pureBlack,
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
                  if (message.isMe && (deliverySpec?.hasCard ?? false)) ...[
                    SizedBox(height: isImage ? 8 : 6),
                    _buildInlineDeliveryStatusCard(
                      context,
                      spec: deliverySpec!,
                    ),
                  ],
                  if (_showLegacyDeliveryFallback &&
                      message.isMe &&
                      message.status == MessageStatus.failed) ...[
                    SizedBox(height: isImage ? 8 : 6),
                    Text(
                      isImage ? '图片发送失败，点左侧重试；原图失效后需重新选择' : '发送失败，点左侧重试',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w300,
                        color: AppColors.error.withValues(alpha: 0.88),
                      ),
                    ),
                  ] else if (_showLegacyDeliveryFallback &&
                      message.isMe &&
                      message.status == MessageStatus.sent &&
                      !message.isBurnAfterReading) ...[
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
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildMessageStateLabel({required bool isImage}) {
    final isFailed = message.status == MessageStatus.failed;
    final statusColor = isFailed ? AppColors.error : AppColors.textTertiary;
    final statusText = isFailed ? '发送失败' : '发送中';
    final detailText =
        isFailed ? (isImage ? '原图失效后需重新选择图片' : '点击左侧按钮可立即重试') : '正在投递给对方';

    return Row(
      children: [
        if (isFailed)
          Icon(
            Icons.error_outline,
            size: 12,
            color: statusColor.withValues(alpha: 0.92),
          )
        else
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.7,
              valueColor: AlwaysStoppedAnimation<Color>(
                statusColor.withValues(alpha: 0.86),
              ),
            ),
          ),
        const SizedBox(width: 6),
        Text(
          statusText,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: statusColor.withValues(alpha: 0.92),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            detailText,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w300,
              color: statusColor.withValues(alpha: 0.82),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildInlineDeliveryStatusCard(
    BuildContext context, {
    required ChatDeliveryStatusSpec spec,
  }) {
    return ChatDeliveryStatusCard(
      spec: spec,
      onActionTap: spec.actionType == null
          ? null
          : () => _handleInlineDeliveryAction(context, spec),
    );
  }

  // ignore: unused_element
  _MessageDeliveryCardDescriptor _buildInlineDeliveryDescriptor({
    required bool isImage,
  }) {
    if (message.status == MessageStatus.sending) {
      return const _MessageDeliveryCardDescriptor(
        title: '发送中',
        detail: '正在投递给对方',
        color: AppColors.brandBlue,
        icon: Icons.schedule_rounded,
      );
    }

    if (message.status == MessageStatus.failed) {
      final needsReselect = isImage && failedImageNeedsReselect(message);
      return _MessageDeliveryCardDescriptor(
        title: needsReselect ? '重选图片' : '发送失败',
        detail: needsReselect
            ? '原图失效，请重新选择图片'
            : (isImage ? '点击重试后重新投递图片' : '点击重试后继续发送'),
        color: AppColors.error,
        icon:
            needsReselect ? Icons.photo_library_outlined : Icons.error_outline,
        actionLabel: needsReselect ? '查看说明' : '立即重试',
        actionType: needsReselect
            ? _MessageDeliveryAction.showGuide
            : _MessageDeliveryAction.retry,
      );
    }

    final isRead = message.isRead;
    return _MessageDeliveryCardDescriptor(
      title: isRead ? '已读' : '已送达',
      detail: isRead ? '对方已经查看这条消息' : '消息已到达对方设备',
      color: isRead
          ? AppColors.textTertiary.withValues(alpha: 0.88)
          : AppColors.textSecondary.withValues(alpha: 0.9),
      icon: isRead ? Icons.done_all_rounded : Icons.done_rounded,
    );
  }

  Future<void> _handleInlineDeliveryAction(
    BuildContext context,
    ChatDeliveryStatusSpec spec,
  ) async {
    final action = spec.actionType;
    if (action == null) {
      return;
    }
    final isImage = message.type == MessageType.image;
    final chatProvider = context.read<ChatProvider>();
    switch (action) {
      case ChatDeliveryAction.retry:
        await HapticFeedback.selectionClick();
        final retried =
            await chatProvider.retryFailedMessage(widget.threadId, message.id);
        if (!context.mounted || retried) {
          return;
        }
        final failureState = chatProvider.deliveryFailureStateFor(
          widget.threadId,
          message.id,
        );
        AppFeedback.showError(
          context,
          switch (failureState) {
            ChatDeliveryFailureState.threadExpired => AppErrorCode.unknown,
            ChatDeliveryFailureState.blockedRelation => AppErrorCode.blocked,
            ChatDeliveryFailureState.imageUploadPreparationFailed =>
              AppErrorCode.sendFailed,
            ChatDeliveryFailureState.imageUploadInterrupted =>
              AppErrorCode.sendFailed,
            ChatDeliveryFailureState.imageUploadTokenInvalid =>
              AppErrorCode.sendFailed,
            ChatDeliveryFailureState.imageUploadFileTooLarge =>
              AppErrorCode.invalidInput,
            ChatDeliveryFailureState.imageUploadUnsupportedFormat =>
              AppErrorCode.invalidInput,
            ChatDeliveryFailureState.networkIssue => AppErrorCode.sendFailed,
            ChatDeliveryFailureState.imageReselectRequired =>
              AppErrorCode.invalidInput,
            ChatDeliveryFailureState.retryUnavailable => AppErrorCode.unknown,
            ChatDeliveryFailureState.retryable => AppErrorCode.sendFailed,
          },
          detail: switch (failureState) {
            ChatDeliveryFailureState.threadExpired =>
              isImage ? '这条图片消息所在的会话已经到期，当前不能继续重试。' : '这条消息所在的会话已经到期，当前不能继续重试。',
            ChatDeliveryFailureState.blockedRelation =>
              isImage ? '你和对方当前处于拉黑关系，图片暂时不能继续发送。' : '你和对方当前处于拉黑关系，消息暂时不能继续发送。',
            ChatDeliveryFailureState.imageUploadPreparationFailed =>
              '图片上传准备失败，服务端暂时无法完成上传准备，请稍后重新发送。',
            ChatDeliveryFailureState.imageUploadInterrupted =>
              '图片上传过程中已中断，建议检查网络后重新投递。',
            ChatDeliveryFailureState.imageUploadTokenInvalid =>
              '图片上传凭证已失效，再试一次就会重新刷新凭证后再提交。',
            ChatDeliveryFailureState.imageUploadFileTooLarge =>
              '当前图片已超过上传大小限制，请更换更小的图片或使用压缩图后再发送。',
            ChatDeliveryFailureState.imageUploadUnsupportedFormat =>
              '当前文件没有通过图片校验，请重新选择常见图片格式后再发送。',
            ChatDeliveryFailureState.networkIssue =>
              isImage ? '网络连接不稳定，建议检查网络后重新投递图片。' : '网络连接不稳定，建议检查网络后重新发送消息。',
            ChatDeliveryFailureState.imageReselectRequired =>
              '图片发送失败，原图失效后请重新选择图片再发送。',
            ChatDeliveryFailureState.retryUnavailable =>
              isImage ? '图片当前暂不可重试，请先确认会话状态后再处理。' : '消息当前暂不可重试，请先确认会话状态后再处理。',
            ChatDeliveryFailureState.retryable =>
              isImage ? '图片发送失败，请检查网络后再试。' : '消息暂时无法重试，请稍后再发一条。',
          },
        );
      case ChatDeliveryAction.showGuide:
        _showImageFailureGuide(
          context,
          spec.guideFailureState ??
              ChatDeliveryFailureState.imageReselectRequired,
        );
    }
  }

  void _showImageFailureGuide(
    BuildContext context,
    ChatDeliveryFailureState failureState,
  ) {
    late final String title;
    late final String description;
    late final ({IconData icon, String title, String detail}) primaryTip;
    late final ({IconData icon, String title, String detail}) secondaryTip;

    switch (failureState) {
      case ChatDeliveryFailureState.imageUploadFileTooLarge:
        title = '图片体积过大';
        description = '这张图片已经超过当前上传大小限制，继续重试通常不会成功，建议先压缩、裁剪或换一张更小的图片。';
        primaryTip = (
          icon: Icons.compress_outlined,
          title: '先压缩后再发送',
          detail: '优先选择压缩图，或者在系统相册里编辑后再发送，成功率会更高。',
        );
        secondaryTip = (
          icon: Icons.crop_outlined,
          title: '裁剪掉不必要区域',
          detail: '减少分辨率和画面范围后，往往就能满足上传限制。',
        );
        break;
      case ChatDeliveryFailureState.imageUploadUnsupportedFormat:
        title = '图片格式暂不支持';
        description = '当前文件没有通过图片格式校验，通常是文件格式异常、文件损坏，或并非标准图片文件。';
        primaryTip = (
          icon: Icons.photo_library_outlined,
          title: '重新选择常见图片格式',
          detail: '优先从系统相册中选择 JPG、JPEG 或 PNG 图片后再发送。',
        );
        secondaryTip = (
          icon: Icons.auto_fix_high_outlined,
          title: '先重新保存一遍图片',
          detail: '重新编辑、导出或截图后再发送，能避开一部分格式兼容问题。',
        );
        break;
      case ChatDeliveryFailureState.retryable:
      case ChatDeliveryFailureState.imageReselectRequired:
      case ChatDeliveryFailureState.imageUploadPreparationFailed:
      case ChatDeliveryFailureState.imageUploadInterrupted:
      case ChatDeliveryFailureState.imageUploadTokenInvalid:
      case ChatDeliveryFailureState.threadExpired:
      case ChatDeliveryFailureState.blockedRelation:
      case ChatDeliveryFailureState.networkIssue:
      case ChatDeliveryFailureState.retryUnavailable:
        title = '图片需要重新选择';
        description = '这次发送依赖的原图已经不可用，系统无法直接帮你重试。';
        primaryTip = (
          icon: Icons.photo_library_outlined,
          title: '回到输入区重新选图',
          detail: '重新选择图片后再发送，通常是最稳妥的处理方式。',
        );
        secondaryTip = (
          icon: Icons.compress_outlined,
          title: '弱网时优先发送压缩图',
          detail: '压缩后的图片更容易上传成功，也更容易更快送达。',
        );
        break;
    }

    _showImageFailureGuideSheet(
      context,
      title: title,
      description: description,
      primaryTip: primaryTip,
      secondaryTip: secondaryTip,
    );
    /*
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (sheetContext) => Container(
        decoration: AppDialog.sheetDecoration(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '图片需要重新选择',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '这次发送依赖的原图已经不可用，系统无法直接替你重试。',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textTertiary.withValues(alpha: 0.92),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              _buildGuideTip(
                icon: Icons.photo_library_outlined,
                title: '回到输入区重新选图',
                detail: '重新选择图片后再发送，成功率最高。',
              ),
              const SizedBox(height: 12),
              _buildGuideTip(
                icon: Icons.compress_outlined,
                title: '弱网场景优先压缩图',
                detail: '压缩图上传更稳，也更容易快速送达。',
              ),
            ],
          ),
        ),
      ),
    );
    */
  }

  void _showImageFailureGuideSheet(
    BuildContext context, {
    required String title,
    required String description,
    required ({IconData icon, String title, String detail}) primaryTip,
    required ({IconData icon, String title, String detail}) secondaryTip,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (sheetContext) => Container(
        decoration: AppDialog.sheetDecoration(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textTertiary.withValues(alpha: 0.92),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              _buildGuideTip(
                icon: primaryTip.icon,
                title: primaryTip.title,
                detail: primaryTip.detail,
              ),
              const SizedBox(height: 12),
              _buildGuideTip(
                icon: secondaryTip.icon,
                title: secondaryTip.title,
                detail: secondaryTip.detail,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideTip({
    required IconData icon,
    required String title,
    required String detail,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.white08),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textTertiary.withValues(alpha: 0.9),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleImageTap(BuildContext context) async {
    final imagePath = message.imagePath;
    if (imagePath == null || imagePath.isEmpty) {
      AppFeedback.showError(
        context,
        AppErrorCode.invalidInput,
        detail: '图片不可用，请重新发送',
      );
      return;
    }

    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: AppColors.pureBlack,
        pageBuilder: (_, __, ___) => _ImagePreviewScreen(
          imagePath: imagePath,
          isBurnAfterReading: false,
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }

  Future<void> _handleBurnLongPressStart(BuildContext context) async {
    if (message.isRead) {
      AppToast.show(context, '闪图已销毁');
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
    await _showBurnPreviewOverlay(context, imagePath);
  }

  Future<void> _showBurnPreviewOverlay(
    BuildContext context,
    String imagePath,
  ) async {
    if (_burnPreviewActive || _burnOverlayEntry != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);

    _burnPreviewActive = true;
    await ScreenshotGuard.setSecure(true);
    if (!mounted) {
      _burnPreviewActive = false;
      await ScreenshotGuard.setSecure(false);
      return;
    }
    if (!_burnPreviewActive) {
      await ScreenshotGuard.setSecure(false);
      return;
    }

    final entry = OverlayEntry(
      builder: (_) => _BurnHoldPreviewOverlay(
        imagePath: imagePath,
        onTimeout: () => _consumeBurnImage(context),
      ),
    );
    _burnOverlayEntry = entry;
    overlay.insert(entry);
    if (mounted) setState(() {});
  }

  Future<void> _consumeBurnImage(BuildContext context) async {
    if (!_burnPreviewActive || _consumingBurn) return;
    _consumingBurn = true;
    final shouldMarkRead = !message.isRead;
    final chatProvider = context.read<ChatProvider>();
    try {
      await _hideBurnPreviewOverlay();
      if (shouldMarkRead && mounted) {
        chatProvider.markImageAsRead(widget.threadId, message.id);
      }
    } finally {
      _consumingBurn = false;
    }
  }

  Future<void> _hideBurnPreviewOverlay() async {
    final entry = _burnOverlayEntry;
    _burnOverlayEntry = null;
    _burnPreviewActive = false;
    if (entry != null) {
      entry.remove();
      if (mounted) setState(() {});
    }
    await ScreenshotGuard.setSecure(false);
  }

  Widget _buildImageContent(BuildContext context) {
    if (message.isBurnAfterReading) {
      return message.isRead
          ? _buildBurnDestroyedPlaceholder()
          : _buildBurnLockedPlaceholder();
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
                  color: AppColors.pureBlack.withValues(alpha: 0.35),
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
    return _buildBurnMosaicPlaceholder(isDestroyed: false);
  }

  Widget _buildBurnDestroyedPlaceholder() {
    return _buildBurnMosaicPlaceholder(isDestroyed: true);
  }

  Widget _buildBurnMosaicPlaceholder({required bool isDestroyed}) {
    final borderColor = isDestroyed
        ? AppColors.white12
        : AppColors.warning.withValues(alpha: 0.45);
    final tintColor = isDestroyed
        ? AppColors.white12
        : AppColors.warning.withValues(alpha: 0.2);

    return Container(
      width: 172,
      height: 198,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(UiTokens.radiusSm),
        border: Border.all(color: borderColor),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(UiTokens.radiusSm),
              child: CustomPaint(
                painter: _MosaicPainter(tintColor: tintColor),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.pureBlack
                    .withValues(alpha: isDestroyed ? 0.3 : 0.22),
                borderRadius: BorderRadius.circular(UiTokens.radiusSm),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isDestroyed
                      ? Icons.hide_image_outlined
                      : Icons.local_fire_department,
                  size: 28,
                  color: isDestroyed
                      ? AppColors.textTertiary
                      : AppColors.warning.withValues(alpha: 0.95),
                ),
                const SizedBox(height: 10),
                Text(
                  isDestroyed ? '闪图已销毁' : '长按查看闪图（最多5秒）',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isDestroyed ? '已无法再次查看' : '松开即销毁',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
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

class _MosaicPainter extends CustomPainter {
  final Color tintColor;

  const _MosaicPainter({required this.tintColor});

  @override
  void paint(Canvas canvas, Size size) {
    const blockSize = 14.0;
    final columns = (size.width / blockSize).ceil();
    final rows = (size.height / blockSize).ceil();
    final paint = Paint()..style = PaintingStyle.fill;

    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final seed = (row * 31 + column * 17) % 5;
        final alpha = 0.12 + (seed * 0.06);
        paint.color = tintColor.withValues(alpha: alpha);
        canvas.drawRect(
          Rect.fromLTWH(
            column * blockSize,
            row * blockSize,
            blockSize,
            blockSize,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MosaicPainter oldDelegate) {
    return oldDelegate.tintColor != tintColor;
  }
}

class _BurnHoldPreviewOverlay extends StatefulWidget {
  final String imagePath;
  final VoidCallback onTimeout;

  const _BurnHoldPreviewOverlay({
    required this.imagePath,
    required this.onTimeout,
  });

  @override
  State<_BurnHoldPreviewOverlay> createState() =>
      _BurnHoldPreviewOverlayState();
}

class _BurnHoldPreviewOverlayState extends State<_BurnHoldPreviewOverlay> {
  static const int _burnSeconds = 5;
  int _secondsLeft = _burnSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        widget.onTimeout();
        return;
      }
      setState(() {
        _secondsLeft -= 1;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNetwork = widget.imagePath.startsWith('http');

    return Material(
      color: AppColors.pureBlack.withValues(alpha: 0.94),
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
            left: 0,
            right: 0,
            bottom: 28,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.pureBlack.withValues(alpha: 0.44),
                  borderRadius: BorderRadius.circular(UiTokens.radiusSm),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  '长按查看中 · $_secondsLeft 秒后销毁',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _MessageDeliveryAction {
  retry,
  showGuide,
}

class _MessageDeliveryCardDescriptor {
  const _MessageDeliveryCardDescriptor({
    required this.title,
    required this.detail,
    required this.color,
    required this.icon,
    this.actionLabel,
    this.actionType,
  });

  final String title;
  final String detail;
  final Color color;
  final IconData icon;
  final String? actionLabel;
  final _MessageDeliveryAction? actionType;
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
      backgroundColor: AppColors.pureBlack.withValues(alpha: 0.94),
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
                      color: AppColors.pureBlack.withValues(alpha: 0.42),
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
