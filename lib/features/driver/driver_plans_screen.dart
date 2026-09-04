import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import 'providers/wallet_provider.dart';

class DriverPlansScreen extends ConsumerStatefulWidget {
  const DriverPlansScreen({super.key});

  @override
  ConsumerState<DriverPlansScreen> createState() => _DriverPlansScreenState();
}

class _DriverPlansScreenState extends ConsumerState<DriverPlansScreen> {
  bool _loading = false;
  String? _error;
  bool _awaitingReturn = false; // true while user is in the browser paying
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    // When user returns from Flutterwave browser, refresh wallet to check if paid
    _lifecycleListener = AppLifecycleListener(
      onResume: _onAppResumed,
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  Future<void> _onAppResumed() async {
    if (!_awaitingReturn) return;
    _awaitingReturn = false;
    setState(() => _loading = true);
    await ref.read(walletProvider.notifier).refresh();
    if (!mounted) return;
    setState(() => _loading = false);
    final wallet = ref.read(walletProvider).valueOrNull;
    if (wallet != null && !wallet.isExpired) {
      if (mounted) context.go('/driver-home');
    }
  }

  Future<void> _openPayment(String amount) async {
    setState(() { _loading = true; _error = null; });
    final (url, err) = await ref.read(walletProvider.notifier).getPaymentUrl(amount: amount);
    if (!mounted) return;

    if (url == null) {
      setState(() { _loading = false; _error = err ?? 'Could not initialize payment.'; });
      return;
    }

    setState(() => _loading = false);
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (launched) {
      setState(() => _awaitingReturn = true);
    } else {
      setState(() => _error = 'Could not open browser. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletProvider);
    final wallet = walletAsync.valueOrNull;
    final isExpired = wallet?.isExpired ?? false;
    final amountOwed = wallet?.amountOwed ?? '0';
    final balance = wallet?.balance ?? '0';
    final hasAmount = (double.tryParse(amountOwed) ?? 0) > 0;

    return Scaffold(
      backgroundColor: SRColors.lavenderBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.canPop() ? context.pop() : context.go('/driver-home'),
          child: const Icon(Icons.arrow_back_rounded, color: SRColors.ink900),
        ),
        title: const Text(
          'Wallet',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: SRColors.ink900),
        ),
        centerTitle: true,
      ),
      body: walletAsync.isLoading || _loading
          ? const Center(child: CircularProgressIndicator(color: SRColors.purple700))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Wallet balance card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: SRColors.gradNight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: SRColors.amber500.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.account_balance_wallet_rounded,
                              color: SRColors.amber500, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Current balance',
                                  style: TextStyle(color: Colors.white54, fontSize: 12)),
                              Text(
                                '₦$balance',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isExpired
                                ? SRColors.coral500.withValues(alpha: 0.2)
                                : SRColors.green500.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            isExpired ? 'Expired' : 'Active',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isExpired ? SRColors.coral500 : SRColors.green500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (isExpired && hasAmount) ...[
                    // Amount due card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: SRColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: SRColors.coral100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.warning_amber_rounded,
                                    color: SRColors.coral500, size: 22),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Account suspended',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: SRColors.ink900,
                                        )),
                                    Text('Top up your wallet to reactivate',
                                        style: TextStyle(fontSize: 12, color: SRColors.ink500)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: SRColors.border),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Amount to pay',
                                  style: TextStyle(fontSize: 14, color: SRColors.ink700)),
                              Text(
                                '₦$amountOwed',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: SRColors.ink900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_awaitingReturn)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: SRColors.purple100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.open_in_browser_rounded,
                                color: SRColors.purple700, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Complete payment in your browser, then return here.',
                                style: TextStyle(fontSize: 13, color: SRColors.purple700),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_error != null) ...[
                      const SizedBox(height: 8),
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
                              child: Text(_error!,
                                  style: const TextStyle(
                                      fontSize: 13, color: SRColors.coral600)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _openPayment(amountOwed),
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          color: SRColors.purple700,
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: [
                            BoxShadow(
                              color: SRColors.purple700.withValues(alpha: 0.3),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _awaitingReturn ? 'Reopen payment page' : 'Pay ₦$amountOwed',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        'You will be redirected to a secure payment page.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: SRColors.ink500),
                      ),
                    ),
                  ] else if (!isExpired) ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: SRColors.green100,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: SRColors.green500, size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your wallet is active. No payment needed.',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: SRColors.green600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
