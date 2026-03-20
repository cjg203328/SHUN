import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.displayDuration = const Duration(milliseconds: 2500),
    this.animationDuration = const Duration(milliseconds: 2500),
    this.authPollInterval = const Duration(milliseconds: 100),
  });

  final Duration displayDuration;
  final Duration animationDuration;
  final Duration authPollInterval;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5)),
    );

    _controller.forward();

    _navigateAfterSplash();
  }

  Future<void> _navigateAfterSplash() async {
    await Future.delayed(widget.displayDuration);
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isInitialized) {
      await Future.doWhile(() async {
        await Future.delayed(widget.authPollInterval);
        return mounted && !authProvider.isInitialized;
      });
      if (!mounted) return;
    }

    // Fade out before navigating to avoid hard cut
    await _controller.reverse();
    if (!mounted) return;
    context.go(authProvider.isLoggedIn ? '/main' : '/login');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pureBlack,
      body: Center(
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 光球动画
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.brandBlue.withValues(alpha: 0.8),
                        AppColors.deepSeaBlue.withValues(alpha: 0.6),
                        AppColors.deepSeaBlue.withValues(alpha: 0.3),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandBlue.withValues(alpha: 0.5),
                        blurRadius: 36,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 50),

              // 品牌名
              Text(
                '瞬',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w100,
                  color: AppColors.textPrimary,
                  letterSpacing: 16,
                  height: 1,
                  fontFeatures: const [
                    FontFeature.proportionalFigures(),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 中文标语
              Text(
                '每个夜晚都是新的开始',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      letterSpacing: 4,
                      color: AppColors.textTertiary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
