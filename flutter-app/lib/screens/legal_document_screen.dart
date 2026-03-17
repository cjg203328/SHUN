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
    final content = AppLegalContent.contentOf(documentType);

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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Container(
          key: const Key('legal-document-card'),
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white05,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.white05),
          ),
          child: SelectableText(
            content,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w300,
              color: AppColors.textSecondary,
              height: 1.85,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
