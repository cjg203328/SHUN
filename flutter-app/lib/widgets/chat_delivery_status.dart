import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/models.dart';

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
      ].whereType<String>().join('|');
}

ChatDeliveryStatusSpec? resolveChatDeliveryStatus(Message message) {
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
    final needsReselect =
        isImage && message.imageQuality == ImageQuality.original;
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
          ? '原图失效，请重新选择图片'
          : (isImage ? '点击重试后重新投递图片' : '点击重试后继续发送'),
      cardColor: AppColors.error,
      cardIcon:
          needsReselect ? Icons.photo_library_outlined : Icons.error_outline,
      actionLabel: needsReselect ? '查看说明' : '立即重试',
      actionType: needsReselect
          ? ChatDeliveryAction.showGuide
          : ChatDeliveryAction.retry,
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
                  blurRadius: 12,
                  spreadRadius: 0.4,
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
      transitionBuilder: (child, animation) {
        final scale = Tween<double>(begin: 0.94, end: 1).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
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

  @override
  Widget build(BuildContext context) {
    if (!spec.hasCard) {
      return const SizedBox.shrink();
    }

    final color = spec.cardColor!;
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
                  blurRadius: 16,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
      child: Row(
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
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  spec.cardDetail!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w300,
                    color: color.withValues(alpha: 0.88),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          if (spec.actionLabel != null && onActionTap != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
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
            ),
          ],
        ],
      ),
    );

    if (!animated) {
      return child;
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final scale = Tween<double>(begin: 0.96, end: 1).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
      child: child,
    );
  }
}
