import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../../../shared/widgets/sr_button.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  final bool isDriver;
  final bool isSignup;

  const OtpScreen({
    super.key,
    required this.phone,
    required this.isDriver,
    required this.isSignup,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _ctrs =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
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

  String get _otp => _ctrs.map((c) => c.text).join();

  void _onChanged(String val, int i) {
    if (val.isNotEmpty && i < 5) {
      _nodes[i + 1].requestFocus();
    } else if (val.isEmpty && i > 0) {
      _nodes[i - 1].requestFocus();
    }
    if (_otp.length == 6) _submit();
  }

  Future<void> _submit() async {
    if (_otp.length < 6) return;
    setState(() => _error = null);

    final result = await ref.read(authProvider.notifier).verifyOtp(
          phone: widget.phone,
          otp: _otp,
        );

    if (!mounted) return;
    if (result.error != null) {
      setState(() => _error = result.error);
      for (final c in _ctrs) {
        c.clear();
      }
      _nodes[0].requestFocus();
      return;
    }

    // isDriver comes back from the auto-login that happens after OTP verify
    final isDriver = result.isDriver ?? widget.isDriver;
    if (isDriver) {
      context.go('/kyc');
    } else {
      context.go('/home');
    }
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0) return;
    await ref.read(authProvider.notifier).requestOtp(phone: widget.phone);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrs) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      backgroundColor: SRColors.surface,
      body: SafeArea(
        child: Padding(
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
                  child: const Icon(Icons.arrow_back_rounded,
                      color: SRColors.ink900),
                ),
              ),
              const SizedBox(height: 36),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: SRColors.purple100,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.sms_rounded,
                    color: SRColors.purple700, size: 32),
              ),
              const SizedBox(height: 20),
              const Text(
                'Verify your number',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: SRColors.ink900,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  text: 'We sent a 6-digit code to ',
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
                  ],
                ),
              ),
              const SizedBox(height: 36),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  6,
                  (i) => SizedBox(
                    width: 46,
                    height: 56,
                    child: TextField(
                      controller: _ctrs[i],
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
                              color: SRColors.border, width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: SRColors.border, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: SRColors.amber500, width: 2),
                        ),
                      ),
                      onChanged: (v) => _onChanged(v, i),
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SRColors.coral100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: SRColors.coral500, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              fontSize: 13, color: SRColors.coral600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Center(
                child: GestureDetector(
                  onTap: _resend,
                  child: Text(
                    _resendSeconds > 0
                        ? 'Resend code in ${_resendSeconds}s'
                        : 'Resend code',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _resendSeconds > 0
                          ? SRColors.ink500
                          : SRColors.purple700,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              SRButton(
                label: 'Verify',
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
