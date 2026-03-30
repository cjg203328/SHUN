import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _supportedFeatures = [
    '登录',
    '匹配',
    '聊天',
    '好友',
    '通知',
    '资料管理',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.pureBlack,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          '关于瞬聊',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        key: const Key('about-screen-list'),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Container(
            key: const Key('about-hero-card'),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.white05,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: const [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: AppColors.white12,
                  child: Icon(
                    Icons.nights_stay_outlined,
                    size: 32,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  '瞬聊',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '轻量、克制的即时社交',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 14),
                _AboutBadge(
                  label: 'V1.0.4',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _InfoCard(
            key: const Key('about-app-info-card'),
            title: '应用信息',
            lines: const [
              '当前版本：V1.0.4',
              '当前构建：移动端体验版',
              '当前形态：本地交互体验版',
            ],
          ),
          const SizedBox(height: 16),
          _FeatureCard(
            features: _supportedFeatures,
          ),
          const SizedBox(height: 16),
          _InfoCard(
            key: const Key('about-product-summary-card'),
            title: '产品定位',
            lines: const [
              '主打轻量、克制和隐私感。',
              '核心入口集中在匹配、聊天、消息和个人资料。',
            ],
          ),
          const SizedBox(height: 16),
          _InfoCard(
            key: const Key('about-copyright-card'),
            title: '版权信息',
            lines: const [
              'Copyright © 2026 瞬团队',
              '保留所有权利。',
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    super.key,
    required this.title,
    required this.lines,
  });

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                line,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textSecondary,
                  height: 1.55,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.features,
  });

  final List<String> features;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('about-feature-card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '支持能力',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: features
                .map(
                  (feature) => _AboutBadge(
                    label: feature,
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _AboutBadge extends StatelessWidget {
  const _AboutBadge({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
