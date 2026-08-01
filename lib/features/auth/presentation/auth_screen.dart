import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/application/providers/auth_provider.dart';
import 'package:fitpilot/application/providers/sync_provider.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/domain/entities/auth_failure.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/config/env.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/app_text_field.dart';
import 'package:fitpilot/application/providers/demo_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  final String? initialMode;
  
  const AuthScreen({super.key, this.initialMode});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late bool _isLogin;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
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
    _isLogin = widget.initialMode != 'signup';
    _passFocusNode.addListener(() {
      setState(() => _passwordFocused = _passFocusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
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
            
        final profile = ref.read(profileProvider).value;
        if (profile != null) {
          final repo = await ref.read(profileRepositoryProvider.future);
          await repo.save(
            profile.copyWith(name: _nameCtrl.text.trim()),
          );
        }
      }

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

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _formError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final isDemo = ref.watch(demoProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero Top
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.15),
                          theme.scaffoldBackgroundColor,
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => context.pop(),
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.0, 0.2),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: Text(
                              _isLogin ? 'Welcome\nback' : 'Create\naccount',
                              key: ValueKey(_isLogin),
                              style: theme.textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom Card
          Expanded(
            flex: 5,
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isDemo) _buildDemoBanner(theme, ext),
                        
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: !_isLogin
                              ? Column(
                                  children: [
                                    AppTextField(
                                      label: 'NAME',
                                      controller: _nameCtrl,
                                      keyboardType: TextInputType.name,
                                      validator: (val) {
                                        if (!_isLogin && (val == null || val.isEmpty)) {
                                          return 'Enter your name';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),

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

                        const SizedBox(height: 32),
                        
                        PrimaryButton(
                          label: _isLogin ? 'Log in' : 'Sign up',
                          onPressed: _submit,
                          isLoading: _isLoading,
                        ),

                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(child: Divider(color: ext.hairline)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'OR',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.textTheme.caption.color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: ext.hairline)),
                          ],
                        ),
                        const SizedBox(height: 24),

                        GoogleButton(
                          isLoading: _isLoading,
                          onPressed: _submitGoogle,
                        ),

                        const SizedBox(height: 32),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isLogin ? "Don't have an account? " : "Already have an account? ",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            GestureDetector(
                              onTap: _toggleMode,
                              child: Text(
                                _isLogin ? 'Sign up' : 'Log in',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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

