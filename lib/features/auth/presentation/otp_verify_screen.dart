import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/application/providers/auth_provider.dart';
import 'package:fitpilot/application/providers/sync_provider.dart';
import 'package:fitpilot/domain/entities/auth_failure.dart';
import 'package:fitpilot/core/ui/app_snackbar.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  final String email;
  const OtpVerifyScreen({super.key, required this.email});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorText;
  int _resendCooldown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown > 0) {
        setState(() => _resendCooldown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String _mapError(Object e) {
    if (e is RateLimitedFailure) return 'Too many attempts, wait a minute.';
    if (e is NetworkUnavailableFailure) return 'No connection.';
    if (e is InvalidCredentialsFailure) return "That code didn't match. Check the newest email.";
    if (e is AuthFailure) return e.message;
    return "That code didn't match. Check the newest email.";
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .verifyOtp(email: widget.email, token: code);

      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
        final merger = ref.read(guestMergeServiceProvider);
        await merger?.mergeGuestData(user.id);
      }

      if (mounted) {
        setState(() {
          _isSuccess = true;
        });
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) context.go('/profile-setup');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorText = _mapError(e));
      }
    } finally {
      if (mounted && !_isSuccess) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0) return;

    try {
      await ref
          .read(authRepositoryProvider)
          .resendOtp(email: widget.email);
      _startCooldown();
      if (mounted) {
        AppSnackbar.success(context, 'Verification code resent to ${widget.email}.');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, _mapError(e));
      }
    }
  }

  String get _formattedTime {
    final minutes = (_resendCooldown / 60).floor().toString().padLeft(2, '0');
    final seconds = (_resendCooldown % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Verify your email',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Enter the 6-digit code sent to',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.email,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Text(
                      'Change',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: theme.extension<AppColors>()!.warning),
                  const SizedBox(width: 4),
                  Text(
                    'Don\'t see it? Check your spam folder.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.extension<AppColors>()!.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              Center(
                child: _OtpDigitBoxes(
                  controller: _codeCtrl,
                  hasError: _errorText != null,
                  onChanged: (val) {
                    if (_errorText != null) setState(() => _errorText = null);
                    if (val.length == 6 && !_isLoading) {
                      Future.microtask(_submit);
                    }
                    setState(() {});
                  },
                ),
              ),
              
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    _errorText!,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              
              if (_isLoading)
                Center(
                  child: CircularProgressIndicator(color: theme.colorScheme.primary),
                )
              else if (_isSuccess)
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, size: 64, color: theme.extension<AppColors>()!.success),
                      const SizedBox(height: 8),
                      Text(
                        'Verified!',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.extension<AppColors>()!.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Center(
                  child: GestureDetector(
                    onTap: _resendCooldown == 0 ? _resend : null,
                    child: Text.rich(
                      TextSpan(
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: _resendCooldown > 0 
                              ? theme.colorScheme.onSurface.withValues(alpha: 0.6) 
                              : theme.colorScheme.primary,
                        ),
                        children: [
                          TextSpan(
                            text: _resendCooldown > 0 ? 'Resend code in ' : 'Resend code',
                          ),
                          if (_resendCooldown > 0)
                            TextSpan(
                              text: _formattedTime,
                              style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                
              const Spacer(),
              
              // Safe Data Card at bottom
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.extension<AppColors>()!.hairline),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.extension<AppColors>()!.success.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.verified_user_outlined, color: theme.extension<AppColors>()!.success),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your data is safe with us',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'We never share your personal\ninformation.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
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
}

class _OtpDigitBoxes extends StatefulWidget {
  final TextEditingController controller;
  final bool hasError;
  final ValueChanged<String> onChanged;

  const _OtpDigitBoxes({
    required this.controller,
    required this.hasError,
    required this.onChanged,
  });

  @override
  State<_OtpDigitBoxes> createState() => _OtpDigitBoxesState();
}

class _OtpDigitBoxesState extends State<_OtpDigitBoxes> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
    _focusNode.addListener(_update);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    _focusNode.removeListener(_update);
    _focusNode.dispose();
    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final theme = Theme.of(context);
    final isFocused = _focusNode.hasFocus;

    return SizedBox(
      width: double.infinity,
      height: 64,
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              final isFilled = index < text.length;
              final isCurrent = index == text.length && isFocused;

              return Container(
                width: 48,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.hasError
                        ? theme.colorScheme.error
                        : isCurrent || isFilled
                            ? theme.colorScheme.primary
                            : theme.extension<AppColors>()!.hairline,
                    width: isCurrent || isFilled ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  isFilled ? text[index] : '',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: widget.hasError ? theme.colorScheme.error : theme.colorScheme.onSurface,
                  ),
                ),
              );
            }),
          ),
          Positioned.fill(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              cursorColor: Colors.transparent,
              style: const TextStyle(color: Colors.transparent),
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
              ),
              onChanged: widget.onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
