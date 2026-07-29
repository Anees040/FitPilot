import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/application/providers/auth_provider.dart';
import 'package:fitpilot/application/providers/sync_provider.dart';
import 'package:fitpilot/domain/entities/auth_failure.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/app_text_field.dart';
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
        String msg = 'An error occurred';
        if (e is AuthFailure) msg = e.message;
        setState(() => _errorText = msg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0) return;

    try {
      _startCooldown();
      if (mounted) {
        confirmSnackbar(context, 'Verification code resent.');
      }
    } catch (e) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              Text(
                'We sent a 6-digit code to ${widget.email}.',
                style: theme.textTheme.body,
              ),
              const SizedBox(height: 32),

              AppTextField(
                label: 'CODE',
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                errorText: _errorText,
                onChanged: (val) {
                  if (_errorText != null) setState(() => _errorText = null);
                  if (val.length == 6 && !_isLoading) _submit();
                },
              ),
              const SizedBox(height: 16),

              PrimaryButton(
                label: 'Verify',
                onPressed: _codeCtrl.text.length == 6 ? _submit : null,
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
