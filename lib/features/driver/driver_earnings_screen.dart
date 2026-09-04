import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/session_service.dart';
import '../../core/api/ride_api.dart';

class DriverEarningsScreen extends StatefulWidget {
  final bool showBackButton;
  const DriverEarningsScreen({super.key, this.showBackButton = true});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  bool _loading = true;
  int _weeklyTotal = 0;
  int _tripCount = 0;
  List<_EarningTrip> _tripLog = [];
  List<({String day, int amount, bool isBest})> _dayData = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profile = SessionService.instance.profile;
    if (profile == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final res = await RideApi.instance.getPaymentHistory(profile.phone);
      final history = res['History'];
      if (history is List) {
        final trips = history.whereType<Map<String, dynamic>>().toList();

        // Build trip log from completed rides
        final log = <_EarningTrip>[];
        int weekTotal = 0;
        final Map<String, int> dailyMap = {};

        for (final j in trips) {
          final status = (j['RideStatus_R'] ?? j['MovtStatus_D'] ?? '').toString().toLowerCase();
          if (status.contains('cancel') || status.contains('reject')) continue;

          final to = (j['toText'] ?? j['ToText'] ?? '').toString();
          final time = (j['Reqtime'] ?? j['reqtime'] ?? '').toString();
          final rawAmt = j['Price_D'] ?? j['amount'] ?? '0';
          final amt = int.tryParse(rawAmt.toString()) ?? 0;
          if (amt <= 0) continue;

          log.add(_EarningTrip(to: to.isNotEmpty ? to : 'Trip', time: time, amount: amt));
          weekTotal += amt;

          // Extract day label from time (e.g., "2024-01-15 14:30" → use day of week)
          if (time.length >= 10) {
            final dayKey = time.substring(0, 10);
            dailyMap[dayKey] = (dailyMap[dayKey] ?? 0) + amt;
          }
        }

        // Build bar chart data from last 7 unique days
        final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        List<({String day, int amount, bool isBest})> dayData;

        if (dailyMap.isNotEmpty) {
          final sortedDays = dailyMap.keys.toList()..sort();
          final last7 = sortedDays.length > 7
              ? sortedDays.sublist(sortedDays.length - 7)
              : sortedDays;
          final maxAmt = last7.map((d) => dailyMap[d]!).reduce((a, b) => a > b ? a : b);
          dayData = List.generate(last7.length, (i) {
            final amt = dailyMap[last7[i]]!;
            return (
              day: dayLabels[i % dayLabels.length],
              amount: amt,
              isBest: amt == maxAmt,
            );
          });
        } else {
          dayData = [];
        }

        if (mounted) {
          setState(() {
            _tripLog = log.take(10).toList();
            _weeklyTotal = weekTotal;
            _tripCount = log.length;
            _dayData = dayData;
          });
        }
      }
    } catch (_) {}

    // Also try BK12 for subscription/charge history
    try {
      await RideApi.instance.getChargeHistory(profile.phone);
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SRColors.lavenderBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: widget.showBackButton
            ? GestureDetector(
                onTap: () => context.pop(),
                child: const Icon(Icons.arrow_back_rounded,
                    color: SRColors.ink900),
              )
            : null,
        title: const Text(
          'Earnings',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: SRColors.ink900,
          ),
        ),
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap: () => context.push('/driver-plans'),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: SRColors.purple100,
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Text(
                'Plans',
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WeeklyCard(
                      total: _weeklyTotal,
                      tripCount: _tripCount,
                    ),
                    const SizedBox(height: 20),
                    if (_dayData.isNotEmpty) ...[
                      const Text(
                        'Daily breakdown',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: SRColors.ink900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _BarChart(dayData: _dayData),
                      const SizedBox(height: 20),
                    ],
                    const Text(
                      'Trip log',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: SRColors.ink900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_tripLog.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No completed trips yet',
                            style:
                                TextStyle(color: SRColors.ink500, fontSize: 14),
                          ),
                        ),
                      )
                    else
                      ..._tripLog.map((t) => _TripLogRow(trip: t)),
                    const SizedBox(height: 20),
                    _CashOutButton(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}

class _WeeklyCard extends StatelessWidget {
  final int total;
  final int tripCount;
  const _WeeklyCard({required this.total, required this.tripCount});

  @override
  Widget build(BuildContext context) {
    final avg = tripCount > 0 ? total ~/ tripCount : 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: SRColors.gradNight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total earnings',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            '₦${_fmt(total)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _WeekStat(label: 'Trips', value: '$tripCount'),
              _WeekStatDivider(),
              _WeekStat(
                  label: 'Avg/trip', value: avg > 0 ? '₦${_fmt(avg)}' : '—'),
              _WeekStatDivider(),
              _WeekStat(label: 'Status', value: tripCount > 0 ? 'Active' : '—'),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _WeekStat extends StatelessWidget {
  final String label;
  final String value;
  const _WeekStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _WeekStatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 28, color: Colors.white12);
  }
}

class _BarChart extends StatelessWidget {
  final List<({String day, int amount, bool isBest})> dayData;
  const _BarChart({required this.dayData});

  @override
  Widget build(BuildContext context) {
    final max = dayData.map((d) => d.amount).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SRColors.border),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: dayData.map((d) {
                final ratio = max > 0 ? d.amount / max : 0.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (d.isBest)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              '₦${(d.amount / 1000).toStringAsFixed(1)}k',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: SRColors.amber600,
                              ),
                            ),
                          ),
                        Container(
                          height: 80 * ratio,
                          decoration: BoxDecoration(
                            color: d.isBest
                                ? SRColors.amber500
                                : SRColors.purple100,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: dayData
                .map(
                  (d) => Expanded(
                    child: Text(
                      d.day,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color:
                            d.isBest ? SRColors.amber600 : SRColors.ink500,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _EarningTrip {
  final String to;
  final String time;
  final int amount;
  const _EarningTrip({required this.to, required this.time, required this.amount});
}

class _TripLogRow extends StatelessWidget {
  final _EarningTrip trip;
  const _TripLogRow({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SRColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: SRColors.purple100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.directions_car_rounded,
                color: SRColors.purple700, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.to,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: SRColors.ink900,
                  ),
                ),
                Text(
                  trip.time,
                  style: const TextStyle(fontSize: 11, color: SRColors.ink500),
                ),
              ],
            ),
          ),
          Text(
            '+₦${trip.amount}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: SRColors.green600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashOutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: SRColors.gradWallet,
          borderRadius: BorderRadius.circular(99),
          boxShadow: [
            BoxShadow(
              color: SRColors.purple700.withValues(alpha: 0.28),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Cash out earnings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
