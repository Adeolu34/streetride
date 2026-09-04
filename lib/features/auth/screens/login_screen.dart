import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/session_service.dart';
import '../providers/auth_provider.dart';
import '../../../shared/widgets/sr_button.dart';
import '../../../shared/widgets/sr_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneCtr = TextEditingController();
  final _passCtr = TextEditingController();
  bool _obscure = true;
  bool _rememberMe = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final saved = await SessionService.instance.loadCredentials();
    if (saved != null && mounted) {
      setState(() {
        _phoneCtr.text = saved.phone;
        _passCtr.text = saved.password;
        _rememberMe = true;
      });
    }
  }

  @override
  void dispose() {
    _phoneCtr.dispose();
    _passCtr.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneCtr.text.trim();
    final pass = _passCtr.text.trim();
    if (phone.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    setState(() => _error = null);

    final result = await ref.read(authProvider.notifier).signIn(
          phone: phone,
          password: pass,
        );

    if (!mounted) return;
    if (result.error != null) {
      setState(() => _error = result.error);
      return;
    }

    if (_rememberMe) {
      await SessionService.instance.saveCredentials(phone, pass);
    } else {
      await SessionService.instance.clearCredentials();
    }

    context.go(result.isDriver! ? '/driver-home' : '/home');
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
              const SizedBox(height: 24),
              const Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: SRColors.ink900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Sign in to continue your journey. We'll text a 6-digit code to verify your number.",
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: SRColors.ink500,
                ),
              ),
              const SizedBox(height: 36),
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
                hint: '••••••••',
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
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _rememberMe = !_rememberMe),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (v) => setState(() => _rememberMe = v ?? false),
                            activeColor: SRColors.purple700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Remember me',
                          style: TextStyle(
                            fontSize: 13,
                            color: SRColors.ink500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: SRColors.purple700,
                      ),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
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
                            fontSize: 13,
                            color: SRColors.coral600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.lock_rounded,
                      size: 14, color: SRColors.green600),
                  const SizedBox(width: 6),
                  Text(
                    'Your number stays private.',
                    style: TextStyle(fontSize: 12, color: SRColors.ink500),
                  ),
                ],
              ),
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
            Text(
              "By continuing you agree to STREETRIDE's Terms & Privacy Policy.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: SRColors.ink500, height: 1.5),
            ),
            const SizedBox(height: 12),
            SRButton(
              label: 'Continue',
              icon: Icons.arrow_forward_rounded,
              isLoading: isLoading,
              onTap: _submit,
            ),
            const SizedBox(height: 16),
            Row(children: [
              const Expanded(child: Divider(color: SRColors.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('or',
                    style: TextStyle(fontSize: 12, color: SRColors.ink500)),
              ),
              const Expanded(child: Divider(color: SRColors.border)),
            ]),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => context.push('/signup?driver=false'),
              child: const Text(
                "Don't have an account? Sign up",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: SRColors.purple700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
