import 'package:flutter/material.dart';
import '../config/theme.dart';

class AppToast {
  static void show(BuildContext context, String message,
      {bool isError = false}) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom + 92;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w300,
            color: AppColors.textPrimary,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
        backgroundColor:
            isError ? AppColors.error.withValues(alpha: 0.14) : AppColors.cardBg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isError
                ? AppColors.error.withValues(alpha: 0.28)
                : AppColors.white12,
          ),
        ),
        margin: const EdgeInsets.only(
          left: 40,
          right: 40,
        ).copyWith(bottom: bottomInset),
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        duration: const Duration(milliseconds: 1800),
        elevation: 0,
      ),
    );
  }
}

class AppDialog {
  static final AnimationStyle sheetAnimationStyle = AppOverlay.sheetAnimationStyle;
  static const BorderRadius sheetBorderRadius = AppOverlay.sheetBorderRadius;

  static BoxDecoration sheetDecoration({Color color = AppColors.cardBg}) {
    return BoxDecoration(
      color: color,
      borderRadius: sheetBorderRadius,
      boxShadow: AppOverlay.softShadow,
      border: Border.all(color: AppColors.white08, width: 0.5),
    );
  }

  static Widget buildSheetSurface({
    required Widget child,
    bool showHandle = true,
    BoxConstraints? constraints,
    EdgeInsetsGeometry? padding,
    Color color = AppColors.cardBg,
  }) {
    final surface = Container(
      constraints: constraints,
      decoration: sheetDecoration(color: color),
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandle) ...[
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
    return ClipRRect(
      borderRadius: sheetBorderRadius,
      child: SafeArea(top: false, child: surface),
    );
  }

  static Future<bool?> showConfirm(
    BuildContext context, {
    required String title,
    String? content,
    String confirmText = '确定',
    String cancelText = '取消',
    bool isDanger = false,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: sheetAnimationStyle,
      builder: (context) => buildSheetSurface(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (content != null) ...[
              const SizedBox(height: 12),
              Text(
                content,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.3,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 30),
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
                    child: Text(
                      cancelText,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                        color: AppColors.textSecondary,
                        letterSpacing: 1,
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
                      backgroundColor: isDanger
                          ? AppColors.error.withValues(alpha: 0.15)
                          : AppColors.white12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      confirmText,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                        color: isDanger ? AppColors.error : AppColors.textPrimary,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Future<String?> showMessageActions(
    BuildContext context, {
    required bool isMe,
    required bool canRecall,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: sheetAnimationStyle,
      builder: (context) => buildSheetSurface(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildActionItem(
              context,
              icon: Icons.content_copy,
              text: '复制',
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            if (isMe && canRecall)
              _buildActionItem(
                context,
                icon: Icons.undo,
                text: '撤回',
                onTap: () => Navigator.pop(context, 'recall'),
                isDanger: true,
              ),
            const SizedBox(height: 8),
            _buildActionItem(
              context,
              icon: Icons.close,
              text: '取消',
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildActionItem(
    BuildContext context, {
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return InkWell(
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
