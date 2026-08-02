import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/application/providers/auth_provider.dart';
import 'package:fitpilot/application/providers/sync_provider.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/domain/entities/auth_failure.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/config/env.dart';
import 'package:fitpilot/core/ui/buttons.dart';

class AuthScreen extends ConsumerStatefulWidget {
  final String? initialMode;

  const AuthScreen({super.key, this.initialMode});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late bool _isLogin;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialMode != 'signup';
    _passCtrl.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    if (!_isLogin && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.removeListener(_onPasswordChanged);
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  String _mapError(Object e) {
    if (e is RateLimitedFailure) return 'Too many attempts, wait a minute.';
    if (e is NetworkUnavailableFailure) return 'No connection.';
    if (e is EmailAlreadyRegisteredFailure) {
      return 'That email is already registered. Try logging in.';
    }
    if (e is InvalidCredentialsFailure) {
      return 'Email or password is incorrect.';
    }
    if (e is AuthFailure) return e.message;
    return 'An error occurred. Please try again.';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isLogin && !_agreedToTerms) {
      setState(() => _formError = 'You must agree to the Terms & Conditions.');
      return;
    }

    if (!_isLogin && _passCtrl.text != _confirmPassCtrl.text) {
      setState(() => _formError = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _formError = null;
    });

    try {
      if (_isLogin) {
        await ref
            .read(authRepositoryProvider)
            .signIn(email: _emailCtrl.text.trim(), password: _passCtrl.text);
      } else {
        await ref
            .read(authRepositoryProvider)
            .signUp(email: _emailCtrl.text.trim(), password: _passCtrl.text);

        final profile = ref.read(profileProvider).value;
        if (profile != null) {
          final repo = await ref.read(profileRepositoryProvider.future);
          await repo.save(profile.copyWith(name: _nameCtrl.text.trim()));
        }
      }

      if (!_isLogin) {
        if (mounted) context.push('/otp', extra: _emailCtrl.text.trim());
        return;
      }

      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
        final merger = ref.read(guestMergeServiceProvider);
        await merger?.mergeGuestData(user.id);
        if (mounted) context.go('/profile-setup');
      }
    } on UnverifiedEmailFailure catch (_) {
      if (mounted) context.push('/otp', extra: _emailCtrl.text.trim());
    } catch (e) {
      if (mounted) {
        if (e is EmailAlreadyRegisteredFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('That email is already registered. Try logging in.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        } else {
          setState(() => _formError = _mapError(e));
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitGoogle() async {
    setState(() {
      _isLoading = true;
      _formError = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .signInWithGoogle(webClientId: Env.googleWebClientId);

      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
        final merger = ref.read(guestMergeServiceProvider);
        await merger?.mergeGuestData(user.id);
        if (mounted) context.go('/profile-setup');
      }
    } catch (e) {
      if (mounted) setState(() => _formError = _mapError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showTermsDialog() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Terms & Conditions',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxHeight: 250),
                child: SingleChildScrollView(
                  child: Text(
                    'Welcome to FitPilot! These terms govern your use of the app...\n\n'
                    '1. Data Privacy\nYour data is stored securely. We do not sell your personal data.\n\n'
                    '2. Honest Tracking\nWe encourage honest tracking. Do not cheat yourself!\n\n'
                    '3. Health Disclaimer\nFitPilot is not a medical professional. Consult a doctor before starting any rigorous exercise.\n\n'
                    '(Mock Terms and Conditions for demonstration purposes.)',
                    style: TextStyle(color: theme.colorScheme.onSurface, height: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'I Accept',
                onPressed: () {
                  setState(() => _agreedToTerms = true);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }



  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _formError = null;
      _passCtrl.clear();
      _confirmPassCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0, top: 8.0),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
                    onPressed: () => context.pop(),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(alpha: 0.2),
                              width: 2,
                            ),
                          ),
                          child: Image.asset(
                            'assets/images/logo_mark_orange.png',
                            height: 48,
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, s) => Icon(Icons.fitness_center, size: 48, color: theme.colorScheme.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _isLogin ? 'Welcome back 👋' : 'Create account',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 32,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isLogin
                            ? 'Login to continue your journey'
                            : 'Let\'s get you started',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 32),

                      if (!_isLogin) ...[
                        _buildTextField(
                          controller: _nameCtrl,
                          hintText: 'Full Name',
                          icon: Icons.person_outline,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                      ],

                      _buildTextField(
                        controller: _emailCtrl,
                        hintText: _isLogin ? 'Email or Phone' : 'Email',
                        icon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (!_isLogin) {
                            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (!emailRegex.hasMatch(v.trim())) return 'Invalid email format';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _passCtrl,
                        hintText: 'Password',
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        onSuffixTap: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (!_isLogin) {
                            final hasLength = v.length >= 8;
                            final hasUpper = v.contains(RegExp(r'[A-Z]'));
                            final hasLower = v.contains(RegExp(r'[a-z]'));
                            final hasNumber = v.contains(RegExp(r'[0-9]'));
                            final hasSpecial = v.contains(RegExp(r'[\W_]'));
                            if (!hasLength || !hasUpper || !hasLower || !hasNumber || !hasSpecial) {
                              return 'Password does not meet requirements';
                            }
                          }
                          return null;
                        },
                      ),
                      
                      if (!_isLogin) _PasswordStrengthIndicator(password: _passCtrl.text),

                      if (!_isLogin) ...[
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _confirmPassCtrl,
                          hintText: 'Confirm Password',
                          icon: Icons.lock_outline,
                          obscureText: _obscureConfirmPassword,
                          onSuffixTap: () => setState(() =>
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (v != _passCtrl.text) return 'Passwords do not match';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _agreedToTerms,
                                onChanged: (val) => setState(
                                    () => _agreedToTerms = val ?? false),
                                activeColor: theme.colorScheme.primary,
                                side: BorderSide(color: theme.extension<AppColors>()!.hairline),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                  children: [
                                    const TextSpan(text: 'I agree to the '),
                                    TextSpan(
                                      text: 'Terms & Conditions',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = _showTermsDialog,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      if (_isLogin) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => context.push('/forgot-password'),
                            child: Text(
                              'Forgot Password?',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],

                      if (_formError != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _formError!,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.error),
                        ),
                      ],

                      const SizedBox(height: 24),

                      PrimaryButton(
                        label: _isLogin ? 'Login' : 'Sign Up',
                        isLoading: _isLoading,
                        onPressed: _submit,
                      ),

                      const SizedBox(height: 32),

                      Row(
                        children: [
                          Expanded(child: Divider(color: theme.extension<AppColors>()!.hairline)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'or continue with',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: theme.extension<AppColors>()!.hairline)),
                        ],
                      ),

                      const SizedBox(height: 24),

                      _SocialButton(
                        label: 'Continue with Google',
                        iconPath: 'assets/images/google_logo.png',
                        onPressed: _submitGoogle,
                      ),

                      if (_isLogin) ...[
                        const SizedBox(height: 12),
                        _SocialButton(
                          label: 'Continue as Guest',
                          icon: Icons.person_outline,
                          onPressed: () => context.go('/profile-setup'),
                        ),
                      ],

                      const SizedBox(height: 40),

                      Center(
                        child: GestureDetector(
                          onTap: _toggleMode,
                          child: Text.rich(
                            TextSpan(
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                              children: [
                                TextSpan(
                                  text: _isLogin
                                      ? "Don't have an account?  "
                                      : 'Already have an account?  ',
                                ),
                                TextSpan(
                                  text: _isLogin ? 'Sign up' : 'Login',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    VoidCallback? onSuffixTap,
  }) {
    final theme = Theme.of(context);
    
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      cursorColor: theme.colorScheme.primary,
      style: TextStyle(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
        prefixIcon: Icon(icon, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        suffixIcon: onSuffixTap != null
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                onPressed: onSuffixTap,
              )
            : null,
        filled: true,
        fillColor: theme.colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.extension<AppColors>()!.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.extension<AppColors>()!.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.error),
        ),
      ),
    );
  }
}

class _PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const _PasswordStrengthIndicator({required this.password});

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasLength = password.length >= 8;
    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasLower = password.contains(RegExp(r'[a-z]'));
    final hasNumber = password.contains(RegExp(r'[0-9]'));
    final hasSpecial = password.contains(RegExp(r'[\W_]'));
    
    int strength = 0;
    if (hasLength) strength++;
    if (hasUpper) strength++;
    if (hasLower) strength++;
    if (hasNumber) strength++;
    if (hasSpecial) strength++;

    final theme = Theme.of(context);
    Color color;
    if (strength <= 2) {
      color = theme.colorScheme.error;
    } else if (strength <= 4) {
      color = theme.extension<AppColors>()!.warning;
    } else {
      color = theme.extension<AppColors>()!.success;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(5, (index) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index < 4 ? 4 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: index < strength ? color : theme.extension<AppColors>()!.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            'Requires: 8+ chars, uppercase, lowercase, number, special char',
            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final String? iconPath;
  final IconData? icon;
  final VoidCallback onPressed;

  const _SocialButton({
    required this.label,
    this.iconPath,
    this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedScaleButton(
      onPressed: onPressed,
      child: Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.extension<AppColors>()!.hairline),
          color: theme.colorScheme.surface,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconPath != null)
              Image.asset(iconPath!, width: 24, height: 24)
            else if (icon != null)
              Icon(icon, size: 24, color: theme.colorScheme.onSurface),
            const SizedBox(width: 12),
            Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
