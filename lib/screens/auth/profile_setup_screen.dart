import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/gradient_button.dart';

/// "Complete Profile": the second step of signing up, for both email and
/// Google sign-ups. Nothing is created on the backend until it's submitted.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _fullNameCtrl = TextEditingController(
    text: context.read<AuthProvider>().pendingSignup?.suggestedName ?? '',
  );
  final _usernameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _organizationCtrl = TextEditingController();
  UserType _userType = UserType.student;

  Timer? _usernameDebounce;
  bool _checkingUsername = false;

  /// The result of the last availability check, for [_checkedUsername].
  bool? _usernameAvailable;
  String _checkedUsername = '';

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _ageCtrl.dispose();
    _organizationCtrl.dispose();
    super.dispose();
  }

  String get _username => _usernameCtrl.text.trim().toLowerCase();

  void _onUsernameChanged(String _) {
    _usernameDebounce?.cancel();
    setState(() {
      _usernameAvailable = null;
      _checkingUsername = false;
    });
    final username = _username;
    if (username.isEmpty || RegExp(r'\s').hasMatch(username)) return;
    _usernameDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _checkUsername(username),
    );
  }

  Future<void> _checkUsername(String username) async {
    setState(() => _checkingUsername = true);
    try {
      final available = await context.read<AuthProvider>().isUsernameAvailable(
        username,
      );
      if (!mounted || username != _username) return;
      setState(() {
        _usernameAvailable = available;
        _checkedUsername = username;
      });
    } catch (_) {
      // The check is a convenience; submitting still validates on the backend.
    } finally {
      if (mounted && username == _username) {
        setState(() => _checkingUsername = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    await auth.completeProfile(
      fullName: _fullNameCtrl.text.trim(),
      username: _username,
      age: int.parse(_ageCtrl.text.trim()),
      userType: _userType,
      organization: _organizationCtrl.text.trim().isEmpty
          ? null
          : _organizationCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: isDark ? AppColors.dark900 : AppColors.gray50,
      appBar: AppBar(
        title: const Text('Complete Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: auth.isLoading ? null : auth.cancelSignup,
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Just a few more details to get you started!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (auth.error != null) ...[
                    ErrorBanner(auth.error!),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _fullNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameCtrl,
                    autocorrect: false,
                    onChanged: _onUsernameChanged,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      prefixText: '@',
                      suffixIcon: _usernameSuffix(),
                    ),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Required';
                      if (RegExp(r'\s').hasMatch(value)) {
                        return 'No spaces allowed';
                      }
                      if (value.length > 30) return 'At most 30 characters';
                      if (_usernameAvailable == false &&
                          _checkedUsername == value.toLowerCase()) {
                        return 'Username is already taken';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _ageCtrl,
                    decoration: const InputDecoration(labelText: 'Age'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final age = int.tryParse((v ?? '').trim());
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (age == null) return 'Must be a number';
                      if (age < 1 || age > 120) {
                        return 'Enter an age from 1 to 120';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _organizationCtrl,
                    maxLength: 255,
                    decoration: const InputDecoration(
                      labelText: 'University or Company (Optional)',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'I am a:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _RoleCard(
                          title: 'Student',
                          imagePath: 'assets/images/student.png',
                          isSelected: _userType == UserType.student,
                          onTap: () =>
                              setState(() => _userType = UserType.student),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _RoleCard(
                          title: 'Employee',
                          imagePath: 'assets/images/employee.png',
                          isSelected: _userType == UserType.employee,
                          onTap: () =>
                              setState(() => _userType = UserType.employee),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  GradientButton(
                    label: auth.isLoading ? 'Saving...' : 'Complete Setup',
                    icon: Icons.check_circle_outline,
                    onTap: auth.isLoading ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _usernameSuffix() {
    if (_checkingUsername) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_usernameAvailable == true && _checkedUsername == _username) {
      return const Icon(Icons.check_circle_rounded, color: AppColors.green500);
    }
    if (_usernameAvailable == false && _checkedUsername == _username) {
      return const Icon(Icons.cancel_rounded, color: AppColors.red500);
    }
    return null;
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String imagePath;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.imagePath,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.purple600.withAlpha(20)
              : (isDark ? AppColors.dark800 : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.purple600
                : (isDark ? AppColors.dark600 : AppColors.gray200),
            width: 2,
          ),
          boxShadow: isDark || isSelected
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                imagePath,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? AppColors.purple600
                    : (isDark ? Colors.white : AppColors.gray800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
