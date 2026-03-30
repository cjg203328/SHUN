import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/theme.dart';
import '../content/app_legal_content.dart';

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.documentType,
  });

  final LegalDocumentType documentType;

  @override
  Widget build(BuildContext context) {
    final title = AppLegalContent.titleOf(documentType);
    final badgeLabel = AppLegalContent.badgeLabelOf(documentType);
    final summary = AppLegalContent.summaryOf(documentType);
    final updateDate = AppLegalContent.updateDateOf(documentType);
    final content = AppLegalContent.contentOf(documentType);
    final size = MediaQuery.of(context).size;
    final isCompact = size.width <= 390 || size.height <= 720;
    final horizontalPadding = isCompact ? 16.0 : 20.0;
    final topPadding = isCompact ? 16.0 : 20.0;
    final cardRadius = isCompact ? 18.0 : 20.0;
    final headerSpacing = isCompact ? 14.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.pureBlack,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        key: const Key('legal-document-scroll-view'),
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          topPadding,
          horizontalPadding,
          32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              key: const Key('legal-document-summary-card'),
              width: double.infinity,
              padding: EdgeInsets.all(isCompact ? 18 : 20),
              decoration: BoxDecoration(
                color: AppColors.white05,
                borderRadius: BorderRadius.circular(cardRadius),
                border: Border.all(color: AppColors.white05),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _LegalMetaBadge(
                        key: const Key('legal-document-type-badge'),
                        label: badgeLabel,
                      ),
                      _LegalMetaBadge(
                        key: const Key('legal-document-update-badge'),
                        label: '更新于 $updateDate',
                      ),
                    ],
                  ),
                  SizedBox(height: isCompact ? 12 : 14),
                  Text(
                    title,
                    key: const Key('legal-document-summary-title'),
                    style: TextStyle(
                      fontSize: isCompact ? 18 : 20,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    summary,
                    key: const Key('legal-document-summary-description'),
                    style: TextStyle(
                      fontSize: isCompact ? 12.5 : 13,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textTertiary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: headerSpacing),
            Container(
              key: const Key('legal-document-card'),
              width: double.infinity,
              padding: EdgeInsets.all(isCompact ? 18 : 20),
              decoration: BoxDecoration(
                color: AppColors.white05,
                borderRadius: BorderRadius.circular(cardRadius),
                border: Border.all(color: AppColors.white05),
              ),
              child: SelectableText(
                content,
                style: TextStyle(
                  fontSize: isCompact ? 13 : 14,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textSecondary,
                  height: isCompact ? 1.75 : 1.85,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalMetaBadge extends StatelessWidget {
  const _LegalMetaBadge({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white08,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.white12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w300,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
