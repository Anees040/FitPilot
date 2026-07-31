import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/application/providers/auth_provider.dart';
import 'package:fitpilot/domain/entities/auth_failure.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/app_text_field.dart';
import 'package:fitpilot/core/ui/app_card.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  // G3.2 — focus node to show checklist only when password field is focused
  final _passFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _emailError;
  String? _formError;

  bool _passwordFocused = false;
  bool _hasLength = false;
  bool _hasLetter = false;
  bool _hasNumber = false;

  @override
  void initState() {
    super.initState();
    _passFocusNode.addListener(() {
      setState(() => _passwordFocused = _passFocusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _passFocusNode.dispose();
    super.dispose();
  }

  void _validatePassword(String value) {
    setState(() {
      _hasLength = value.length >= 8;
      _hasLetter = RegExp(r'[a-zA-Z]').hasMatch(value);
      _hasNumber = RegExp(r'[0-9]').hasMatch(value);
    });
  }

  bool get _isPasswordValid => _hasLength && _hasLetter && _hasNumber;

  bool _validateForm() {
    final email = _emailCtrl.text.trim();
    String? emailErr;
    if (email.isEmpty) {
      emailErr = 'Enter your email';
    } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      emailErr = 'Enter a valid email address';
    }
    setState(() => _emailError = emailErr);
    return emailErr == null;
  }

  // G3.4 — friendly error mapping
  String _mapError(Object e) {
    if (e is RateLimitedFailure) return 'Too many attempts, wait a minute.';
    if (e is NetworkUnavailableFailure) return 'No connection.';
    if (e is EmailAlreadyRegisteredFailure) return 'That email is already registered. Try logging in.';
    if (e is AuthFailure) return e.message;
    return 'An error occurred. Please try again.';
  }

  Future<void> _submit() async {
    if (!_validateForm() || !_isPasswordValid) return;

    setState(() {
      _isLoading = true;
      _formError = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .signUp(email: _emailCtrl.text.trim(), password: _passCtrl.text);
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
        title: Text('Create your account', style: theme.textTheme.h2),
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
                      child: GestureDetector(
                        onTap: () => context.pushReplacement('/signin'),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Log in',
                            style: theme.textTheme.bodyStrong.copyWith(color: theme.textTheme.caption.color),
                          ),
                        ),
                      ),
                    ),
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
                          'Sign up',
                          style: theme.textTheme.bodyStrong,
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
                errorText: _emailError,
                onChanged: (_) {
                  if (_emailError != null) _validateForm();
                  if (_formError != null) setState(() => _formError = null);
                },
              ),
              const SizedBox(height: 16),

              // G3.2 — password with eye toggle + focus node
              AppTextField(
                label: 'PASSWORD',
                controller: _passCtrl,
                focusNode: _passFocusNode,
                obscureText: _obscurePassword,
                trailing: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: theme.textTheme.caption.color,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                onChanged: _validatePassword,
              ),
              const SizedBox(height: 12),

              // G3.2 — checklist shows only when password field is focused or has content
              if (_passwordFocused || _passCtrl.text.isNotEmpty) ...[
                _buildChecklistItem(context, 'Minimum 8 characters', _hasLength),
                _buildChecklistItem(context, 'At least one letter', _hasLetter),
                _buildChecklistItem(context, 'At least one number', _hasNumber),
                const SizedBox(height: 8),
              ],

              if (_formError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _formError!,
                  style: theme.textTheme.caption.copyWith(color: ext.error),
                ),
              ],

              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Sign up',
                onPressed: _submit,
                isLoading: _isLoading,
              ),

              const SizedBox(height: 24),
              AppCard(
                color: theme.scaffoldBackgroundColor,
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: ext.success, size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'We use this for auth and sync. No spam ever.',
                        style: theme.textTheme.caption,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChecklistItem(BuildContext context, String text, bool isMet) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isMet ? Icons.check_circle : Icons.radio_button_unchecked,
              key: ValueKey(isMet),
              size: 16,
              color: isMet ? ext.success : ext.hairline,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: theme.textTheme.caption.copyWith(
              color: isMet ? theme.textTheme.body.color : theme.textTheme.caption.color,
            ),
          ),
        ],
      ),
    );
  }
}
