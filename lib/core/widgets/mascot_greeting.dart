import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/session_service.dart';

class MascotGreeting extends StatefulWidget {
  const MascotGreeting({super.key});

  @override
  State<MascotGreeting> createState() => _MascotGreetingState();
}

class _MascotGreetingState extends State<MascotGreeting>
    with TickerProviderStateMixin {
  static const _shownKey = 'sr_mascot_last_shown';
  static const _tourKey = 'sr_onboarding_done';

  late final AnimationController _slideCtrl;
  late final AnimationController _waveCtrl;
  late final AnimationController _bobCtrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _bob;

  bool _visible = false;
  bool _dismissed = false;
  String _greeting = '';

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..repeat(reverse: true);
    _bobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _slide = Tween<Offset>(
      begin: const Offset(0, 2.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutBack));

    _bob = Tween<double>(begin: -4.0, end: 4.0).animate(
      CurvedAnimation(parent: _bobCtrl, curve: Curves.easeInOut),
    );

    _checkAndShow();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _waveCtrl.dispose();
    _bobCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAndShow() async {
    final prefs = await SharedPreferences.getInstance();

    // Don't show mascot while onboarding tour is still pending
    final tourDone = prefs.getBool(_tourKey) ?? false;
    if (!tourDone) return;

    final lastShown = prefs.getString(_shownKey) ?? '';
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (lastShown == today) return;

    _greeting = _buildGreeting();
    await prefs.setString(_shownKey, today);

    if (!mounted) return;
    setState(() => _visible = true);
    _slideCtrl.forward();

    await Future.delayed(const Duration(seconds: 5));
    _dismiss();
  }

  String _buildGreeting() {
    final name = SessionService.instance.profile?.firstName ?? 'there';
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Good morning, $name! 🌅\nReady to take a ride?';
    if (h >= 12 && h < 17) return 'Good afternoon, $name! ☀️\nWhere are we going today?';
    if (h >= 17 && h < 21) return 'Good evening, $name! 🌆\nHeading somewhere?';
    return 'Hey $name, night owl! 🌙\nStreetRide is always here.';
  }

  void _dismiss() {
    if (_dismissed || !mounted) return;
    _dismissed = true;
    _slideCtrl.reverse().then((_) {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 12, bottom: 96),
        child: GestureDetector(
          onTap: _dismiss,
          child: SlideTransition(
            position: _slide,
            child: AnimatedBuilder(
              animation: Listenable.merge([_waveCtrl, _bobCtrl]),
              builder: (_, __) {
                return Transform.translate(
                  offset: Offset(0, _bob.value),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _SpeechBubble(greeting: _greeting),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 82,
                        height: 106,
                        child: CustomPaint(
                          painter: _MascotPainter(_waveCtrl.value),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  final String greeting;
  const _SpeechBubble({required this.greeting});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1B4B),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text(
                  'Strider',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFFC61A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            greeting,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1B4B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Tap to dismiss',
            style: TextStyle(fontSize: 10, color: Color(0xFF8A8699)),
          ),
        ],
      ),
    );
  }
}

class _MascotPainter extends CustomPainter {
  final double wave;
  _MascotPainter(this.wave);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.52;
    final cy = size.height * 0.48;
    final r = size.width * 0.36;

    _drawBody(canvas, cx, cy, r);
    _drawCap(canvas, cx, cy, r);
    _drawFace(canvas, cx, cy, r);
    _drawArm(canvas, cx, cy, r);
    _drawShadow(canvas, cx, cy, r);
  }

  void _drawShadow(Canvas canvas, double cx, double cy, double r) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + r + 6),
        width: r * 1.4,
        height: r * 0.22,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.10),
    );
  }

  void _drawBody(Canvas canvas, double cx, double cy, double r) {
    // Shirt (dark navy trapezoid below neck)
    final bodyPath = Path()
      ..moveTo(cx - r * 0.55, cy + r * 0.82)
      ..lineTo(cx + r * 0.55, cy + r * 0.82)
      ..lineTo(cx + r * 0.75, cy + r * 1.85)
      ..lineTo(cx - r * 0.75, cy + r * 1.85)
      ..close();
    canvas.drawPath(bodyPath, Paint()..color = const Color(0xFF1A1B4B));

    // Yellow collar strip
    final collarPath = Path()
      ..moveTo(cx - r * 0.45, cy + r * 0.80)
      ..lineTo(cx + r * 0.45, cy + r * 0.80)
      ..lineTo(cx + r * 0.35, cy + r * 1.05)
      ..lineTo(cx - r * 0.35, cy + r * 1.05)
      ..close();
    canvas.drawPath(collarPath, Paint()..color = const Color(0xFFFFC61A));

    // Face circle
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = const Color(0xFFC68642),
    );
  }

  void _drawCap(Canvas canvas, double cx, double cy, double r) {
    final capPaint = Paint()..color = const Color(0xFF1A1B4B);

    // Cap dome — clips the top half of face area
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(cx - r * 1.3, 0, cx + r * 1.3, cy - r * 0.05));
    canvas.drawCircle(Offset(cx, cy), r, capPaint);
    canvas.restore();

    // Brim
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx + r * 0.12, cy - r * 0.6),
          width: r * 2.2,
          height: r * 0.24,
        ),
        const Radius.circular(5),
      ),
      capPaint,
    );

    // Amber badge on cap
    canvas.drawCircle(
      Offset(cx, cy - r * 0.75),
      r * 0.2,
      Paint()..color = const Color(0xFFFFC61A),
    );
    // Dark center dot
    canvas.drawCircle(
      Offset(cx, cy - r * 0.75),
      r * 0.09,
      Paint()..color = const Color(0xFF1A1B4B),
    );
  }

  void _drawFace(Canvas canvas, double cx, double cy, double r) {
    // Eyes
    for (final sign in [-1.0, 1.0]) {
      // White sclera
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + sign * r * 0.30, cy - r * 0.10),
          width: r * 0.34,
          height: r * 0.40,
        ),
        Paint()..color = Colors.white,
      );
      // Pupil
      canvas.drawCircle(
        Offset(cx + sign * r * 0.30, cy - r * 0.10),
        r * 0.11,
        Paint()..color = const Color(0xFF2D1B00),
      );
      // Highlight
      canvas.drawCircle(
        Offset(cx + sign * (r * 0.30 - r * 0.07), cy - r * 0.16),
        r * 0.04,
        Paint()..color = Colors.white,
      );
    }

    // Rosy cheeks
    for (final sign in [-1.0, 1.0]) {
      canvas.drawCircle(
        Offset(cx + sign * r * 0.48, cy + r * 0.20),
        r * 0.12,
        Paint()..color = const Color(0xFFE07050).withValues(alpha: 0.38),
      );
    }

    // Smile arc
    final smilePaint = Paint()
      ..color = const Color(0xFF2D1B00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.07
      ..strokeCap = StrokeCap.round;
    final smilePath = Path()
      ..moveTo(cx - r * 0.35, cy + r * 0.22)
      ..quadraticBezierTo(cx, cy + r * 0.52, cx + r * 0.35, cy + r * 0.22);
    canvas.drawPath(smilePath, smilePaint);

    // Teeth fill
    final teethPath = Path()
      ..moveTo(cx - r * 0.30, cy + r * 0.24)
      ..quadraticBezierTo(cx, cy + r * 0.44, cx + r * 0.30, cy + r * 0.24)
      ..close();
    canvas.drawPath(teethPath, Paint()..color = Colors.white);
  }

  void _drawArm(Canvas canvas, double cx, double cy, double r) {
    // Waving arm (left side)
    final angle = -pi * 0.38 - sin(wave * pi) * pi * 0.22;
    final shoulder = Offset(cx - r * 0.62, cy + r * 0.58);
    final hand = Offset(
      shoulder.dx + cos(angle) * r * 0.75,
      shoulder.dy + sin(angle) * r * 0.75,
    );

    // Sleeve
    canvas.drawLine(
      shoulder,
      hand,
      Paint()
        ..color = const Color(0xFF1A1B4B)
        ..strokeWidth = r * 0.26
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // Hand
    canvas.drawCircle(hand, r * 0.14, Paint()..color = const Color(0xFFC68642));
  }

  @override
  bool shouldRepaint(_MascotPainter old) => old.wave != wave;
}
