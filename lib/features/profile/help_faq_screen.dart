import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';

class HelpFaqScreen extends StatelessWidget {
  const HelpFaqScreen({super.key});

  static const _faqs = [
    (
      q: 'How does StreetRide pricing work?',
      a:
          'StreetRide uses a driver-led pricing model. When you request a ride, nearby drivers each name their own price. You see all offers and choose the one that works for you — no surge pricing, no surprises.',
    ),
    (
      q: 'Can I select specific drivers?',
      a:
          'Yes. After entering your destination, you can browse available drivers and hand-pick who you want to request. Each selected driver then sends you their price offer.',
    ),
    (
      q: 'What happens if no driver accepts?',
      a:
          'Your request stays live for a few minutes. If no driver responds, you can try again with more drivers selected or at a different time.',
    ),
    (
      q: 'How do I pay for my ride?',
      a:
          'Payment is handled through your StreetRide wallet. Fund your wallet before your trip, and the fare is deducted automatically when the ride is completed.',
    ),
    (
      q: 'Can I cancel a ride?',
      a:
          'Yes, you can cancel a pending ride before a driver starts heading to you. Once a driver is en route, a cancellation fee may apply.',
    ),
    (
      q: 'How do I rate my driver?',
      a:
          'After your trip ends, you\'ll be taken to the rate & pay screen where you can give a 1–5 star rating and leave optional feedback.',
    ),
    (
      q: 'What is the Safety Hub?',
      a:
          'The Safety Hub lets you share your live trip with trusted contacts, trigger an SOS alert in an emergency, and access safety resources. Find it in your profile menu.',
    ),
    (
      q: 'How do I add money to my wallet?',
      a:
          'Wallet top-up is coming soon. For now, contact support to manually credit your account during testing.',
    ),
  ];

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse('https://wa.me/2349024706049');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openEmail() async {
    final uri = Uri.parse('mailto:support@streetrideplus.com?subject=StreetRide%20Support');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SRColors.lavenderBg,
      appBar: AppBar(
        backgroundColor: SRColors.purple700,
        foregroundColor: Colors.white,
        title: const Text(
          'Help & FAQ',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Frequently asked questions',
            style: TextStyle(fontSize: 14, color: SRColors.ink500),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: SRColors.border, width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                children: List.generate(_faqs.length, (i) {
                  final faq = _faqs[i];
                  final isLast = i == _faqs.length - 1;
                  return Column(
                    children: [
                      _FaqTile(question: faq.q, answer: faq.a),
                      if (!isLast)
                        const Divider(height: 1, indent: 16, endIndent: 16, color: SRColors.border),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'STILL NEED HELP?',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: SRColors.ink500,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          _ContactTile(
            icon: Icons.chat_rounded,
            color: const Color(0xFF25D366),
            title: 'WhatsApp support',
            subtitle: 'Chat with us — usually replies in minutes',
            onTap: _openWhatsApp,
          ),
          const SizedBox(height: 10),
          _ContactTile(
            icon: Icons.email_rounded,
            color: SRColors.purple700,
            title: 'Email us',
            subtitle: 'support@streetrideplus.com',
            onTap: _openEmail,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _open = !_open),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.question,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: SRColors.ink900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more_rounded, color: SRColors.purple700),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  widget.answer,
                  style: const TextStyle(fontSize: 13, color: SRColors.ink500, height: 1.5),
                ),
              ),
              crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SRColors.border, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: SRColors.ink900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: SRColors.ink500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: SRColors.ink500),
          ],
        ),
      ),
    );
  }
}
