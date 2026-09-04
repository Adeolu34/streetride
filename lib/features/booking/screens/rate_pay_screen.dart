import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/ride_api.dart';
import '../../../core/theme/app_theme.dart';

class RatePayScreen extends ConsumerStatefulWidget {
  final String driverName;
  final String car;
  final double rating;
  final int price;
  final String to;
  final String reqId;

  const RatePayScreen({
    super.key,
    required this.driverName,
    required this.car,
    required this.rating,
    required this.price,
    required this.to,
    required this.reqId,
  });

  @override
  ConsumerState<RatePayScreen> createState() => _RatePayScreenState();
}

class _RatePayScreenState extends ConsumerState<RatePayScreen> {
  int _stars = 0;
  String _carCondition = '';
  String _safety = '';
  String _fairness = '';
  final _commentCtrl = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (widget.reqId.isNotEmpty) {
      await Future.wait([
        RideApi.instance.rateDriver(
          reqId: widget.reqId,
          rate: _stars > 0 ? _stars.toString() : '0',
          comment: _commentCtrl.text.trim(),
          carCondition: _carCondition.isNotEmpty ? _carCondition : 'Good',
          safety: _safety.isNotEmpty ? _safety : 'Safe',
          fairness: _fairness.isNotEmpty ? _fairness : 'Fair',
        ).catchError((_) => <String, dynamic>{}),
        RideApi.instance
            .setRiderStatus(widget.reqId, 'Completed')
            .catchError((_) => <String, dynamic>{}),
      ]);
    }
    if (!mounted) return;
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) context.go('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.driverName.split(' ').first;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Header
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: const BoxDecoration(
                          color: SRColors.green100, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded,
                          color: SRColors.green500, size: 36),
                    ),
                    const SizedBox(height: 12),
                    const Text("You've arrived",
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: SRColors.ink900)),
                    const SizedBox(height: 5),
                    Text(
                      'Hope you enjoyed your trip to ${widget.to}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: SRColors.ink500),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Fare card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    border: Border.all(color: SRColors.border),
                    borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.verified_rounded, size: 14, color: SRColors.green600),
                      SizedBox(width: 5),
                      Text('FAIR PRICE · no surge applied',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: SRColors.green600,
                              letterSpacing: 0.3)),
                    ]),
                    const SizedBox(height: 12),
                    _FareRow(label: 'Trip fare', value: '₦${widget.price}'),
                    const SizedBox(height: 6),
                    _FareRow(label: 'Booking fee', value: '₦0'),
                    const SizedBox(height: 10),
                    const Divider(color: SRColors.border, height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: SRColors.ink900)),
                        Text('₦${widget.price}',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: SRColors.purple700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Row(children: [
                      Icon(Icons.account_balance_wallet_rounded,
                          size: 14, color: SRColors.purple700),
                      SizedBox(width: 5),
                      Text('Paid with Wallet',
                          style: TextStyle(fontSize: 12, color: SRColors.ink500)),
                    ]),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Overall star rating
              Text('Rate $firstName',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: SRColors.ink900)),
              const SizedBox(height: 12),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    return GestureDetector(
                      onTap: () => setState(() => _stars = i + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.star_rounded,
                          size: 40,
                          color: i < _stars ? SRColors.amber500 : SRColors.border,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  _stars == 0
                      ? 'Tap a star to rate'
                      : ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'][_stars],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _stars == 0 ? SRColors.ink500 : SRColors.amber500,
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Car condition
              _SectionLabel('Car condition'),
              const SizedBox(height: 8),
              _OptionRow(
                options: const ['Good', 'Average', 'Poor'],
                selected: _carCondition,
                colors: const [SRColors.green500, SRColors.amber500, SRColors.coral500],
                onSelect: (v) => setState(() => _carCondition = v),
              ),

              const SizedBox(height: 16),

              // Price fairness
              _SectionLabel('Price fairness'),
              const SizedBox(height: 8),
              _OptionRow(
                options: const ['Fair', 'Slightly high', 'Overpriced'],
                selected: _fairness,
                colors: const [SRColors.green500, SRColors.amber500, SRColors.coral500],
                onSelect: (v) => setState(() => _fairness = v),
              ),

              const SizedBox(height: 16),

              // Safety
              _SectionLabel('Safety'),
              const SizedBox(height: 8),
              _OptionRow(
                options: const ['Safe', 'Moderate', 'Unsafe'],
                selected: _safety,
                colors: const [SRColors.green500, SRColors.amber500, SRColors.coral500],
                onSelect: (v) => setState(() => _safety = v),
              ),

              const SizedBox(height: 16),

              // Comment
              _SectionLabel('Leave a comment (optional)'),
              const SizedBox(height: 8),
              TextField(
                controller: _commentCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Tell us about your experience…',
                  hintStyle: const TextStyle(color: SRColors.ink500, fontSize: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: SRColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: SRColors.border),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),

              const SizedBox(height: 28),

              // Submit
              GestureDetector(
                onTap: _submitted ? null : _submit,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 54,
                  decoration: BoxDecoration(
                    color: _submitted ? SRColors.green500 : SRColors.purple700,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: SRColors.purple700.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _submitted
                        ? const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.check_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('Done!',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                          ])
                        : const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.check_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('Submit & done',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                          ]),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: SRColors.ink700));
}

class _OptionRow extends StatelessWidget {
  final List<String> options;
  final List<Color> colors;
  final String selected;
  final ValueChanged<String> onSelect;

  const _OptionRow({
    required this.options,
    required this.colors,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(options.length, (i) {
        final opt = options[i];
        final col = colors[i];
        final active = selected == opt;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: i < options.length - 1 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: active ? col.withValues(alpha: 0.12) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: active ? col : SRColors.border,
                    width: active ? 1.5 : 1),
              ),
              child: Column(
                children: [
                  Icon(
                    i == 0
                        ? Icons.sentiment_satisfied_rounded
                        : i == 1
                            ? Icons.sentiment_neutral_rounded
                            : Icons.sentiment_dissatisfied_rounded,
                    color: active ? col : SRColors.ink500,
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  Text(opt,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: active ? col : SRColors.ink500)),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _FareRow extends StatelessWidget {
  final String label;
  final String value;
  const _FareRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: SRColors.ink500)),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: SRColors.ink900)),
      ],
    );
  }
}
