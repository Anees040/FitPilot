import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/application/providers/auth_provider.dart';
import 'package:fitpilot/domain/entities/auth_failure.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/app_text_field.dart';
import 'package:fitpilot/core/ui/states.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;
  String? _errorText;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email: email);
      if (mounted) {
        setState(() => _sent = true);
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

    if (_sent) {
      return Scaffold(
        body: SafeArea(
          child: EmptyState(
            message: 'If an account exists, a reset link has been sent to your email.',
            buttonLabel: 'Back to Sign in',
            onAction: () => context.pop(),
            illustration: 'email_sent',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Reset Password', style: theme.textTheme.h2),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter your email and we\'ll send you a reset link.',
                style: theme.textTheme.body,
              ),
              const SizedBox(height: 32),

              AppTextField(
                label: 'EMAIL',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                errorText: _errorText,
                onChanged: (_) {
                  if (_errorText != null) setState(() => _errorText = null);
                },
              ),
              const SizedBox(height: 24),

              PrimaryButton(
                label: 'Send Link',
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
