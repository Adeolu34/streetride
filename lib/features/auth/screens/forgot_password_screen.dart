import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/auth_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/sr_button.dart';
import '../../../shared/widgets/sr_text_field.dart';
import '../providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  final String initialPhone;

  const ForgotPasswordScreen({
    super.key,
    this.initialPhone = '',
  });

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final TextEditingController _phoneCtr;
  String? _error;

  @override
  void initState() {
    super.initState();
    // If initial phone starts with 234 or +234, format nicely for input
    var raw = widget.initialPhone.trim();
    if (raw.startsWith('+234')) {
      raw = raw.substring(4);
    } else if (raw.startsWith('234')) {
      raw = raw.substring(3);
    } else if (raw.startsWith('0') && raw.length == 11) {
      raw = raw.substring(1);
    }
    _phoneCtr = TextEditingController(text: raw);
  }

  @override
  void dispose() {
    _phoneCtr.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final rawPhone = _phoneCtr.text.trim();
    if (rawPhone.isEmpty) {
      setState(() => _error = 'Please enter your phone number.');
      return;
    }

    final normalized = AuthApi.normalizeResetPhone(rawPhone);
    if (normalized.length != 11 || !normalized.startsWith('0')) {
      setState(() => _error = 'Please enter a valid 11-digit Nigerian phone number.');
      return;
    }

    setState(() => _error = null);

    final result = await ref
        .read(authProvider.notifier)
        .requestPasswordResetOtp(phone: normalized);

    if (!mounted) return;

    if (result.error != null) {
      setState(() => _error = result.error);
      return;
    }

    // Success — navigate to Reset Password screen with normalized phone
    context.push(
      '/reset-password',
      extra: {'phone': normalized},
    );
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
              const SizedBox(height: 32),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [SRColors.purple700, SRColors.purple600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: SRColors.purple700.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Forgot password?',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: SRColors.ink900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Don't worry, it happens! Enter your registered phone number and we'll send you a 6-digit recovery code.",
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: SRColors.ink500,
                ),
              ),
              const SizedBox(height: 36),

              // ── Phone Input ──────────────────────────────────────────────
              const Text(
                'Phone number',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: SRColors.ink700,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: SRColors.border, width: 1.5),
                      borderRadius: BorderRadius.circular(15),
                      color: SRColors.white,
                    ),
                    child: const Row(
                      children: [
                        Text('🇳🇬', style: TextStyle(fontSize: 18)),
                        SizedBox(width: 6),
                        Text(
                          '+234',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: SRColors.ink900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SRTextField(
                      controller: _phoneCtr,
                      hint: '803 123 4567',
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
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

              const SizedBox(height: 32),
              SRButton(
                label: 'Send Recovery Code',
                isLoading: isLoading,
                onTap: _submit,
              ),

              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: () => context.pop(),
                  child: const Text(
                    'Remember your password? Sign In',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: SRColors.purple700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
