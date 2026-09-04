import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/ride_api.dart';
import '../../core/models/ride_model.dart';
import '../../core/models/wallet_model.dart';
import '../../core/services/background_poll_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/session_service.dart';
import '../../core/widgets/permission_setup_sheet.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ride_notification_overlay.dart';
import '../booking/providers/ride_provider.dart';
import 'driver_earnings_screen.dart';
import 'driver_profile_screen.dart';
import 'driver_ride_history_screen.dart';
import 'providers/wallet_provider.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen>
    with WidgetsBindingObserver {
  bool _online = true;
  int _selectedTab = 0;
  String _driverFirstName = 'Driver';
  String _driverInitials = 'D';
  String? _driverPhotoUrl;
  String _normalizedPhone = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final profile = SessionService.instance.profile;
    _driverFirstName = profile?.firstName ?? 'Driver';
    _driverInitials = profile?.initials ?? 'D';
    _driverPhotoUrl = profile?.photoUrl;
    final phone = profile?.phone ?? '';
    _normalizedPhone = phone.startsWith('234')
        ? phone
        : '234${phone.replaceFirst(RegExp(r'^0'), '')}';
    Future.microtask(() async {
      await BackgroundPollService.start();
      ref.read(rideProvider.notifier).poll();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) PermissionSetupSheet.showIfNeeded(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      NotificationService.instance.consumePendingRoute(context);
      // Restart background service if TECNO killed it while app was away
      BackgroundPollService.start();
    }
  }

  Future<void> _toggleOnline() async {
    final newVal = !_online;
    setState(() => _online = newVal);
    final phone = SessionService.instance.profile?.phone ?? '';
    await RideApi.instance
        .setDriverOnlineStatus(phone: phone, online: newVal)
        .catchError((_) => <String, dynamic>{});
  }

  @override
  Widget build(BuildContext context) {
    final rideState = ref.watch(rideProvider);
    final pending = rideState.pendingForDriver(_normalizedPhone);

    // Wallet status — only gate when we have a confirmed expired result (never block on loading)
    final wallet = ref.watch(walletProvider).valueOrNull;
    final isExpired = wallet?.isExpired ?? false;

    return Scaffold(
      backgroundColor: SRColors.lavenderBg,
      body: RideNotificationOverlay(
        child: isExpired
            ? _ExpiredWalletGate(wallet: wallet!)
            : IndexedStack(
                index: _selectedTab,
                children: [
                  _HomeContent(
                    online: _online,
                    onToggle: _toggleOnline,
                    driverFirstName: _driverFirstName,
                    driverInitials: _driverInitials,
                    driverPhotoUrl: _driverPhotoUrl,
                    requests: pending,
                    onRefresh: () => ref.read(rideProvider.notifier).poll(),
                  ),
                  const DriverRideHistoryScreen(embedded: true),
                  const DriverEarningsScreen(showBackButton: false),
                  const DriverProfileScreen(),
                ],
              ),
      ),
      bottomNavigationBar: isExpired
          ? null
          : _DriverBottomNav(
              selected: _selectedTab,
              onSelect: (i) => setState(() => _selectedTab = i),
            ),
    );
  }
}

class _ExpiredWalletGate extends StatelessWidget {
  final WalletStatus wallet;
  const _ExpiredWalletGate({required this.wallet});

