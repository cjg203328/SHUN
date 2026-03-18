import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../core/feedback/app_feedback.dart';
import '../core/network/api_exception.dart';
import '../services/api_client.dart';

enum ReportTargetType { user, message }

class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    required this.targetId,
    required this.targetType,
    this.targetName,
  });

  final String targetId;
  final ReportTargetType targetType;
  final String? targetName;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  static const List<_ReportCategory> _categories = [
    _ReportCategory(
      id: 'spam',
      label: '垃圾信息 / 广告',
      icon: Icons.block_outlined,
    ),
    _ReportCategory(
      id: 'harassment',
      label: '骚扰 / 威胁',
      icon: Icons.warning_amber_outlined,
    ),
    _ReportCategory(
      id: 'inappropriate_content',
      label: '不雅内容 / 色情',
      icon: Icons.visibility_off_outlined,
    ),
    _ReportCategory(
      id: 'fraud',
      label: '诈骗 / 欺诈',
      icon: Icons.gpp_bad_outlined,
    ),
    _ReportCategory(
      id: 'hate_speech',
      label: '仇恨言论 / 歧视',
      icon: Icons.sentiment_very_dissatisfied_outlined,
    ),
    _ReportCategory(
      id: 'underage',
      label: '疑似未成年人',
      icon: Icons.child_care_outlined,
    ),
    _ReportCategory(
      id: 'other',
      label: '其他问题',
      icon: Icons.more_horiz_outlined,
    ),
  ];

  String? _selectedCategoryId;
  final TextEditingController _detailController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedCategoryId == null) {
      AppFeedback.showError(context, AppErrorCode.invalidInput,
          detail: '请选择举报类型');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ApiClient.instance.post<Map<String, dynamic>>(
        '/report',
        data: {
          'targetType': widget.targetType == ReportTargetType.user
              ? 'user'
              : 'message',
          'targetId': widget.targetId,
          'category': _selectedCategoryId,
          if (_detailController.text.trim().isNotEmpty)
            'detail': _detailController.text.trim(),
        },
      );
      if (!mounted) return;
      AppFeedback.showToast(context, AppToastCode.sent, subject: '举报');
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, AppErrorCode.sendFailed,
          detail: e.message);
    } catch (_) {
      if (!mounted) return;
      AppFeedback.showError(context, AppErrorCode.sendFailed);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetLabel = widget.targetType == ReportTargetType.user
        ? (widget.targetName != null ? '举报用户「${widget.targetName}」' : '举报用户')
        : '举报消息内容';

    return Scaffold(
      backgroundColor: AppColors.pureBlack,
      appBar: AppBar(
        backgroundColor: AppColors.pureBlack,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 22),
          color: AppColors.textSecondary,
          onPressed: () => context.pop(),
        ),
        title: const Text('举报'),
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              targetLabel,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ..._categories.map((cat) => _CategoryTile(
                      category: cat,
                      isSelected: _selectedCategoryId == cat.id,
                      onTap: () =>
                          setState(() => _selectedCategoryId = cat.id),
                    )),
                const SizedBox(height: 20),
                // Detail text field
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  crossFadeState: _selectedCategoryId != null
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox.shrink(),
                  secondChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '补充说明（选填）',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _detailController,
                        maxLines: 4,
                        maxLength: 300,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w300,
                        ),
                        decoration: InputDecoration(
                          hintText: '请描述具体情况，有助于我们更快处理',
                          filled: true,
                          fillColor: AppColors.white05,
                          counterStyle: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.white12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.white12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.brandBlue),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    disabledBackgroundColor:
                        AppColors.error.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '提交举报',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
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

class _ReportCategory {
  const _ReportCategory({
    required this.id,
    required this.label,
    required this.icon,
  });
  final String id;
  final String label;
  final IconData icon;
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final _ReportCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.error.withValues(alpha: 0.08)
              : AppColors.white05,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.error.withValues(alpha: 0.35)
                : AppColors.white08,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(
              category.icon,
              size: 20,
              color: isSelected
                  ? AppColors.error
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                category.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w300,
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: isSelected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 160),
              child: Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
