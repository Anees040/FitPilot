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

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isLogin = true;

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
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
    if (_isLogin) return;
    setState(() {
      _hasLength = value.length >= 8;
      _hasLetter = RegExp(r'[a-zA-Z]').hasMatch(value);
      _hasNumber = RegExp(r'[0-9]').hasMatch(value);
    });
  }

  bool get _isPasswordValid => _isLogin || (_hasLength && _hasLetter && _hasNumber);

  String _mapError(Object e) {
    if (e is RateLimitedFailure) return 'Too many attempts, wait a minute.';
    if (e is NetworkUnavailableFailure) return 'No connection.';
    if (e is EmailAlreadyRegisteredFailure) return 'That email is already registered. Try logging in.';
    if (e is InvalidCredentialsFailure) return 'Email or password is incorrect.';
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
      if (_isLogin) {
        await ref
            .read(authRepositoryProvider)
            .signIn(email: _emailCtrl.text.trim(), password: _passCtrl.text);
      } else {
        await ref
            .read(authRepositoryProvider)
            .signUp(email: _emailCtrl.text.trim(), password: _passCtrl.text);
      }

      // Check if we need to verify email
      if (!_isLogin) {
        if (mounted) context.push('/otp', extra: _emailCtrl.text.trim());
        return;
      }

      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
        final merger = ref.read(guestMergeServiceProvider);
        await merger?.mergeGuestData(user.id);
        if (mounted) context.go('/today');
      }
    } on UnverifiedEmailFailure catch (_) {
      if (mounted) context.push('/otp', extra: _emailCtrl.text.trim());
    } catch (e) {
      if (mounted) setState(() => _formError = _mapError(e));
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
        if (mounted) context.go('/today');
      }
    } catch (e) {
      if (mounted) setState(() => _formError = _mapError(e));
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
                if (isDemo) _buildDemoBanner(theme, ext),
                
                // Logo
                Center(
                  child: Image.asset(
                    theme.brightness == Brightness.dark ? 'assets/images/logo_mark_white.png' : 'assets/images/logo_mark_orange.png',
                    height: 48,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Title with fade transition
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _isLogin ? 'Welcome back' : 'Create your account',
                    key: ValueKey(_isLogin),
                    style: theme.textTheme.h2,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Segmented Control
                _buildSegmentedControl(theme, ext),
                const SizedBox(height: 32),

                // Google Button
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
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _isLogin ? 'or log in with email' : 'or sign up with email',
                          key: ValueKey(_isLogin),
                          style: theme.textTheme.caption,
                        ),
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
                
                // Animated space for SignUp extras or Login extras
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: Column(
                    children: [
                      if (!_isLogin && (_passwordFocused || _passCtrl.text.isNotEmpty)) ...[
                        const SizedBox(height: 12),
                        _buildChecklistItem(context, 'Minimum 8 characters', _hasLength),
                        _buildChecklistItem(context, 'At least one letter', _hasLetter),
                        _buildChecklistItem(context, 'At least one number', _hasNumber),
                        const SizedBox(height: 8),
                      ],
                      if (_isLogin) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TertiaryButton(
                            label: 'Forgot password?',
                            onPressed: () => context.push('/forgot-password'),
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (_formError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _formError!,
                    style: theme.textTheme.caption.copyWith(color: ext.error),
                  ),
                ],

                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: PrimaryButton(
                    key: ValueKey(_isLogin),
                    label: _isLogin ? 'Log in' : 'Sign up',
                    onPressed: _submit,
                    isLoading: _isLoading,
                  ),
                ),

                const SizedBox(height: 24),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: !_isLogin
                      ? AppCard(
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
                        )
                      : const SizedBox.shrink(),
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

  Widget _buildSegmentedControl(ThemeData theme, AppColors ext) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: ext.hairline,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Animated Selection Box
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: _isLogin ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                margin: const EdgeInsets.all(2),
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
              ),
            ),
          ),
          // Text Labels
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (!_isLogin) {
                      setState(() {
                        _isLogin = true;
                        _formError = null;
                      });
                    }
                  },
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: theme.textTheme.bodyStrong.copyWith(
                        color: _isLogin ? theme.textTheme.body.color : theme.textTheme.caption.color,
                      ),
                      child: const Text('Log in'),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_isLogin) {
                      setState(() {
                        _isLogin = false;
                        _formError = null;
                      });
                    }
                  },
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: theme.textTheme.bodyStrong.copyWith(
                        color: !_isLogin ? theme.textTheme.body.color : theme.textTheme.caption.color,
                      ),
                      child: const Text('Sign up'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDemoBanner(ThemeData theme, AppColors ext) {
    return Container(
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
    );
  }
}
