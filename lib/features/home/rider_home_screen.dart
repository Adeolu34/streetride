import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/background_poll_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/permission_setup_sheet.dart';
import '../../core/services/session_service.dart';
import '../../core/widgets/ride_notification_overlay.dart';
import '../booking/providers/ride_provider.dart';
import '../../core/models/ride_model.dart';
import '../wallet/wallet_screen.dart';
import '../profile/profile_screen.dart';
import '../trips/trips_screen.dart';
import 'widgets/home_header.dart';
import 'widgets/active_offer_card.dart';
import 'widgets/nearby_map_card.dart';

class RiderHomeScreen extends ConsumerStatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  ConsumerState<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends ConsumerState<RiderHomeScreen>
    with WidgetsBindingObserver {
  int _tab = 0;

  static const _tabs = [
    _HomeTab(),
    TripsScreen(),
    WalletScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SRColors.lavenderBg,
      body: RideNotificationOverlay(
        child: IndexedStack(index: _tab, children: _tabs),
      ),
      bottomNavigationBar: _BottomNav(
        current: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = SessionService.instance;
    final rideState = ref.watch(rideProvider);

    final bookingCard = GestureDetector(
      onTap: () => context.push('/search'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: SRColors.purple700.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.search_rounded,
                    color: SRColors.purple700, size: 24),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Where to?',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: SRColors.ink900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: SRColors.lavenderBg,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 14, color: SRColors.ink500),
                      SizedBox(width: 4),
                      Text('Now',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: SRColors.ink500)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(
                height: 22, color: SRColors.lavenderBg, thickness: 1),
            Row(
              children: [
                _QuickChip(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  onTap: () => context.push('/search'),
                ),
                const SizedBox(width: 8),
                _QuickChip(
                  icon: Icons.work_rounded,
                  label: 'Work',
                  onTap: () => context.push('/search'),
                ),
                const SizedBox(width: 8),
                _QuickChip(
                  icon: Icons.flight_rounded,
                  label: 'Airport',
                  onTap: () => context.push('/search'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Column(
      children: [
        HomeHeader(profile: session.profile, bookingCard: bookingCard),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                const SizedBox(height: 12),

                // ── Active ride card ───────────────────────────────────
                if (rideState.activeRide != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _ActiveRideCard(
                      ride: rideState.activeRide!,
                      onTrack: () => context.push('/live-tracking', extra: {
                        'driverName': rideState.activeRide!.driverName.isNotEmpty
                            ? rideState.activeRide!.driverName
                            : 'Driver',
                        'driverInitials': _initials(rideState.activeRide!.driverName),
                        'car': rideState.activeRide!.vehicleType.isNotEmpty
                            ? rideState.activeRide!.vehicleType
                            : '—',
                        'rating': 0.0,
                        'price': int.tryParse(rideState.activeRide!.priceByDriver) ?? 0,
                        'from': rideState.activeRide!.fromText,
                        'to': rideState.activeRide!.toText,
                        'reqId': rideState.activeRide!.reqId,
                      }),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Pending requests card ──────────────────────────────
                if (rideState.pendingRides.isNotEmpty && rideState.activeRide == null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _PendingRidesCard(
                      rides: rideState.pendingRides,
                      onView: () => context.push('/request-pending', extra: {
                        'from': rideState.pendingRides.first.fromText,
                        'to': rideState.pendingRides.first.toText,
                        'selectedCount': rideState.pendingRides.length,
                        'reqIds': rideState.pendingRides.map((r) => r.reqId).toList(),
                      }),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Price offer card or promo banner ───────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: rideState.activeOffer != null
                      ? ActiveOfferCard(
                          ride: rideState.activeOffer!,
                          onAccept: () => ref
                              .read(rideProvider.notifier)
                              .acceptOffer(rideState.activeOffer!),
                          onDecline: () => ref
                              .read(rideProvider.notifier)
                              .declineOffer(rideState.activeOffer!),
                        )
                      : (rideState.activeRide == null && rideState.pendingRides.isEmpty)
                          ? _PromoBanner()
                          : const SizedBox.shrink(),
                ),

                if (rideState.activeOffer == null &&
                    (rideState.activeRide != null || rideState.pendingRides.isNotEmpty))
                  const SizedBox(height: 0)
                else
                  const SizedBox(height: 12),

                // ── Nearby drivers map card ────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: NearbyMapCard(
                    driverCount: rideState.nearbyDriverCount,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: SRColors.surfaceAlt,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: SRColors.purple700),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: SRColors.ink700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  if (parts.isNotEmpty) return parts[0][0].toUpperCase();
  return 'D';
}

// ── Active Ride Card ──────────────────────────────────────────────────────────

class _ActiveRideCard extends StatelessWidget {
  final RideMessage ride;
  final VoidCallback onTrack;

  const _ActiveRideCard({required this.ride, required this.onTrack});

  @override
  Widget build(BuildContext context) {
    final movt = ride.movtStatusDriver.toLowerCase().trim();
    final String statusText;
    final Color statusColor;

    if (movt == 'started') {
      statusText = 'Driver on the way';
      statusColor = SRColors.green500;
    } else if (movt == 'arrived') {
      statusText = 'Driver has arrived!';
      statusColor = SRColors.amber500;
    } else if (movt == 'intransit') {
      statusText = 'In transit';
      statusColor = SRColors.purple300;
    } else {
      statusText = 'Ride confirmed';
      statusColor = SRColors.green500;
    }

    final driverName =
        ride.driverName.isNotEmpty ? ride.driverName : 'Your driver';
    final car = ride.vehicleType.isNotEmpty ? ride.vehicleType : 'Vehicle';
    final price = ride.priceByDriver.isNotEmpty ? '₦${ride.priceByDriver}' : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: SRColors.gradNight,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: SRColors.indigo900.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (price.isNotEmpty)
                Text(
                  price,
                  style: const TextStyle(
                    color: SRColors.amber500,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Driver info
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: SRColors.purple700,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    _initials(driverName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      car,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Route summary
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: SRColors.purple300,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 1.5,
                      height: 18,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: Colors.white24,
                    ),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: Colors.white,
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
                      Text(
                        ride.fromText.isEmpty ? 'Pickup' : ride.fromText,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ride.toText.isEmpty ? 'Destination' : ride.toText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Track button
          GestureDetector(
            onTap: onTrack,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: SRColors.purple700,
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on_rounded,
                      color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Track live',
                    style: TextStyle(
                      color: Colors.white,
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
    );
  }
}

// ── Pending Rides Card ────────────────────────────────────────────────────────

class _PendingRidesCard extends StatefulWidget {
  final List<RideMessage> rides;
  final VoidCallback onView;

  const _PendingRidesCard({required this.rides, required this.onView});

  @override
  State<_PendingRidesCard> createState() => _PendingRidesCardState();
}

class _PendingRidesCardState extends State<_PendingRidesCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.rides.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: SRColors.amber500.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: SRColors.amber500.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Pulsing indicator
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: SRColors.amber500
                    .withValues(alpha: 0.1 + _pulse.value * 0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: SRColors.amber500,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Waiting for $count driver${count == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: SRColors.ink900,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Drivers are reviewing your request',
                  style: TextStyle(fontSize: 11, color: SRColors.ink500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: widget.onView,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: SRColors.lavenderBg,
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Text(
                'View',
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

class _PromoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SRColors.indigo900,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: SRColors.amber500.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bolt_rounded,
                color: SRColors.amber500, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready to ride?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Tap "Where to?" above to book your next trip.',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int current;
  final void Function(int) onTap;

  const _BottomNav({required this.current, required this.onTap});

  static const _items = [
    (Icons.home_rounded, Icons.home_outlined, 'Home'),
    (Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Trips'),
    (Icons.account_balance_wallet_rounded, Icons.account_balance_wallet_outlined, 'Wallet'),
    (Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64 + MediaQuery.of(context).padding.bottom,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: SRColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(_items.length, (i) {
            final item = _items[i];
            final active = i == current;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      active ? item.$1 : item.$2,
                      color: active ? SRColors.purple700 : SRColors.ink500.withValues(alpha: 0.6),
                      size: 24,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.$3,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? SRColors.purple700 : SRColors.ink500.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
