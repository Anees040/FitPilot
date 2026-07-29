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
  String? _errorText;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
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
        String msg = 'An error occurred';
        if (e is AuthFailure) msg = e.message;
        setState(() => _errorText = msg);
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

              AppTextField(
                label: 'EMAIL',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) {
                  if (_errorText != null) setState(() => _errorText = null);
                },
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'PASSWORD',
                controller: _passCtrl,
                obscureText: true,
                errorText: _errorText,
                onChanged: (_) {
                  if (_errorText != null) setState(() => _errorText = null);
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
