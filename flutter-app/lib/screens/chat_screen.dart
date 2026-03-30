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
import '../utils/chat_retry_feedback.dart';
import '../utils/intimacy_system.dart';
import '../utils/image_helper.dart';
import '../utils/notification_permission_guidance.dart';
import '../utils/permission_manager.dart';
import '../services/screenshot_guard.dart';
import '../widgets/app_user_avatar.dart';
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
    required this.isTight,
    required this.outerPadding,
    required this.innerPadding,
    required this.controlSize,
    required this.controlGap,
    required this.fieldHorizontalPadding,
    required this.fieldVerticalPadding,
    required this.statusTopPadding,
    required this.chipSpacing,
    required this.chipRunSpacing,
    required this.maxInputLines,
  });

  final bool isCompact;
  final bool isTight;
  final EdgeInsets outerPadding;
  final EdgeInsets innerPadding;
  final double controlSize;
  final double controlGap;
  final double fieldHorizontalPadding;
  final double fieldVerticalPadding;
  final double statusTopPadding;
  final double chipSpacing;
  final double chipRunSpacing;
  final int maxInputLines;

  static _ChatComposerLayoutSpec fromSize(Size size) {
    final isTight = size.width <= 340 || size.height <= 620;
    final isCompact = isTight || size.width <= 390 || size.height <= 720;
    if (isTight) {
      return const _ChatComposerLayoutSpec(
        isCompact: true,
        isTight: true,
        outerPadding: EdgeInsets.fromLTRB(8, 5, 8, 6),
        innerPadding: EdgeInsets.fromLTRB(7, 7, 7, 6),
        controlSize: 40,
        controlGap: 6,
        fieldHorizontalPadding: 12,
        fieldVerticalPadding: 8,
        statusTopPadding: 5,
        chipSpacing: 5,
        chipRunSpacing: 4,
        maxInputLines: 2,
      );
    }

    if (isCompact) {
      return const _ChatComposerLayoutSpec(
        isCompact: true,
        isTight: false,
        outerPadding: EdgeInsets.fromLTRB(10, 6, 10, 8),
        innerPadding: EdgeInsets.fromLTRB(8, 8, 8, 6),
        controlSize: 42,
        controlGap: 8,
        fieldHorizontalPadding: 14,
        fieldVerticalPadding: 10,
        statusTopPadding: 6,
        chipSpacing: 6,
        chipRunSpacing: 5,
        maxInputLines: 4,
      );
    }

    return const _ChatComposerLayoutSpec(
      isCompact: false,
      isTight: false,
      outerPadding: EdgeInsets.fromLTRB(12, 8, 12, 10),
      innerPadding: EdgeInsets.fromLTRB(9, 9, 9, 6),
      controlSize: 46,
      controlGap: 10,
      fieldHorizontalPadding: 16,
      fieldVerticalPadding: 12,
      statusTopPadding: 7,
      chipSpacing: 8,
      chipRunSpacing: 6,
      maxInputLines: 6,
    );
  }
}

class _ChatScreenLayoutSpec {
  const _ChatScreenLayoutSpec({
    required this.isCompact,
    required this.isTight,
    required this.toolbarHeight,
    required this.leadingWidth,
    required this.actionButtonExtent,
    required this.headerAvatarSize,
    required this.headerGap,
    required this.headerTitleSize,
    required this.headerSubtitleSize,
    required this.showHeaderSubtitle,
    required this.bannerPadding,
    required this.unfollowPadding,
    required this.unfollowInnerPadding,
    required this.messageListPadding,
  });

  final bool isCompact;
  final bool isTight;
  final double toolbarHeight;
  final double leadingWidth;
  final double actionButtonExtent;
  final double headerAvatarSize;
  final double headerGap;
  final double headerTitleSize;
  final double headerSubtitleSize;
  final bool showHeaderSubtitle;
  final EdgeInsets bannerPadding;
  final EdgeInsets unfollowPadding;
  final EdgeInsets unfollowInnerPadding;
  final EdgeInsets messageListPadding;

  static _ChatScreenLayoutSpec fromSize(Size size) {
    final isTight = size.width <= 340 || size.height <= 620;
    final isCompact = isTight || size.width <= 390 || size.height <= 720;
    if (isTight) {
      return const _ChatScreenLayoutSpec(
        isCompact: true,
        isTight: true,
        toolbarHeight: 52,
        leadingWidth: 44,
        actionButtonExtent: 40,
        headerAvatarSize: 28,
        headerGap: 6,
        headerTitleSize: 13,
        headerSubtitleSize: 9,
        showHeaderSubtitle: false,
        bannerPadding: EdgeInsets.fromLTRB(8, 4, 8, 2),
        unfollowPadding: EdgeInsets.fromLTRB(8, 6, 8, 4),
        unfollowInnerPadding: EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        messageListPadding: EdgeInsets.fromLTRB(10, 10, 10, 10),
      );
    }

    if (isCompact) {
      return const _ChatScreenLayoutSpec(
        isCompact: true,
        isTight: false,
        toolbarHeight: 54,
        leadingWidth: 48,
        actionButtonExtent: 42,
        headerAvatarSize: 30,
        headerGap: 7,
        headerTitleSize: 13.5,
        headerSubtitleSize: 9.5,
        showHeaderSubtitle: true,
        bannerPadding: EdgeInsets.fromLTRB(8, 4, 8, 2),
        unfollowPadding: EdgeInsets.fromLTRB(10, 6, 10, 4),
        unfollowInnerPadding: EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 9,
        ),
        messageListPadding: EdgeInsets.fromLTRB(12, 12, 12, 12),
      );
    }

    return const _ChatScreenLayoutSpec(
      isCompact: false,
      isTight: false,
      toolbarHeight: 64,
      leadingWidth: 56,
      actionButtonExtent: 44,
      headerAvatarSize: 36,
      headerGap: 10,
      headerTitleSize: 15,
      headerSubtitleSize: 11,
      showHeaderSubtitle: true,
      bannerPadding: EdgeInsets.fromLTRB(12, 8, 12, 2),
      unfollowPadding: EdgeInsets.fromLTRB(14, 10, 14, 4),
      unfollowInnerPadding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 11,
      ),
      messageListPadding: EdgeInsets.all(20),
    );
  }
}

class _ChatHeaderViewData {
  const _ChatHeaderViewData({
    required this.avatarText,
    required this.displayName,
    required this.hasUnlockedNickname,
    required this.subtitle,
  });

  final String avatarText;
  final String displayName;
  final bool hasUnlockedNickname;
  final String subtitle;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ChatHeaderViewData &&
          avatarText == other.avatarText &&
          displayName == other.displayName &&
          hasUnlockedNickname == other.hasUnlockedNickname &&
          subtitle == other.subtitle;

  @override
  int get hashCode =>
      Object.hash(avatarText, displayName, hasUnlockedNickname, subtitle);
}

class _ChatHeaderSelectorState {
  const _ChatHeaderSelectorState({
    required this.headerRevision,
    required this.isFriend,
  });

  final int headerRevision;
  final bool isFriend;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ChatHeaderSelectorState &&
          headerRevision == other.headerRevision &&
          isFriend == other.isFriend;

  @override
  int get hashCode => Object.hash(headerRevision, isFriend);
}

class _ChatComposerViewData {
  const _ChatComposerViewData({
    required this.hasThread,
    required this.canSend,
    required this.canSendImage,
    required this.imageCapabilityLabel,
    required this.imageUnlockHint,
    required this.flashImageUnlockHint,
  });

  final bool hasThread;
  final bool canSend;
  final bool canSendImage;
  final String imageCapabilityLabel;
  final String imageUnlockHint;
  final String flashImageUnlockHint;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ChatComposerViewData &&
          hasThread == other.hasThread &&
          canSend == other.canSend &&
          canSendImage == other.canSendImage &&
          imageCapabilityLabel == other.imageCapabilityLabel &&
          imageUnlockHint == other.imageUnlockHint &&
          flashImageUnlockHint == other.flashImageUnlockHint;

  @override
  int get hashCode => Object.hash(
        hasThread,
        canSend,
        canSendImage,
        imageCapabilityLabel,
        imageUnlockHint,
        flashImageUnlockHint,
      );
}

class _ChatUnfollowBannerViewData {
  const _ChatUnfollowBannerViewData({
    required this.remainingMessages,
    required this.showRemindAction,
  });

  final int remainingMessages;
  final bool showRemindAction;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ChatUnfollowBannerViewData &&
          remainingMessages == other.remainingMessages &&
          showRemindAction == other.showRemindAction;

  @override
  int get hashCode => Object.hash(remainingMessages, showRemindAction);
}

class _ChatActionMenuViewData {
  const _ChatActionMenuViewData({
    required this.otherUserId,
    required this.otherUserNickname,
    required this.isFriend,
    required this.isBlocked,
    required this.canCall,
    required this.canAddFriend,
    required this.items,
  });

