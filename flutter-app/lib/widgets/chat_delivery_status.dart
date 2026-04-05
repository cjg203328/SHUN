import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/models.dart';
import '../utils/chat_delivery_state.dart';

enum ChatDeliveryAction {
  retry,
  showGuide,
}

class ChatDeliveryStatusSpec {
  const ChatDeliveryStatusSpec({
    this.previewText,
    this.previewColor,
    this.badgeLabel,
    this.badgeColor,
    this.badgeIcon,
    this.cardLabel,
    this.cardDetail,
    this.cardColor,
    this.cardIcon,
    this.actionLabel,
    this.actionType,
    this.guideFailureState,
  });

  final String? previewText;
  final Color? previewColor;
  final String? badgeLabel;
  final Color? badgeColor;
  final IconData? badgeIcon;
  final String? cardLabel;
  final String? cardDetail;
  final Color? cardColor;
  final IconData? cardIcon;
  final String? actionLabel;
  final ChatDeliveryAction? actionType;
  final ChatDeliveryFailureState? guideFailureState;

  bool get hasBadge =>
      badgeLabel != null && badgeColor != null && badgeIcon != null;

  bool get hasCard =>
      cardLabel != null &&
      cardDetail != null &&
      cardColor != null &&
      cardIcon != null;

  bool get isSuccessState => badgeLabel == '已送达' || badgeLabel == '已读';

  String get stateKey => [
        previewText,
        badgeLabel,
        cardLabel,
        actionLabel,
        guideFailureState?.name,
      ].whereType<String>().join('|');
}

