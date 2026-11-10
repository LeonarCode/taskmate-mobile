import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../widgets/app_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _textController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeIn));
    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _textController.forward();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.darkBgGradient
              : const LinearGradient(
                  colors: [
                    AppColors.purple50,
                    Colors.white,
                    AppColors.purple100,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _logoController,
                builder: (_, child) => Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(scale: _logoScale.value, child: child),
                ),
                child: const AppLogo(size: 140),
              ),
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: _textController,
                builder: (_, child) => FadeTransition(
                  opacity: _textOpacity,
                  child: SlideTransition(position: _textSlide, child: child),
                ),
                child: Column(
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Task',
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: AppColors.purple600,
                              letterSpacing: -0.5,
                            ),
                          ),
                          TextSpan(
                            text: 'Mate',
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: AppColors.pink500,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your smart productivity mate 🚀',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.gray400 : AppColors.gray500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(
                    isDark ? AppColors.purple400 : AppColors.purple600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
