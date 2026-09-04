import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/ride_api.dart';
import '../../core/models/ride_model.dart';
import '../../core/services/session_service.dart';
import '../../core/theme/app_theme.dart';
import '../booking/providers/ride_provider.dart';

enum _RideStatus { completed, cancelled, rejected, active, awaiting, pending }

class _HistoryRide {
  final String reqId;
  final String fromText;
  final String toText;
  final String riderName;
  final String price;
  final String time;
  final _RideStatus status;

  const _HistoryRide({
    required this.reqId,
    required this.fromText,
    required this.toText,
    required this.riderName,
    required this.price,
    required this.time,
    required this.status,
  });

  factory _HistoryRide.fromJson(Map<String, dynamic> j) {
    final movt = (j['MovtStatus_D'] ?? '').toString().toLowerCase();
    final ride = (j['RideStatus_R'] ?? '').toString().toLowerCase();
    final price = (j['Price_D'] ?? '').toString().trim();
    final confirm = (j['ConfirmStatus_R'] ?? '').toString().toLowerCase();

    _RideStatus status;
    if (movt == 'completed' || ride == 'completed') {
      status = _RideStatus.completed;
    } else if (movt.contains('cancel') || ride == 'cancelled' || ride == 'withdraw') {
      status = _RideStatus.cancelled;
    } else if (ride.contains('reject') || movt.contains('reject')) {
      status = _RideStatus.rejected;
    } else if (confirm == 'accept' && price.isNotEmpty) {
      status = _RideStatus.active;
    } else if (price.isNotEmpty && ride.isEmpty) {
      status = _RideStatus.awaiting;
    } else {
      status = _RideStatus.pending;
    }

    final name = (j['Dname'] ?? j['Rname'] ?? '').toString().trim();

    return _HistoryRide(
      reqId: (j['reqid'] ?? '').toString(),
      fromText: (j['fromText'] ?? '').toString(),
      toText: (j['toText'] ?? '').toString(),
      riderName: name.isNotEmpty ? name : 'Rider',
      price: price,
      time: (j['Reqtime'] ?? '').toString(),
      status: status,
    );
  }

  factory _HistoryRide.fromMessage(RideMessage m) {
    final movt = m.movtStatusDriver.toLowerCase();
    final ride = m.rideStatusRider.toLowerCase();
    final price = m.priceByDriver.trim();
    final confirm = m.confirmStatusRider.toLowerCase();

    _RideStatus status;
    if (movt == 'completed' || ride == 'completed') {
      status = _RideStatus.completed;
    } else if (movt.contains('cancel') || ride == 'cancelled' || ride == 'withdraw') {
      status = _RideStatus.cancelled;
    } else if (ride.contains('reject') || movt.contains('reject')) {
      status = _RideStatus.rejected;
    } else if (confirm == 'accept' && price.isNotEmpty) {
      status = _RideStatus.active;
    } else if (price.isNotEmpty) {
      status = _RideStatus.awaiting; // sent price, waiting for rider
    } else {
      status = _RideStatus.pending;
    }

    final name = m.riderName.trim();
    return _HistoryRide(
      reqId: m.reqId,
      fromText: m.fromText,
      toText: m.toText,
      riderName: name.isNotEmpty ? name : 'Rider',
      price: price,
      time: m.requestTime,
      status: status,
    );
  }
}

class DriverRideHistoryScreen extends ConsumerStatefulWidget {
  final bool embedded; // true = used as a tab inside DriverHomeScreen
  const DriverRideHistoryScreen({super.key, this.embedded = false});

  @override
  ConsumerState<DriverRideHistoryScreen> createState() =>
      _DriverRideHistoryScreenState();
}

class _DriverRideHistoryScreenState extends ConsumerState<DriverRideHistoryScreen> {
  bool _loading = true;
  List<_HistoryRide> _archive = []; // older completed rides from R11.6
  _RideStatus? _filter;
  String _normalizedPhone = '';

  @override
  void initState() {
    super.initState();
    final phone = SessionService.instance.profile?.phone ?? '';
    _normalizedPhone = phone.startsWith('234')
        ? phone
        : '234${phone.replaceFirst(RegExp(r'^0'), '')}';
    _loadArchive();
  }

