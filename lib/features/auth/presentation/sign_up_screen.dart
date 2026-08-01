import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/application/providers/auth_provider.dart';
import 'package:fitpilot/application/providers/sync_provider.dart';
import 'package:fitpilot/domain/entities/auth_failure.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/config/env.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/app_text_field.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/application/providers/demo_provider.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  // G3.2 — focus node to show checklist only when password field is focused
  final _passFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
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
  // G3.4 — friendly error mapping
  String _mapError(Object e) {
    if (e is RateLimitedFailure) return 'Too many attempts, wait a minute.';
    if (e is NetworkUnavailableFailure) return 'No connection.';
    if (e is EmailAlreadyRegisteredFailure) return 'That email is already registered. Try logging in.';
    if (e is AuthFailure) return e.message;
    return 'An error occurred. Please try again.';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || !_isPasswordValid) return;

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

  // G4 — Google Sign-in flow
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
        if (mounted) {
          context.go('/today');
        }
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
    final isDemo = ref.watch(demoProvider);

    return Scaffold(
      appBar: AppBar(elevation: 0, backgroundColor: Colors.transparent),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isDemo)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: ext.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ext.warning, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: ext.warning),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Demo Mode — Data will not be saved',
                            style: theme.textTheme.caption.copyWith(color: ext.warning, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Logo
                Center(
                  child: Image.asset(
                    'assets/images/logo_mark_orange.png',
                    height: 48,
                  ),
                ),
                const SizedBox(height: 16),
                // Title
                Text('Create your account', style: theme.textTheme.h2, textAlign: TextAlign.center),
                const SizedBox(height: 32),
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

              // G4: Google Sign-in button
              GoogleButton(
                isLoading: _isLoading,
                onPressed: _submitGoogle,
              ),
              
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Divider(color: ext.hairline)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or sign up with email',
                      style: theme.textTheme.caption,
                    ),
                  ),
                  Expanded(child: Divider(color: ext.hairline)),
                ],
              ),
              const SizedBox(height: 24),

              AppTextField(
                label: 'EMAIL',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter your email';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(val)) return 'Enter a valid email address';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // G3.2 — password with eye toggle + focus node
              AppTextField(
                label: 'PASSWORD',
                controller: _passCtrl,
                focusNode: _passFocusNode,
                obscureText: _obscurePassword,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter your password';
                  return _formError;
                },
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
