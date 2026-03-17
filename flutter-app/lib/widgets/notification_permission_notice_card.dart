import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../utils/notification_permission_guidance.dart';

class NotificationPermissionNoticeCard extends StatelessWidget {
  const NotificationPermissionNoticeCard({
    super.key,
    required this.description,
    required this.actionLabel,
    required this.onActionPressed,
    this.actionKey,
    this.secondaryActionLabel,
    this.onSecondaryActionPressed,
    this.secondaryActionKey,
  });

  final String description;
  final String actionLabel;
  final VoidCallback onActionPressed;
  final Key? actionKey;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryActionPressed;
  final Key? secondaryActionKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.brandBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.brandBlue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.notifications_paused_outlined,
              size: 16,
              color: AppColors.brandBlue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Text(
                        NotificationPermissionGuidance.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
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
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textTertiary.withValues(alpha: 0.92),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      key: actionKey,
                      onPressed: onActionPressed,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        foregroundColor: AppColors.brandBlue,
                        backgroundColor:
                            AppColors.brandBlue.withValues(alpha: 0.12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        actionLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                    if (secondaryActionLabel != null &&
                        onSecondaryActionPressed != null)
                      TextButton(
                        key: secondaryActionKey,
                        onPressed: onSecondaryActionPressed,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          foregroundColor: AppColors.textSecondary,
                          backgroundColor: AppColors.white08,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.white12),
                          ),
                        ),
                        child: Text(
                          secondaryActionLabel!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
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