  final String otherUserId;
  final String otherUserNickname;
  final bool isFriend;
  final bool isBlocked;
  final bool canCall;
  final bool canAddFriend;
  final List<_ChatActionMenuItemViewData> items;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ChatActionMenuViewData &&
          otherUserId == other.otherUserId &&
          otherUserNickname == other.otherUserNickname &&
          isFriend == other.isFriend &&
          isBlocked == other.isBlocked &&
          canCall == other.canCall &&
          canAddFriend == other.canAddFriend &&
          items.length == other.items.length &&
          items.asMap().entries.every(
                (entry) => entry.value == other.items[entry.key],
              );

  @override
  int get hashCode => Object.hash(
        otherUserId,
        otherUserNickname,
        isFriend,
        isBlocked,
        canCall,
        canAddFriend,
        Object.hashAll(items),
      );
}

class _ChatActionMenuSelectorState {
  const _ChatActionMenuSelectorState({
    required this.headerRevision,
    required this.isFriend,
    required this.isBlocked,
  });

  final int headerRevision;
  final bool isFriend;
  final bool isBlocked;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ChatActionMenuSelectorState &&
          headerRevision == other.headerRevision &&
          isFriend == other.isFriend &&
          isBlocked == other.isBlocked;

  @override
  int get hashCode => Object.hash(headerRevision, isFriend, isBlocked);
}

class _ChatActionMenuItemViewData {
  const _ChatActionMenuItemViewData({
    required this.key,
    required this.value,
    required this.icon,
    required this.label,
    this.isDanger = false,
  });

  final Key key;
  final String value;
  final IconData icon;
  final String label;
  final bool isDanger;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ChatActionMenuItemViewData &&
          key == other.key &&
          value == other.value &&
          icon == other.icon &&
          label == other.label &&
          isDanger == other.isDanger;

  @override
  int get hashCode => Object.hash(
        key,
        value,
        icon,
        label,
        isDanger,
      );
}

class _ChatUserProfileSheetViewData {
  const _ChatUserProfileSheetViewData({
    required this.thread,
    required this.user,
    required this.avatarText,
    required this.displayName,
    required this.statusText,
    required this.isFriend,
    required this.isBlocked,
    required this.canOpenFullProfile,
    required this.canShowPublicUid,
    required this.canFollow,
    required this.pointsToUnlock,
    required this.minutesToUnlock,
  });

  final ChatThread thread;
  final User user;
  final String avatarText;
  final String displayName;
  final String statusText;
  final bool isFriend;
  final bool isBlocked;
  final bool canOpenFullProfile;
  final bool canShowPublicUid;
  final bool canFollow;
  final int pointsToUnlock;
  final int minutesToUnlock;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ChatUserProfileSheetViewData &&
          thread.id == other.thread.id &&
          thread.intimacyPoints == other.thread.intimacyPoints &&
          thread.createdAt == other.thread.createdAt &&
          user.id == other.user.id &&
          user.uid == other.user.uid &&
          avatarText == other.avatarText &&
          displayName == other.displayName &&
          statusText == other.statusText &&
          user.distance == other.user.distance &&
          user.isOnline == other.user.isOnline &&
          isFriend == other.isFriend &&
          isBlocked == other.isBlocked &&
          canOpenFullProfile == other.canOpenFullProfile &&
          canShowPublicUid == other.canShowPublicUid &&
          canFollow == other.canFollow &&
          pointsToUnlock == other.pointsToUnlock &&
          minutesToUnlock == other.minutesToUnlock;

  @override
  int get hashCode => Object.hash(
        thread.id,
        thread.intimacyPoints,
        thread.createdAt,
        user.id,
        user.uid,
        avatarText,
        displayName,
        statusText,
        user.distance,
        user.isOnline,
        isFriend,
        isBlocked,
        canOpenFullProfile,
        canShowPublicUid,
        canFollow,
        pointsToUnlock,
        minutesToUnlock,
      );
}

class _ChatMessageListViewData {
  const _ChatMessageListViewData({
    required this.thread,
    required this.bubbles,
    required this.presentationKey,
  });

  final ChatThread? thread;
  final List<_ChatMessageBubbleViewData> bubbles;
  final int presentationKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ChatMessageListViewData &&
          presentationKey == other.presentationKey;

  @override
  int get hashCode => presentationKey;
}

class _ChatMessageBubbleViewData {
  const _ChatMessageBubbleViewData({
    required this.message,
    required this.canRecall,
    required this.deliverySpec,
  });

  final Message message;
  final bool canRecall;
  final ChatDeliveryStatusSpec? deliverySpec;
}

class _ChatIntimacyChangeState {
  const _ChatIntimacyChangeState({
    required this.change,
    required this.token,
  });

  final int change;
  final int token;
}

class _ChatScreenState extends State<ChatScreen> {
  static const int _messageMaxLength = 300;
  static const double _snapScrollToBottomDistance = 96;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  ChatProvider? _chatProvider;
  bool _chatProviderListenerAttached = false;
  Timer? _intimacyHideTimer;
  int _lastIntimacyPoints = 0;
  int _lastMessageCount = 0;
  int _intimacyAnimationToken = 0;
  final ValueNotifier<_ChatIntimacyChangeState?> _intimacyChangeNotifier =
      ValueNotifier<_ChatIntimacyChangeState?>(null);
  final Map<String, OutgoingDeliveryObservation> _deliveryStateSnapshot =
      <String, OutgoingDeliveryObservation>{};
  final ValueNotifier<bool> _burnAfterReadEnabledNotifier =
      ValueNotifier<bool>(false);
  OutgoingDeliveryFeedback? _pendingOutgoingDeliveryFeedback;
  bool _scrollToBottomQueued = false;
  bool _outgoingDeliveryFeedbackQueued = false;
  bool _canonicalRouteSyncQueued = false;
  bool _suspendDraftSync = false;
  bool _didActivateInitialThread = false;
  int _lastObservedThreadInteractionRevision = 0;
  String? _lastObservedCanonicalThreadId;
  int _lastObservedQuickSignal = 0;
  int _lastObservedOutgoingDeliveryFingerprint = 0;
  int _lastObservedOutgoingDeliveryRevision = 0;
  int _cachedMessageListViewKey = -1;
  _ChatMessageListViewData? _cachedMessageListViewData;
  int _cachedComposerViewKey = -1;
  _ChatComposerViewData? _cachedComposerViewData;