  @override
  Widget build(BuildContext context) {
    final owed = wallet.amountOwed;
    final oweText = (int.tryParse(owed) ?? 0) > 0 ? '₦$owed' : 'your subscription fee';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: SRColors.coral100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: SRColors.coral500,
                size: 38,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Subscription expired',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: SRColors.ink900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your driver wallet has expired. Pay $oweText to reactivate your account and start accepting rides.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
                color: SRColors.ink500,
              ),
            ),
            const SizedBox(height: 32),
            if ((int.tryParse(owed) ?? 0) > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: SRColors.coral100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Amount owed',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: SRColors.coral600,
                      ),
                    ),
                    Text(
                      '₦$owed',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: SRColors.coral500,
                      ),
                    ),
                  ],
                ),
              ),
            GestureDetector(
              onTap: () => context.push('/driver-plans'),
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: SRColors.purple700,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: SRColors.purple700.withValues(alpha: 0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Renew subscription',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => context.push('/driver-profile'),
              child: const Text(
                'Contact support',
                style: TextStyle(
                  fontSize: 13,
                  color: SRColors.purple700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final bool online;
  final VoidCallback onToggle;
  final String driverFirstName;
  final String driverInitials;
  final String? driverPhotoUrl;
  final List<RideMessage> requests;
  final VoidCallback onRefresh;

  const _HomeContent({
    required this.online,
    required this.onToggle,
    required this.driverFirstName,
    required this.driverInitials,
    required this.requests,
    required this.onRefresh,
    this.driverPhotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DriverHeader(
          online: online,
          onToggle: onToggle,
          driverFirstName: driverFirstName,
          driverInitials: driverInitials,
          driverPhotoUrl: driverPhotoUrl,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _EarningsCard(),
                const SizedBox(height: 20),
                if (online) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Rider requests',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: SRColors.ink900,
                        ),
                      ),
                      GestureDetector(
                        onTap: onRefresh,
                        child: const Icon(Icons.refresh_rounded,
                            color: SRColors.purple700, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (requests.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Text(
                          'No ride requests right now.',
                          style: TextStyle(
                              fontSize: 14, color: SRColors.ink500),
                        ),
                      ),
                    )
                  else
                    ...requests.map((m) {
                      final name = m.riderName.isNotEmpty ? m.riderName : 'Rider';
                      final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
                      final initials = parts.length >= 2
                          ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
                          : (parts.isNotEmpty ? parts[0][0].toUpperCase() : 'R');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RequestCard(
                          from: m.fromText.isNotEmpty ? m.fromText : 'Pickup',
                          to: m.toText.isNotEmpty ? m.toText : 'Drop-off',
                          distance: m.km.isNotEmpty ? '${m.km} km' : '—',
                          eta: m.estimatedTime.isNotEmpty ? '${m.estimatedTime} min' : '—',
                          onPrice: () => context.push(
                            '/driver-name-price',
                            extra: {
                              'reqId': m.reqId,
                              'fromText': m.fromText,
                              'toText': m.toText,
                              'riderName': name,
                              'riderInitials': initials,
                              'km': m.km,
                              'eta': m.estimatedTime,
                            },
                          ),
                          onSkip: () async {
                            await Future.wait([
                              RideApi.instance.setDriverMovementStatus(m.reqId, 'Cancel')
                                  .catchError((_) => <String, dynamic>{}),
                              RideApi.instance.setRiderStatus(m.reqId, 'Reject Ride')
                                  .catchError((_) => <String, dynamic>{}),
                            ]);
                            onRefresh();
                          },
                        ),
                      );
                    }),
                ] else ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Column(
                        children: [
                          Icon(Icons.power_settings_new_rounded,
                              size: 52, color: SRColors.ink500),
                          SizedBox(height: 12),
                          Text(
                            "You're offline",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: SRColors.ink900,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Go online to start receiving ride requests.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: SRColors.ink500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DriverHeader extends StatelessWidget {
  final bool online;
  final VoidCallback onToggle;
  final String driverFirstName;
  final String driverInitials;
  final String? driverPhotoUrl;

  const _DriverHeader({
    required this.online,
    required this.onToggle,
    required this.driverFirstName,
    required this.driverInitials,
    this.driverPhotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning,'
        : hour < 17
            ? 'Good afternoon,'
            : 'Good evening,';

    return Container(
      decoration: const BoxDecoration(
        gradient: SRColors.gradNight,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 44,
                    height: 44,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                    ),
                    child: driverPhotoUrl != null && driverPhotoUrl!.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              driverPhotoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(driverInitials,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(driverInitials,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                          ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          driverFirstName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onToggle,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: online
                            ? SRColors.green500
                            : SRColors.ink500.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: online ? Colors.white : Colors.white54,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            online ? 'Online' : 'Offline',
                            style: TextStyle(
                              color:
                                  online ? Colors.white : Colors.white54,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Row(
                children: [
                  _HeaderStat(
                    label: 'Today',
                    value: '₦0',
                    color: SRColors.amber500,
                  ),
                  SizedBox(width: 24),
                  _HeaderStat(label: 'Trips', value: '0'),
                  SizedBox(width: 24),
                  _HeaderStat(label: 'Rating', value: '—'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _HeaderStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}

class _EarningsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/driver-earnings'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: SRColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'This week',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: SRColors.ink500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: SRColors.lavenderBg,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'View details',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: SRColors.purple700,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded,
                          size: 14, color: SRColors.purple700),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '—',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: SRColors.ink900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final String from;
  final String to;
  final String distance;
  final String eta;
  final VoidCallback onPrice;
  final VoidCallback onSkip;

  const _RequestCard({
    required this.from,
    required this.to,
    required this.distance,
    required this.eta,
    required this.onPrice,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SRColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: SRColors.purple700,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 16,
                    color: SRColors.border,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: SRColors.ink900,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(from,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: SRColors.ink900)),
                    const SizedBox(height: 6),
                    Text(to,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: SRColors.ink900)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    distance,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: SRColors.ink900,
                    ),
                  ),
                  Text(
                    '$eta away',
                    style: const TextStyle(
                        fontSize: 11, color: SRColors.ink500),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onSkip,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: SRColors.border, width: 1.5),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Center(
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: SRColors.ink700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: onPrice,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: SRColors.purple700,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Center(
                      child: Text(
                        'Send price',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
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

class _DriverBottomNav extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;

  const _DriverBottomNav({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_rounded, Icons.home_outlined, 'Home'),
      (Icons.history_rounded, Icons.history_outlined, 'My Rides'),
      (Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Earnings'),
      (Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
    ];
    return Container(
      height: 70 + MediaQuery.of(context).padding.bottom,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: SRColors.border)),
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final active = i == selected;
          final item = items[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    active ? item.$1 : item.$2,
                    color:
                        active ? SRColors.purple700 : SRColors.ink500,
                    size: 26,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.$3,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? SRColors.purple700
                          : SRColors.ink500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
