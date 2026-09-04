import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class SafetyScreen extends StatefulWidget {
  const SafetyScreen({super.key});

  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen> {
  bool _sosSending = false;

  Future<void> _triggerSos() async {
    setState(() => _sosSending = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _sosSending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SRColors.lavenderBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back_rounded, color: SRColors.ink900),
        ),
        title: const Text(
          'Safety Hub',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: SRColors.ink900,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            const Text(
              "Your safety is our\ntop priority",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: SRColors.ink900,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Press and hold the SOS button in an emergency.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: SRColors.ink500, height: 1.4),
            ),
            const SizedBox(height: 36),
            _SosButton(
              sending: _sosSending,
              onActivate: _triggerSos,
            ),
            const SizedBox(height: 36),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Safety toolkit',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: SRColors.ink900,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ToolkitCard(
              icon: Icons.share_location_rounded,
              iconColor: SRColors.purple700,
              iconBg: SRColors.purple100,
              title: 'Share live trip',
              subtitle: 'Send your real-time location to a trusted contact.',
              onTap: () {},
            ),
            const SizedBox(height: 10),
            _ToolkitCard(
              icon: Icons.people_rounded,
              iconColor: SRColors.green500,
              iconBg: SRColors.green100,
              title: 'Trusted contacts',
              subtitle: 'Add up to 5 contacts who receive your trip details.',
              onTap: () {},
            ),
            const SizedBox(height: 10),
            _ToolkitCard(
              icon: Icons.flag_rounded,
              iconColor: SRColors.amber600,
              iconBg: SRColors.amber100,
              title: 'Report an issue',
              subtitle: 'Report driver behaviour, route deviation, or other issues.',
              onTap: () {},
            ),
            const SizedBox(height: 10),
            _ToolkitCard(
              icon: Icons.checklist_rounded,
              iconColor: SRColors.indigo700,
              iconBg: SRColors.lavenderBg,
              title: 'Safety checklist',
              subtitle: 'Quick tips to stay safe on every ride.',
              onTap: () {},
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SosButton extends StatefulWidget {
  final bool sending;
  final Future<void> Function() onActivate;
  const _SosButton({required this.sending, required this.onActivate});

  @override
  State<_SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<_SosButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: widget.sending ? null : () => widget.onActivate(),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) {
          final scale = 1.0 + _pulse.value * 0.08;
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: widget.sending ? SRColors.coral600 : SRColors.coral500,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: SRColors.coral500.withValues(alpha: 0.4),
                blurRadius: 32,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Center(
            child: widget.sending
                ? const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  )
                : const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emergency_rounded,
                          color: Colors.white, size: 38),
                      SizedBox(height: 4),
                      Text(
                        'SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Hold to activate',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ToolkitCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolkitCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SRColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: SRColors.ink900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: SRColors.ink500,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: SRColors.ink500, size: 20),
          ],
        ),
      ),
    );
  }
}
