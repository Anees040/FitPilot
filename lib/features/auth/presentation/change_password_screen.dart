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
  final _formKey = GlobalKey<FormState>();
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
  void initState() {
    super.initState();
    _newPassCtrl.addListener(() => setState(() {}));
    _confirmPassCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final currentPass = _currentPassCtrl.text;
    final newPass = _newPassCtrl.text;
    final confirmPass = _confirmPassCtrl.text;

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
      setState(() => _errorText = 'New password does not meet all complexity requirements.');
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
        try {
          await ref.read(authRepositoryProvider).signIn(
            email: user.email,
            password: currentPass,
          );
        } catch (e) {
          if (mounted) {
            setState(() {
              _errorText = 'Incorrect current password. Please verify and try again.';
              _isLoading = false;
            });
          }
          return;
        }
      }

      await ref.read(authRepositoryProvider).updatePassword(newPassword: newPass);
      if (mounted) {
        setState(() => _success = true);
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to update password.';
        if (e is AuthFailure) msg = e.message;
        setState(() => _errorText = msg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildReqChip(String label, bool isMet, ThemeData theme) {
    final ext = theme.extension<AppColors>()!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isMet ? Icons.check_circle : Icons.circle_outlined,
          size: 14,
          color: isMet ? ext.success : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.caption.copyWith(
            color: isMet ? ext.success : theme.textTheme.bodySmall?.color,
            fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    if (_success) {
      return Scaffold(
        appBar: AppBar(title: const Text('Change Password')),
        body: SafeArea(
          child: EmptyState(
            message: 'Your password has been successfully updated.',
            buttonLabel: 'Back to Settings',
            onAction: () => context.pop(),
            illustration: 'phone_check',
          ),
        ),
      );
    }

    final newPass = _newPassCtrl.text;
    final confirmPass = _confirmPassCtrl.text;

    final hasLength = newPass.length >= 8;
    final hasUpper = newPass.contains(RegExp(r'[A-Z]'));
    final hasLower = newPass.contains(RegExp(r'[a-z]'));
    final hasNumber = newPass.contains(RegExp(r'[0-9]'));
    final hasSpecial = newPass.contains(RegExp(r'[\W_]'));

    final hasMatchText = confirmPass.isNotEmpty;
    final isMatch = hasMatchText && newPass == confirmPass;

    return Scaffold(
      appBar: AppBar(
        title: Text('Change Password', style: theme.textTheme.h2),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Update your account password below.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 24),
              AppTextField(
                label: 'Current Password',
                controller: _currentPassCtrl,
                obscureText: _obscureCurrent,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter your current password';
                  return null;
                },
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
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter a new password';
                  return null;
                },
                trailing: IconButton(
                  icon: Icon(
                    _obscureNew ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildReqChip('8+ chars', hasLength, theme),
                  _buildReqChip('1 uppercase', hasUpper, theme),
                  _buildReqChip('1 lowercase', hasLower, theme),
                  _buildReqChip('1 number', hasNumber, theme),
                  _buildReqChip('1 symbol', hasSpecial, theme),
                ],
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Confirm New Password',
                controller: _confirmPassCtrl,
                obscureText: _obscureConfirm,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please confirm your new password';
                  return null;
                },
                trailing: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              if (hasMatchText) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      isMatch ? Icons.check_circle : Icons.cancel,
                      size: 16,
                      color: isMatch ? ext.success : ext.error,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isMatch ? 'Passwords match' : 'Passwords do not match',
                      style: theme.textTheme.caption.copyWith(
                        color: isMatch ? ext.success : ext.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              if (_errorText != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ext.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ext.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: ext.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorText!,
                          style: TextStyle(color: ext.error, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
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
      ),
    );
  }
}