  Future<void> _loadArchive() async {
    setState(() => _loading = true);
    try {
      final phone = SessionService.instance.profile?.phone ?? '';
      final res = await RideApi.instance.getPaymentHistory(phone);
      final history = res['History'];
      if (history is List) {
        final rides = history
            .whereType<Map<String, dynamic>>()
            .map(_HistoryRide.fromJson)
            .toList();
        rides.sort((a, b) => b.time.compareTo(a.time));
        if (mounted) setState(() => _archive = rides);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  // Merge BK8 recent rides with R11.6 archive; BK8 wins on conflicts
  List<_HistoryRide> _merge(List<_HistoryRide> recent) {
    final recentIds = recent.map((r) => r.reqId).toSet();
    final merged = [...recent, ..._archive.where((r) => !recentIds.contains(r.reqId))];
    merged.sort((a, b) => b.time.compareTo(a.time));
    return merged;
  }

  List<_HistoryRide> _filtered(List<_HistoryRide> all) =>
      _filter == null ? all : all.where((r) => r.status == _filter).toList();

  int _countOf(_RideStatus s, List<_HistoryRide> all) =>
      all.where((r) => r.status == s).length;

  @override
  Widget build(BuildContext context) {
    final rideState = ref.watch(rideProvider);
    final recentRides = rideState
        .historyForDriver(_normalizedPhone)
        .map(_HistoryRide.fromMessage)
        .toList();
    final all = _merge(recentRides);
    final shown = _filtered(all);
    final completed = _countOf(_RideStatus.completed, all);
    final total = all.length;
    final rate = total > 0 ? (completed / total * 100).round() : 0;

    return Scaffold(
      backgroundColor: SRColors.lavenderBg,
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: GestureDetector(
                onTap: () => context.pop(),
                child: const Icon(Icons.arrow_back_rounded, color: SRColors.ink900),
              ),
              title: const Text(
                'Ride History',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: SRColors.ink900,
                ),
              ),
              centerTitle: true,
            ),
      body: _loading && all.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: SRColors.purple700))
          : RefreshIndicator(
              onRefresh: _loadArchive,
              color: SRColors.purple700,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.embedded)
                            const SafeArea(
                              bottom: false,
                              child: Padding(
                                padding: EdgeInsets.only(top: 8, bottom: 12),
                                child: Text(
                                  'My Rides',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: SRColors.ink900,
                                  ),
                                ),
                              ),
                            ),
                          _SummaryStrip(
                            total: total,
                            completed: completed,
                            rate: rate,
                          ),
                          const SizedBox(height: 16),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _FilterChip(
                                  label: 'All',
                                  count: total,
                                  active: _filter == null,
                                  onTap: () => setState(() => _filter = null),
                                ),
                                const SizedBox(width: 8),
                                _FilterChip(
                                  label: 'Awaiting',
                                  count: _countOf(_RideStatus.awaiting, all),
                                  active: _filter == _RideStatus.awaiting,
                                  color: SRColors.amber500,
                                  onTap: () => setState(() => _filter = _RideStatus.awaiting),
                                ),
                                const SizedBox(width: 8),
                                _FilterChip(
                                  label: 'Active',
                                  count: _countOf(_RideStatus.active, all),
                                  active: _filter == _RideStatus.active,
                                  color: SRColors.purple700,
                                  onTap: () => setState(() => _filter = _RideStatus.active),
                                ),
                                const SizedBox(width: 8),
                                _FilterChip(
                                  label: 'Completed',
                                  count: _countOf(_RideStatus.completed, all),
                                  active: _filter == _RideStatus.completed,
                                  color: SRColors.green500,
                                  onTap: () => setState(() => _filter = _RideStatus.completed),
                                ),
                                const SizedBox(width: 8),
                                _FilterChip(
                                  label: 'Cancelled',
                                  count: _countOf(_RideStatus.cancelled, all),
                                  active: _filter == _RideStatus.cancelled,
                                  color: SRColors.coral500,
                                  onTap: () => setState(() => _filter = _RideStatus.cancelled),
                                ),
                                const SizedBox(width: 8),
                                _FilterChip(
                                  label: 'Rejected',
                                  count: _countOf(_RideStatus.rejected, all),
                                  active: _filter == _RideStatus.rejected,
                                  color: SRColors.ink500,
                                  onTap: () => setState(() => _filter = _RideStatus.rejected),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  if (shown.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history_rounded,
                                size: 52,
                                color: SRColors.ink500.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            Text(
                              _filter == null
                                  ? 'No rides yet'
                                  : 'No ${_filterLabel(_filter!).toLowerCase()} rides',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: SRColors.ink500),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _RideCard(
                              ride: shown[i],
                              onCancelled: _loadArchive,
                            ),
                          ),
                          childCount: shown.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  String _filterLabel(_RideStatus s) {
    switch (s) {
      case _RideStatus.completed:
        return 'Completed';
      case _RideStatus.cancelled:
        return 'Cancelled';
      case _RideStatus.rejected:
        return 'Rejected';
      case _RideStatus.active:
        return 'Active';
      case _RideStatus.awaiting:
        return 'Awaiting';
      case _RideStatus.pending:
        return 'Pending';
    }
  }
}

class _SummaryStrip extends StatelessWidget {
  final int total;
  final int completed;
  final int rate;

