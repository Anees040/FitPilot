import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/utils/require_online.dart';
import 'package:fitpilot/application/providers/auth_provider.dart';
import 'package:fitpilot/domain/entities/auth_failure.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/app_text_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!requireOnline(context, ref, feature: 'Reset Password')) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailCtrl.text.trim();

    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    
    final ext = Theme.of(context).extension<AppColors>()!;

    try {
      try {
        await ref.read(authRepositoryProvider).signIn(email: email, password: 'WRONG_PASSWORD_123_!');
      } catch (innerE) {
        if (innerE is InvalidCredentialsFailure) {
          // Email exists, proceed to send reset link
        } else if (innerE is RateLimitedFailure || innerE is NetworkUnavailableFailure) {
          rethrow;
        } else {
          if (!mounted) return;
          setState(() => _isLoading = false);
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Icon(Icons.error_outline, color: ext.error, size: 28),
                  const SizedBox(width: 12),
                  const Text('Account Not Found'),
                ],
              ),
              content: const Text(
                'There is no account registered with this email address. Please check the spelling or sign up for a new account.',
                style: TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          );
          return;
        }
      }

      await ref.read(authRepositoryProvider).sendPasswordReset(email: email);
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Icon(Icons.mark_email_read_outlined, color: ext.success, size: 28),
                const SizedBox(width: 12),
                const Text('Email Sent'),
              ],
            ),
            content: const Text(
              'A password reset link has been sent to your email. Please check your inbox and click the link to reset your password.',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // pop dialog
                  context.pop(); // pop screen
                },
                child: const Text('Back to Sign in', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        );
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


    return Scaffold(
      appBar: AppBar(
        title: Text('Reset Password', style: theme.textTheme.h2),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enter your email and we\'ll send you a reset link.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),

                AppTextField(
                  label: 'EMAIL',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  errorText: _errorText,
                  leading: const Icon(Icons.mail_outline),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter your email';
                    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                    if (!emailRegex.hasMatch(v.trim())) return 'Please enter a valid email';
                    return null;
                  },
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
      ),
    );
  }
}
