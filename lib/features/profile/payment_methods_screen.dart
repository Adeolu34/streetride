import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SRColors.lavenderBg,
      appBar: AppBar(
        backgroundColor: SRColors.purple700,
        foregroundColor: Colors.white,
        title: const Text(
          'Payment Methods',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: SRColors.purple100,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Icons.credit_card_rounded, color: SRColors.purple700, size: 40),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No payment methods yet',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: SRColors.ink900),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Card payments are coming soon. For now, fund your rides through your StreetRide wallet.',
                      style: TextStyle(fontSize: 14, color: SRColors.ink500, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add card — Coming soon'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
