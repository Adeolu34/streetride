import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingTour extends StatefulWidget {
  const OnboardingTour({super.key});

  @override
  State<OnboardingTour> createState() => _OnboardingTourState();
}

class _OnboardingTourState extends State<OnboardingTour>
    with SingleTickerProviderStateMixin {
  static const _key = 'sr_onboarding_done';

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  bool _visible = false;
  int _step = 0;

  Future<void> _skip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    _fadeCtrl.reverse().then((_) {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _checkAndShow();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAndShow() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_key) ?? false) return;
    if (!mounted) return;
    setState(() => _visible = true);
    _fadeCtrl.forward();
  }

  Future<void> _next() async {
    if (_step < _tourSteps.length - 1) {
      setState(() => _step++);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
      _fadeCtrl.reverse().then((_) {
        if (mounted) setState(() => _visible = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final mq = MediaQuery.of(context);
    final size = mq.size;
    final safeTop = mq.padding.top;
    final navHeight = 60.0 + mq.padding.bottom;
    final step = _tourSteps[_step];
    final spot = step.buildSpot(size, safeTop, navHeight);

    return FadeTransition(
      opacity: _fade,
      child: GestureDetector(
        onTap: () {}, // absorb taps on the dark overlay
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // Dark overlay with spotlight hole
            CustomPaint(
              size: size,
              painter: _SpotlightPainter(spotlight: spot),
            ),

            // Skip button (top-right)
            Positioned(
              top: safeTop + 12,
              right: 16,
              child: GestureDetector(
                onTap: _skip,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Skip tour',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            // Tooltip card
            _TooltipPositioned(
              size: size,
              spot: spot,
              above: step.tooltipAbove,
              child: _TooltipCard(
                text: step.text,
                nextLabel: step.nextLabel,
                step: _step,
                total: _tourSteps.length,
                onNext: _next,
                onSkip: _skip,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tour step data ─────────────────────────────────────────────────────────────

typedef _SpotBuilder = Rect? Function(Size size, double safeTop, double nav);

class _Step {
  final String text;
  final _SpotBuilder buildSpot;
  final bool tooltipAbove;
  final String nextLabel;

  const _Step({
    required this.text,
    required this.buildSpot,
    this.tooltipAbove = true,
    this.nextLabel = 'Next →',
  });
}

final _tourSteps = [
  _Step(
    text: "Hi! I'm Strider 👋\nYour StreetRide buddy!\nLet me show you around the app.",
    buildSpot: (s, top, nav) => null,
    nextLabel: 'Show me! →',
  ),
  _Step(
    text: "This is your live map 🗺️\nSee nearby StreetRide drivers\nin real time!",
    buildSpot: (s, top, nav) =>
        Rect.fromLTRB(8, top + 52, s.width - 8, s.height * 0.53),
    tooltipAbove: false,
  ),
  _Step(
    text: "Tap here to search for your\ndestination 🔍\nDrivers will bid for your trip!",
    buildSpot: (s, top, nav) =>
        Rect.fromLTRB(12, s.height * 0.50, s.width - 12, s.height * 0.66),
    tooltipAbove: false,
  ),
  _Step(
    text: "View all your past trips\nand receipts here 🚗",
    buildSpot: (s, top, nav) => Rect.fromLTRB(
      s.width * 0.25 - 30, s.height - nav, s.width * 0.25 + 30, s.height - 2),
    tooltipAbove: true,
  ),
  _Step(
    text: "Top up your wallet and\npay for rides here 💰",
    buildSpot: (s, top, nav) => Rect.fromLTRB(
      s.width * 0.50 - 30, s.height - nav, s.width * 0.50 + 30, s.height - 2),
    tooltipAbove: true,
  ),
  _Step(
    text: "Your profile, settings,\nand saved places are here ⚙️",
    buildSpot: (s, top, nav) => Rect.fromLTRB(
      s.width * 0.75 - 30, s.height - nav, s.width * 0.75 + 30, s.height - 2),
    tooltipAbove: true,
  ),
  _Step(
    text: "You're all set! 🎉\nEnjoy StreetRide!\nSafe travels, and happy riding!",
    buildSpot: (s, top, nav) => null,
    nextLabel: "Let's ride! 🚗",
  ),
];

// ── Spotlight painter ──────────────────────────────────────────────────────────

class _SpotlightPainter extends CustomPainter {
  final Rect? spotlight;
  _SpotlightPainter({this.spotlight});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.74),
    );
    if (spotlight != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(spotlight!, const Radius.circular(18)),
        Paint()..blendMode = BlendMode.clear,
      );
    }
    canvas.restore();

    // Amber glow border around the spotlight
    if (spotlight != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(spotlight!.inflate(2.5), const Radius.circular(20)),
        Paint()
          ..color = const Color(0xFFFFC61A).withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.spotlight != spotlight;
}

// ── Tooltip positioning ────────────────────────────────────────────────────────

class _TooltipPositioned extends StatelessWidget {
  final Size size;
  final Rect? spot;
  final bool above;
  final Widget child;

  const _TooltipPositioned({
    required this.size,
    required this.spot,
    required this.above,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    double top;
    if (spot == null) {
      // Welcome / done step — center of screen
      top = size.height * 0.28;
    } else if (above) {
      top = (spot!.top - 168).clamp(12.0, size.height * 0.6);
    } else {
      top = (spot!.bottom + 14).clamp(12.0, size.height * 0.6);
    }

    return Positioned(
      left: 0,
      right: 0,
      top: top,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: child,
      ),
    );
  }
}

// ── Tooltip card ───────────────────────────────────────────────────────────────

class _TooltipCard extends StatelessWidget {
  final String text;
  final String nextLabel;
  final int step;
  final int total;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _TooltipCard({
    required this.text,
    required this.nextLabel,
    required this.step,
    required this.total,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Guide header
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1B4B),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('👋', style: TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Strider',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1B4B),
                    ),
                  ),
                  Text(
                    'StreetRide Guide',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '${step + 1} of $total',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Guide text
          Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1B4B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // Progress + button row
          Row(
            children: [
              // Progress dots
              ...List.generate(total, (i) {
                final active = i == step;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  width: active ? 22 : 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF6C3AE8)
                        : const Color(0xFFE2DFF0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
              const Spacer(),
              // Next button
              GestureDetector(
                onTap: onNext,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C3AE8),
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C3AE8).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    nextLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
