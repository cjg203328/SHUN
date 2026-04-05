import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../utils/notification_permission_guidance.dart';

class NotificationPermissionNoticeCard extends StatelessWidget {
  const NotificationPermissionNoticeCard({
    super.key,
    required this.description,
    required this.actionLabel,
    required this.onActionPressed,
    this.compact = false,
    this.actionKey,
    this.secondaryActionLabel,
    this.onSecondaryActionPressed,
    this.secondaryActionKey,
  });

  final String description;
  final String actionLabel;
  final VoidCallback onActionPressed;
  final bool compact;
  final Key? actionKey;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryActionPressed;
  final Key? secondaryActionKey;

  @override
  Widget build(BuildContext context) {
    final hasSecondaryAction =
        secondaryActionLabel != null && onSecondaryActionPressed != null;
    final useStackedCompactActions = compact && hasSecondaryAction;
    final contentPadding = compact
        ? const EdgeInsets.fromLTRB(10, 8, 10, 7)
        : const EdgeInsets.all(12);
    final iconSize = compact ? 24.0 : 30.0;
    final iconRadius = compact ? 8.0 : 10.0;
    final titleSize = compact ? 11.5 : 13.0;
    final descriptionSize = compact ? 10.5 : 11.0;
    return Container(
      padding: contentPadding,
      decoration: BoxDecoration(
        color: AppColors.brandBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: AppColors.brandBlue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(iconRadius),
            ),
            child: Icon(
              Icons.notifications_paused_outlined,
              size: compact ? 15 : 16,
              color: AppColors.brandBlue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (compact) ...[
                  Text(
                    key: const Key('notification-permission-notice-title'),
                    NotificationPermissionGuidance.title,
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    key: const Key('notification-permission-notice-badge'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brandBlue.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      NotificationPermissionGuidance.badgeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w300,
                        color: AppColors.brandBlue,
                      ),
                    ),
                  ),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          key:
                              const Key('notification-permission-notice-title'),
                          NotificationPermissionGuidance.title,
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        key: const Key('notification-permission-notice-badge'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandBlue.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          NotificationPermissionGuidance.badgeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w300,
                            color: AppColors.brandBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: compact ? 4 : 6),
                Text(
                  key: const Key('notification-permission-notice-description'),
                  description,
                  style: TextStyle(
                    fontSize: descriptionSize,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textTertiary.withValues(alpha: 0.92),
                    height: 1.35,
                  ),
                  maxLines: compact ? 2 : null,
                  overflow:
                      compact ? TextOverflow.ellipsis : TextOverflow.visible,
                ),
                SizedBox(height: compact ? 8 : 10),
                if (useStackedCompactActions) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 34,
                    child: TextButton(
                      key: actionKey,
                      onPressed: onActionPressed,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        foregroundColor: AppColors.brandBlue,
                        backgroundColor:
                            AppColors.brandBlue.withValues(alpha: 0.14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        actionLabel,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 34,
                    child: TextButton(
                      key: secondaryActionKey,
                      onPressed: onSecondaryActionPressed,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        foregroundColor: AppColors.textSecondary,
                        backgroundColor: AppColors.white08,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(
                            color: AppColors.white12,
                          ),
                        ),
                      ),
                      child: Text(
                        secondaryActionLabel!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: compact ? 34 : 38,
                          child: TextButton(
                            key: actionKey,
                            onPressed: onActionPressed,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              foregroundColor: AppColors.brandBlue,
                              backgroundColor:
                                  AppColors.brandBlue.withValues(alpha: 0.14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              actionLabel,
                              style: TextStyle(
                                fontSize: compact ? 11.5 : 12,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (hasSecondaryAction) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: compact ? 34 : 38,
                            child: TextButton(
                              key: secondaryActionKey,
                              onPressed: onSecondaryActionPressed,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                foregroundColor: AppColors.textSecondary,
                                backgroundColor: AppColors.white08,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: const BorderSide(
                                    color: AppColors.white12,
                                  ),
                                ),
                              ),
                              child: Text(
                                secondaryActionLabel!,
                                style: TextStyle(
                                  fontSize: compact ? 11.5 : 12,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
