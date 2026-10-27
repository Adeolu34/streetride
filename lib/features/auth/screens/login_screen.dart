import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/biometric_service.dart';
import '../providers/auth_provider.dart';
import '../../../shared/widgets/sr_button.dart';
import '../../../shared/widgets/sr_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneCtr = TextEditingController();
  final _passCtr = TextEditingController();
  bool _obscure = true;
  bool _rememberMe = false;
  String? _error;

  bool _biometricSupported = false;
  bool _biometricEnabled = false;
  List<BiometricType> _biometricTypes = [];

  late final AnimationController _bioBtnCtrl;
  late final Animation<double> _bioBtnScale;

  @override
  void initState() {
    super.initState();
    _bioBtnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _bioBtnScale = Tween(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _bioBtnCtrl, curve: Curves.easeIn),
    );
    _loadSavedCredentials();
    _checkBiometric();
  }

  @override
  void dispose() {
    _phoneCtr.dispose();
    _passCtr.dispose();
    _bioBtnCtrl.dispose();
    super.dispose();
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

  Future<void> _checkBiometric() async {
    final bio = BiometricService.instance;
    final supported = await bio.isSupported();
    final enabled = await bio.isEnabled();
    final types = supported ? await bio.availableTypes() : <BiometricType>[];
    if (mounted) {
      setState(() {
        _biometricSupported = supported;
        _biometricEnabled = enabled;
        _biometricTypes = types;
      });
    }
    // If biometric is set up and credentials are saved, auto-trigger
    if (supported && enabled) {
      final saved = await SessionService.instance.loadCredentials();
      if (saved != null && mounted) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) _triggerBiometric();
      }
    }
  }

  bool get _hasFace =>
      _biometricTypes.contains(BiometricType.face);

  IconData get _bioIcon =>
      _hasFace ? Icons.face_rounded : Icons.fingerprint_rounded;

  String get _bioLabel =>
      _hasFace ? 'Use Face ID' : 'Use fingerprint';

  Future<void> _triggerBiometric() async {
    final bio = BiometricService.instance;
    final authenticated = await bio.authenticate();
    if (!authenticated || !mounted) return;

    final saved = await SessionService.instance.loadCredentials();
    if (saved == null) {
      if (mounted) setState(() => _error = 'No saved credentials. Please log in with your password.');
      return;
    }

    setState(() => _error = null);
    final result = await ref.read(authProvider.notifier).signIn(
          phone: saved.phone,
          password: saved.password,
        );
    if (!mounted) return;
    if (result.error != null) {
      setState(() => _error = result.error);
      return;
    }
    context.go(result.isDriver! ? '/driver-home' : '/home');
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

    // After successful login, offer to enable biometrics if supported and not yet enabled
    if (_biometricSupported && !_biometricEnabled && _rememberMe && mounted) {
      await _promptEnableBiometric();
    }

    if (!mounted) return;
    context.go(result.isDriver! ? '/driver-home' : '/home');
  }

  Future<void> _promptEnableBiometric() async {
    final label = _hasFace ? 'Face ID' : 'Fingerprint';
    final icon = _bioIcon;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [SRColors.purple700, SRColors.purple600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: SRColors.purple700.withValues(alpha: 0.30),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              'Enable $label login?',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: SRColors.ink900),
            ),
            const SizedBox(height: 10),
            Text(
              'Sign in instantly next time without typing your password.',
              style: const TextStyle(
                  fontSize: 14, color: SRColors.ink500, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(icon, size: 18),
                label: Text('Enable $label'),
                onPressed: () async {
                  await BiometricService.instance.setEnabled(true);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Not now'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;
    final showBioButton = _biometricSupported;

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
                  child: const Icon(Icons.arrow_back_rounded, color: SRColors.ink900),
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
                    fontSize: 26, fontWeight: FontWeight.w800, color: SRColors.ink900),
              ),
              const SizedBox(height: 8),
              const Text(
                "Sign in to continue your journey.",
                style: TextStyle(fontSize: 14, height: 1.5, color: SRColors.ink500),
              ),
              const SizedBox(height: 36),

              // ── Phone field ──────────────────────────────────────────────
              const Text('Phone number',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SRColors.ink700)),
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
                        Text('+234',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: SRColors.ink900)),
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

              // ── Password field ───────────────────────────────────────────
              const SizedBox(height: 16),
              const Text('Password',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SRColors.ink700)),
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
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _rememberMe = !_rememberMe),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
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
                                  borderRadius: BorderRadius.circular(4)),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('Remember me',
                              style: TextStyle(fontSize: 13, color: SRColors.ink500)),
                        ],
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        final currentPhone = _phoneCtr.text.trim();
                        context.push(
                          currentPhone.isNotEmpty
                              ? '/forgot-password?phone=${Uri.encodeComponent(currentPhone)}'
                              : '/forgot-password',
                          extra: {'phone': currentPhone},
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: SRColors.purple700,
                          ),
                        ),
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
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: SRColors.coral500, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(fontSize: 13, color: SRColors.coral600)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.lock_rounded, size: 14, color: SRColors.green600),
                  const SizedBox(width: 6),
                  const Text('Your number stays private.',
                      style: TextStyle(fontSize: 12, color: SRColors.ink500)),
                ],
              ),

              // ── Biometric quick-access card ──────────────────────────────
              if (showBioButton) ...[
                const SizedBox(height: 24),
                _BiometricCard(
                  icon: _bioIcon,
                  label: _bioLabel,
                  onTap: _triggerBiometric,
                  scale: _bioBtnScale,
                  ctrl: _bioBtnCtrl,
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
            const Text(
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
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => context.push('/signup?driver=false'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    "Don't have an account? Sign up",
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: SRColors.purple700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Biometric quick-access card ───────────────────────────────────────────────

class _BiometricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Animation<double> scale;
  final AnimationController ctrl;

  const _BiometricCard({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.scale,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => ctrl.forward(),
      onTapUp: (_) { ctrl.reverse(); onTap(); },
      onTapCancel: () => ctrl.reverse(),
      child: ScaleTransition(
        scale: scale,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: SRColors.purple700.withValues(alpha: 0.25), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: SRColors.purple700.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [SRColors.purple700, SRColors.purple600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: SRColors.purple700.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700, color: SRColors.ink900),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tap to sign in instantly',
                      style: TextStyle(fontSize: 12, color: SRColors.ink500),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: SRColors.purple700, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
