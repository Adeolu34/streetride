import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/ride_api.dart';
import '../../../core/models/ride_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/sr_button.dart';
import '../providers/ride_provider.dart';

class RequestPendingScreen extends ConsumerStatefulWidget {
  final String from;
  final String to;
  final int selectedCount;
  final List<String> reqIds;

  const RequestPendingScreen({
    super.key,
    required this.from,
    required this.to,
    required this.selectedCount,
    this.reqIds = const [],
  });

  @override
  ConsumerState<RequestPendingScreen> createState() =>
      _RequestPendingScreenState();
}

class _RequestPendingScreenState extends ConsumerState<RequestPendingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinner;
  int _secondsLeft = 120;
  Timer? _timer;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _spinner = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(rideProvider.notifier).poll();
    });
  }

  @override
  void dispose() {
    _spinner.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String get _timerLabel {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _accept(RideMessage ride) async {
    await RideApi.instance.acceptPrice(ride.reqId);
    if (!mounted) return;
    ref.read(rideProvider.notifier).stopPolling();
    context.pushReplacement('/driver-offers', extra: {
      'from': widget.from,
      'to': widget.to,
      'reqIds': widget.reqIds,
    });
  }

  Future<void> _decline(RideMessage ride) async {
    await RideApi.instance.rejectPrice(ride.reqId);
    ref.read(rideProvider.notifier).poll();
  }

  Future<void> _cancelAll() async {
    if (_cancelling) return;
    setState(() => _cancelling = true);
    final toCancel = ref.read(rideProvider).messages.where((m) =>
      m.statusLabel == RideStatusLabel.pending ||
      m.statusLabel == RideStatusLabel.offerReceived,
    ).toList();
    await Future.wait(
      toCancel.map((m) => RideApi.instance
          .setRiderStatus(m.reqId, 'Cancelled')
          .catchError((_) => <String, dynamic>{})),
    );
    ref.read(rideProvider.notifier).stopPolling();
    if (!mounted) return;
    context.go('/home');
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty) return parts[0][0].toUpperCase();
    return 'D';
  }

  static String? _cardState(RideMessage m) {
    if (m.statusLabel == RideStatusLabel.offerReceived) {
      final raw = m.priceByDriver.trim();
      return raw.isNotEmpty ? '₦$raw' : null;
    }
    if (m.movtStatusDriver.isNotEmpty) return 'viewed';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final rideState = ref.watch(rideProvider);
    final rides = rideState.messages.where((m) =>
      m.statusLabel != RideStatusLabel.cancelled &&
      m.statusLabel != RideStatusLabel.rejected &&
      m.statusLabel != RideStatusLabel.accepted &&
      m.statusLabel != RideStatusLabel.inTransit &&
      m.statusLabel != RideStatusLabel.arrived &&
      m.statusLabel != RideStatusLabel.pickup &&
      (widget.reqIds.isEmpty || widget.reqIds.contains(m.reqId)),
    ).toList();

    final pricesIn = rides.where(
      (m) => m.statusLabel == RideStatusLabel.offerReceived,
    ).length;
    final total = rides.isEmpty ? widget.selectedCount : rides.length;
    final pending = total - pricesIn;

    return Scaffold(
      backgroundColor: SRColors.lavenderBg,
      body: SafeArea(
        child: Column(
          children: [
            // Dark header
            Container(
              decoration: const BoxDecoration(
                gradient: SRColors.gradNight,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 23),
                      ),
                      const SizedBox(width: 11),
                      const Text(
                        'Waiting for prices',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: SRColors.amber500.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_rounded,
                                size: 14, color: SRColors.amber500),
                            const SizedBox(width: 4),
                            Text(
                              _timerLabel,
                              style: const TextStyle(
                                color: SRColors.amber500,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            RotationTransition(
                              turns: _spinner,
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border(
                                  top: const BorderSide(
                                      color: SRColors.amber500, width: 3),
                                  right: BorderSide(
                                      color: Colors.transparent, width: 3),
                                  bottom: BorderSide(
                                      color: Colors.transparent, width: 3),
                                  left: BorderSide(
                                      color: Colors.transparent, width: 3),
                                ),
                              ),
                            ),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '$pricesIn',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '/$total',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$pricesIn price${pricesIn == 1 ? '' : 's'} in, $pending driver${pending == 1 ? '' : 's'} still deciding',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Accept any offer the moment it lands.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 11,
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

            const SizedBox(height: 12),

            // Route summary card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: SRColors.border),
                ),
                child: Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: SRColors.purple700,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 12,
                          color: SRColors.border,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                        ),
                        Container(
                          width: 7,
                          height: 7,
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
                          Text(
                            '${widget.from} → ${widget.to}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: SRColors.ink900,
                            ),
                          ),
                          const Text(
                            'pays with Wallet',
                            style: TextStyle(
                              fontSize: 11,
                              color: SRColors.ink500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: const Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: SRColors.purple700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Drivers you asked',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: SRColors.ink900,
                    ),
                  ),
                  Text(
                    'updates live',
                    style: TextStyle(fontSize: 11, color: SRColors.ink500),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: rides.isEmpty
                  ? _buildPlaceholders()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: rides.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final m = rides[i];
                        final cardState = _cardState(m);
                        return _PendingDriverCard(
                          initials: _initials(m.driverName),
                          name: m.driverName.isNotEmpty ? m.driverName : 'Driver',
                          car: m.vehicleType.isNotEmpty ? m.vehicleType : '—',
                          state: cardState,
                          onAccept: cardState != null && cardState.startsWith('₦')
                              ? () => _accept(m)
                              : null,
                          onDecline: cardState != null && cardState.startsWith('₦')
                              ? () => _decline(m)
                              : null,
                        );
                      },
                    ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: Row(
                children: [
                  Expanded(
                    child: SRButton(
                      label: 'Ask more',
                      isSecondary: true,
                      onTap: () => context.pop(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SRButton(
                      label: _cancelling ? 'Cancelling…' : 'Cancel',
                      color: SRColors.coral100,
                      onTap: _cancelling ? null : _cancelAll,
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

  Widget _buildPlaceholders() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: widget.selectedCount,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => const _PendingDriverCard(
        initials: '•',
        name: 'Waiting for response…',
        car: '—',
        state: null,
        onAccept: null,
        onDecline: null,
      ),
    );
  }
}

class _PendingDriverCard extends StatelessWidget {
  final String initials;
  final String name;
  final String car;
  final String? state; // null=pending, '₦X'=offer, 'viewed'=seen
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const _PendingDriverCard({
    required this.initials,
    required this.name,
    required this.car,
    required this.state,
    this.onAccept,
    this.onDecline,
  });

  bool get hasOffer => state != null && state!.startsWith('₦');

  @override
  Widget build(BuildContext context) {
    Color borderColor = SRColors.border;
    if (hasOffer) borderColor = SRColors.green500;
    if (state == 'setting') borderColor = SRColors.amber500;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(15),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: SRColors.purple700,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
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
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: SRColors.ink900,
                      ),
                    ),
                    Text(
                      car,
                      style: const TextStyle(fontSize: 11, color: SRColors.ink500),
                    ),
                  ],
                ),
              ),
              if (hasOffer)
                Text(
                  state!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: SRColors.ink900,
                  ),
                )
              else
                _StatusBadge(state: state),
            ],
          ),
          if (hasOffer) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onDecline,
                    child: Container(
                      height: 34,
                      decoration: BoxDecoration(
                        border: Border.all(color: SRColors.border, width: 1.5),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Center(
                        child: Text('Decline',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: SRColors.ink700)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: onAccept,
                    child: Container(
                      height: 34,
                      decoration: BoxDecoration(
                        color: SRColors.purple700,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Center(
                        child: Text(
                          'Accept $state',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String? state;
  const _StatusBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state == 'setting') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: SRColors.amber100,
          borderRadius: BorderRadius.circular(99),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_rounded, size: 11, color: Color(0xFFB26A00)),
            SizedBox(width: 4),
            Text('SETTING PRICE',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB26A00),
                    letterSpacing: 0.5)),
          ],
        ),
      );
    }
    if (state == 'viewed') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: SRColors.lavenderBg,
          borderRadius: BorderRadius.circular(99),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_rounded, size: 11, color: SRColors.ink500),
            SizedBox(width: 4),
            Text('VIEWED',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: SRColors.ink500,
                    letterSpacing: 0.5)),
          ],
        ),
      );
    }
    return SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: SRColors.ink500.withValues(alpha: 0.5),
      ),
    );
  }
}
