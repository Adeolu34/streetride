import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/sr_button.dart';
import '../../../shared/widgets/sr_text_field.dart';
import '../providers/auth_provider.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String phone;

  const ResetPasswordScreen({
    super.key,
    required this.phone,
  });

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final List<TextEditingController> _otpCtrs =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

  final _newPassCtr = TextEditingController();
  final _confirmPassCtr = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;

  String? _error;
  int _resendSeconds = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendSeconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds == 0) {
        t.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  String get _otp => _otpCtrs.map((c) => c.text).join();

  void _onOtpChanged(String val, int i) {
    if (val.isNotEmpty && i < 5) {
      _nodes[i + 1].requestFocus();
    } else if (val.isEmpty && i > 0) {
      _nodes[i - 1].requestFocus();
    }
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0) return;
    setState(() => _error = null);

    final result = await ref
        .read(authProvider.notifier)
        .requestPasswordResetOtp(phone: widget.phone);

    if (!mounted) return;

    if (result.error != null) {
      setState(() => _error = result.error);
      return;
    }

    _startTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('A fresh recovery code has been sent to your phone.'),
        backgroundColor: SRColors.green600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submit() async {
    final otp = _otp.trim();
    final newPass = _newPassCtr.text.trim();
    final confirmPass = _confirmPassCtr.text.trim();

    if (otp.length < 6) {
      setState(() => _error = 'Please enter the complete 6-digit recovery code.');
      return;
    }

    if (newPass.isEmpty || confirmPass.isEmpty) {
      setState(() => _error = 'Please fill in both password fields.');
      return;
    }

    if (newPass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters long.');
      return;
    }

    if (newPass != confirmPass) {
      setState(() => _error = 'Passwords do not match. Please verify.');
      return;
    }

    setState(() => _error = null);

    final result = await ref.read(authProvider.notifier).resetPassword(
          phone: widget.phone,
          otp: otp,
          newPassword: newPass,
        );

    if (!mounted) return;

    if (result.error != null) {
      setState(() => _error = result.error);
      return;
    }

    // Success dialog
    _showSuccessDialog();
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: SRColors.green100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: SRColors.green600,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Password Reset!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: SRColors.ink900,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your password has been successfully updated. You can now sign in with your new credentials.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: SRColors.ink500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SRColors.purple700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go('/login');
                },
                child: const Text(
                  'Back to Sign In',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _otpCtrs) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    _newPassCtr.dispose();
    _confirmPassCtr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      backgroundColor: SRColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: SRColors.lavenderBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: SRColors.ink900,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: SRColors.purple100,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.key_rounded,
                  color: SRColors.purple700,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Create new password',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: SRColors.ink900,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  text: 'Enter the 6-digit code sent to ',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: SRColors.ink500,
                  ),
                  children: [
                    TextSpan(
                      text: widget.phone,
                      style: const TextStyle(
                        color: SRColors.ink900,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const TextSpan(
                      text: ' along with your new password.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── 6-Digit OTP Fields ──────────────────────────────────────
              const Text(
                'Recovery code (OTP)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: SRColors.ink700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  6,
                  (i) => SizedBox(
                    width: 46,
                    height: 56,
                    child: TextField(
                      controller: _otpCtrs[i],
                      focusNode: _nodes[i],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: SRColors.ink900,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: SRColors.border,
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: SRColors.border,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: SRColors.purple700,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (v) => _onOtpChanged(v, i),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _resend,
                  child: Text(
                    _resendSeconds > 0
                        ? 'Resend code in ${_resendSeconds}s'
                        : 'Resend code',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _resendSeconds > 0
                          ? SRColors.ink500
                          : SRColors.purple700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── New Password Field ──────────────────────────────────────
              const Text(
                'New password',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: SRColors.ink700,
                ),
              ),
              const SizedBox(height: 8),
              SRTextField(
                controller: _newPassCtr,
                hint: '••••••••',
                obscureText: _obscureNew,
                suffix: GestureDetector(
                  onTap: () => setState(() => _obscureNew = !_obscureNew),
                  child: Icon(
                    _obscureNew
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: SRColors.ink500,
                    size: 20,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Confirm Password Field ──────────────────────────────────
              const Text(
                'Confirm new password',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: SRColors.ink700,
                ),
              ),
              const SizedBox(height: 8),
              SRTextField(
                controller: _confirmPassCtr,
                hint: '••••••••',
                obscureText: _obscureConfirm,
                suffix: GestureDetector(
                  onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  child: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: SRColors.ink500,
                    size: 20,
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SRColors.coral100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: SRColors.coral500,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: SRColors.coral600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 36),
              SRButton(
                label: 'Update Password',
                isLoading: isLoading,
                onTap: _submit,
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