ChatDeliveryStatusSpec? resolveChatDeliveryStatus(
  Message message, {
  ChatDeliveryFailureState failureState = ChatDeliveryFailureState.retryable,
}) {
  if (!message.isMe) {
    return null;
  }

  final isImage = message.type == MessageType.image;
  if (message.status == MessageStatus.sending) {
    return ChatDeliveryStatusSpec(
      previewText: isImage ? '图片发送中' : '发送中：${message.content}',
      previewColor: AppColors.textSecondary,
      badgeLabel: '发送中',
      badgeColor: AppColors.brandBlue,
      badgeIcon: Icons.schedule_rounded,
      cardLabel: '发送中',
      cardDetail: '正在投递给对方',
      cardColor: AppColors.brandBlue,
      cardIcon: Icons.schedule_rounded,
    );
  }

  if (message.status == MessageStatus.failed) {
    if (failureState == ChatDeliveryFailureState.threadExpired) {
      return ChatDeliveryStatusSpec(
        previewText: '会话已过期，暂不可重试',
        previewColor: AppColors.warning.withValues(alpha: 0.92),
        badgeLabel: '会话已过期',
        badgeColor: AppColors.warning,
        badgeIcon: Icons.hourglass_disabled_outlined,
        cardLabel: '会话已过期',
        cardDetail: '会话已过期，请返回列表重试',
        cardColor: AppColors.warning,
        cardIcon: Icons.hourglass_disabled_outlined,
      );
    }

    if (failureState == ChatDeliveryFailureState.blockedRelation) {
      return ChatDeliveryStatusSpec(
        previewText: '关系受限，暂不能发送',
        previewColor: AppColors.warning.withValues(alpha: 0.92),
        badgeLabel: '关系受限',
        badgeColor: AppColors.warning,
        badgeIcon: Icons.block_outlined,
        cardLabel: '关系受限',
        cardDetail: '当前关系受限，暂不能发送',
        cardColor: AppColors.warning,
        cardIcon: Icons.block_outlined,
      );
    }

    if (failureState == ChatDeliveryFailureState.imageUploadPreparationFailed) {
      return ChatDeliveryStatusSpec(
        previewText: '准备失败，可重试',
        previewColor: AppColors.warning.withValues(alpha: 0.92),
        badgeLabel: '上传准备失败',
        badgeColor: AppColors.warning,
        badgeIcon: Icons.cloud_off_rounded,
        cardLabel: '上传准备失败',
        cardDetail: '图片准备失败，请重试',
        cardColor: AppColors.warning,
        cardIcon: Icons.cloud_off_rounded,
        actionLabel: '立即重试',
        actionType: ChatDeliveryAction.retry,
      );
    }

    if (failureState == ChatDeliveryFailureState.imageUploadInterrupted) {
      return ChatDeliveryStatusSpec(
        previewText: '上传中断，可重试',
        previewColor: AppColors.warning.withValues(alpha: 0.92),
        badgeLabel: '上传中断',
        badgeColor: AppColors.warning,
        badgeIcon: Icons.upload_file_rounded,
        cardLabel: '上传中断',
        cardDetail: '网络中断，请重试',
        cardColor: AppColors.warning,
        cardIcon: Icons.upload_file_rounded,
        actionLabel: '立即重试',
        actionType: ChatDeliveryAction.retry,
      );
    }

    if (failureState == ChatDeliveryFailureState.imageUploadTokenInvalid) {
      return ChatDeliveryStatusSpec(
        previewText: '凭证失效，可重试',
        previewColor: AppColors.warning.withValues(alpha: 0.92),
        badgeLabel: '上传凭证失效',
        badgeColor: AppColors.warning,
        badgeIcon: Icons.vpn_key_off_rounded,
        cardLabel: '上传凭证失效',
        cardDetail: '上传凭证失效，请重试',
        cardColor: AppColors.warning,
        cardIcon: Icons.vpn_key_off_rounded,
        actionLabel: '立即重试',
        actionType: ChatDeliveryAction.retry,
      );
    }

    if (failureState == ChatDeliveryFailureState.imageUploadFileTooLarge) {
      return const ChatDeliveryStatusSpec(
        previewText: '图片过大，需重选',
        previewColor: AppColors.warning,
        badgeLabel: '图片过大',
        badgeColor: AppColors.warning,
        badgeIcon: Icons.photo_size_select_large_rounded,
        cardLabel: '图片过大',
        cardDetail: '图片超过大小限制，请换一张再发。',
        cardColor: AppColors.warning,
        cardIcon: Icons.photo_size_select_large_rounded,
        actionLabel: '查看说明',
        actionType: ChatDeliveryAction.showGuide,
        guideFailureState: ChatDeliveryFailureState.imageUploadFileTooLarge,
      );
    }

    if (failureState == ChatDeliveryFailureState.imageUploadUnsupportedFormat) {
      return const ChatDeliveryStatusSpec(
        previewText: '格式异常，需重选',
        previewColor: AppColors.warning,
        badgeLabel: '格式异常',
        badgeColor: AppColors.warning,
        badgeIcon: Icons.broken_image_outlined,
        cardLabel: '格式异常',
        cardDetail: '图片校验未通过，请换常见格式。',
        cardColor: AppColors.warning,
        cardIcon: Icons.broken_image_outlined,
        actionLabel: '查看说明',
        actionType: ChatDeliveryAction.showGuide,
        guideFailureState:
            ChatDeliveryFailureState.imageUploadUnsupportedFormat,
      );
    }

    if (failureState == ChatDeliveryFailureState.networkIssue) {
      return ChatDeliveryStatusSpec(
        previewText: '网络异常，可重试',
        previewColor: AppColors.warning.withValues(alpha: 0.92),
        badgeLabel: '网络波动',
        badgeColor: AppColors.warning,
        badgeIcon: Icons.wifi_off_rounded,
        cardLabel: '网络波动',
        cardDetail: '网络异常，请重试',
        cardColor: AppColors.warning,
        cardIcon: Icons.wifi_off_rounded,
        actionLabel: '立即重试',
        actionType: ChatDeliveryAction.retry,
      );
    }

    if (failureState == ChatDeliveryFailureState.retryUnavailable) {
      return ChatDeliveryStatusSpec(
        previewText: '当前不可重试',
        previewColor: AppColors.warning.withValues(alpha: 0.92),
        badgeLabel: '暂不可重试',
        badgeColor: AppColors.warning,
        badgeIcon: Icons.block_outlined,
        cardLabel: '暂不可重试',
        cardDetail: '当前不可重试，请确认会话状态',
        cardColor: AppColors.warning,
        cardIcon: Icons.block_outlined,
      );
    }

    final needsReselect =
        failureState == ChatDeliveryFailureState.imageReselectRequired ||
            (failureState == ChatDeliveryFailureState.retryable &&
                isImage &&
                failedImageNeedsReselect(message));
    return ChatDeliveryStatusSpec(
      previewText: needsReselect
          ? '原图失效，请重选图片'
          : (isImage ? '图片发送失败，可立即重试' : '发送失败，可立即重试'),
      previewColor: AppColors.error.withValues(alpha: 0.92),
      badgeLabel: needsReselect ? '重选图片' : '发送失败',
      badgeColor: AppColors.error,
      badgeIcon:
          needsReselect ? Icons.photo_library_outlined : Icons.error_outline,
      cardLabel: needsReselect ? '重选图片' : '发送失败',
      cardDetail: needsReselect
          ? '原图失效，请重选图片'
          : (isImage ? '点击重试后重新发送图片' : '点击重试后继续发送'),
      cardColor: AppColors.error,
      cardIcon:
          needsReselect ? Icons.photo_library_outlined : Icons.error_outline,
      actionLabel: needsReselect ? '查看说明' : '立即重试',
      actionType: needsReselect
          ? ChatDeliveryAction.showGuide
          : ChatDeliveryAction.retry,
      guideFailureState:
          needsReselect ? ChatDeliveryFailureState.imageReselectRequired : null,
    );
  }

  if (message.status == MessageStatus.sent && !message.isBurnAfterReading) {
    final color = message.isRead
        ? AppColors.textTertiary.withValues(alpha: 0.82)
        : AppColors.textSecondary.withValues(alpha: 0.88);
    return ChatDeliveryStatusSpec(
      badgeLabel: message.isRead ? '已读' : '已送达',
      badgeColor: color,
      badgeIcon: message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
      cardLabel: message.isRead ? '已读' : '已送达',
      cardDetail: message.isRead ? '对方已经查看这条消息' : '消息已到达对方设备',
      cardColor: color,
      cardIcon: message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
    );
  }

  return null;
}