  const _SummaryStrip({
    required this.total,
    required this.completed,
    required this.rate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SRColors.border),
      ),
      child: Row(
        children: [
          _Stat(label: 'Total rides', value: '$total'),
          _Divider(),
          _Stat(label: 'Completed', value: '$completed'),
          _Divider(),
          _Stat(
            label: 'Completion',
            value: '$rate%',
            valueColor: rate >= 70 ? SRColors.green600 : SRColors.coral500,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _Stat({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: valueColor ?? SRColors.ink900,
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: SRColors.ink500)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: SRColors.border);
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.active,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? SRColors.purple700;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? accent : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: active ? accent : SRColors.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : SRColors.ink700,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.25)
                      : accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : accent,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RideCard extends StatefulWidget {
  final _HistoryRide ride;
  final VoidCallback onCancelled;
  const _RideCard({required this.ride, required this.onCancelled});

  @override
  State<_RideCard> createState() => _RideCardState();
}

class _RideCardState extends State<_RideCard> {
  bool _cancelling = false;

  bool get _canMessage =>
      widget.ride.status == _RideStatus.active;

  bool get _canCancel =>
      widget.ride.status == _RideStatus.awaiting ||
      widget.ride.status == _RideStatus.active;

  Future<void> _cancel() async {
    final isAwaiting = widget.ride.status == _RideStatus.awaiting;

    // For price-offered rides, just confirm; for active rides ask for reason
    String? reason;
    if (isAwaiting) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Withdraw price offer?',
              style: TextStyle(fontWeight: FontWeight.w700)),
          content: const Text('This will remove your quoted price.',
              style: TextStyle(color: SRColors.ink700)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Withdraw',
                  style: TextStyle(color: SRColors.coral500)),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    } else {
      reason = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => const _CancelReasonSheet(isDriver: true),
      );
      if (reason == null || !mounted) return;
    }

    setState(() => _cancelling = true);
    try {
      final bk4 = isAwaiting ? 'Reject Price' : 'Cancel';
      final bk5 = isAwaiting ? 'Reject Ride' : 'Cancelled';
      await Future.wait([
        RideApi.instance.setDriverMovementStatus(widget.ride.reqId, bk4)
            .catchError((_) => <String, dynamic>{}),
        RideApi.instance.setRiderStatus(widget.ride.reqId, bk5)
            .catchError((_) => <String, dynamic>{}),
        if (reason != null && reason.isNotEmpty)
          RideApi.instance.flagRide(
              reqId: widget.ride.reqId, flag: 'Yellow', comment: reason)
              .catchError((_) => <String, dynamic>{}),
      ]);
      if (mounted) widget.onCancelled();
    } catch (_) {}
    if (mounted) setState(() => _cancelling = false);
  }

