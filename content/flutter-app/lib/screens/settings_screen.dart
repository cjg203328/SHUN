import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_toast.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
          '设置',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w300,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          
          // 账号与安全
          _buildSectionTitle('账号与安全'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.white05,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildSettingItem(
                  context,
                  icon: Icons.phone_outlined,
                  title: '手机号',
                  trailing: Consumer<AuthProvider>(
                    builder: (context, auth, child) => Text(
                      auth.phone ?? '未绑定',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  onTap: () => AppToast.show(context, '手机号绑定功能即将上线'),
                ),
                _buildDivider(),
                _buildSettingItem(
                  context,
                  icon: Icons.lock_outlined,
                  title: '修改密码',
                  onTap: () => AppToast.show(context, '修改密码功能即将上线'),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          
          // 隐私设置
          _buildSectionTitle('隐私设置'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.white05,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildSettingItem(
                  context,
                  icon: Icons.block_outlined,
                  title: '黑名单',
                  onTap: () => AppToast.show(context, '黑名单功能即将上线'),
                ),
                _buildDivider(),
                _buildSettingItem(
                  context,
                  icon: Icons.visibility_off_outlined,
                  title: '隐身模式',
                  trailing: Switch(
                    value: false,
                    onChanged: (value) {
                      AppToast.show(context, '隐身模式功能即将上线');
                    },
                    activeColor: AppColors.brandBlue,
                  ),
                  onTap: null,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          
          // 通知设置
          _buildSectionTitle('通知设置'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.white05,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildSettingItem(
                  context,
                  icon: Icons.notifications_outlined,
                  title: '消息通知',
                  trailing: Switch(
                    value: true,
                    onChanged: (value) {
                      AppToast.show(context, value ? '已开启通知' : '已关闭通知');
                    },
                    activeColor: AppColors.brandBlue,
                  ),
                  onTap: null,
                ),
                _buildDivider(),
                _buildSettingItem(
                  context,
                  icon: Icons.vibration_outlined,
                  title: '震动',
                  trailing: Switch(
                    value: true,
                    onChanged: (value) {
                      AppToast.show(context, value ? '已开启震动' : '已关闭震动');
                    },
                    activeColor: AppColors.brandBlue,
                  ),
                  onTap: null,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          
          // 关于
          _buildSectionTitle('关于'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.white05,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildSettingItem(
                  context,
                  icon: Icons.info_outlined,
                  title: '关于瞬',
                  onTap: () => _showAboutDialog(context),
                ),
                _buildDivider(),
                _buildSettingItem(
                  context,
                  icon: Icons.privacy_tip_outlined,
                  title: '隐私政策',
                  onTap: () => AppToast.show(context, '隐私政策'),
                ),
                _buildDivider(),
                _buildSettingItem(
                  context,
                  icon: Icons.description_outlined,
                  title: '用户协议',
                  onTap: () => AppToast.show(context, '用户协议'),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          
          // 退出登录
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: OutlinedButton(
              onPressed: () => _showLogoutDialog(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppColors.error, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '退出登录',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 15,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 版本信息
          Center(
            child: Text(
              'V1.0.2',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textDisabled,
              ),
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 20, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w300,
            color: AppColors.textTertiary,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            if (trailing != null)
              trailing
            else if (onTap != null)
              const Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 1,
      color: AppColors.white05,
    );
  }

  void _showAboutDialog(BuildContext context) async {
    await AppDialog.showConfirm(
      context,
      title: '关于瞬',
      content: '版本：V1.0.2\n\n24小时限时匿名社交\n每个夜晚都是新的开始\n\nCopyright © 2026 瞬团队',
      confirmText: '确定',
      cancelText: '',
    );
  }

  void _showLogoutDialog(BuildContext context) async {
    final confirm = await AppDialog.showConfirm(
      context,
      title: '退出登录',
      content: '确定要退出登录吗？',
      confirmText: '退出',
      isDanger: true,
    );
    
    if (confirm == true && context.mounted) {
      context.read<AuthProvider>().logout();
      context.go('/login');
    }
  }
}