class ChatDeliveryBadge extends StatelessWidget {
  const ChatDeliveryBadge({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    this.animated = true,
    this.emphasized = false,
  });

  final String label;
  final Color color;
  final IconData icon;
  final bool animated;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      key: ValueKey<String>('badge:$label:$icon:$emphasized'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: emphasized ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: emphasized
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.12),
                  blurRadius: 8,
                  spreadRadius: 0.2,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );

    if (!animated) {
      return child;
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: child,
    );
  }
}

class ChatDeliveryStatusCard extends StatelessWidget {
  const ChatDeliveryStatusCard({
    super.key,
    required this.spec,
    this.onActionTap,
    this.animated = true,
  });

  final ChatDeliveryStatusSpec spec;
  final VoidCallback? onActionTap;
  final bool animated;

  Widget _buildActionChip(Color color) {
    return GestureDetector(
      key: ValueKey<String>(
        'chat-delivery-status-action:${spec.actionType?.name ?? spec.actionLabel}',
      ),
      onTap: onActionTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          spec.actionLabel!,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!spec.hasCard) {
      return const SizedBox.shrink();
    }

    final color = spec.cardColor!;
    final hasAction = spec.actionLabel != null && onActionTap != null;
    final child = Container(
      key: ValueKey<String>('card:${spec.stateKey}'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: spec.isSuccessState ? 0.15 : 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: spec.isSuccessState
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 10,
                  spreadRadius: 0.2,
                ),
              ]
            : null,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useStackedAction = hasAction && constraints.maxWidth <= 240;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(spec.cardIcon!, size: 13, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      spec.cardLabel!,
                      key: ValueKey<String>(
                        'chat-delivery-status-label:${spec.stateKey}',
                      ),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      spec.cardDetail!,
                      key: ValueKey<String>(
                        'chat-delivery-status-detail:${spec.stateKey}',
                      ),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w300,
                        color: color.withValues(alpha: 0.88),
                        height: 1.25,
                      ),
                    ),
                    if (useStackedAction) ...[
                      const SizedBox(height: 8),
                      _buildActionChip(color),
                    ],
                  ],
                ),
              ),
              if (hasAction && !useStackedAction) ...[
                const SizedBox(width: 8),
                _buildActionChip(color),
              ],
            ],
          );
        },
      ),
    );

    if (!animated) {
      return child;
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: child,
    );
  }
}