  void _openChat() {
    final name = widget.ride.riderName;
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    context.push('/chat', extra: {
      'driverName': name,
      'driverInitials': initials,
      'reqId': widget.ride.reqId,
    });
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    final statusInfo = _statusInfo(ride.status);

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
          // Top row: status badge + time
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusInfo.bg,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusInfo.icon, size: 11, color: statusInfo.color),
                    const SizedBox(width: 4),
                    Text(
                      statusInfo.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusInfo.color,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                _relativeTime(ride.time),
                style: const TextStyle(fontSize: 11, color: SRColors.ink500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Route
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: SRColors.purple700, shape: BoxShape.circle),
                  ),
                  Container(
                    width: 1.5, height: 20, color: SRColors.border,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                  ),
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: SRColors.ink900,
                      borderRadius: BorderRadius.circular(2)),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ride.fromText.isNotEmpty ? ride.fromText : 'Pickup location',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: SRColors.ink900),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      ride.toText.isNotEmpty ? ride.toText : 'Drop-off location',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: SRColors.ink900),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Rider name + price
          Row(
            children: [
              Container(
                width: 26, height: 26,
                decoration: const BoxDecoration(
                    color: SRColors.lavenderBg, shape: BoxShape.circle),
                child: const Icon(Icons.person_rounded,
                    size: 14, color: SRColors.purple700),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  ride.riderName,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: SRColors.ink700),
                ),
              ),
              if (ride.price.isNotEmpty)
                Text(
                  '₦${ride.price}',
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800,
                    color: ride.status == _RideStatus.completed
                        ? SRColors.green600
                        : SRColors.ink900,
                  ),
                ),
            ],
          ),
          // Action buttons — only when there's something to do
          if (_canMessage || _canCancel) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: SRColors.border),
            const SizedBox(height: 10),
            Row(
              children: [
                if (_canMessage) ...[
                  _ActionBtn(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Message',
                    color: SRColors.purple700,
                    onTap: _openChat,
                  ),
                  const SizedBox(width: 8),
                ],
                if (_canCancel)
                  _ActionBtn(
                    icon: _cancelling
                        ? Icons.hourglass_top_rounded
                        : Icons.cancel_outlined,
                    label: _cancelling ? 'Cancelling…' : 'Cancel ride',
                    color: SRColors.coral500,
                    onTap: _cancelling ? null : _cancel,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  ({String label, Color color, Color bg, IconData icon}) _statusInfo(
      _RideStatus s) {
    switch (s) {
      case _RideStatus.completed:
        return (label: 'COMPLETED', color: SRColors.green600,
            bg: SRColors.green100, icon: Icons.check_circle_rounded);
      case _RideStatus.cancelled:
        return (label: 'CANCELLED', color: SRColors.coral500,
            bg: SRColors.coral100, icon: Icons.cancel_rounded);
      case _RideStatus.rejected:
        return (label: 'REJECTED', color: SRColors.ink500,
            bg: SRColors.lavenderBg, icon: Icons.close_rounded);
      case _RideStatus.active:
        return (label: 'ACTIVE', color: SRColors.purple700,
            bg: SRColors.purple100, icon: Icons.directions_car_rounded);
      case _RideStatus.awaiting:
        return (label: 'AWAITING', color: SRColors.amber600,
            bg: const Color(0xFFFFF8E1), icon: Icons.schedule_rounded);
      case _RideStatus.pending:
        return (label: 'PENDING', color: SRColors.ink500,
            bg: SRColors.lavenderBg, icon: Icons.hourglass_empty_rounded);
    }
  }

  String _relativeTime(String raw) {
    if (raw.isEmpty) return '';
    try {
      // Try ISO first, then replace space with T
      DateTime? dt;
      try {
        dt = DateTime.parse(raw.trim());
      } catch (_) {
        dt = DateTime.parse(raw.trim().replaceFirst(' ', 'T'));
      }
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      const m = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      return '${m[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return raw.length > 10 ? raw.substring(0, 10) : raw;
    }
  }
}

class _CancelReasonSheet extends StatefulWidget {
  final bool isDriver;
  const _CancelReasonSheet({required this.isDriver});

  @override
  State<_CancelReasonSheet> createState() => _CancelReasonSheetState();
}

class _CancelReasonSheetState extends State<_CancelReasonSheet> {
  String? _selected;
  final _otherCtrl = TextEditingController();

  List<String> get _reasons => widget.isDriver
      ? ['Rider not responding', 'Rider not at location', 'Emergency', 'Wrong information', 'Other']
      : ['Change of plans', 'Wait is too long', 'Found another ride', 'Emergency', 'Other'];

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: SRColors.border, borderRadius: BorderRadius.circular(99)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Why are you cancelling?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SRColors.ink900)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _reasons.map((r) {
              final active = _selected == r;
              return GestureDetector(
                onTap: () => setState(() => _selected = r),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? SRColors.purple700 : Colors.white,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: active ? SRColors.purple700 : SRColors.border),
                  ),
                  child: Text(r,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: active ? Colors.white : SRColors.ink700)),
                ),
              );
            }).toList(),
          ),
          if (_selected == 'Other') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _otherCtrl,
              decoration: InputDecoration(
                hintText: 'Tell us more…',
                hintStyle: const TextStyle(color: SRColors.ink500),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: SRColors.border)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              maxLines: 2,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, null),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                    side: const BorderSide(color: SRColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Keep ride',
                      style: TextStyle(color: SRColors.ink700, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SRColors.coral500,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _selected == null ? null : () {
                    final reason = _selected == 'Other' ? _otherCtrl.text.trim() : _selected!;
                    Navigator.pop(context, reason.isEmpty ? 'Other' : reason);
                  },
                  child: const Text('Cancel ride',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: onTap == null ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
