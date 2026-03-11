import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../content/app_legal_content.dart';
import '../core/feedback/app_feedback.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/friend_provider.dart';
import '../providers/match_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
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
  bool _sendingCode = false;
  bool _loggingIn = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_phoneController.text.length != 11) {
      AppFeedback.showError(
        context,
        AppErrorCode.invalidInput,
        detail: '请输入11位手机号后继续',
      );
      return;
    }

    setState(() {
      _sendingCode = true;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.sendOtp(_phoneController.text);

    if (!mounted) return;

    setState(() {
      _sendingCode = false;
    });

    if (!success) {
      AppFeedback.showError(
        context,
        AppErrorCode.sendFailed,
        detail: authProvider.lastError,
      );
      return;
    }

    setState(() {
      _codeSent = true;
      _countdown = 60;
    });

    AppFeedback.showToast(context, AppToastCode.sent, subject: '验证码');

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
    setState(() {
      _loggingIn = true;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _phoneController.text,
      _codeController.text,
    );

    if (!mounted) return;

    setState(() {
      _loggingIn = false;
    });

    if (success) {
      try {
        await context.read<ProfileProvider>().refreshFromRemote();
        await context.read<SettingsProvider>().refreshFromRemote();
        await context.read<FriendProvider>().refreshFromRemote();
        await context.read<MatchProvider>().refreshFromRemote();
        await context.read<ChatProvider>().refreshFromRemote();
      } catch (_) {}

      if (!mounted) return;
      context.go('/main');
    } else {
      AppFeedback.showError(
        context,
        AppErrorCode.invalidInput,
        detail: authProvider.lastError,
      );
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
    final documentType = title == '用户协议'
        ? LegalDocumentType.userAgreement
        : LegalDocumentType.privacyPolicy;
    return AppLegalContent.contentOf(documentType);
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
                      onChanged: (_) => setState(() {}),
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
                            onChanged: (_) => setState(() {}),
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
                          onPressed:
                              (_countdown > 0 || _sendingCode) ? null : _sendCode,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            backgroundColor: (_countdown > 0 || _sendingCode)
                                ? AppColors.white05
                                : AppColors.white12,
                          ),
                          child: Text(
                            _sendingCode
                                ? '发送中...'
                                : (_countdown > 0 ? '${_countdown}s' : '发送验证码'),
                            style: TextStyle(
                              color: (_countdown > 0 || _sendingCode)
                                  ? AppColors.textDisabled
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: !_loggingIn &&
                                _phoneController.text.length == 11 &&
                                _codeController.text.length == 6
                            ? _login
                            : null,
                        child: Text(_loggingIn ? '登录中...' : '登录'),
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
