import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/ride_api.dart';
import '../../core/models/ride_model.dart';
import '../../core/theme/app_theme.dart';
import '../../features/booking/providers/ride_provider.dart';

class DriverOfferStatusScreen extends ConsumerStatefulWidget {
  final int price;
  final String reqId;
  final String fromText;
  final String toText;
  final String riderName;

  const DriverOfferStatusScreen({
    super.key,
    required this.price,
    required this.reqId,
    required this.fromText,
    required this.toText,
    required this.riderName,
  });

  @override
  ConsumerState<DriverOfferStatusScreen> createState() =>
      _DriverOfferStatusScreenState();
}

class _DriverOfferStatusScreenState
    extends ConsumerState<DriverOfferStatusScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(rideProvider.notifier).poll();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  RideMessage? _activeRide(List<RideMessage> messages) {
    if (widget.reqId.isEmpty) return null;
    try {
      return messages.firstWhere((m) => m.reqId == widget.reqId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _cancelOffer() async {
    if (widget.reqId.isNotEmpty) {
      await RideApi.instance
          .setDriverMovementStatus(widget.reqId, 'Cancel')
          .catchError((_) => <String, dynamic>{});
    }
    ref.read(rideProvider.notifier).stopPolling();
    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(rideProvider).messages;
    final ride = _activeRide(messages);

    final isAccepted =
        ride?.statusLabel == RideStatusLabel.accepted ||
        ride?.confirmStatusRider.toLowerCase() == 'accept';
    final isRejected =
        ride?.rideStatusRider.toLowerCase() == 'reject price' ||
        ride?.statusLabel == RideStatusLabel.rejected;

    // Auto-navigate when rider accepts
    if (isAccepted && !_navigated) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/driver-navigate', extra: {'reqId': widget.reqId});
      });
    }

    return Scaffold(
      backgroundColor: SRColors.lavenderBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back_rounded, color: SRColors.ink900),
        ),
        title: const Text(
          'Offer status',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: SRColors.ink900,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ActiveOfferCard(
              price: widget.price,
              fromText: widget.fromText.isNotEmpty
                  ? widget.fromText
                  : 'Pickup',
              toText: widget.toText.isNotEmpty
                  ? widget.toText
                  : 'Drop-off',
              riderName: widget.riderName.isNotEmpty
                  ? widget.riderName
                  : 'Rider',
              isAccepted: isAccepted,
              isRejected: isRejected,
              reqId: widget.reqId,
              onCancel: _cancelOffer,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveOfferCard extends StatelessWidget {
  final int price;
  final String fromText;
  final String toText;
  final String riderName;
  final bool isAccepted;
  final bool isRejected;
  final String reqId;
  final VoidCallback onCancel;

  const _ActiveOfferCard({
    required this.price,
    required this.fromText,
    required this.toText,
    required this.riderName,
    required this.isAccepted,
    required this.isRejected,
    required this.reqId,
    required this.onCancel,
  });

  Color get _borderColor {
    if (isAccepted) return SRColors.green500;
    if (isRejected) return SRColors.coral500;
    return SRColors.purple700;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: _borderColor.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusBadge(
                isAccepted: isAccepted,
                isRejected: isRejected,
              ),
              const Spacer(),
              if (!isAccepted && !isRejected)
                const Row(
                  children: [
                    _PulseDot(),
                    SizedBox(width: 5),
                    Text(
                      'Live',
                      style: TextStyle(
                        fontSize: 12,
                        color: SRColors.purple700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '$fromText → $toText',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: SRColors.ink900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Rider: $riderName',
            style: const TextStyle(fontSize: 12, color: SRColors.ink500),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₦$price',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: isAccepted
                      ? SRColors.green600
                      : isRejected
                          ? SRColors.coral500
                          : SRColors.purple700,
                ),
              ),
              if (isAccepted)
                GestureDetector(
                  onTap: () => context.go('/driver-navigate', extra: {'reqId': reqId}),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: SRColors.purple700,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'Navigate to pickup',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              else if (isRejected)
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: SRColors.coral100,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'Adjust price',
                      style: TextStyle(
                        color: SRColors.coral500,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: onCancel,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: SRColors.lavenderBg,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'Cancel offer',
                      style: TextStyle(
                        color: SRColors.ink700,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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

class _StatusBadge extends StatelessWidget {
  final bool isAccepted;
  final bool isRejected;
  const _StatusBadge({required this.isAccepted, required this.isRejected});

  @override
  Widget build(BuildContext context) {
    if (isAccepted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: SRColors.green100,
          borderRadius: BorderRadius.circular(99),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded,
                size: 12, color: SRColors.green500),
            SizedBox(width: 4),
            Text(
              'ACCEPTED',
              style: TextStyle(
                color: SRColors.green600,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }
    if (isRejected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: SRColors.coral100,
          borderRadius: BorderRadius.circular(99),
        ),
        child: const Row(
          children: [
            Icon(Icons.close_rounded, size: 12, color: SRColors.coral500),
            SizedBox(width: 4),
            Text(
              'PRICE REJECTED',
              style: TextStyle(
                color: SRColors.coral500,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: SRColors.purple100,
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: SRColors.purple700,
            ),
          ),
          SizedBox(width: 6),
          Text(
            'AWAITING RESPONSE',
            style: TextStyle(
              color: SRColors.purple700,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: SRColors.purple700.withValues(alpha: 0.5 + 0.5 * _anim.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
