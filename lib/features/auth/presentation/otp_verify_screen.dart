import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/application/providers/auth_provider.dart';
import 'package:fitpilot/application/providers/sync_provider.dart';
import 'package:fitpilot/domain/entities/auth_failure.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/confirm_snackbar.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  final String email;
  const OtpVerifyScreen({super.key, required this.email});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;
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

  // G3.4 — friendly error mapping
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
        context.go('/today');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorText = _mapError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // G3.3 — resend actually calls the API
  Future<void> _resend() async {
    if (_resendCooldown > 0) return;

    try {
      await ref
          .read(authRepositoryProvider)
          .resendOtp(email: widget.email);
      _startCooldown();
      if (mounted) {
        confirmSnackbar(context, 'Verification code resent to ${widget.email}.');
      }
    } catch (e) {
      if (mounted) {
        confirmSnackbar(context, _mapError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: Text('Verify Email', style: theme.textTheme.h2),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // G3.3 — show email address and 'edit' link
              RichText(
                text: TextSpan(
                  style: theme.textTheme.body,
                  children: [
                    const TextSpan(text: 'Code sent to '),
                    TextSpan(
                      text: widget.email,
                      style: theme.textTheme.bodyStrong,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // G3.3 — 'edit' link goes back to sign-up/sign-in
              GestureDetector(
                onTap: () => context.pop(),
                child: Text(
                  'Wrong address? Edit',
                  style: theme.textTheme.caption.copyWith(
                    color: theme.colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // G3.3 — OTP boxes; validate ONLY on explicit Verify tap or auto-submit after 6th digit
              _OtpDigitBoxes(
                controller: _codeCtrl,
                hasError: _errorText != null,
                onChanged: (val) {
                  // Clear error when user edits
                  if (_errorText != null) setState(() => _errorText = null);
                  // G3.3 — auto-submit on 6th digit WITH loading spinner first
                  if (val.length == 6 && !_isLoading) {
                    // Trigger submit asynchronously — spinner shows before network call
                    Future.microtask(_submit);
                  }
                  setState(() {});
                },
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  style: theme.textTheme.caption.copyWith(color: ext.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),

              PrimaryButton(
                label: 'Verify',
                onPressed: _codeCtrl.text.length == 6 && !_isLoading ? _submit : null,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 16),

              TertiaryButton(
                label: _resendCooldown > 0
                    ? 'Resend in ${_resendCooldown}s'
                    : 'Resend code',
                onPressed: _resendCooldown == 0 ? _resend : null,
                color: _resendCooldown > 0
                    ? theme.textTheme.caption.color
                    : theme.colorScheme.primary,
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
    final ext = theme.extension<AppColors>()!;
    final isFocused = _focusNode.hasFocus;

    return Stack(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            final isFilled = index < text.length;
            final isCurrent = index == text.length && isFocused;

            return Container(
              width: 48,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.hasError
                      ? ext.error
                      : isCurrent
                          ? theme.colorScheme.primary
                          : ext.hairline,
                  width: isCurrent ? 2 : 1,
                ),
              ),
              child: Text(
                isFilled ? text[index] : '',
                style: theme.textTheme.h1.copyWith(
                  color: widget.hasError ? ext.error : theme.textTheme.display.color,
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
    );
  }
}
