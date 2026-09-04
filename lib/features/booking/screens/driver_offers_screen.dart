import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/ride_api.dart';
import '../../../core/models/ride_model.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/ride_provider.dart';

class DriverOffersScreen extends ConsumerStatefulWidget {
  final String from;
  final String to;
  final List<String> reqIds;

  const DriverOffersScreen({
    super.key,
    required this.from,
    required this.to,
    this.reqIds = const [],
  });

  @override
  ConsumerState<DriverOffersScreen> createState() => _DriverOffersScreenState();
}

class _DriverOffersScreenState extends ConsumerState<DriverOffersScreen> {
  int _secondsLeft = 42;
  Timer? _timer;
  final Set<String> _declinedReqIds = {};

  @override
  void initState() {
    super.initState();
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
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _accept(RideMessage ride) async {
    await RideApi.instance.acceptPrice(ride.reqId);
    ref.read(rideProvider.notifier).stopPolling();
    if (!mounted) return;
    context.push('/live-tracking', extra: {
      'driverName': ride.driverName.isNotEmpty ? ride.driverName : 'Driver',
      'driverInitials': _initials(ride.driverName),
      'car': ride.vehicleType.isNotEmpty ? ride.vehicleType : '—',
      'rating': 0.0,
      'price': _parsePrice(ride.priceByDriver),
      'from': widget.from,
      'to': widget.to,
      'reqId': ride.reqId,
    });
  }

  Future<void> _decline(RideMessage ride) async {
    setState(() => _declinedReqIds.add(ride.reqId));
    await RideApi.instance.rejectPrice(ride.reqId);
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty) return parts[0][0].toUpperCase();
    return 'D';
  }

  static int _parsePrice(String raw) =>
      int.tryParse(raw.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(rideProvider).messages;

    // All offers (priceByDriver set) — include declined for the greyed-out view
    // Filter to this session's reqIds to exclude historical rides from other sessions
    final allOffers = messages
        .where((m) =>
            m.priceByDriver.trim().isNotEmpty &&
            m.statusLabel != RideStatusLabel.cancelled &&
            (widget.reqIds.isEmpty || widget.reqIds.contains(m.reqId)))
        .toList();

    final active = allOffers
        .where((m) => !_declinedReqIds.contains(m.reqId))
        .toList();

    final prices = active.map((m) => _parsePrice(m.priceByDriver)).toList();
    final bestPrice = prices.isEmpty ? 0 : prices.reduce((a, b) => a < b ? a : b);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: SRColors.ink900, size: 24),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${active.length} price${active.length == 1 ? '' : 's'} came in',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: SRColors.ink900,
                          ),
                        ),
                        Text(
                          widget.to,
                          style: const TextStyle(
                              fontSize: 12, color: SRColors.ink500),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: SRColors.amber100,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '0:${_secondsLeft.toString().padLeft(2, '0')} left',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB26A00),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            allOffers.isEmpty
                ? const Expanded(
                    child: Center(
                      child: Text(
                        'No offers yet — drivers are still responding.',
                        style: TextStyle(fontSize: 14, color: SRColors.ink500),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
                      itemCount: allOffers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final m = allOffers[i];
                        if (_declinedReqIds.contains(m.reqId)) {
                          return _DeclinedCard(
                            name: m.driverName.isNotEmpty ? m.driverName : 'Driver',
                            price: _parsePrice(m.priceByDriver),
                          );
                        }
                        final price = _parsePrice(m.priceByDriver);
                        final isBest = price == bestPrice && bestPrice > 0;
                        return _OfferCard(
                          initials: _initials(m.driverName),
                          name: m.driverName.isNotEmpty ? m.driverName : 'Driver',
                          car: m.vehicleType.isNotEmpty ? m.vehicleType : '—',
                          price: price,
                          isBest: isBest,
                          onAccept: () => _accept(m),
                          onDecline: () => _decline(m),
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
      bottomSheet: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        child: const Row(
          children: [
            Icon(Icons.verified_rounded, size: 16, color: SRColors.green600),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'You only pay the price you accept — no surge, no hidden fees.',
                style: TextStyle(fontSize: 11, color: SRColors.ink500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final String initials;
  final String name;
  final String car;
  final int price;
  final bool isBest;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _OfferCard({
    required this.initials,
    required this.name,
    required this.car,
    required this.price,
    required this.isBest,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(13, 16, 13, 13),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: isBest ? SRColors.purple700 : SRColors.border,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: SRColors.purple700.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: SRColors.purple700,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        initials,
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
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: SRColors.ink900,
                          ),
                        ),
                        Text(
                          car,
                          style: const TextStyle(
                              fontSize: 11, color: SRColors.ink500),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₦$price',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: SRColors.ink900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: onDecline,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: SRColors.border, width: 1.5),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Center(
                          child: Text(
                            'Decline',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: SRColors.ink700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    flex: 3,
                    child: GestureDetector(
                      onTap: onAccept,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: isBest
                              ? SRColors.purple700
                              : SRColors.purple100,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Center(
                          child: Text(
                            'Accept ₦$price',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color:
                                  isBest ? Colors.white : SRColors.purple700,
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
        ),
        if (isBest)
          Positioned(
            top: -10,
            left: 13,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: SRColors.green500,
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Text(
                'BEST PRICE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DeclinedCard extends StatelessWidget {
  final String name;
  final int price;

  const _DeclinedCard({required this.name, required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SRColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: SRColors.coral100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded,
                color: SRColors.coral500, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name · ₦$price',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: SRColors.ink900,
                  ),
                ),
                const Text(
                  'Price declined by you',
                  style: TextStyle(fontSize: 11, color: SRColors.coral500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
