import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _float;
  late final AnimationController _stars;

  late final Animation<double> _logoFade;
  late final Animation<double> _textSlide;
  late final Animation<double> _textFade;
  late final Animation<double> _subSlide;
  late final Animation<double> _subFade;
  late final Animation<double> _btnSlide;
  late final Animation<double> _btnFade;
  late final Animation<double> _carFloat;

  @override
  void initState() {
    super.initState();

    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _float = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat(reverse: true);
    _stars = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);

    _logoFade  = _curved(_intro, 0.00, 0.30, Curves.easeOut);
    _textSlide = _curved(_intro, 0.20, 0.55, Curves.easeOutCubic);
    _textFade  = _curved(_intro, 0.20, 0.55, Curves.easeOut);
    _subSlide  = _curved(_intro, 0.40, 0.70, Curves.easeOutCubic);
    _subFade   = _curved(_intro, 0.40, 0.70, Curves.easeOut);
    _btnSlide  = _curved(_intro, 0.65, 1.00, Curves.easeOutBack);
    _btnFade   = _curved(_intro, 0.65, 1.00, Curves.easeOut);

    _carFloat = Tween(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _float, curve: Curves.easeInOut),
    );

    _intro.forward();
  }

  Animation<double> _curved(AnimationController c, double begin, double end, Curve curve) =>
      Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: c, curve: Interval(begin, end, curve: curve)),
      );

  @override
  void dispose() {
    _intro.dispose();
    _float.dispose();
    _stars.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4A0B44), Color(0xFF7B1A6E), Color(0xFF5A0D54)],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // ── Floating star particles ──────────────────────────────────
            AnimatedBuilder(
              animation: _stars,
              builder: (_, __) => CustomPaint(
                size: Size(size.width, size.height),
                painter: _StarPainter(_stars.value),
              ),
            ),

            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),

                  // ── Logo ────────────────────────────────────────────────
                  FadeTransition(
                    opacity: _logoFade,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'assets/images/streetride4.jpeg',
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ── Hero text ────────────────────────────────────────────
                  AnimatedBuilder(
                    animation: _textSlide,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(-40 * (1 - _textSlide.value), 0),
                      child: Opacity(opacity: _textFade.value.clamp(0, 1), child: child),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 28),
                      child: Text(
                        'Fast, safe rides\nat your\nfingertips.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Subtitle ─────────────────────────────────────────────
                  AnimatedBuilder(
                    animation: _subSlide,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(-40 * (1 - _subSlide.value), 0),
                      child: Opacity(opacity: _subFade.value.clamp(0, 1), child: child),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 28),
                      child: Text(
                        'You set the destination.\nDrivers set the price. No surge — ever.',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ),

                  // ── Floating car illustration ─────────────────────────────
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer glow ring
                        Positioned(
                          bottom: -40,
                          child: AnimatedBuilder(
                            animation: _float,
                            builder: (_, __) => Container(
                              width: size.width * 0.85,
                              height: size.width * 0.85,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(
                                    alpha: 0.03 + _float.value * 0.02),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          child: Container(
                            width: size.width * 0.60,
                            height: size.width * 0.60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                        ),
                        // The car — floats up and down
                        AnimatedBuilder(
                          animation: _carFloat,
                          builder: (_, child) => Transform.translate(
                            offset: Offset(0, _carFloat.value),
                            child: child,
                          ),
                          child: Image.asset(
                            'assets/images/illustration-car-day.png',
                            width: size.width * 0.88,
                            fit: BoxFit.contain,
                          ),
                        ),
                        // Glow shadow under car (fades with float)
                        Positioned(
                          bottom: 12,
                          child: AnimatedBuilder(
                            animation: _carFloat,
                            builder: (_, __) {
                              final progress = (_carFloat.value + 8) / 16; // 0..1
                              return Container(
                                width: size.width * 0.55 * (0.7 + progress * 0.3),
                                height: 14,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(99),
                                  color: Colors.black.withValues(
                                      alpha: 0.12 + (1 - progress) * 0.08),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Bottom CTAs ───────────────────────────────────────────
                  AnimatedBuilder(
                    animation: _btnSlide,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(0, 80 * (1 - _btnSlide.value)),
                      child: Opacity(opacity: _btnFade.value.clamp(0, 1), child: child),
                    ),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            const Color(0xFF4A0B44).withValues(alpha: 0.9),
                          ],
                        ),
                      ),
                      child: Column(
                        children: [
                          _PulseButton(
                            onTap: () => context.push('/onboarding'),
                            label: 'Get Started as Rider',
                            primary: true,
                          ),
                          const SizedBox(height: 14),
                          _PulseButton(
                            onTap: () => context.push('/signup?driver=true'),
                            label: "I'm a driver",
                            primary: false,
                          ),
                          const SizedBox(height: 22),
                          GestureDetector(
                            onTap: () => context.push('/login'),
                            child: RichText(
                              text: const TextSpan(
                                text: 'Already have an account?  ',
                                style: TextStyle(color: Colors.white60, fontSize: 14),
                                children: [
                                  TextSpan(
                                    text: 'Log in',
                                    style: TextStyle(
                                      color: SRColors.amber500,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Floating star particles ─────────────────────────────────────────────────

class _StarPainter extends CustomPainter {
  final double t;
  _StarPainter(this.t);

  static final _stars = [
    (0.08, 0.12, 3.0, 0.0),
    (0.85, 0.08, 2.0, 0.3),
    (0.72, 0.22, 4.0, 0.6),
    (0.15, 0.35, 2.5, 0.1),
    (0.92, 0.45, 3.0, 0.8),
    (0.55, 0.18, 2.0, 0.4),
    (0.35, 0.10, 1.5, 0.2),
    (0.65, 0.38, 3.5, 0.9),
    (0.20, 0.55, 2.0, 0.5),
    (0.78, 0.55, 2.5, 0.7),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final (rx, ry, r, phase) in _stars) {
      final alpha = (0.3 + 0.5 * math.sin((t + phase) * math.pi * 2)).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(rx * size.width, ry * size.height),
        r,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.t != t;
}

// ── Tactile CTA button with scale press ──────────────────────────────────────

class _PulseButton extends StatefulWidget {
  final VoidCallback onTap;
  final String label;
  final bool primary;
  const _PulseButton({required this.onTap, required this.label, required this.primary});

  @override
  State<_PulseButton> createState() => _PulseButtonState();
}

class _PulseButtonState extends State<_PulseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) { _press.reverse(); widget.onTap(); },
      onTapCancel: () => _press.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: widget.primary ? 56 : 52,
          decoration: BoxDecoration(
            color: widget.primary
                ? Colors.white
                : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: widget.primary
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
            boxShadow: widget.primary
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.primary ? SRColors.purple700 : Colors.white,
                fontSize: widget.primary ? 16 : 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