  @override
  void initState() {
    super.initState();

    _inputController.addListener(_handleInputChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindChatProvider();
    if (_didActivateInitialThread) {
      return;
    }
    _didActivateInitialThread = true;
    _activateCurrentThread();
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
    _inputController.removeListener(_handleInputChanged);
    _inputController.dispose();
    _scrollController.dispose();
    _intimacyChangeNotifier.dispose();
    _burnAfterReadEnabledNotifier.dispose();
    super.dispose();
  }

  void _handleInputChanged() {
    if (_suspendDraftSync) {
      return;
    }
    _chatProvider?.saveDraft(widget.threadId, _inputController.text);
  }

  void _bindChatProvider() {
    final nextChatProvider = context.read<ChatProvider>();
    if (identical(_chatProvider, nextChatProvider) &&
        _chatProviderListenerAttached) {
      return;
    }
    if (_chatProviderListenerAttached) {
      _chatProvider?.removeListener(_handleChatProviderChanged);
      _chatProviderListenerAttached = false;
    }
    _chatProvider = nextChatProvider;
    _chatProvider?.addListener(_handleChatProviderChanged);
    _chatProviderListenerAttached = true;
  }

  void _activateCurrentThread() {
    _chatProvider?.setActiveThread(widget.threadId);
    _hydrateDraftForThread(widget.threadId);
    final thread = _chatProvider?.getThread(widget.threadId);
    final messages =
        _chatProvider?.getMessages(widget.threadId) ?? const <Message>[];
    _clearCurrentThreadViewCaches();
    _lastIntimacyPoints = thread?.intimacyPoints ?? 0;
    _lastMessageCount = messages.length;
    _lastObservedThreadInteractionRevision =
        _chatProvider?.threadInteractionRevision(widget.threadId) ?? 0;
    _lastObservedCanonicalThreadId =
        _chatProvider?.canonicalThreadId(widget.threadId);
    _lastObservedQuickSignal = _buildCurrentThreadQuickSignal(thread, messages);
    _lastObservedOutgoingDeliveryFingerprint =
        _buildOutgoingDeliveryFingerprint(messages);
    _lastObservedOutgoingDeliveryRevision =
        _chatProvider?.threadOutgoingDeliveryRevision(widget.threadId) ?? 0;
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
    _replaceComposerText(draft);
  }

  void _replaceComposerText(String text) {
    _suspendDraftSync = true;
    _inputController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _suspendDraftSync = false;
  }

  void _resetTransientComposerStateForThreadChange() {
    _intimacyHideTimer?.cancel();
    _intimacyAnimationToken += 1;
    _intimacyChangeNotifier.value = null;
    _deliveryStateSnapshot.clear();
    _burnAfterReadEnabledNotifier.value = false;
    _pendingOutgoingDeliveryFeedback = null;
    _scrollToBottomQueued = false;
    _outgoingDeliveryFeedbackQueued = false;
    _clearCurrentThreadViewCaches();
  }

  void _clearCurrentThreadViewCaches() {
    _cachedMessageListViewKey = -1;
    _cachedMessageListViewData = null;
    _cachedComposerViewKey = -1;
    _cachedComposerViewData = null;
  }

  int _currentThreadViewKey(
    ChatProvider chatProvider, {
    required ChatThread? thread,
    required List<Message> messages,
  }) {
    return Object.hash(
      chatProvider.canonicalThreadId(widget.threadId) ?? widget.threadId,
      chatProvider.threadInteractionRevision(widget.threadId),
      _buildCurrentThreadQuickSignal(thread, messages),
    );
  }

  int _currentComposerViewKey(
    ChatProvider chatProvider,
    ChatThread? thread,
  ) {
    return Object.hash(
      chatProvider.canonicalThreadId(widget.threadId) ?? widget.threadId,
      chatProvider.threadComposerRevision(widget.threadId),
      thread?.id,
    );
  }

  _ChatMessageListViewData _selectMessageListViewData(
    ChatProvider chatProvider,
  ) {
    final thread = chatProvider.getThread(widget.threadId);
    final messages = chatProvider.getMessages(widget.threadId);
    final selectorKey = _currentThreadViewKey(
      chatProvider,
      thread: thread,
      messages: messages,
    );
    final cachedState = _cachedMessageListViewData;
    if (cachedState != null && _cachedMessageListViewKey == selectorKey) {
      return cachedState;
    }
    final bubbles = messages.map(
      (message) {
        final failureState = chatProvider.deliveryFailureStateForMessage(
          widget.threadId,
          message,
        );
        return _ChatMessageBubbleViewData(
          message: message,
          canRecall: _canRecallMessage(message),
          deliverySpec: resolveChatDeliveryStatus(
            message,
            failureState: failureState,
          ),
        );
      },
    ).toList(growable: false);
    final viewData = _ChatMessageListViewData(
      thread: thread,
      bubbles: bubbles,
      presentationKey: _buildMessageListPresentationKey(thread, bubbles),
    );
    _cachedMessageListViewKey = selectorKey;
    _cachedMessageListViewData = viewData;
    return viewData;
  }

  _ChatComposerViewData _selectComposerViewData(ChatProvider chatProvider) {
    final thread = chatProvider.getThread(widget.threadId);
    final selectorKey = _currentComposerViewKey(chatProvider, thread);
    final cachedState = _cachedComposerViewData;
    if (cachedState != null && _cachedComposerViewKey == selectorKey) {
      return cachedState;
    }
    final viewData = _ChatComposerViewData(
      hasThread: thread != null,
      canSend: thread?.canSendMessage ?? true,
      canSendImage: thread != null && FeaturePolicy.canSendImage(thread),
      imageCapabilityLabel: thread == null ? '图片暂不可用' : '图片待解锁',
      imageUnlockHint: thread == null
          ? '当前会话还没准备好。'
          : FeaturePolicy.profileUnlockHint(thread, '图片消息'),
      flashImageUnlockHint: thread == null
          ? '当前会话还没准备好。'
          : FeaturePolicy.profileUnlockHint(thread, '闪图模式'),
    );
    _cachedComposerViewKey = selectorKey;
    _cachedComposerViewData = viewData;
    return viewData;
  }

  _ChatUnfollowBannerViewData? _selectUnfollowBannerViewData(
    ChatProvider chatProvider,
  ) {
    final thread = chatProvider.getThread(widget.threadId);
    if (thread == null || !thread.isUnfollowed) {
      return null;
    }

    final remainingMessages = thread.messagesSinceUnfollow >= 3
        ? 0
        : 3 - thread.messagesSinceUnfollow;
    return _ChatUnfollowBannerViewData(
      remainingMessages: remainingMessages,
      showRemindAction: remainingMessages <= 0,
    );
  }

  _ChatHeaderViewData? _selectHeaderViewData(
    ChatProvider chatProvider, {
    required bool isFriend,
  }) {
    final thread = chatProvider.getThread(widget.threadId);
    if (thread == null) {
      return null;
    }
    return _ChatHeaderViewData(
      avatarText: thread.otherUser.avatar ?? '👤',
      displayName: thread.otherUser.nickname,
      hasUnlockedNickname: thread.hasUnlockedNickname,
      subtitle: _getHeaderSubtitle(thread, isFriend),
    );
  }

  _ChatActionMenuViewData? _selectActionMenuViewData(
    ChatProvider chatProvider, {
    required bool isFriend,
    required bool isBlocked,
  }) {
    final thread = chatProvider.getThread(widget.threadId);
    if (thread == null) {
      return null;
    }
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
    final baseMenuState = _ChatActionMenuViewData(
      otherUserId: thread.otherUser.id,
      otherUserNickname: thread.otherUser.nickname,
      isFriend: isFriend,
      isBlocked: isBlocked,
      canCall: canCall,
      canAddFriend: canAddFriend,
      items: const <_ChatActionMenuItemViewData>[],
    );
    return _ChatActionMenuViewData(
      otherUserId: baseMenuState.otherUserId,
      otherUserNickname: baseMenuState.otherUserNickname,
      isFriend: baseMenuState.isFriend,
      isBlocked: baseMenuState.isBlocked,
      canCall: baseMenuState.canCall,
      canAddFriend: baseMenuState.canAddFriend,
      items: _buildActionMenuItems(baseMenuState),
    );
  }

  _ChatUserProfileSheetViewData _selectUserProfileSheetViewData(
    ChatProvider chatProvider,
    FriendProvider friendProvider,
    ChatThread fallbackThread,
  ) {
    final currentThread =
        chatProvider.getThread(fallbackThread.id) ?? fallbackThread;
    final user = currentThread.otherUser;
    final isFriend = friendProvider.isFriend(user.id);
    final isBlocked = friendProvider.isBlocked(user.id);
    final canOpenFullProfile = FeaturePolicy.canOpenProfile(currentThread);
    final canShowPublicUid = canOpenFullProfile && isFriend;
    final canFollow = FeaturePolicy.canMutualFollow(
      thread: currentThread,
      isFriend: isFriend,
      isBlocked: isBlocked,
    );

    return _ChatUserProfileSheetViewData(
      thread: currentThread,
      user: user,
      avatarText: user.avatar ?? '🙂',
      displayName: user.nickname,
      statusText: user.status,
      isFriend: isFriend,
      isBlocked: isBlocked,
      canOpenFullProfile: canOpenFullProfile,
      canShowPublicUid: canShowPublicUid,
      canFollow: canFollow,
      pointsToUnlock: FeaturePolicy.profilePointsRemaining(currentThread),
      minutesToUnlock: FeaturePolicy.profileMinutesRemaining(currentThread),
    );
  }

  List<_ChatActionMenuItemViewData> _buildActionMenuItems(
    _ChatActionMenuViewData menuState,
  ) {
    final items = <_ChatActionMenuItemViewData>[
      const _ChatActionMenuItemViewData(
        key: Key('chat-action-menu-profile'),
        value: 'profile',
        icon: Icons.person_outline,
        label: '个人主页',
      ),
      _ChatActionMenuItemViewData(
        key: const Key('chat-action-menu-call'),
        value: 'call',
        icon: Icons.phone_outlined,
        label: menuState.isBlocked
            ? '语音通话（需先解除拉黑）'
            : menuState.canCall
                ? '语音通话'
                : '语音通话（互动后解锁）',
      ),
      _ChatActionMenuItemViewData(
        key: const Key('chat-action-menu-add-friend'),
        value: 'add_friend',
        icon: Icons.person_add_outlined,
        label: menuState.isFriend
            ? '已互关'
            : menuState.canAddFriend
                ? '添加好友'
                : menuState.isBlocked
                    ? '已拉黑（需先解除）'
                    : '互关权限（互动后解锁）',
      ),
    ];

    if (menuState.isFriend) {
      items.addAll(const [
        _ChatActionMenuItemViewData(
          key: Key('chat-action-menu-remark'),
          value: 'remark',
          icon: Icons.edit_outlined,
          label: '设置备注',
        ),
        _ChatActionMenuItemViewData(
          key: Key('chat-action-menu-unfollow'),
          value: 'unfollow',
          icon: Icons.person_remove_outlined,
          label: '取关',
          isDanger: true,
        ),
      ]);
    }

    if (!menuState.isBlocked) {
      items.add(
        const _ChatActionMenuItemViewData(
          key: Key('chat-action-menu-block'),
          value: 'block',
          icon: Icons.block_outlined,
          label: '拉黑',
          isDanger: true,
        ),
      );
    }

    items.add(
      const _ChatActionMenuItemViewData(
        key: Key('chat-action-menu-report'),
        value: 'report',
        icon: Icons.flag_outlined,
        label: '举报',
        isDanger: true,
      ),
    );

    return List<_ChatActionMenuItemViewData>.unmodifiable(items);
  }

  int _buildMessageListPresentationKey(
    ChatThread? thread,
    List<_ChatMessageBubbleViewData> bubbles,
  ) {
    final threadKey = Object.hash(
      thread?.id,
      thread?.otherUser.id,
      thread?.otherUser.nickname,
      thread?.otherUser.avatar,
      thread?.otherUser.isOnline,
      thread?.isFriend,
      thread?.isUnfollowed,
      thread?.messagesSinceUnfollow,
      thread?.unreadCount,
      thread?.intimacyPoints,
      thread?.expiresAt.millisecondsSinceEpoch,
    );
    return Object.hash(
      threadKey,
      Object.hashAll(bubbles.map(_buildMessagePresentationKey)),
    );
  }

  int _buildMessagePresentationKey(_ChatMessageBubbleViewData bubble) {
    final message = bubble.message;
    return Object.hash(
      message.id,
      message.content,
      message.isMe,
      message.timestamp.millisecondsSinceEpoch,
      message.status,
      message.type,
      message.imagePath,
      message.isBurnAfterReading,
      message.isRead,
      message.imageQuality,
      bubble.canRecall,
      bubble.deliverySpec?.stateKey,
    );
  }

  bool _canRecallMessage(Message message) {
    return message.isMe &&
        message.status == MessageStatus.sent &&
        DateTime.now().difference(message.timestamp).inMinutes < 2;
  }

  int _buildOutgoingDeliveryFingerprint(List<Message> messages) {
    return Object.hashAll(
      messages.where((message) => message.isMe).map((message) {
        return Object.hash(
          message.id,
          message.status,
          message.isRead,
          message.type,
          message.imagePath,
          message.imageQuality,
        );
      }),
    );
  }

  int _buildCurrentThreadQuickSignal(
    ChatThread? thread,
    List<Message> messages,
  ) {
    final lastMessage = messages.isNotEmpty ? messages.last : null;
    return Object.hash(
      thread?.id,
      thread?.unreadCount,
      thread?.intimacyPoints,
      thread?.isUnfollowed,
      thread?.messagesSinceUnfollow,
      messages.length,
      lastMessage?.id,
      lastMessage?.status,
      lastMessage?.isRead,
      lastMessage?.type,
      lastMessage?.imageQuality,
      lastMessage?.imagePath,
      lastMessage?.content,
    );
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

  bool _shouldSurfaceOutgoingDeliveryFeedback(
    OutgoingDeliveryFeedback feedback,
  ) {
    // 成功态已经由我方消息气泡内联展示，避免再叠加 toast 打断操作。
    return feedback.isError;
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

  void _scheduleOutgoingDeliveryFeedback(OutgoingDeliveryFeedback feedback) {
    if (!_shouldSurfaceOutgoingDeliveryFeedback(feedback)) {
      return;
    }
    _pendingOutgoingDeliveryFeedback = feedback;
    if (_outgoingDeliveryFeedbackQueued) {
      return;
    }
    _outgoingDeliveryFeedbackQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _outgoingDeliveryFeedbackQueued = false;
      final pendingFeedback = _pendingOutgoingDeliveryFeedback;
      _pendingOutgoingDeliveryFeedback = null;
      if (!mounted || pendingFeedback == null) {
        return;
      }
      _showOutgoingDeliveryFeedback(pendingFeedback);
    });
  }

  void _scrollToBottom() {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final targetOffset = position.maxScrollExtent;
    final distanceToBottom = (targetOffset - position.pixels).abs();

    if (distanceToBottom <= 1) {
      return;
    }

    if (distanceToBottom <= _snapScrollToBottomDistance) {
      _scrollController.jumpTo(targetOffset);
      return;
    }

    _scrollController.animateTo(
      targetOffset,
      duration: Duration(
        milliseconds: distanceToBottom <= 320 ? 180 : 300,
      ),
      curve: Curves.easeOutCubic,
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
    final chatProvider = _chatProvider;
    if (chatProvider == null) {
      return;
    }

    final currentInteractionRevision =
        chatProvider.threadInteractionRevision(widget.threadId);
    final currentCanonicalThreadId =
        chatProvider.canonicalThreadId(widget.threadId);
    final thread = chatProvider.getThread(widget.threadId);
    final messages = chatProvider.getMessages(widget.threadId);
    final currentQuickSignal = _buildCurrentThreadQuickSignal(thread, messages);
    final currentOutgoingDeliveryRevision =
        chatProvider.threadOutgoingDeliveryRevision(widget.threadId);
    if (currentInteractionRevision == _lastObservedThreadInteractionRevision &&
        currentCanonicalThreadId == _lastObservedCanonicalThreadId &&
        currentQuickSignal == _lastObservedQuickSignal &&
        currentOutgoingDeliveryRevision ==
            _lastObservedOutgoingDeliveryRevision) {
      return;
    }
    final currentIntimacyPoints = thread?.intimacyPoints ?? 0;
    final currentMessageCount = messages.length;
    var didOutgoingDeliveryChange = currentOutgoingDeliveryRevision !=
        _lastObservedOutgoingDeliveryRevision;
    var currentOutgoingDeliveryFingerprint =
        _lastObservedOutgoingDeliveryFingerprint;
    if (didOutgoingDeliveryChange ||
        currentQuickSignal != _lastObservedQuickSignal ||
        currentMessageCount != _lastMessageCount) {
      currentOutgoingDeliveryFingerprint =
          _buildOutgoingDeliveryFingerprint(messages);
      if (!didOutgoingDeliveryChange) {
        didOutgoingDeliveryChange = currentOutgoingDeliveryFingerprint !=
            _lastObservedOutgoingDeliveryFingerprint;
      }
    }

    final hasMeaningfulCurrentThreadChange =
        currentInteractionRevision != _lastObservedThreadInteractionRevision ||
            currentCanonicalThreadId != _lastObservedCanonicalThreadId ||
            currentIntimacyPoints != _lastIntimacyPoints ||
            currentMessageCount != _lastMessageCount ||
            didOutgoingDeliveryChange;

    if (!hasMeaningfulCurrentThreadChange) {
      return;
    }

    _lastObservedThreadInteractionRevision = currentInteractionRevision;
    _lastObservedCanonicalThreadId = currentCanonicalThreadId;
    _lastObservedQuickSignal = currentQuickSignal;
    _lastObservedOutgoingDeliveryFingerprint =
        currentOutgoingDeliveryFingerprint;
    _lastObservedOutgoingDeliveryRevision = currentOutgoingDeliveryRevision;

    final deliveryFeedback = didOutgoingDeliveryChange
        ? _resolveOutgoingDeliveryFeedback(messages)
        : null;
    _scheduleCanonicalRouteSync();
    if (thread != null && thread.intimacyPoints != _lastIntimacyPoints) {
      final change = thread.intimacyPoints - _lastIntimacyPoints;
      _lastIntimacyPoints = thread.intimacyPoints;

      if (change > 0) {
        _intimacyHideTimer?.cancel();
        _intimacyAnimationToken += 1;
        final token = _intimacyAnimationToken;
        _intimacyChangeNotifier.value = _ChatIntimacyChangeState(
          change: change,
          token: token,
        );

        _intimacyHideTimer = Timer(const Duration(seconds: 2), () {
          if (!mounted || token != _intimacyAnimationToken) return;
          _intimacyChangeNotifier.value = null;
        });
      }
    }

    final messageCount = messages.length;
    if (messageCount != _lastMessageCount) {
      _lastMessageCount = messageCount;
      // 只要用户仍停留在当前会话页面，新增消息立刻按已读处理
      if ((thread?.unreadCount ?? 0) > 0) {
        chatProvider.markAsRead(widget.threadId);
      }
      _scheduleScrollToBottom();
    }
    if (deliveryFeedback != null) {
      _scheduleOutgoingDeliveryFeedback(deliveryFeedback);
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
      _replaceComposerText('');
      context.read<ChatProvider>().clearDraft(widget.threadId);
      return;
    }

    AppFeedback.showError(
      context,
      AppErrorCode.sendFailed,
      detail: '消息未发出，请重试。',
    );
  }

  Widget _buildEmptyConversationState(ChatThread? thread) {
    final title = thread == null ? '会话暂不可用' : '发一句开场白吧';
    final subtitle = thread == null
        ? '返回消息列表后再试。'
        : thread.otherUser.isOnline
            ? '对方在线，可以先打个招呼。'
            : '对方暂时不在线，也可以先留句话。';
    final suggestions = thread == null
        ? const <String>['返回上一页', '重新进入会话']
        : thread.otherUser.isOnline
            ? const <String>['嗨，刚好看到你', '你现在在忙什么', '想和你聊两句']
            : const <String>['先给你留个言', '等你看到时回我就好', '想认识一下你'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTight =
            constraints.maxWidth <= 340 || constraints.maxHeight <= 420;
        final horizontalPadding = isTight ? 16.0 : 28.0;
        final verticalPadding = isTight ? 12.0 : 20.0;
        final cardPadding = EdgeInsets.symmetric(
          horizontal: isTight ? 16 : 22,
          vertical: isTight ? 18 : 24,
        );
        final iconBoxSize = isTight ? 52.0 : 58.0;
        final iconRadius = isTight ? 16.0 : 18.0;
        final iconSize = isTight ? 24.0 : 28.0;
        final titleTopSpacing = isTight ? 12.0 : 16.0;
        final subtitleTopSpacing = isTight ? 6.0 : 8.0;
        final suggestionTopSpacing = isTight ? 12.0 : 16.0;
        final chipSpacing = isTight ? 6.0 : 8.0;
        final chipHorizontalPadding = isTight ? 10.0 : 12.0;
        final chipVerticalPadding = isTight ? 7.0 : 8.0;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - verticalPadding * 2).clamp(
                0,
                double.infinity,
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  width: double.infinity,
                  padding: cardPadding,
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
                        width: iconBoxSize,
                        height: iconBoxSize,
                        decoration: BoxDecoration(
                          color: AppColors.white08,
                          borderRadius: BorderRadius.circular(iconRadius),
                        ),
                        child: Icon(
                          thread?.otherUser.isOnline == true
                              ? Icons.waving_hand_rounded
                              : Icons.mark_chat_unread_outlined,
                          color: AppColors.textPrimary,
                          size: iconSize,
                        ),
                      ),
                      SizedBox(height: titleTopSpacing),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isTight ? 15.5 : 17,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: subtitleTopSpacing),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isTight ? 12 : 13,
                          fontWeight: FontWeight.w300,
                          color: AppColors.textTertiary.withValues(alpha: 0.9),
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: suggestionTopSpacing),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: chipSpacing,
                        runSpacing: chipSpacing,
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
                                  },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: chipHorizontalPadding,
                                vertical: chipVerticalPadding,
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
                                  fontSize: isTight ? 11.5 : 12,
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernComposerMetaRow({
    required bool hasThread,
    required String imageCapabilityLabel,
    required bool canSend,
    required bool canSendImage,
    required bool burnAfterReadEnabled,
    required _ChatComposerLayoutSpec layout,
  }) {
    final pills = <Widget>[];

    if (!canSend) {
      pills.add(
        _buildModernComposerPill(
          icon: Icons.lock_outline,
          label: '等待确认后继续发送',
          color: AppColors.error,
          compact: layout.isCompact,
        ),
      );
    } else if (!canSendImage) {
      pills.add(
        _buildModernComposerPill(
          icon: Icons.chat_bubble_outline_rounded,
          label: '文字可发送',
          color: AppColors.textSecondary,
          compact: layout.isCompact,
        ),
      );
      pills.add(
        _buildModernComposerPill(
          icon: Icons.image_not_supported_outlined,
          label: hasThread ? imageCapabilityLabel : '图片暂不可用',
          color: AppColors.textTertiary,
          compact: layout.isCompact,
        ),
      );
    }

    if (burnAfterReadEnabled) {
      pills.add(
        _buildModernComposerPill(
          icon: Icons.local_fire_department,
          label: '闪图已开启',
          color: AppColors.warning,
          compact: layout.isCompact,
        ),
      );
    }

    if (pills.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(bottom: layout.statusTopPadding),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          key: const Key('chat-composer-capability-row'),
          spacing: layout.chipSpacing,
          runSpacing: layout.chipRunSpacing,
          children: pills,
        ),
      ),
    );
  }

  Widget _buildModernComposerStatus({
    required bool canSend,
    required bool canSendImage,
    required String imageUnlockHint,
    required int inputLength,
    required bool burnAfterReadEnabled,
    required _ChatComposerLayoutSpec layout,
  }) {
    final hasDraft = inputLength > 0;
    final remaining = _messageMaxLength - inputLength;
    final shouldShowStatus = !canSend ||
        !canSendImage ||
        burnAfterReadEnabled ||
        hasDraft ||
        remaining <= 60;

    if (!shouldShowStatus) {
      return const SizedBox.shrink();
    }

    String text;
    IconData icon;
    Color accent;
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
      text = imageUnlockHint;
      icon = Icons.image_not_supported_outlined;
      accent = AppColors.textTertiary;
    } else if (burnAfterReadEnabled) {
      text = '闪图已开启，下一张图片会按阅后即焚发送。';
      icon = Icons.local_fire_department;
      accent = AppColors.warning;
    } else if (hasDraft) {
      text = '草稿已保留，发出后会自动清空。';
      icon = Icons.edit_note_outlined;
      accent = AppColors.brandBlue;
    } else {
      text = '剩余字数不多了，发出前可以再快速看一眼。';
      icon = Icons.tips_and_updates_outlined;
      accent = AppColors.textTertiary;
    }

    final counter = AnimatedContainer(
      duration: UiTokens.motionFast,
      padding: EdgeInsets.symmetric(
        horizontal: layout.isTight ? 7 : 8,
        vertical: layout.isTight ? 3 : 4,
      ),
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
          fontSize: layout.isTight ? 10 : 11,
          fontWeight: FontWeight.w400,
          color: counterAccent,
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(top: layout.statusTopPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: layout.isTight ? 13 : 14,
                color: accent.withValues(alpha: 0.9),
              ),
              SizedBox(width: layout.isTight ? 5 : 6),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: layout.isTight ? 10.5 : 11,
                    fontWeight: FontWeight.w300,
                    color: accent.withValues(alpha: 0.92),
                    height: 1.35,
                  ),
                  maxLines: layout.isTight ? 2 : null,
                  overflow: layout.isTight
                      ? TextOverflow.ellipsis
                      : TextOverflow.visible,
                ),
              ),
              if (!layout.isTight && (hasDraft || remaining <= 60)) ...[
                const SizedBox(width: 8),
                counter,
              ],
            ],
          ),
          if (layout.isTight && (hasDraft || remaining <= 60)) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: counter,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModernComposerPill({
    required IconData icon,
    required String label,
    required Color color,
    required bool compact,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 10,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: compact ? 11 : 12,
            color: color.withValues(alpha: 0.92),
          ),
          SizedBox(width: compact ? 4 : 5),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10.5 : 11,
              fontWeight: FontWeight.w400,
              color: color.withValues(alpha: 0.94),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationPermissionBanner() {
    final screenLayout = _ChatScreenLayoutSpec.fromSize(
      MediaQuery.of(context).size,
    );
    return Padding(
      padding: screenLayout.bannerPadding,
      child: NotificationPermissionNoticeCard(
        key: const Key('chat-notification-permission-banner'),
        description: NotificationPermissionGuidance.chatDescription,
        actionLabel: NotificationPermissionGuidance.openSettingsPageAction,
        compact: screenLayout.isCompact,
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
    final screenLayout = _ChatScreenLayoutSpec.fromSize(
      MediaQuery.of(context).size,
    );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.pureBlack,
        elevation: 0,
        toolbarHeight: screenLayout.toolbarHeight,
        leadingWidth: screenLayout.leadingWidth,
        titleSpacing: screenLayout.isTight ? 2 : 0,
        leading: IconButton(
          padding: EdgeInsets.zero,
          visualDensity: screenLayout.isTight
              ? VisualDensity.compact
              : VisualDensity.standard,
          constraints: BoxConstraints.tightFor(
            width: screenLayout.leadingWidth,
            height: screenLayout.toolbarHeight,
          ),
          icon: Icon(
            Icons.arrow_back,
            size: screenLayout.isTight ? 20 : 24,
            color: AppColors.textPrimary,
          ),
          onPressed: () => context.pop(),
        ),
        title:
            Selector2<ChatProvider, FriendProvider, _ChatHeaderSelectorState>(
          selector: (context, chatProvider, friendProvider) {
            final thread = chatProvider.getThread(widget.threadId);
            final userId = thread?.otherUser.id;
            return _ChatHeaderSelectorState(
              headerRevision:
                  chatProvider.threadHeaderRevision(widget.threadId),
              isFriend: userId != null && friendProvider.isFriend(userId),
            );
          },
          builder: (context, selection, child) {
            final headerData = _selectHeaderViewData(
              context.read<ChatProvider>(),
              isFriend: selection.isFriend,
            );
            if (headerData == null) {
              return const SizedBox();
            }

            return Row(
              children: [
                Container(
                  key: const Key('chat-header-avatar'),
                  width: screenLayout.headerAvatarSize,
                  height: screenLayout.headerAvatarSize,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.white08,
                  ),
                  child: AppUserAvatar(
                    avatar: headerData.avatarText,
                    textStyle: TextStyle(
                      fontSize: screenLayout.isCompact ? 16 : 18,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(width: screenLayout.headerGap),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        key: const Key('chat-header-title'),
                        headerData.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: screenLayout.headerTitleSize,
                          fontWeight: FontWeight.w300,
                          color: headerData.hasUnlockedNickname
                              ? AppColors.textPrimary
                              : AppColors.textTertiary,
                        ),
                      ),
                      if (screenLayout.showHeaderSubtitle) ...[
                        const SizedBox(height: 2),
                        Text(
                          headerData.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: screenLayout.headerSubtitleSize,
                            fontWeight: FontWeight.w300,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          // 更多菜单
          Selector2<ChatProvider, FriendProvider, _ChatActionMenuSelectorState>(
            selector: (context, chatProvider, friendProvider) {
              final thread = chatProvider.getThread(widget.threadId);
              final userId = thread?.otherUser.id;
              return _ChatActionMenuSelectorState(
                headerRevision: chatProvider.threadHeaderRevision(
                  widget.threadId,
                ),
                isFriend: userId != null && friendProvider.isFriend(userId),
                isBlocked: userId != null && friendProvider.isBlocked(userId),
              );
            },
            builder: (context, selection, child) {
              final menuState = _selectActionMenuViewData(
                context.read<ChatProvider>(),
                isFriend: selection.isFriend,
                isBlocked: selection.isBlocked,
              );
              if (menuState == null) return const SizedBox();

              return SizedBox.square(
                dimension: screenLayout.actionButtonExtent,
                child: PopupMenuButton<String>(
                  key: const Key('chat-action-menu-button'),
                  padding: EdgeInsets.zero,
                  splashRadius: screenLayout.actionButtonExtent / 2,
                  iconSize: screenLayout.isTight ? 20 : 24,
                  icon: const Icon(
                    Icons.more_horiz,
                    color: AppColors.textPrimary,
                  ),
                  color: AppColors.cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  offset: const Offset(0, 50),
                  onSelected: (value) =>
                      _handleActionMenuSelection(context, menuState, value),
                  itemBuilder: (context) => menuState.items
                      .map(
                        (item) => PopupMenuItem<String>(
                          key: item.key,
                          value: item.value,
                          child: _buildMenuItem(
                            item.icon,
                            item.label,
                            isDanger: item.isDanger,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Selector<SettingsProvider?, bool>(
            selector: (context, settingsProvider) {
              if (settingsProvider == null) {
                return false;
              }
              return NotificationPermissionGuidance.needsSystemPermission(
                notificationEnabled: settingsProvider.notificationEnabled,
                permissionGranted:
                    settingsProvider.pushRuntimeState.permissionGranted,
              );
            },
            builder: (context, showNotificationPermissionBanner, child) {
              if (!showNotificationPermissionBanner) {
                return const SizedBox.shrink();
              }
              return child!;
            },
            child: _buildNotificationPermissionBanner(),
          ),
          // 取关提示横幅
          Selector<ChatProvider, int>(
            selector: (context, chatProvider) =>
                chatProvider.threadHeaderRevision(widget.threadId),
            builder: (context, _, child) {
              final bannerState = _selectUnfollowBannerViewData(
                context.read<ChatProvider>(),
              );
              if (bannerState == null) {
                return const SizedBox();
              }

              final remainingMessages = bannerState.remainingMessages;
              final showRemindAction = bannerState.showRemindAction;
              final messageText = screenLayout.isCompact
                  ? (remainingMessages > 0
                      ? '对方已取关，还可发送$remainingMessages条'
                      : '等待确认后继续聊天')
                  : (remainingMessages > 0
                      ? '对方已取关，还可发送$remainingMessages条消息'
                      : '等待对方确认后可继续聊天');

              final remindAction = TextButton(
                key: const Key('chat-unfollow-banner-remind-action'),
                onPressed: () {
                  AppFeedback.showToast(
                    context,
                    AppToastCode.sent,
                    subject: '提醒',
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenLayout.isTight ? 4 : 8,
                    vertical: 3,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  '提醒',
                  style: TextStyle(
                    fontSize: screenLayout.isCompact ? 11.5 : 12,
                    color: AppColors.error.withValues(alpha: 0.88),
                  ),
                ),
              );

              return Padding(
                padding: screenLayout.unfollowPadding,
                child: Container(
                  key: const Key('chat-unfollow-banner'),
                  width: double.infinity,
                  padding: screenLayout.unfollowInnerPadding,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(UiTokens.radiusSm),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.22),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final shouldStackAction = showRemindAction &&
                          (screenLayout.isTight || constraints.maxWidth < 300);
                      final message = Text(
                        messageText,
                        style: TextStyle(
                          fontSize: screenLayout.isCompact ? 11.5 : 12,
                          fontWeight: FontWeight.w300,
                          color: AppColors.error.withValues(alpha: 0.88),
                        ),
                        maxLines: shouldStackAction ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                      );

                      if (shouldStackAction) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 15,
                                  color:
                                      AppColors.error.withValues(alpha: 0.78),
                                ),
                                const SizedBox(width: 7),
                                Expanded(child: message),
                              ],
                            ),
                            const SizedBox(height: 6),
                            remindAction,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 15,
                            color: AppColors.error.withValues(alpha: 0.78),
                          ),
                          const SizedBox(width: 7),
                          Expanded(child: message),
                          if (showRemindAction) remindAction,
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),

          // 消息列表
          Expanded(
            child: Stack(
              children: [
                RepaintBoundary(
                  child: Selector<ChatProvider, _ChatMessageListViewData>(
                    selector: (context, chatProvider) =>
                        _selectMessageListViewData(chatProvider),
                    builder: (context, messageListState, child) {
                      if (messageListState.bubbles.isEmpty) {
                        return _buildEmptyConversationState(
                          messageListState.thread,
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: screenLayout.messageListPadding,
                        itemCount: messageListState.bubbles.length,
                        itemBuilder: (context, index) {
                          return _MessageBubble(
                            viewData: messageListState.bubbles[index],
                            threadId: widget.threadId,
                          );
                        },
                      );
                    },
                  ),
                ),

                // 亲密度变化动画
                ValueListenableBuilder<_ChatIntimacyChangeState?>(
                  valueListenable: _intimacyChangeNotifier,
                  builder: (context, intimacyChange, child) {
                    if (intimacyChange == null) {
                      return const SizedBox.shrink();
                    }

                    return Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: SafeArea(
                          bottom: false,
                          child: Center(
                            child: IntimacyChangeAnimation(
                              key: ValueKey(intimacyChange.token),
                              change: intimacyChange.change,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // 输入区域
          Selector<ChatProvider, _ChatComposerViewData>(
            selector: (context, chatProvider) =>
                _selectComposerViewData(chatProvider),
            builder: (context, composerState, child) {
              final composerLayout =
                  _ChatComposerLayoutSpec.fromSize(MediaQuery.of(context).size);

              return RepaintBoundary(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _burnAfterReadEnabledNotifier,
                  builder: (context, burnAfterReadEnabled, child) {
                    return Container(
                      padding: composerLayout.outerPadding,
                      decoration: BoxDecoration(
                        color: AppColors.pureBlack,
                        border:
                            Border(top: BorderSide(color: AppColors.white05)),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Container(
                          key: const Key('chat-composer-shell'),
                          padding: composerLayout.innerPadding,
                          decoration: BoxDecoration(
                            color: AppColors.cardBg.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(
                              UiTokens.radiusLg,
                            ),
                            border: Border.all(color: AppColors.white08),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildModernComposerMetaRow(
                                hasThread: composerState.hasThread,
                                imageCapabilityLabel:
                                    composerState.imageCapabilityLabel,
                                canSend: composerState.canSend,
                                canSendImage: composerState.canSendImage,
                                burnAfterReadEnabled: burnAfterReadEnabled,
                                layout: composerLayout,
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _buildImageAction(
                                    canSend: composerState.canSend,
                                    canSendImage: composerState.canSendImage,
                                    imageUnlockHint:
                                        composerState.imageUnlockHint,
                                    flashImageUnlockHint:
                                        composerState.flashImageUnlockHint,
                                    burnAfterReadEnabled: burnAfterReadEnabled,
                                    layout: composerLayout,
                                  ),
                                  SizedBox(width: composerLayout.controlGap),
                                  Expanded(
                                    child: TextField(
                                      key: const Key('chat-composer-input'),
                                      controller: _inputController,
                                      maxLength: _messageMaxLength,
                                      minLines: 1,
                                      maxLines: composerLayout.maxInputLines,
                                      textInputAction: TextInputAction.send,
                                      enabled: composerState.canSend,
                                      onSubmitted: (_) => _sendCurrentMessage(
                                        composerState.canSend,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: composerState.canSend
                                            ? '输入你想说的话...'
                                            : '当前无法发送消息',
                                        counterText: '',
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: composerLayout
                                              .fieldHorizontalPadding,
                                          vertical: composerLayout
                                              .fieldVerticalPadding,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: composerLayout.controlGap),
                                  ValueListenableBuilder<TextEditingValue>(
                                    valueListenable: _inputController,
                                    builder: (context, inputValue, child) {
                                      final hasText =
                                          inputValue.text.trim().isNotEmpty;
                                      return Container(
                                        width: composerLayout.controlSize,
                                        height: composerLayout.controlSize,
                                        decoration: BoxDecoration(
                                          color:
                                              hasText && composerState.canSend
                                                  ? AppColors.textPrimary
                                                  : AppColors.white05,
                                          borderRadius: BorderRadius.circular(
                                            UiTokens.radiusSm,
                                          ),
                                          border: Border.all(
                                            color: AppColors.white08,
                                          ),
                                        ),
                                        child: IconButton(
                                          key: const Key(
                                            'chat-composer-send-button',
                                          ),
                                          icon: Icon(
                                            Icons.arrow_upward,
                                            size: composerLayout.isTight
                                                ? 18
                                                : 20,
                                            color:
                                                hasText && composerState.canSend
                                                    ? AppColors.pureBlack
                                                    : AppColors.textDisabled,
                                          ),
                                          onPressed:
                                              !hasText || !composerState.canSend
                                                  ? null
                                                  : () => _sendCurrentMessage(
                                                        composerState.canSend,
                                                      ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _inputController,
                                builder: (context, inputValue, child) {
                                  return _buildModernComposerStatus(
                                    canSend: composerState.canSend,
                                    canSendImage: composerState.canSendImage,
                                    imageUnlockHint:
                                        composerState.imageUnlockHint,
                                    inputLength:
                                        inputValue.text.characters.length,
                                    burnAfterReadEnabled: burnAfterReadEnabled,
                                    layout: composerLayout,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
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
    final burnAfterReadEnabled = _burnAfterReadEnabledNotifier.value;
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

    if (burnAfterReadEnabled) {
      _burnAfterReadEnabledNotifier.value = false;
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
                ? '会话已过期，请返回列表重试'
                : '会话不可用，请返回列表重试';
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
    required String imageUnlockHint,
    required String flashImageUnlockHint,
    required bool burnAfterReadEnabled,
    required _ChatComposerLayoutSpec layout,
  }) {
    final canUseImage = canSend && canSendImage;
    final lockBadgeSize = layout.isTight ? 12.0 : 14.0;
    final burnToggleSize = layout.isTight ? 20.0 : 22.0;
    return SizedBox(
      width: layout.controlSize + 2,
      height: layout.controlSize + 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: UiTokens.motionNormal,
            curve: Curves.easeOutCubic,
            width: layout.controlSize,
            height: layout.controlSize,
            decoration: BoxDecoration(
              color: canUseImage
                  ? (burnAfterReadEnabled
                      ? AppColors.warning.withValues(alpha: 0.18)
                      : AppColors.white08)
                  : AppColors.white05,
              borderRadius: BorderRadius.circular(UiTokens.radiusSm),
              border: Border.all(
                color: burnAfterReadEnabled
                    ? AppColors.warning.withValues(alpha: 0.5)
                    : AppColors.white08,
              ),
              boxShadow: burnAfterReadEnabled
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
                    ? (burnAfterReadEnabled
                        ? AppColors.warning
                        : AppColors.textSecondary)
                    : AppColors.textDisabled,
                size: layout.isTight ? 18 : 20,
              ),
              onPressed: canSend
                  ? () {
                      if (!canSendImage) {
                        AppFeedback.showError(
                          context,
                          AppErrorCode.unlockRequired,
                          detail: imageUnlockHint,
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
              right: layout.isTight ? 7 : 9,
              top: layout.isTight ? 7 : 9,
              child: Container(
                width: lockBadgeSize,
                height: lockBadgeSize,
                decoration: BoxDecoration(
                  color: AppColors.pureBlack.withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(lockBadgeSize / 2),
                  border: Border.all(color: AppColors.white12),
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: layout.isTight ? 8 : 9,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(UiTokens.radiusSm),
              onTap: canSend
                  ? () {
                      if (!canSendImage) {
                        AppFeedback.showError(
                          context,
                          AppErrorCode.unlockRequired,
                          detail: flashImageUnlockHint,
                        );
                        return;
                      }
                      HapticFeedback.selectionClick();
                      _burnAfterReadEnabledNotifier.value =
                          !burnAfterReadEnabled;
                    }
                  : null,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: 1,
                  end: burnAfterReadEnabled ? 1.08 : 1,
                ),
                duration: UiTokens.motionNormal,
                curve: Curves.easeOutBack,
                builder: (context, scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: Container(
                  width: burnToggleSize,
                  height: burnToggleSize,
                  decoration: BoxDecoration(
                    color: burnAfterReadEnabled
                        ? AppColors.warning.withValues(alpha: 0.2)
                        : (canSendImage ? AppColors.cardBg : AppColors.white05),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: burnAfterReadEnabled
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
                    size: layout.isTight ? 12 : 13,
                    color: burnAfterReadEnabled
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
      ),
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
    return '轻聊中 · 距离解锁$nextUnlock还差$pointsToNext点';
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

  void _handleActionMenuSelection(
    BuildContext context,
    _ChatActionMenuViewData menuState,
    String value,
  ) {
    final thread = context.read<ChatProvider>().getThread(widget.threadId);
    if (thread == null) {
      return;
    }

    switch (value) {
      case 'call':
        if (menuState.isBlocked) {
          AppFeedback.showError(context, AppErrorCode.blocked);
          return;
        }
        if (menuState.canCall) {
          _handleVoiceCall(context, thread.otherUser);
          return;
        }
        AppFeedback.showError(
          context,
          AppErrorCode.unlockRequired,
          detail: FeaturePolicy.stageTwoUnlockHint(thread, '语音通话'),
        );
        return;
      case 'add_friend':
        if (menuState.isFriend) {
          AppFeedback.showToast(
            context,
            AppToastCode.enabled,
            subject: '互关',
          );
          return;
        }
        if (menuState.isBlocked) {
          AppFeedback.showError(context, AppErrorCode.blocked);
          return;
        }
        if (menuState.canAddFriend) {
          _showAddFriendDialog(context, thread.otherUser);
          return;
        }
        AppFeedback.showError(
          context,
          AppErrorCode.unlockRequired,
          detail: FeaturePolicy.stageTwoUnlockHint(thread, '互关'),
        );
        return;
      case 'profile':
        _showUserProfile(context, thread);
        return;
      case 'remark':
        _showSetRemarkDialog(context, menuState.otherUserId);
        return;
      case 'unfollow':
        _showUnfollowDialog(context, thread);
        return;
      case 'block':
        _showBlockDialog(context, thread);
        return;
      case 'report':
        context.push(
          '/report/user/${menuState.otherUserId}?name=${Uri.encodeComponent(menuState.otherUserNickname)}',
        );
        return;
    }
  }

  void _handleVoiceCall(BuildContext context, User user) async {
    final confirm = await AppDialog.showConfirm(
      context,
      title: '发起语音通话',
      content: '对方接听后将开始计时，通话时长不影响聊天倒计时。',
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
      content: '取关后对方只能再发3条消息，需要你确认后才能继续聊天。',
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
      builder: (sheetContext) => Selector2<ChatProvider, FriendProvider,
          _ChatUserProfileSheetViewData>(
        selector: (context, chatProvider, friendProvider) =>
            _selectUserProfileSheetViewData(
          chatProvider,
          friendProvider,
          thread,
        ),
        builder: (sheetContext, viewData, child) {
          final currentThread = viewData.thread;
          final user = viewData.user;
          final isFriend = viewData.isFriend;
          final isBlocked = viewData.isBlocked;
          final canOpenFullProfile = viewData.canOpenFullProfile;
          final canShowPublicUid = viewData.canShowPublicUid;
          final canFollow = viewData.canFollow;
          final pointsToUnlock = viewData.pointsToUnlock;
          final minutesToUnlock = viewData.minutesToUnlock;

          return Container(
            key: const Key('chat-user-profile-sheet'),
            height: MediaQuery.of(sheetContext).size.height * 0.88,
            decoration: AppDialog.sheetDecoration(color: AppColors.pureBlack),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                              viewData.canOpenFullProfile
                                  ? AppColors.white12
                                  : AppColors.white08,
                              AppColors.white05,
                            ],
                          ),
                        ),
                        alignment: Alignment.bottomCenter,
                        padding: const EdgeInsets.only(bottom: 22),
                        child: Container(
                          key: Key('chat-user-profile-avatar-${user.id}'),
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.white08,
                            border: Border.all(
                                color: AppColors.pureBlack, width: 3),
                          ),
                          child: AppUserAvatar(
                            avatar: user.avatar,
                            textStyle: const TextStyle(fontSize: 42),
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
                          canShowPublicUid
                              ? 'UID ${user.uid}'
                              : 'UID在主页解锁并互关后可见',
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
                          '继续互动后可查看完整主页\n还差$pointsToUnlock点${minutesToUnlock > 0 ? '，至少再等$minutesToUnlock分钟' : ''}',
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
                    Container(
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
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        key: const Key('chat-user-profile-primary-action'),
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
                          foregroundColor:
                              canFollow || (!isFriend && !isBlocked)
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
  late final ValueNotifier<int> _elapsedSecondsNotifier;
  late final ValueNotifier<bool> _isMutedNotifier;
  late final ValueNotifier<bool> _isSpeakerOnNotifier;
  Timer? _elapsedTimer;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _elapsedSecondsNotifier = ValueNotifier<int>(0);
    _isMutedNotifier = ValueNotifier<bool>(false);
    _isSpeakerOnNotifier = ValueNotifier<bool>(true);
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSecondsNotifier.value =
          DateTime.now().difference(_startTime).inSeconds;
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _elapsedSecondsNotifier.dispose();
    _isMutedNotifier.dispose();
    _isSpeakerOnNotifier.dispose();
    super.dispose();
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
              key: Key('voice-call-avatar-${widget.user.id}'),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.white08,
                border: Border.all(color: AppColors.white12, width: 1),
              ),
              child: AppUserAvatar(
                avatar: widget.user.avatar,
                textStyle: const TextStyle(fontSize: 34),
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
            ValueListenableBuilder<int>(
              valueListenable: _elapsedSecondsNotifier,
              builder: (context, elapsedSeconds, child) {
                final minutes =
                    (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
                final seconds =
                    (elapsedSeconds % 60).toString().padLeft(2, '0');
                return Text(
                  key: const Key('voice-call-duration-label'),
                  '通话中 $minutes:$seconds',
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
                ValueListenableBuilder<bool>(
                  valueListenable: _isMutedNotifier,
                  builder: (context, isMuted, child) {
                    return _buildCallAction(
                      buttonKey: const Key('voice-call-mute-action'),
                      icon: isMuted ? Icons.mic_off : Icons.mic_none,
                      label: isMuted ? '已静音' : '静音',
                      onTap: () => _isMutedNotifier.value = !isMuted,
                    );
                  },
                ),
                const SizedBox(width: 16),
                ValueListenableBuilder<bool>(
                  valueListenable: _isSpeakerOnNotifier,
                  builder: (context, isSpeakerOn, child) {
                    return _buildCallAction(
                      buttonKey: const Key('voice-call-speaker-action'),
                      icon: isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                      label: isSpeakerOn ? '扬声器' : '听筒',
                      onTap: () => _isSpeakerOnNotifier.value = !isSpeakerOn,
                    );
                  },
                ),
                const SizedBox(width: 16),
                _buildCallAction(
                  buttonKey: const Key('voice-call-end-action'),
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
    Key? buttonKey,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return InkWell(
      key: buttonKey,
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
  final _ChatMessageBubbleViewData viewData;
  final String threadId;

  const _MessageBubble({
    required this.viewData,
    required this.threadId,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _burnOverlayEntry;
  bool _burnPreviewActive = false;
  bool _consumingBurn = false;
  bool get _showLegacyDeliveryFallback => false;
  late final AnimationController _entryController;
  late final Animation<double> _entryOpacity;

  Message get message => widget.viewData.message;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _entryOpacity = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _burnOverlayEntry?.remove();
    _burnOverlayEntry = null;
    _burnPreviewActive = false;
    ScreenshotGuard.setSecure(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canRecall = widget.viewData.canRecall;
    final isImage = message.type == MessageType.image;
    final isBurnImage = isImage && message.isBurnAfterReading;
    final deliverySpec = widget.viewData.deliverySpec;

    return FadeTransition(
      opacity: _entryOpacity,
      child: Align(
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
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
              onLongPress:
                  isBurnImage || message.status == MessageStatus.sending
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
                                detail: '图片暂不支持复制',
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
                                  detail: '消息只能在发送后2分钟内撤回。',
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
                  maxWidth: MediaQuery.of(context).size.width *
                      (isImage ? 0.64 : 0.7),
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
      ),
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
          deliveryRetryErrorCodeFor(failureState),
          detail: deliveryRetryErrorDetailFor(
            failureState,
            isImage: isImage,
          ),
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
        title = '图片太大';
        description = '图片超过大小限制';
        primaryTip = (
          icon: Icons.compress_outlined,
          title: '先压缩再发送',
          detail: '压缩后更容易发送',
        );
        secondaryTip = (
          icon: Icons.crop_outlined,
          title: '裁剪后再发送',
          detail: '裁掉一部分再试',
        );
        break;
      case ChatDeliveryFailureState.imageUploadUnsupportedFormat:
        title = '图片格式不支持';
        description = '当前图片格式不支持';
        primaryTip = (
          icon: Icons.photo_library_outlined,
          title: '换 JPG/PNG',
          detail: '优先选 JPG、PNG',
        );
        secondaryTip = (
          icon: Icons.auto_fix_high_outlined,
          title: '重新保存后再发',
          detail: '重新保存或截图后再试',
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
        title = '图片需要重选';
        description = '原图已不可用';
        primaryTip = (
          icon: Icons.photo_library_outlined,
          title: '重新选图',
          detail: '选好后再发送',
        );
        secondaryTip = (
          icon: Icons.compress_outlined,
          title: '先发压缩图',
          detail: '弱网下更容易发出',
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
      builder: (sheetContext) {
        final sheetSize = MediaQuery.of(sheetContext).size;
        final isTight = sheetSize.width <= 340 || sheetSize.height <= 620;
        final horizontalPadding = isTight ? 16.0 : 20.0;
        final topPadding = isTight ? 16.0 : 20.0;
        final bottomPadding = isTight ? 18.0 : 24.0;
        final titleSize = isTight ? 16.0 : 18.0;
        final descriptionSize = isTight ? 12.0 : 13.0;
        final tipSpacing = isTight ? 10.0 : 12.0;
        final contentSpacing = isTight ? 14.0 : 16.0;
        return Container(
          key: const Key('chat-image-failure-guide-sheet'),
          constraints: BoxConstraints(
            maxHeight: sheetSize.height * (isTight ? 0.82 : 0.78),
          ),
          decoration: AppDialog.sheetDecoration(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            topPadding,
            horizontalPadding,
            bottomPadding,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
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
                      fontSize: descriptionSize,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textTertiary.withValues(alpha: 0.92),
                      height: 1.45,
                    ),
                  ),
                  SizedBox(height: contentSpacing),
                  _buildGuideTip(
                    icon: primaryTip.icon,
                    title: primaryTip.title,
                    detail: primaryTip.detail,
                    compact: isTight,
                  ),
                  SizedBox(height: tipSpacing),
                  _buildGuideTip(
                    icon: secondaryTip.icon,
                    title: secondaryTip.title,
                    detail: secondaryTip.detail,
                    compact: isTight,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGuideTip({
    required IconData icon,
    required String title,
    required String detail,
    bool compact = false,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
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
                  style: TextStyle(
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: compact ? 3 : 4),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: compact ? 11.5 : 12,
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
  late final ValueNotifier<int> _secondsLeftNotifier;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsLeftNotifier = ValueNotifier<int>(_burnSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final nextSeconds = _secondsLeftNotifier.value - 1;
      if (nextSeconds <= 0) {
        timer.cancel();
        widget.onTimeout();
        return;
      }
      _secondsLeftNotifier.value = nextSeconds;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _secondsLeftNotifier.dispose();
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
              child: ValueListenableBuilder<int>(
                valueListenable: _secondsLeftNotifier,
                builder: (context, secondsLeft, child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.pureBlack.withValues(alpha: 0.44),
                      borderRadius: BorderRadius.circular(UiTokens.radiusSm),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      key: const Key('burn-preview-countdown-label'),
                      '长按查看中 · $secondsLeft 秒后销毁',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
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
  late final ValueNotifier<int> _secondsLeftNotifier;
  Timer? _burnTimer;

  @override
  void initState() {
    super.initState();
    _secondsLeftNotifier = ValueNotifier<int>(_burnSeconds);
    if (widget.isBurnAfterReading) {
      _startBurnCountdown();
    }
  }

  @override
  void dispose() {
    _burnTimer?.cancel();
    _secondsLeftNotifier.dispose();
    super.dispose();
  }

  void _startBurnCountdown() {
    _burnTimer?.cancel();
    _burnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !widget.isBurnAfterReading) {
        timer.cancel();
        return;
      }

      final nextSeconds = _secondsLeftNotifier.value - 1;
      if (nextSeconds <= 0) {
        timer.cancel();
        Navigator.pop(context);
        return;
      }

      _secondsLeftNotifier.value = nextSeconds;
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
                  child: ValueListenableBuilder<int>(
                    valueListenable: _secondsLeftNotifier,
                    builder: (context, secondsLeft, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.pureBlack.withValues(alpha: 0.42),
                          borderRadius:
                              BorderRadius.circular(UiTokens.radiusSm),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          key: const Key(
                            'image-preview-burn-countdown-label',
                          ),
                          '闪图剩余 $secondsLeft 秒',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
