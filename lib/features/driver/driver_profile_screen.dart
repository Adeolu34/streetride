import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/api/ride_api.dart';
import '../../core/services/session_service.dart';
import '../../core/services/background_poll_service.dart';
import '../../core/services/engagement_service.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  int _walletBalance = 0;
  int _totalTrips = 0;
  int _streak = 0;
  String _avgRating = '';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final profile = SessionService.instance.profile;
    if (profile == null) return;

    try {
      final walletRes = await RideApi.instance.getWalletStatus(profile.phone);
      final bal = walletRes['ToBalance'] ?? walletRes['TotalBalance'] ?? '0';
      final parsed = double.tryParse(bal.toString()) ?? 0;
      if (mounted) setState(() => _walletBalance = parsed.toInt());
    } catch (_) {
      final fromProfile = double.tryParse(profile.walletBalance) ?? 0;
      if (mounted) setState(() => _walletBalance = fromProfile.toInt());
    }

    try {
      final histRes = await RideApi.instance.getPaymentHistory(profile.phone);
      final total = histRes['TotalTransactions'] ?? 0;
      if (mounted) setState(() => _totalTrips = int.tryParse(total.toString()) ?? 0);
    } catch (_) {}


    final streak = await EngagementService.instance.getStreak();
    if (mounted) setState(() => _streak = streak);

    try {
      final detail = await RideApi.instance.getUserDetail(profile.phone);
      final data = detail['Data'] as Map<String, dynamic>?;
      if (data != null) {
        final rawRating = (data['AverageRating'] ?? data['avg_rating'] ?? data['AvgRating'] ?? data['Rating'] ?? 0);
        final rating = double.tryParse(rawRating.toString()) ?? 0;
        final totalRides = (data['TotalRides'] ?? data['total_rides'] ?? 0) as num;
        if (mounted) {
          setState(() {
            if (rating > 0) _avgRating = rating.toStringAsFixed(1);
            if (totalRides > 0 && _totalTrips == 0) _totalTrips = totalRides.toInt();
          });
        }
      }
    } catch (_) {}
  }

  String _fmtBalance(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Future<void> _goEdit() async {
    await context.push('/driver-edit-profile');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final profile = SessionService.instance.profile;
    final initials = profile?.initials ?? '?';
    final name = profile?.fullName ?? 'Driver';
    final photoUrl = profile?.photoUrl ?? '';
    final isKyc = profile?.kycVerified ?? false;

    final vMake = profile?.vMake ?? '';
    final vModel = profile?.vModel ?? '';
    final vYear = profile?.vYear ?? '';
    final vColor = profile?.vColor ?? '';
    final vType = profile?.vType ?? '';

    final vehicleLine =
        [vColor, vMake, vModel].where((s) => s.isNotEmpty).join(' ');
    final vehicleDetail = vehicleLine.isEmpty ? '—' : vehicleLine;
    final yearLabel = vYear.isNotEmpty ? ' · $vYear' : '';
    final typeLabel = vType.isNotEmpty ? vType : 'Vehicle';

    return Scaffold(
      backgroundColor: SRColors.lavenderBg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _DriverProfileHeader(
              initials: initials,
              name: name,
              photoUrl: photoUrl,
              isKyc: isKyc,
              avgRating: _avgRating,
              onEdit: _goEdit,
            ),
            const SizedBox(height: 16),

            // Stats row
            _DriverStatsRow(
              walletBalance: '₦${_fmtBalance(_walletBalance)}',
              totalTrips: _totalTrips,
              streak: _streak,
            ),
            const SizedBox(height: 16),

            _VehicleCard(
              typeLabel: typeLabel,
              vehicleDetail: vehicleDetail,
              yearLabel: yearLabel,
              onEdit: _goEdit,
            ),
            const SizedBox(height: 16),

            // Mode switch — switch back to rider mode
            _DriverModeSwitchSection(profile: profile),
            const SizedBox(height: 16),

            _MenuSection(
              title: 'Account',
              items: [
                _MenuItem(
                  icon: Icons.verified_rounded,
                  label: 'KYC documents',
                  onTap: () => context.push('/kyc'),
                ),
                _MenuItem(
                  icon: Icons.credit_card_rounded,
                  label: 'Payout account',
                  onTap: _goEdit,
                ),
                _MenuItem(
                  icon: Icons.local_offer_rounded,
                  label: 'Driver Plans',
                  onTap: () => context.push('/driver-plans'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MenuSection(
              title: 'Settings',
              items: [
                _MenuItem(
                  icon: Icons.language_rounded,
                  label: 'Language & region',
                  onTap: () => context.push('/language'),
                ),
                _MenuItem(
                  icon: Icons.notifications_rounded,
                  label: 'Notifications',
                  onTap: () => context.push('/notifications'),
                ),
                _MenuItem(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & support',
                  onTap: () => context.push('/help-faq'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: GestureDetector(
                onTap: () {
                  SessionService.instance.clear();
                  BackgroundPollService.stop();
                  context.go('/welcome');
                },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: SRColors.coral100,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: SRColors.coral500, width: 1.5),
                  ),
                  child: const Center(
                    child: Text(
                      'Log out',
                      style: TextStyle(
                        color: SRColors.coral500,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Driver stats row ───────────────────────────────────────────────────────────

class _DriverStatsRow extends StatelessWidget {
  final String walletBalance;
  final int totalTrips;
  final int streak;
  const _DriverStatsRow({
    required this.walletBalance,
    required this.totalTrips,
    this.streak = 0,
  });

  @override
  Widget build(BuildContext context) {
    final streakLabel =
        streak >= 2 ? '🔥 $streak days' : streak == 1 ? '1 day' : '—';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SRColors.border),
      ),
      child: Row(
        children: [
          _Stat(label: 'Total trips', value: '$totalTrips'),
          _StatDivider(),
          _Stat(label: 'Earnings', value: walletBalance),
          _StatDivider(),
          _Stat(label: 'Streak', value: streakLabel),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: SRColors.ink900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: SRColors.ink500),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: SRColors.border);
}

// ── Mode switch (Driver → Rider) ───────────────────────────────────────────────

class _DriverModeSwitchSection extends StatelessWidget {
  final dynamic profile;
  const _DriverModeSwitchSection({required this.profile});

  Future<void> _switchToRider(BuildContext context) async {
    await SessionService.instance.switchMode(false);
    BackgroundPollService.stop();
    await BackgroundPollService.start();
    if (context.mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF3CD), Color(0xFFFFE082)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: SRColors.amber500.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  const Icon(Icons.drive_eta_rounded,
                      size: 16, color: SRColors.amber600),
                  const SizedBox(width: 6),
                  const Text(
                    "You're driving",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: SRColors.amber600,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Switch mode',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: SRColors.amber600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    // Rider side (inactive)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _switchToRider(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_rounded,
                                  size: 18, color: SRColors.ink500),
                              SizedBox(width: 7),
                              Text(
                                'Rider',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: SRColors.ink500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Driver side (active)
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: SRColors.amber500,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: SRColors.amber500.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.drive_eta_rounded,
                                size: 18, color: Colors.white),
                            SizedBox(width: 7),
                            Text(
                              'Driver',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile header ─────────────────────────────────────────────────────────────

class _DriverProfileHeader extends StatelessWidget {
  final String initials;
  final String name;
  final String photoUrl;
  final bool isKyc;
  final String avgRating;
  final VoidCallback onEdit;

  const _DriverProfileHeader({
    required this.initials,
    required this.name,
    required this.photoUrl,
    required this.isKyc,
    this.avgRating = '',
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: SRColors.gradNight,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: onEdit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_rounded,
                              color: Colors.white, size: 14),
                          SizedBox(width: 5),
                          Text(
                            'Edit profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: SRColors.amber500.withValues(alpha: 0.6),
                      width: 2.5),
                ),
                child: photoUrl.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(initials,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (avgRating.isNotEmpty) ...[
                    const Icon(Icons.star_rounded,
                        color: SRColors.amber500, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$avgRating · ',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                  ],
                  const Text(
                    'Driver',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: (isKyc ? SRColors.green500 : SRColors.amber500)
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                          color: (isKyc ? SRColors.green500 : SRColors.amber500)
                              .withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isKyc
                              ? Icons.verified_rounded
                              : Icons.pending_rounded,
                          size: 12,
                          color: isKyc ? SRColors.green500 : SRColors.amber500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isKyc ? 'KYC Verified' : 'KYC Pending',
                          style: TextStyle(
                            color:
                                isKyc ? SRColors.green500 : SRColors.amber500,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Vehicle card ───────────────────────────────────────────────────────────────

class _VehicleCard extends StatelessWidget {
  final String typeLabel;
  final String vehicleDetail;
  final String yearLabel;
  final VoidCallback onEdit;

  const _VehicleCard({
    required this.typeLabel,
    required this.vehicleDetail,
    required this.yearLabel,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SRColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: SRColors.indigo800,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.directions_car_rounded,
                color: SRColors.amber500, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: SRColors.ink900,
                  ),
                ),
                Text(
                  '$vehicleDetail$yearLabel',
                  style: const TextStyle(fontSize: 12, color: SRColors.ink500),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: SRColors.lavenderBg,
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Text(
                'Edit',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: SRColors.purple700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Menu section ───────────────────────────────────────────────────────────────

class _MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;
  const _MenuSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: SRColors.ink500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: SRColors.border),
            ),
            child: Column(
              children: List.generate(items.length, (i) {
                final item = items[i];
                return Column(
                  children: [
                    GestureDetector(
                      onTap: item.onTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: SRColors.lavenderBg,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(item.icon,
                                  color: SRColors.purple700, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.label,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: SRColors.ink900,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: SRColors.ink500, size: 20),
                          ],
                        ),
                      ),
                    ),
                    if (i < items.length - 1)
                      const Divider(
                          height: 1, color: SRColors.border, indent: 64),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItem(
      {required this.icon, required this.label, required this.onTap});
}
