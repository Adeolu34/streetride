import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../../../shared/widgets/sr_button.dart';
import '../../../shared/widgets/sr_text_field.dart';

class SignupScreen extends ConsumerStatefulWidget {
  final bool isDriver;
  const SignupScreen({super.key, required this.isDriver});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _firstCtr = TextEditingController();
  final _surnameCtr = TextEditingController();
  final _phoneCtr = TextEditingController();
  final _passCtr = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _firstCtr.dispose();
    _surnameCtr.dispose();
    _phoneCtr.dispose();
    _passCtr.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final first = _firstCtr.text.trim();
    final surname = _surnameCtr.text.trim();
    final phone = _phoneCtr.text.trim();
    final pass = _passCtr.text.trim();

    if (first.isEmpty || surname.isEmpty || phone.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    setState(() => _error = null);

    final result = await ref.read(authProvider.notifier).register(
      phone: phone,
      firstName: first,
      surname: surname,
      password: pass,
    );
    if (!mounted) return;
    if (result.error != null) {
      setState(() => _error = result.error);
      return;
    }

    context.push('/otp', extra: {
      'phone': phone,
      'isDriver': widget.isDriver,
      'isSignup': true,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;
    final label = widget.isDriver ? 'Driver' : 'Rider';

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
                  child: const Icon(Icons.arrow_back_rounded,
                      color: SRColors.ink900),
                ),
              ),
              const SizedBox(height: 28),
              Image.asset(
                'assets/images/streetridelogo.jpeg',
                height: 36,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: SRColors.purple100,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'Signing up as $label',
                  style: const TextStyle(
                    color: SRColors.purple700,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Create your account',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: SRColors.ink900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "We'll send a verification code to your phone number.",
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: SRColors.ink500,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      label: 'First name',
                      controller: _firstCtr,
                      hint: 'Emeka',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      label: 'Surname',
                      controller: _surnameCtr,
                      hint: 'Obi',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              const Text(
                'Password',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: SRColors.ink700,
                ),
              ),
              const SizedBox(height: 8),
              SRTextField(
                controller: _passCtr,
                hint: 'At least 6 characters',
                obscureText: _obscure,
                suffix: GestureDetector(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Icon(
                    _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: SRColors.ink500,
                    size: 20,
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
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
            24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SRButton(
              label: 'Send OTP',
              icon: Icons.arrow_forward_rounded,
              isLoading: isLoading,
              onTap: _submit,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => context.push('/login'),
              child: RichText(
                text: const TextSpan(
                  text: 'Already have an account?  ',
                  style: TextStyle(
                    fontSize: 14,
                    color: SRColors.ink500,
                  ),
                  children: [
                    TextSpan(
                      text: 'Log in',
                      style: TextStyle(
                        color: SRColors.purple700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: SRColors.ink700,
          ),
        ),
        const SizedBox(height: 8),
        SRTextField(controller: controller, hint: hint),
      ],
    );
  }
}
