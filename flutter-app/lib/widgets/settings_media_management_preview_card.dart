import 'package:flutter/material.dart';

import '../config/theme.dart';

class SettingsMediaManagementPreviewCard extends StatelessWidget {
  const SettingsMediaManagementPreviewCard({
    super.key,
    required this.leading,
    required this.statusLabel,
    required this.statusKey,
    required this.badgeLabel,
    required this.badgeKey,
    required this.hasMedia,
    this.leadingGap = 10,
  });

  final Widget leading;
  final String statusLabel;
  final Key statusKey;
  final String badgeLabel;
  final Key badgeKey;
  final bool hasMedia;
  final double leadingGap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white08),
      ),
      child: Row(
        children: [
          leading,
          SizedBox(width: leadingGap),
          Expanded(
            child: Text(
              statusLabel,
              key: statusKey,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: hasMedia
                  ? AppColors.brandBlue.withValues(alpha: 0.14)
                  : AppColors.white08,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: hasMedia
                    ? AppColors.brandBlue.withValues(alpha: 0.22)
                    : AppColors.white12,
              ),
            ),
            child: Text(
              badgeLabel,
              key: badgeKey,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w300,
                color: hasMedia ? AppColors.brandBlue : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
