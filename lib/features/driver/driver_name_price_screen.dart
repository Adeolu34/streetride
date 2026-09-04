import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/ride_api.dart';
import '../../core/theme/app_theme.dart';

class DriverNamePriceScreen extends ConsumerStatefulWidget {
  final String reqId;
  final String fromText;
  final String toText;
  final String riderName;
  final String riderInitials;
  final String km;
  final String eta;

  const DriverNamePriceScreen({
    super.key,
    required this.reqId,
    required this.fromText,
    required this.toText,
    required this.riderName,
    required this.riderInitials,
    required this.km,
    required this.eta,
  });

  @override
  ConsumerState<DriverNamePriceScreen> createState() =>
      _DriverNamePriceScreenState();
}

class _DriverNamePriceScreenState extends ConsumerState<DriverNamePriceScreen>
    with SingleTickerProviderStateMixin {
  final _priceController = TextEditingController();
  int _secondsLeft = 45;
  late AnimationController _ring;
  bool _sending = false;

  final _quickPrices = [1500, 2000, 2500, 3000];

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 45),
    )..forward();

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _secondsLeft = (_secondsLeft - 1).clamp(0, 45));
      if (_secondsLeft == 0) {
        if (mounted) context.pop();
        return false;
      }
      return true;
    });
  }

  @override
  void dispose() {
    _ring.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _sendPrice() async {
    final price = int.tryParse(_priceController.text);
    if (price == null || price <= 0 || _sending) return;
    setState(() => _sending = true);
    if (widget.reqId.isNotEmpty) {
      // Set price, then sync both sides: driver = Set Price, rider = Awaiting Response
      await RideApi.instance
          .setPrice(reqId: widget.reqId, price: price.toString())
          .catchError((_) => <String, dynamic>{});
      await Future.wait([
        RideApi.instance
            .setDriverMovementStatus(widget.reqId, 'Set Price')
            .catchError((_) => <String, dynamic>{}),
        RideApi.instance
            .setRiderStatus(widget.reqId, 'Awaiting Response')
            .catchError((_) => <String, dynamic>{}),
      ]);
    }
    if (!mounted) return;
    context.push('/driver-offer-status', extra: {
      'price': price,
      'reqId': widget.reqId,
      'fromText': widget.fromText,
      'toText': widget.toText,
      'riderName': widget.riderName,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0A1E),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white70, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Name your price',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _CountdownRing(seconds: _secondsLeft, total: 45),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RiderInfoRow(
                      name: widget.riderName,
                      initials: widget.riderInitials,
                    ),
                    const SizedBox(height: 14),
                    _RouteRow(
                      from: widget.fromText.isNotEmpty
                          ? widget.fromText
                          : 'Pickup',
                      to: widget.toText.isNotEmpty
                          ? widget.toText
                          : 'Drop-off',
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (widget.km.isNotEmpty && widget.km != '—')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: SRColors.purple700.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '${widget.km} km',
                              style: const TextStyle(
                                fontSize: 12,
                                color: SRColors.purple300,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (widget.km.isNotEmpty && widget.km != '—')
                          const SizedBox(width: 8),
                        if (widget.eta.isNotEmpty && widget.eta != '—')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '~${widget.eta} min',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white60,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your price (₦)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      prefixText: '₦',
                      prefixStyle: const TextStyle(
                        color: SRColors.amber500,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _quickPrices.map((p) {
                      return GestureDetector(
                        onTap: () {
                          _priceController.text = p.toString();
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: SRColors.amber500.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: SRColors.amber500.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            '₦$p',
                            style: const TextStyle(
                              color: SRColors.amber500,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Center(
                              child: Text(
                                'Skip',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: (_priceController.text.isEmpty || _sending)
                              ? null
                              : _sendPrice,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 50,
                            decoration: BoxDecoration(
                              color: (_priceController.text.isEmpty || _sending)
                                  ? SRColors.purple700.withValues(alpha: 0.4)
                                  : SRColors.purple700,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Center(
                              child: _sending
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Send price',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
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
            const SizedBox(height: 28),
          ],
        ),
        ),
      ),
    );
  }
}

class _CountdownRing extends StatelessWidget {
  final int seconds;
  final int total;
  const _CountdownRing({required this.seconds, required this.total});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: seconds / total,
            strokeWidth: 3,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              seconds < 10 ? SRColors.coral500 : SRColors.amber500,
            ),
          ),
          Text(
            '$seconds',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiderInfoRow extends StatelessWidget {
  final String name;
  final String initials;
  const _RiderInfoRow({required this.name, required this.initials});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: SRColors.purple700.withValues(alpha: 0.3),
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Row(
              children: [
                Icon(Icons.star_rounded,
                    size: 12, color: SRColors.amber500),
                SizedBox(width: 3),
                Text(
                  'Rider',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _RouteRow extends StatelessWidget {
  final String from;
  final String to;
  const _RouteRow({required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 3),
              decoration: const BoxDecoration(
                color: SRColors.purple700,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 2,
              height: 18,
              color: Colors.white24,
              margin: const EdgeInsets.symmetric(vertical: 2),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: SRColors.amber500,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(from,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            Text(to,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }
}
