import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/ui_helpers.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/common.dart';
import '../../widgets/gradient_button.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  late final AnimationController _bounceCtrl;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _bounceAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _bounceAnim = CurvedAnimation(
      parent: _bounceCtrl,
      curve: Curves.elasticOut,
    );

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _bounceCtrl.forward();
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _fadeCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() => _isLogin = !_isLogin);
    _fadeCtrl.reset();
    _fadeCtrl.forward();
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    auth.clearError();

    if (_isLogin) {
      await auth.signInWithEmail(_emailCtrl.text.trim(), _passwordCtrl.text);
    } else {
      // Registering continues on the "Complete Profile" screen.
      await auth.startEmailSignup(_emailCtrl.text.trim(), _passwordCtrl.text);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final auth = context.read<AuthProvider>();
    auth.clearError();
    await auth.signInWithGoogle();
  }

  void _showForgotPassword() {
    showAppSheet<void>(
      context,
      (_) => _ForgotPasswordSheet(initialEmail: _emailCtrl.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: isDark ? AppColors.dark900 : AppColors.purple50,
      body: Stack(
        children: [
          _buildBgDecoration(isDark),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  ScaleTransition(
                    scale: _bounceAnim,
                    child: Column(
                      children: [
                        const AppLogo(size: 120),
                        const SizedBox(height: 16),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Task',
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.purple600,
                                ),
                              ),
                              TextSpan(
                                text: 'Mate',
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.pink500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isLogin
                              ? 'Welcome back! 👋'
                              : "Let's get started! 🚀",
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark
                                ? AppColors.gray400
                                : AppColors.gray500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: _buildCard(isDark, auth),
                  ),
                  const SizedBox(height: 20),
                  _buildToggle(isDark),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          if (auth.isLoading) _buildLoadingOverlay(isDark),
        ],
      ),
    );
  }

  Widget _buildBgDecoration(bool isDark) {
    return Stack(
      children: [
        Positioned(
          top: -80,
          right: -80,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.pink500.withAlpha(isDark ? 20 : 30),
            ),
          ),
        ),
        Positioned(
          bottom: -60,
          left: -60,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.purple600.withAlpha(isDark ? 25 : 30),
            ),
          ),
        ),
        Positioned(
          top: 160,
          left: 20,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.pink400.withAlpha(isDark ? 100 : 160),
              boxShadow: [
                BoxShadow(
                  color: AppColors.pink400.withAlpha(80),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 240,
          right: 40,
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.purple400.withAlpha(isDark ? 100 : 160),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(bool isDark, AuthProvider auth) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.dark800 : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: isDark
            ? Border.all(color: AppColors.dark600, width: 1.5)
            : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.purple600.withAlpha(25),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: AppColors.pink500.withAlpha(12),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tab header
            _buildTabHeader(isDark),
            const SizedBox(height: 24),
            // Google button
            _buildGoogleButton(isDark),
            const SizedBox(height: 20),
            _buildDivider(isDark),
            const SizedBox(height: 20),
            if (auth.error != null) ...[
              ErrorBanner(auth.error!),
              const SizedBox(height: 20),
            ],
            // Email field
            _buildField(
              controller: _emailCtrl,
              label: 'Email',
              hint: 'you@example.com',
              icon: Icons.mail_rounded,
              iconColor: AppColors.purple600,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email is required';
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            // Password field
            _buildField(
              controller: _passwordCtrl,
              label: 'Password',
              hint: '••••••••',
              icon: Icons.lock_rounded,
              iconColor: AppColors.pink500,
              obscureText: _obscurePassword,
              suffixIcon: GestureDetector(
                onTap: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                child: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: isDark ? AppColors.gray400 : AppColors.gray500,
                  size: 20,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                // Signing in accepts any password; the rules apply to new ones.
                if (!_isLogin) {
                  if (v.length < 8) return 'Minimum 8 characters';
                  if (utf8.encode(v).length > 72) return 'Maximum 72 bytes';
                }
                return null;
              },
            ),
            if (!_isLogin) ...[
              const SizedBox(height: 14),
              _buildField(
                controller: _confirmPasswordCtrl,
                label: 'Confirm Password',
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                iconColor: AppColors.purple400,
                obscureText: _obscureConfirmPassword,
                suffixIcon: GestureDetector(
                  onTap: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                  child: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: isDark ? AppColors.gray400 : AppColors.gray500,
                    size: 20,
                  ),
                ),
                validator: (v) {
                  if (v != _passwordCtrl.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 24),
            GradientButton(
              label: _isLogin ? 'Sign In' : 'Create Account',
              icon: Icons.arrow_forward_rounded,
              onTap: auth.isLoading ? null : _handleEmailAuth,
            ),
            if (_isLogin) ...[
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: _showForgotPassword,
                  child: Text(
                    'Forgot password?',
                    style: TextStyle(
                      color: AppColors.pink500,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabHeader(bool isDark) {
    return Row(
      children: [
        _tab('Sign In', _isLogin, isDark, () {
          if (!_isLogin) _toggleMode();
        }),
        const SizedBox(width: 8),
        _tab('Register', !_isLogin, isDark, () {
          if (_isLogin) _toggleMode();
        }),
      ],
    );
  }

  Widget _tab(String label, bool active, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: active ? AppColors.primaryGradient : null,
          color: active ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: active
                ? Colors.white
                : (isDark ? AppColors.gray400 : AppColors.gray500),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton(bool isDark) {
    return GestureDetector(
      onTap: _handleGoogleSignIn,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 54,
        decoration: BoxDecoration(
          color: isDark ? AppColors.dark700 : AppColors.gray50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.dark500 : AppColors.gray200,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CustomPaint(painter: _GooglePainter()),
            ),
            const SizedBox(width: 10),
            Text(
              'Continue with Google',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.gray800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    final dividerColor = isDark ? AppColors.dark500 : AppColors.gray200;
    return Row(
      children: [
        Expanded(child: Container(height: 1.2, color: dividerColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or continue with email',
            style: TextStyle(
              color: isDark ? AppColors.gray500 : AppColors.gray400,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Container(height: 1.2, color: dividerColor)),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color iconColor,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.gray200 : AppColors.gray700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.gray900,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Container(
              margin: const EdgeInsets.all(10),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            suffixIcon: suffixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: suffixIcon,
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildToggle(bool isDark) {
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        Text(
          _isLogin ? "Don't have an account? " : 'Already have an account? ',
          style: TextStyle(
            color: isDark ? AppColors.gray400 : AppColors.gray500,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        GestureDetector(
          onTap: _toggleMode,
          child: Text(
            _isLogin ? 'Sign up' : 'Sign in',
            style: TextStyle(
              color: AppColors.purple600,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.purple600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingOverlay(bool isDark) {
    return Container(
      color: Colors.black.withAlpha(isDark ? 100 : 60),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: isDark ? AppColors.dark700 : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.purple600.withAlpha(40),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.purple600),
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                _isLogin ? 'Signing in...' : 'Creating account...',
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.gray800,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Forgot Password Sheet ──────────────────────────────────────────────────────
/// Two steps: ask for a 6-digit code by email, then enter it with a new password.
class _ForgotPasswordSheet extends StatefulWidget {
  final String initialEmail;
  const _ForgotPasswordSheet({required this.initialEmail});

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

enum _ResetStep { email, code, done }

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  late final _emailCtrl = TextEditingController(text: widget.initialEmail);
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  _ResetStep _step = _ResetStep.email;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    await _run(() async {
      await context.read<AuthProvider>().sendPasswordResetCode(email);
      if (mounted) setState(() => _step = _ResetStep.code);
    });
  }

  Future<void> _resetPassword() async {
    final code = _codeCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    if (utf8.encode(password).length > 72) {
      setState(() => _error = 'Password must be at most 72 bytes.');
      return;
    }
    await _run(() async {
      await context.read<AuthProvider>().resetPassword(
        email: _emailCtrl.text.trim(),
        code: code,
        newPassword: password,
      );
      if (mounted) setState(() => _step = _ResetStep.done);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SheetContainer(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            Text(
              'Reset Password',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.gray900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              switch (_step) {
                _ResetStep.email =>
                  "Enter your email and we'll send you a 6-digit code.",
                _ResetStep.code =>
                  'We sent a code to ${_emailCtrl.text.trim()}. '
                      'Enter it below with your new password.',
                _ResetStep.done => 'All set!',
              },
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.gray400 : AppColors.gray500,
              ),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              ErrorBanner(_error!),
              const SizedBox(height: 16),
            ],
            ..._buildStep(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStep() {
    switch (_step) {
      case _ResetStep.email:
        return [
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'you@example.com',
              prefixIcon: Icon(Icons.mail_rounded),
            ),
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: 'Send Code',
            icon: Icons.send_rounded,
            onTap: _loading ? null : _sendCode,
          ),
        ];
      case _ResetStep.code:
        return [
          TextField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              hintText: '6-digit code',
              counterText: '',
              prefixIcon: Icon(Icons.pin_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              hintText: 'New password (8+ characters)',
              prefixIcon: const Icon(Icons.lock_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: 'Reset Password',
            icon: Icons.check_rounded,
            onTap: _loading ? null : _resetPassword,
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _loading ? null : _sendCode,
              child: const Text('Send a new code'),
            ),
          ),
        ];
      case _ResetStep.done:
        return [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.green500.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.green500.withAlpha(80)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.green500,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Password updated. You can sign in now.',
                    style: TextStyle(
                      color: AppColors.green500,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: 'Back to Sign In',
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
          ),
        ];
    }
  }
}

// ── Google G painter ───────────────────────────────────────────────────────────
class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = Colors.white);

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.75);
    final sw = size.width * 0.18;

    void arc(double start, double sweep, Color color) {
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.butt,
      );
    }

    arc(-0.3, 2.0, const Color(0xFF4285F4));
    arc(3.6, 1.7, const Color(0xFFEA4335));
    arc(1.7, 1.1, const Color(0xFFFBBC05));
    arc(2.8, 0.85, const Color(0xFF34A853));

    canvas.drawRect(
      Rect.fromLTWH(cx, cy - size.height * 0.09, r * 0.72, size.height * 0.18),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
