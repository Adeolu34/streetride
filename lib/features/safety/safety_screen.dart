import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/trusted_contacts_service.dart';
import '../../core/theme/app_theme.dart';

class SafetyScreen extends StatefulWidget {
  final String? driverName;
  final String? driverPhone;
  final String? tripFrom;
  final String? tripTo;
  final String? riderName;

  const SafetyScreen({
    super.key,
    this.driverName,
    this.driverPhone,
    this.tripFrom,
    this.tripTo,
    this.riderName,
  });

  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen> {
  bool _sosSending = false;

  Future<void> _triggerSos() async {
    setState(() => _sosSending = true);

    // Step 1: dial emergency number
    final dialUri = Uri.parse('tel:112');
    if (await canLaunchUrl(dialUri)) await launchUrl(dialUri);

    // Step 2: alert trusted contacts via WhatsApp
    final contacts = await TrustedContactsService.load();
    if (contacts.isNotEmpty) {
      final name = widget.riderName ?? 'Someone';
      final location = (widget.tripFrom != null && widget.tripTo != null)
          ? 'from ${widget.tripFrom} to ${widget.tripTo}'
          : 'on a StreetRide trip';
      final driver = widget.driverName != null
          ? ' Driver: ${widget.driverName}.'
          : '';
      final message = Uri.encodeComponent(
          '🚨 SOS ALERT: $name needs help! They are $location.$driver Please call them or contact emergency services.');

      for (final c in contacts) {
        final phone = c.phone.replaceAll(RegExp(r'[^0-9]'), '');
        final intl = phone.startsWith('234') ? phone : '234${phone.replaceFirst(RegExp(r'^0'), '')}';
        final waUri = Uri.parse('https://wa.me/$intl?text=$message');
        if (await canLaunchUrl(waUri)) {
          await launchUrl(waUri, mode: LaunchMode.externalApplication);
          await Future.delayed(const Duration(milliseconds: 800));
        }
      }
    }

    if (mounted) setState(() => _sosSending = false);
  }

  Future<void> _shareLiveTrip() async {
    final name = widget.riderName ?? 'A StreetRide user';
    final route = (widget.tripFrom != null && widget.tripTo != null)
        ? 'from *${widget.tripFrom}* to *${widget.tripTo}*'
        : 'on a trip';
    final driver =
        widget.driverName != null ? '\nDriver: *${widget.driverName}*' : '';
    final message = Uri.encodeComponent(
        '👋 Hi! I want you to know I\'m currently on a StreetRide trip.\n\n📍 Route: $route$driver\n\nPlease check on me if you don\'t hear from me soon.');

    final waUri = Uri.parse('https://wa.me/?text=$message');
    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri, mode: LaunchMode.externalApplication);
    }
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
              'Press and hold the SOS button in an emergency.\nCalls 112 and alerts your trusted contacts.',
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
              subtitle: 'Send your trip details to a contact via WhatsApp.',
              onTap: _shareLiveTrip,
            ),
            const SizedBox(height: 10),
            _ToolkitCard(
              icon: Icons.people_rounded,
              iconColor: SRColors.green500,
              iconBg: SRColors.green100,
              title: 'Trusted contacts',
              subtitle: 'Add up to 5 contacts who receive your SOS alert.',
              onTap: () => context.push('/trusted-contacts'),
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
              onTap: () => _showChecklist(context),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showChecklist(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: SizedBox(
                width: 36,
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: SRColors.border,
                      borderRadius: BorderRadius.all(Radius.circular(99))),
                ),
              ),
            ),
            SizedBox(height: 16),
            Text('Safety checklist',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: SRColors.ink900)),
            SizedBox(height: 14),
            _CheckItem("Verify the driver's name and car before entering"),
            _CheckItem("Check the car plate matches what's shown"),
            _CheckItem('Share your trip with a trusted contact'),
            _CheckItem('Sit in the back seat'),
            _CheckItem('Keep your phone charged'),
            _CheckItem('Trust your instincts — exit if uncomfortable'),
          ],
        ),
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String text;
  const _CheckItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: SRColors.green500, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, color: SRColors.ink700, height: 1.4)),
          ),
        ],
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
        builder: (_, child) => Transform.scale(
          scale: 1.0 + _pulse.value * 0.08,
          child: child,
        ),
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
                    color: Colors.white, strokeWidth: 3)
                : const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emergency_rounded, color: Colors.white, size: 38),
                      SizedBox(height: 4),
                      Text('SOS',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2)),
                      SizedBox(height: 2),
                      Text('Hold to activate',
                          style: TextStyle(color: Colors.white60, fontSize: 10)),
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
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: SRColors.ink900)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: SRColors.ink500, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: SRColors.ink500, size: 20),
          ],
        ),
      ),
    );
  }
}
