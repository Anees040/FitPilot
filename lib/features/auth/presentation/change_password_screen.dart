import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/application/providers/auth_provider.dart';
import 'package:fitpilot/domain/entities/auth_failure.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/app_text_field.dart';
import 'package:fitpilot/core/ui/states.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _isLoading = false;
  bool _success = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _errorText;

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final currentPass = _currentPassCtrl.text;
    final newPass = _newPassCtrl.text;
    final confirmPass = _confirmPassCtrl.text;

    if (currentPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      setState(() => _errorText = 'All fields are required.');
      return;
    }

    if (newPass != confirmPass) {
      setState(() => _errorText = 'New passwords do not match.');
      return;
    }

    final hasLength = newPass.length >= 8;
    final hasUpper = newPass.contains(RegExp(r'[A-Z]'));
    final hasLower = newPass.contains(RegExp(r'[a-z]'));
    final hasNumber = newPass.contains(RegExp(r'[0-9]'));
    final hasSpecial = newPass.contains(RegExp(r'[\W_]'));

    if (!hasLength || !hasUpper || !hasLower || !hasNumber || !hasSpecial) {
      setState(() => _errorText = 'New password does not meet complexity requirements.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null && user.email.isNotEmpty) {
        // Re-authenticate user with current password
        await ref.read(authRepositoryProvider).signIn(
          email: user.email,
          password: currentPass,
        );
      }

      await ref.read(authRepositoryProvider).updatePassword(newPassword: newPass);
      if (mounted) {
        setState(() => _success = true);
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to change password.';
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

    if (_success) {
      return Scaffold(
        appBar: AppBar(title: const Text('Change Password')),
        body: SafeArea(
          child: EmptyState(
            message: 'Your password has been successfully updated.',
            buttonLabel: 'Back to Settings',
            onAction: () => context.pop(),
            illustration: 'success_check',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Change Password', style: theme.textTheme.h2),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Update your password below.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 24),
            AppTextField(
              label: 'Current Password',
              controller: _currentPassCtrl,
              obscureText: _obscureCurrent,
              trailing: IconButton(
                icon: Icon(
                  _obscureCurrent ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'New Password',
              controller: _newPassCtrl,
              obscureText: _obscureNew,
              trailing: IconButton(
                icon: Icon(
                  _obscureNew ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Confirm New Password',
              controller: _confirmPassCtrl,
              obscureText: _obscureConfirm,
              trailing: IconButton(
                icon: Icon(
                  _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Must be at least 8 characters with 1 uppercase, 1 lowercase, 1 digit, and 1 special character.',
              style: theme.textTheme.caption,
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorText!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 14),
              ),
            ],
            const SizedBox(height: 32),
            PrimaryButton(
              label: 'Update Password',
              isLoading: _isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
