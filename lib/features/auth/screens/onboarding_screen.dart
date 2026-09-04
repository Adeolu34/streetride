import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _current = 0;
  static const _total = 3;

  void _next() {
    if (_current < _total - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/signup');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SRColors.lavenderBg,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 16, 0),
                child: GestureDetector(
                  onTap: () => context.go('/signup'),
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: SRColors.ink500,
                    ),
                  ),
                ),
              ),
            ),
            // Pages
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _current = i),
                children: const [
                  _Page1(),
                  _Page2(),
                  _Page3(),
                ],
              ),
            ),
            // Dots + Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
              child: Column(
                children: [
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_total, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _current == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _current == i
                              ? SRColors.purple700
                              : SRColors.border,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  // CTA button
                  GestureDetector(
                    onTap: _next,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: SRColors.purple700,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: SRColors.purple700.withValues(alpha: 0.32),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _current == _total - 1 ? 'Get Started' : 'Next',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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

// ─── Page 1: "Tell us where you're going" ───────────────────────────────────

class _Page1 extends StatelessWidget {
  const _Page1();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        _BookingCard(),
        const SizedBox(height: 32),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tell us where\nyou\'re going',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: SRColors.ink900,
                  height: 1.2,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Enter your pickup and destination. We\'ll connect you with nearby drivers instantly.',
                style: TextStyle(
                  fontSize: 15,
                  color: SRColors.ink500,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BookingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5A0D54), Color(0xFF8E2472)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: SRColors.purple700.withValues(alpha: 0.30),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Where to?',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          // From
          _RouteField(
            icon: Icons.radio_button_checked,
            iconColor: SRColors.amber500,
            value: 'Current location',
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Container(
                width: 2, height: 14, color: Colors.white24),
          ),
          // To
          _RouteField(
            icon: Icons.location_on_rounded,
            iconColor: SRColors.coral500,
            value: 'Victoria Island',
          ),
          const SizedBox(height: 16),
          // Driver chips
          Row(
            children: [
              _DriverChip(initials: 'MK', price: '₦1,900', best: true),
              const SizedBox(width: 8),
              _DriverChip(initials: 'AO', price: '₦2,100', best: false),
              const SizedBox(width: 8),
              _DriverChip(initials: 'IE', price: '₦2,500', best: false),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteField extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  const _RouteField({required this.icon, required this.iconColor, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverChip extends StatelessWidget {
  final String initials;
  final String price;
  final bool best;
  const _DriverChip({required this.initials, required this.price, required this.best});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: best
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: best
              ? Border.all(color: Colors.white.withValues(alpha: 0.4))
              : null,
        ),
        child: Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: best ? Colors.white : Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: best ? SRColors.purple700 : Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              price,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: best ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Page 2: "Drivers name their own price" ──────────────────────────────────

class _Page2 extends StatelessWidget {
  const _Page2();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        _PriceOffersCard(),
        const SizedBox(height: 32),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Drivers name\ntheir own price',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: SRColors.ink900,
                  height: 1.2,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'No fixed fares, no surge pricing. You see every offer and choose who to ride with.',
                style: TextStyle(
                  fontSize: 15,
                  color: SRColors.ink500,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PriceOffersCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: SRColors.border),
        boxShadow: [
          BoxShadow(
            color: SRColors.indigo900.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '3 prices came in',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: SRColors.ink900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Victoria Island · 8.4 km',
            style: TextStyle(fontSize: 12, color: SRColors.ink500),
          ),
          const SizedBox(height: 14),
          _OfferRow(
            initials: 'MK',
            name: 'Musa K.',
            car: 'Corolla · 4 min',
            price: 1900,
            isBest: true,
          ),
          const SizedBox(height: 10),
          _OfferRow(
            initials: 'AO',
            name: 'Ada Obi',
            car: 'Camry · 3 min',
            price: 2100,
            isBest: false,
          ),
          const SizedBox(height: 10),
          _OfferRow(
            initials: 'IE',
            name: 'Ifeanyi E.',
            car: 'Sienna · 6 min',
            price: 2600,
            isBest: false,
          ),
        ],
      ),
    );
  }
}

class _OfferRow extends StatelessWidget {
  final String initials;
  final String name;
  final String car;
  final int price;
  final bool isBest;

  const _OfferRow({
    required this.initials,
    required this.name,
    required this.car,
    required this.price,
    required this.isBest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isBest ? SRColors.purple100 : SRColors.lavenderBg,
        borderRadius: BorderRadius.circular(12),
        border: isBest
            ? Border.all(color: SRColors.purple700, width: 1.5)
            : Border.all(color: SRColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isBest ? SRColors.purple700 : SRColors.border,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isBest ? Colors.white : SRColors.ink700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: SRColors.ink900)),
                Text(car,
                    style: const TextStyle(
                        fontSize: 11, color: SRColors.ink500)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₦$price',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color:
                      isBest ? SRColors.purple700 : SRColors.ink900,
                ),
              ),
              if (isBest)
                const Text(
                  'BEST',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: SRColors.green600,
                    letterSpacing: 0.5,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Page 3: "Ride safe, pay your way" ───────────────────────────────────────

class _Page3 extends StatelessWidget {
  const _Page3();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        _NightSafeCard(),
        const SizedBox(height: 32),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ride safe,\npay your way',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: SRColors.ink900,
                  height: 1.2,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'One-tap SOS, live trip sharing, and wallet payments — safety and convenience, always.',
                style: TextStyle(
                  fontSize: 15,
                  color: SRColors.ink500,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NightSafeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1133), Color(0xFF3A1D5C)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: SRColors.indigo900.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Image.asset(
            'assets/images/illustration-car-night.png',
            height: 130,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 12),
          // Safety row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SafetyChip(icon: Icons.emergency_rounded, label: 'SOS', color: SRColors.coral500),
              const SizedBox(width: 10),
              _SafetyChip(icon: Icons.share_location_rounded, label: 'Live share', color: SRColors.green500),
              const SizedBox(width: 10),
              _SafetyChip(icon: Icons.account_balance_wallet_rounded, label: 'Wallet', color: SRColors.amber500),
            ],
          ),
        ],
      ),
    );
  }
}

class _SafetyChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SafetyChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
