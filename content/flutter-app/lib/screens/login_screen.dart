import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_toast.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;
  int _countdown = 0;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _sendCode() {
    if (_phoneController.text.length != 11) {
      AppToast.show(context, '请输入正确的手机号');
      return;
    }

    setState(() {
      _codeSent = true;
      _countdown = 60;
    });

    // 倒计时
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;

      setState(() {
        _countdown--;
      });

      return _countdown > 0;
    });
  }

  Future<void> _login() async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _phoneController.text,
      _codeController.text,
    );

    if (!mounted) return;

    if (success) {
      context.go('/main');
    } else {
      AppToast.show(context, '验证码错误，请输入123456', isError: true);
    }
  }

  void _showAgreement(BuildContext context, String title) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      sheetAnimationStyle: AppDialog.sheetAnimationStyle,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: AppDialog.sheetDecoration(),
        child: Column(
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.white05),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 内容
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _getAgreementContent(title),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textSecondary,
                    height: 1.8,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getAgreementContent(String title) {
    if (title == '用户协议') {
      return '''
# 瞬用户协议

更新日期：2026年2月24日
生效日期：2026年2月24日

欢迎使用瞬！

## 1. 协议的接受

1.1 本协议是您与瞬（以下简称"我们"）之间关于您使用瞬服务所订立的协议。

1.2 在使用瞬服务前，请您务必仔细阅读并充分理解本协议。如果您不同意本协议的任何内容，请不要使用瞬服务。

## 2. 服务说明

2.1 瞬是一款24小时限时匿名社交应用，为用户提供随机匹配、即时聊天等服务。

2.2 所有对话将在24小时后自动消失（好友对话除外）。

2.3 我们保留随时修改或中断服务的权利。

## 3. 用户行为规范

3.1 您承诺不会利用瞬服务从事以下行为：
- 发布违法、暴力、色情、诈骗等不良信息
- 骚扰、威胁、侮辱他人
- 传播虚假信息
- 侵犯他人知识产权
- 其他违反法律法规的行为

3.2 如发现违规行为，我们有权采取警告、限制功能、封禁账号等措施。

## 4. 隐私保护

4.1 我们重视用户隐私保护，详见《隐私政策》。

4.2 您的聊天记录将在24小时后自动删除。

## 5. 免责声明

5.1 瞬仅提供信息交流平台，不对用户发布的内容负责。

5.2 因不可抗力导致的服务中断，我们不承担责任。

## 6. 协议修改

6.1 我们有权随时修改本协议，修改后的协议将在应用内公布。

6.2 继续使用服务即表示您接受修改后的协议。

## 7. 联系我们

如有任何问题，请通过应用内反馈功能联系我们。

---

瞬团队
2026年2月24日
''';
    } else {
      return '''
# 瞬隐私政策

更新日期：2026年2月24日
生效日期：2026年2月24日

瞬（以下简称"我们"）深知个人信息对您的重要性，我们将按照法律法规要求，采取相应安全保护措施，尽力保护您的个人信息安全可控。

## 1. 我们如何收集和使用您的个人信息

### 1.1 注册和登录
- 手机号码：用于账号注册和登录验证

### 1.2 匹配和聊天
- 位置信息：用于匹配附近的用户（每次使用时需要您确认）
- 聊天内容：用于提供即时通讯服务，24小时后自动删除

### 1.3 个人资料
- 昵称、头像、个人签名：用于展示个人信息

### 1.4 设备信息
- 设备型号、操作系统版本：用于优化应用性能

## 2. 我们如何使用Cookie等技术

2.1 我们使用本地存储技术保存您的登录状态和应用设置。

2.2 您可以通过清除应用数据来删除这些信息。

## 3. 我们如何共享、转让、公开披露您的个人信息

3.1 我们不会与第三方共享、转让您的个人信息，除非：
- 获得您的明确同意
- 法律法规要求
- 保护用户或公众的安全

3.2 我们不会公开披露您的个人信息。

## 4. 我们如何保护您的个人信息

4.1 我们采用行业标准的安全措施保护您的个人信息。

4.2 聊天记录采用端到端加密传输。

4.3 所有对话在24小时后自动删除。

## 5. 您的权利

5.1 您有权访问、更正、删除您的个人信息。

5.2 您有权注销账号，注销后所有数据将被永久删除。

5.3 您可以通过应用内设置管理权限。

## 6. 未成年人保护

6.1 我们不向18岁以下的未成年人提供服务。

6.2 如发现未成年人使用，我们将立即停止服务并删除相关信息。

## 7. 隐私政策的修改

7.1 我们可能适时修订本政策，修订后的政策将在应用内公布。

7.2 重大变更时，我们会通过显著方式通知您。

## 8. 联系我们

如对本政策有任何疑问，请通过应用内反馈功能联系我们。

---

瞬团队
2026年2月24日
''';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 60),

              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.brandBlue,
                      AppColors.deepSeaBlue,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandBlue.withValues(alpha: 0.5),
                      blurRadius: 50,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              Text('瞬', style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: 12),
              Text(
                '每个夜晚都是新的开始',
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: 60),

              // 登录表单
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.white08),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('手机号', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 11,
                      decoration: const InputDecoration(
                        hintText: '请输入手机号',
                        counterText: '',
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text('验证码', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: const InputDecoration(
                              hintText: '请输入验证码',
                              counterText: '',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _countdown > 0 ? null : _sendCode,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            backgroundColor: _countdown > 0
                                ? AppColors.white05
                                : AppColors.white12,
                          ),
                          child: Text(
                            _countdown > 0 ? '${_countdown}s' : '发送验证码',
                            style: TextStyle(
                              color: _countdown > 0
                                  ? AppColors.textDisabled
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_codeSent) ...[
                      const SizedBox(height: 8),
                      Text(
                        '测试验证码：123456',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _phoneController.text.length == 11 &&
                                _codeController.text.length == 6
                            ? _login
                            : null,
                        child: const Text('登录'),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 用户协议和隐私政策
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '登录即表示同意',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          GestureDetector(
                            onTap: () => _showAgreement(context, '用户协议'),
                            child: Text(
                              '《用户协议》',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.brandBlue,
                                    decoration: TextDecoration.underline,
                                  ),
                            ),
                          ),
                          Text(
                            '和',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          GestureDetector(
                            onTap: () => _showAgreement(context, '隐私政策'),
                            child: Text(
                              '《隐私政策》',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.brandBlue,
                                    decoration: TextDecoration.underline,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
