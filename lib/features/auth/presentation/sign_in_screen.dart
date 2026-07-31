import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/application/providers/auth_provider.dart';
import 'package:fitpilot/application/providers/sync_provider.dart';
import 'package:fitpilot/domain/entities/auth_failure.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/app_text_field.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // G3.1 — per-field inline validation errors
  String? _emailError;
  String? _passwordError;
  String? _formError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // G3.1 — client-side validation
  bool _validate() {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    String? emailErr;
    String? passErr;

    if (email.isEmpty) {
      emailErr = 'Enter your email';
    } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      emailErr = 'Enter a valid email address';
    }

    if (password.isEmpty) {
      passErr = 'Enter your password';
    }

    setState(() {
      _emailError = emailErr;
      _passwordError = passErr;
    });

    return emailErr == null && passErr == null;
  }

  // G3.4 — friendly error mapping
  String _mapError(Object e) {
    if (e is RateLimitedFailure) return 'Too many attempts, wait a minute.';
    if (e is NetworkUnavailableFailure) return 'No connection.';
    if (e is InvalidCredentialsFailure) return 'Email or password is incorrect.';
    if (e is AuthFailure) return e.message;
    return 'An error occurred. Please try again.';
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() {
      _isLoading = true;
      _formError = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: _emailCtrl.text.trim(), password: _passCtrl.text);

      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
        final merger = ref.read(guestMergeServiceProvider);
        await merger?.mergeGuestData(user.id);
        if (mounted) {
          context.go('/today');
        }
      }
    } on UnverifiedEmailFailure catch (_) {
      if (mounted) {
        context.push('/otp', extra: _emailCtrl.text.trim());
      }
    } catch (e) {
      if (mounted) {
        setState(() => _formError = _mapError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome back', style: theme.textTheme.h2),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Segmented Control
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: ext.hairline,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        margin: const EdgeInsets.all(2),
                        alignment: Alignment.center,
                        child: Text(
                          'Log in',
                          style: theme.textTheme.bodyStrong,
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.pushReplacement('/signup'),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Sign up',
                            style: theme.textTheme.bodyStrong.copyWith(color: theme.textTheme.caption.color),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // G3.1 — email with inline validation
              AppTextField(
                label: 'EMAIL',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                errorText: _emailError,
                onChanged: (_) {
                  if (_emailError != null || _formError != null) {
                    setState(() {
                      _emailError = null;
                      _formError = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // G3.2 — password with eye toggle
              AppTextField(
                label: 'PASSWORD',
                controller: _passCtrl,
                obscureText: _obscurePassword,
                errorText: _passwordError ?? _formError,
                trailing: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: theme.textTheme.caption.color,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                onChanged: (_) {
                  if (_passwordError != null || _formError != null) {
                    setState(() {
                      _passwordError = null;
                      _formError = null;
                    });
                  }
                },
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TertiaryButton(
                  label: 'Forgot password?',
                  onPressed: () => context.push('/forgot-password'),
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),

              PrimaryButton(
                label: 'Log in',
                onPressed: _submit,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
