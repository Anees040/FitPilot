import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/application/providers/auth_provider.dart';
import 'package:fitpilot/domain/entities/auth_failure.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/app_text_field.dart';
import 'package:fitpilot/core/ui/states.dart';

class UpdatePasswordScreen extends ConsumerStatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  ConsumerState<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends ConsumerState<UpdatePasswordScreen> {
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  
  bool _isLoading = false;
  bool _success = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorText;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pass = _passCtrl.text;
    final confirmPass = _confirmPassCtrl.text;
    
    if (pass.isEmpty || confirmPass.isEmpty) return;
    
    if (pass != confirmPass) {
      setState(() => _errorText = 'Passwords do not match.');
      return;
    }

    final hasLength = pass.length >= 8;
    final hasUpper = pass.contains(RegExp(r'[A-Z]'));
    final hasLower = pass.contains(RegExp(r'[a-z]'));
    final hasNumber = pass.contains(RegExp(r'[0-9]'));
    final hasSpecial = pass.contains(RegExp(r'[\W_]'));
    
    if (!hasLength || !hasUpper || !hasLower || !hasNumber || !hasSpecial) {
      setState(() => _errorText = 'Password does not meet requirements.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await ref.read(authRepositoryProvider).updatePassword(newPassword: pass);
      if (mounted) {
        setState(() => _success = true);
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

    if (_success) {
      return Scaffold(
        body: SafeArea(
          child: EmptyState(
            message: 'Your password has been successfully updated.',
            buttonLabel: 'Go to Log',
            onAction: () => context.go('/today'),
            illustration: 'success_check',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('New Password', style: theme.textTheme.h2),
        centerTitle: true,
        automaticallyImplyLeading: false, // User must finish or restart app
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Please enter your new password below.',
                style: theme.textTheme.body,
              ),
              const SizedBox(height: 32),

              AppTextField(
                label: 'NEW PASSWORD',
                controller: _passCtrl,
                leading: const Icon(Icons.lock_outline),
                obscureText: _obscurePassword,
                errorText: _errorText,
                trailing: GestureDetector(
                  onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                  child: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                ),
                onChanged: (_) {
                  if (_errorText != null) setState(() => _errorText = null);
                },
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'CONFIRM PASSWORD',
                controller: _confirmPassCtrl,
                leading: const Icon(Icons.lock_outline),
                obscureText: _obscureConfirmPassword,
                trailing: GestureDetector(
                  onTap: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  child: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                ),
                onChanged: (_) {
                  if (_errorText != null) setState(() => _errorText = null);
                },
              ),
              const SizedBox(height: 32),

              PrimaryButton(
                label: 'Update Password',
                onPressed: _isLoading ? null : _submit,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
