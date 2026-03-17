import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
          '关于瞬',
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
                  '瞬',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '24小时限时匿名社交',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '每个夜晚都是新的开始',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _InfoCard(
            title: '版本信息',
            lines: const [
              '当前版本：V1.0.3',
              '交付形态：正式发布版',
              '支持能力：登录、匹配、聊天、好友、通知、资料管理',
            ],
          ),
          const SizedBox(height: 16),
          _InfoCard(
            title: '产品说明',
            lines: const [
              '瞬致力于打造轻量、克制、注重隐私的即时社交体验。',
              '你可以在这里完成随机匹配、建立好友关系，以及进行实时聊天互动。',
              '应用已支持基础账号体系、媒体上传、消息通知与设置管理。',
            ],
          ),
          const SizedBox(height: 16),
          _InfoCard(
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
                  height: 1.7,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
