import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/session_service.dart';
import '../../core/services/background_poll_service.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
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

    final vehicleLine = [vColor, vMake, vModel].where((s) => s.isNotEmpty).join(' ');
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
              onEdit: _goEdit,
            ),
            const SizedBox(height: 16),
            _VehicleCard(
              typeLabel: typeLabel,
              vehicleDetail: vehicleDetail,
              yearLabel: yearLabel,
              onEdit: _goEdit,
            ),
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
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & support',
                  onTap: () {},
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

class _DriverProfileHeader extends StatelessWidget {
  final String initials;
  final String name;
  final String photoUrl;
  final bool isKyc;
  final VoidCallback onEdit;

  const _DriverProfileHeader({
    required this.initials,
    required this.name,
    required this.photoUrl,
    required this.isKyc,
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
              // Edit button top-right
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

              // Avatar
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
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, color: SRColors.amber500, size: 14),
                  SizedBox(width: 4),
                  Text(
                    '4.8 · Driver',
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
