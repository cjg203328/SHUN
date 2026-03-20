import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../content/app_legal_content.dart';
import '../core/feedback/app_feedback.dart';
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
  int _countdown = 0;
  bool _sendingCode = false;
  bool _loggingIn = false;
  bool _agreedToTerms = false;
  String? _otpRequestedPhone;

  bool get _canLogin =>
      !_loggingIn &&
      _agreedToTerms &&
      _phoneController.text.length == 11 &&
      _codeController.text.length == 6 &&
      _otpRequestedPhone == _phoneController.text;

  bool get _hasRequestedOtpForCurrentPhone =>
      _otpRequestedPhone != null && _otpRequestedPhone == _phoneController.text;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    // Prevent multiple simultaneous OTP requests
    if (_sendingCode) return;

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
      final errorMessage = authProvider.lastError;
      if (errorMessage != null && errorMessage.isNotEmpty) {
        AppFeedback.showError(
          context,
          AppErrorCode.sendFailed,
          detail: errorMessage,
        );
      }
      return;
    }

    setState(() {
      _countdown = 60;
      _otpRequestedPhone = _phoneController.text;
    });

    AppFeedback.showToast(context, AppToastCode.sent, subject: '验证码');

    // 倒计时
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;

      setState(() {
        if (_countdown > 0) {
          _countdown--;
        }
      });

      return _countdown > 0;
    });
  }

  Future<void> _login() async {
    // Prevent multiple simultaneous login attempts
    if (_loggingIn) return;

    final authProvider = context.read<AuthProvider>();

    setState(() {
      _loggingIn = true;
    });

    final success = await authProvider.login(
      _phoneController.text,
      _codeController.text,
    );

    if (!mounted) return;

    setState(() {
      _loggingIn = false;
    });

    if (success) {
      if (!mounted) return;
      context.go('/main?entry=login');
    } else {
      // Only show error if we have a specific error message
      final errorMessage = authProvider.lastError;
      if (errorMessage != null && errorMessage.isNotEmpty) {
        AppFeedback.showError(
          context,
          AppErrorCode.invalidInput,
          detail: errorMessage,
        );
      }
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

  String _maskPhone(String phone) {
    if (phone.length != 11) return phone;
    return '${phone.substring(0, 3)}****${phone.substring(7)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      (constraints.maxHeight - 40).clamp(0.0, double.infinity),
                ),
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
                            blurRadius: 28,
                            spreadRadius: 4,
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
                          Text('手机号',
                              style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 10),
                          TextField(
                            key: const Key('login-phone-field'),
                            controller: _phoneController,
                            onChanged: (value) {
                              setState(() {
                                if (_otpRequestedPhone != null &&
                                    value != _otpRequestedPhone) {
                                  _otpRequestedPhone = null;
                                  _countdown = 0;
                                }
                              });
                            },
                            keyboardType: TextInputType.phone,
                            maxLength: 11,
                            decoration: const InputDecoration(
                              hintText: '请输入手机号',
                              counterText: '',
                            ),
                          ),

                          const SizedBox(height: 20),

                          Text('验证码',
                              style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  key: const Key('login-code-field'),
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
                                key: const Key('login-send-code-button'),
                                onPressed: (_countdown > 0 || _sendingCode)
                                    ? null
                                    : _sendCode,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 14),
                                  backgroundColor:
                                      (_countdown > 0 || _sendingCode)
                                          ? AppColors.white05
                                          : AppColors.white12,
                                ),
                                child: Text(
                                  _sendingCode
                                      ? '发送中...'
                                      : (_countdown > 0
                                          ? '${_countdown}s'
                                          : '发送验证码'),
                                  style: TextStyle(
                                    color: (_countdown > 0 || _sendingCode)
                                        ? AppColors.textDisabled
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (_hasRequestedOtpForCurrentPhone) ...[
                            const SizedBox(height: 14),
                            Container(
                              key: const Key('login-otp-inline-hint'),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.white05,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.white08),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: AppColors.brandBlue.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.mark_email_read_outlined,
                                      size: 14,
                                      color: AppColors.brandBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '验证码已发送至 ${_maskPhone(_phoneController.text)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _countdown > 0
                                              ? '当前号码已完成验证码请求，约 ${_countdown}s 后可重新获取。'
                                              : '当前号码已完成验证码请求，如未收到短信可重新获取验证码。',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w300,
                                            color: AppColors.textSecondary,
                                            height: 1.45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 30),

                          // 协议同意复选框
                          GestureDetector(
                            key: const Key('login-terms-toggle'),
                            onTap: () => setState(
                                () => _agreedToTerms = !_agreedToTerms),
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                  width: 20,
                                  height: 20,
                                  margin: const EdgeInsets.only(top: 1),
                                  decoration: BoxDecoration(
                                    color: _agreedToTerms
                                        ? AppColors.brandBlue
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: _agreedToTerms
                                          ? AppColors.brandBlue
                                          : AppColors.white20,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: _agreedToTerms
                                      ? const Icon(
                                          Icons.check,
                                          size: 13,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        '我已阅读并同意',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(height: 1.6),
                                      ),
                                      GestureDetector(
                                        key: const Key(
                                            'login-user-agreement-link'),
                                        onTap: () =>
                                            _showAgreement(context, '用户协议'),
                                        child: Text(
                                          '《用户协议》',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.brandBlue,
                                                height: 1.6,
                                              ),
                                        ),
                                      ),
                                      Text(
                                        '与',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(height: 1.6),
                                      ),
                                      GestureDetector(
                                        key: const Key(
                                            'login-privacy-policy-link'),
                                        onTap: () =>
                                            _showAgreement(context, '隐私政策'),
                                        child: Text(
                                          '《隐私政策》',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.brandBlue,
                                                height: 1.6,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              key: const Key('login-submit-button'),
                              onPressed: _canLogin ? _login : null,
                              child: Text(_loggingIn ? '登录中...' : '登录'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
