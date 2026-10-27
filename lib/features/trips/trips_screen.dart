import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/ride_api.dart';
import '../../core/models/ride_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/session_service.dart';
import '../../shared/widgets/driver_avatar.dart';
import '../booking/providers/ride_provider.dart';

class TripsScreen extends ConsumerStatefulWidget {
  const TripsScreen({super.key});

  @override
  ConsumerState<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends ConsumerState<TripsScreen> {
  int _tab = 0;
  final _tabs = ['All', 'Active', 'Completed', 'Cancelled'];
  List<_Trip> _archive = [];
  bool _loading = true;
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
    final profile = SessionService.instance.profile;
    if (profile == null) { setState(() => _loading = false); return; }
    try {
      final res = await RideApi.instance.getPaymentHistory(profile.phone);
      final history = res['History'];
      if (history is List && mounted) {
        setState(() {
          _archive = history
              .whereType<Map<String, dynamic>>()
              .map(_Trip.fromJson)
              .toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<_Trip> _merge(List<_Trip> recent) {
    final recentIds = recent.map((t) => t.reqId).toSet();
    final merged = [...recent, ..._archive.where((t) => !recentIds.contains(t.reqId))];
    // Sort newest first: use numeric rowId from API when available,
    // fall back to parsed Reqtime so string comparison never drives order.
    merged.sort((a, b) {
      if (a.rowId > 0 && b.rowId > 0) return b.rowId.compareTo(a.rowId);
      return _parseReqtime(b.date).compareTo(_parseReqtime(a.date));
    });
    return merged;
  }

  static DateTime _parseReqtime(String s) {
    try {
      // Format: "M/d/yyyy h:mm:ss AM" — manual parse avoids intl dependency
      final parts = s.split(' ');
      if (parts.length < 2) return DateTime(2000);
      final dateParts = parts[0].split('/');
      final timeParts = parts[1].split(':');
      final isPm = parts.length >= 3 && parts[2].toUpperCase() == 'PM';
      int hour = int.parse(timeParts[0]);
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
      return DateTime(
        int.parse(dateParts[2]),
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        hour,
        int.parse(timeParts[1]),
        int.parse(timeParts[2]),
      );
    } catch (_) {
      return DateTime(2000);
    }
  }

  List<_Trip> _filtered(List<_Trip> all) {
    switch (_tab) {
      case 1: return all.where((t) => t.isActive).toList();
      case 2: return all.where((t) => t.status == _TripStatus.completed).toList();
      case 3: return all.where((t) =>
          t.status == _TripStatus.cancelled || t.status == _TripStatus.rejected).toList();
      default: return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideState = ref.watch(rideProvider);
    final recent = rideState.historyForRider(_normalizedPhone).map(_Trip.fromMessage).toList();
    final all = _merge(recent);
    final shown = _filtered(all);

    return Scaffold(
      backgroundColor: SRColors.lavenderBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: Text('Your trips',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: SRColors.ink900)),
            ),
            const SizedBox(height: 14),
            _TabRow(tabs: _tabs, selected: _tab, onSelect: (i) => setState(() => _tab = i)),
            const SizedBox(height: 16),
            Expanded(
              child: _loading && all.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: SRColors.purple700))
                  : RefreshIndicator(
                      onRefresh: _loadArchive,
                      color: SRColors.purple700,
                      child: shown.isEmpty
                          ? const _EmptyTrips()
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
                              itemCount: shown.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, i) => _TripCard(
                                trip: shown[i],
                                onRefresh: () {
                                  _loadArchive();
                                  ref.read(rideProvider.notifier).poll();
                                },
                              ),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Models ──────────────────────────────────────────────────────────────────

enum _TripStatus { requesting, priceOffered, active, completed, cancelled, rejected }

class _Trip {
  final String reqId;
  final String destination;
  final String from;
  final String date;
  final int rowId; // numeric id from API — used for chronological sort
  final int price;
  final _TripStatus status;
  final String driverName;
  final String driverPhone;
  final String movtStatus;
  final String rideStatus;
  final String confirmStatus;
  final RideMessage? message; // non-null for BK8 rides

  const _Trip({
    required this.reqId,
    required this.destination,
    required this.from,
    required this.date,
    required this.rowId,
    required this.price,
    required this.status,
    required this.driverName,
    required this.driverPhone,
    required this.movtStatus,
    required this.rideStatus,
    required this.confirmStatus,
    this.message,
  });

  bool get isActive =>
      status == _TripStatus.active ||
      status == _TripStatus.requesting ||
      status == _TripStatus.priceOffered;

  String get movtLabel {
    switch (movtStatus.toLowerCase()) {
      case 'started': return 'Driver is on the way';
      case 'arrived': return 'Driver has arrived';
      case 'intransit': return 'Trip in progress';
      case 'set price': return 'Price offered';
      case 'accepted': return 'Ride accepted';
      default:
        if (rideStatus.toLowerCase() == 'accepted') return 'Ride accepted';
        if (rideStatus.toLowerCase() == 'boarded') return 'Trip in progress';
        if (price > 0) return 'Price offered';
        return 'Requesting driver';
    }
  }

  static _TripStatus _classify(String ride, String movt, String confirm, int price) {
    final r = ride.toLowerCase();
    final m = movt.toLowerCase();
    if (m == 'completed' || r == 'completed') return _TripStatus.completed;
    if (m.contains('cancel') || r.contains('cancel') || r == 'withdraw') return _TripStatus.cancelled;
    if (r.contains('reject') || m.contains('reject')) return _TripStatus.rejected;
    if (m == 'intransit' || r == 'boarded' || m == 'arrived' || m == 'started') return _TripStatus.active;
    if (confirm == 'accept' || r == 'accepted') return _TripStatus.active;
    if (price > 0) return _TripStatus.priceOffered;
    return _TripStatus.requesting;
  }

  factory _Trip.fromJson(Map<String, dynamic> j) {
    final ride = (j['RideStatus_R'] ?? '').toString();
    final movt = (j['MovtStatus_D'] ?? '').toString();
    final confirm = (j['ConfirmStatus_R'] ?? '').toString().toLowerCase();
    final price = int.tryParse((j['Price_D'] ?? j['amount'] ?? '0').toString()) ?? 0;
    return _Trip(
      reqId: (j['reqid'] ?? '').toString(),
      destination: (j['toText'] ?? j['ToText'] ?? '').toString(),
      from: (j['fromText'] ?? j['FromText'] ?? '').toString(),
      date: (j['Reqtime'] ?? j['reqtime'] ?? '').toString(),
      rowId: int.tryParse((j['id'] ?? '0').toString()) ?? 0,
      price: price,
      status: _classify(ride, movt, confirm, price),
      driverName: (j['Dname'] ?? '').toString(),
      driverPhone: (j['Dphone'] ?? j['dphone'] ?? '').toString(),
      movtStatus: movt,
      rideStatus: ride,
      confirmStatus: confirm,
    );
  }

  factory _Trip.fromMessage(RideMessage m) {
    final ride = m.rideStatusRider;
    final movt = m.movtStatusDriver;
    final confirm = m.confirmStatusRider.toLowerCase();
    final price = int.tryParse(m.priceByDriver) ?? 0;
    return _Trip(
      reqId: m.reqId,
      destination: m.toText,
      from: m.fromText,
      date: m.requestTime,
      rowId: 0, // BK8 messages don't carry a row id; date fallback handles sort
      price: price,
      status: _classify(ride, movt, confirm, price),
      driverName: m.driverName,
      driverPhone: m.driverPhone,
      movtStatus: movt,
      rideStatus: ride,
      confirmStatus: confirm,
      message: m,
    );
  }
}

// ─── Trip Card ────────────────────────────────────────────────────────────────

class _TripCard extends StatefulWidget {
  final _Trip trip;
  final VoidCallback onRefresh;
  const _TripCard({required this.trip, required this.onRefresh});

  @override
  State<_TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<_TripCard> {
  bool _acting = false;
  String? _driverPhotoUrl;

  _Trip get t => widget.trip;

  @override
  void initState() {
    super.initState();
    _fetchDriverPhoto();
  }

  Future<void> _fetchDriverPhoto() async {
    final phone = t.driverPhone.trim();
    if (phone.isEmpty) return;
    try {
      final detail = await RideApi.instance.getUserDetail(phone);
      final url = (detail['Photo'] ?? detail['photo'] ?? '').toString().trim();
      if (mounted && url.isNotEmpty) setState(() => _driverPhotoUrl = url);
    } catch (_) {}
  }

  bool get _canWithdraw =>
      t.message != null &&
      (t.status == _TripStatus.requesting || t.status == _TripStatus.priceOffered);

  bool get _canCancelActive =>
      t.message != null && t.status == _TripStatus.active;

  bool get _canAcceptReject =>
      t.message != null && t.status == _TripStatus.priceOffered;

  bool get _canMessage =>
      t.message != null && t.status == _TripStatus.active;

  bool get _canTrack =>
      t.message != null && t.status == _TripStatus.active;

  bool get _canRebook => t.status == _TripStatus.completed && t.destination.isNotEmpty;
  bool get _hasActions => _canWithdraw || _canAcceptReject || _canMessage || _canCancelActive || _canRebook;

  Future<void> _withdraw() async {
    if (_acting) return;
    setState(() => _acting = true);
    final m = t.message!;
    final hasPrice = m.priceByDriver.trim().isNotEmpty;
    final bk5 = hasPrice ? 'Reject Price' : 'Withdraw';
    final bk4 = hasPrice ? 'Reject Price' : 'Cancel';
    await Future.wait([
      RideApi.instance.setRiderStatus(m.reqId, bk5).catchError((_) => <String, dynamic>{}),
      RideApi.instance.setDriverMovementStatus(m.reqId, bk4).catchError((_) => <String, dynamic>{}),
    ]);
    if (mounted) { setState(() => _acting = false); widget.onRefresh(); }
  }

  Future<void> _accept() async {
    if (_acting) return;
    setState(() => _acting = true);
    final m = t.message!;
    await Future.wait([
      RideApi.instance.acceptPrice(m.reqId).catchError((_) => <String, dynamic>{}),
      RideApi.instance.setRiderStatus(m.reqId, 'Accepted').catchError((_) => <String, dynamic>{}),
      RideApi.instance.setDriverMovementStatus(m.reqId, 'Accepted').catchError((_) => <String, dynamic>{}),
    ]);
    if (mounted) { setState(() => _acting = false); widget.onRefresh(); }
  }

  Future<void> _reject() async {
    if (_acting) return;
    setState(() => _acting = true);
    final m = t.message!;
    await Future.wait([
      RideApi.instance.rejectPrice(m.reqId).catchError((_) => <String, dynamic>{}),
      RideApi.instance.setRiderStatus(m.reqId, 'Reject Price').catchError((_) => <String, dynamic>{}),
      RideApi.instance.setDriverMovementStatus(m.reqId, 'Reject Price').catchError((_) => <String, dynamic>{}),
    ]);
    if (mounted) { setState(() => _acting = false); widget.onRefresh(); }
  }

  Future<void> _cancelActive() async {
    if (_acting) return;
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _CancelReasonSheet(isDriver: false),
    );
    if (reason == null || !mounted) return;
    setState(() => _acting = true);
    final m = t.message!;
    await Future.wait([
      RideApi.instance.setRiderStatus(m.reqId, 'Cancelled').catchError((_) => <String, dynamic>{}),
      RideApi.instance.setDriverMovementStatus(m.reqId, 'Cancel').catchError((_) => <String, dynamic>{}),
      RideApi.instance.flagRide(reqId: m.reqId, flag: 'Yellow', comment: reason)
          .catchError((_) => <String, dynamic>{}),
    ]);
    if (mounted) { setState(() => _acting = false); widget.onRefresh(); }
  }

  void _openChat() {
    final name = t.driverName.isNotEmpty ? t.driverName : 'Driver';
    context.push('/chat', extra: {
      'driverName': name,
      'driverInitials': name[0].toUpperCase(),
      'reqId': t.reqId,
    });
  }

  void _track() {
    final m = t.message!;
    final name = t.driverName.isNotEmpty ? t.driverName : 'Driver';
    context.push('/live-tracking', extra: {
      'driverName': name,
      'driverInitials': name[0].toUpperCase(),
      'car': '',
      'rating': 0.0,
      'price': t.price,
      'from': t.from,
      'to': t.destination,
      'reqId': m.reqId,
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = _statusInfo(t.status);

    return GestureDetector(
      onTap: _canTrack ? _track : null,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: t.status == _TripStatus.active ? SRColors.purple700.withValues(alpha: 0.4) : SRColors.border,
            width: t.status == _TripStatus.active ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                t.driverName.isNotEmpty
                    ? DriverAvatar(
                        size: 40,
                        fontSize: 15,
                        initials: t.driverName[0].toUpperCase(),
                        photoUrl: _driverPhotoUrl,
                      )
                    : Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: info.bg, shape: BoxShape.circle),
                        child: Icon(info.icon, color: info.color, size: 20),
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.destination.isNotEmpty ? t.destination : 'Unknown destination',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: SRColors.ink900),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t.movtLabel,
                        style: TextStyle(fontSize: 11, color: info.color, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      t.price > 0 ? '₦${t.price}' : '—',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: SRColors.ink900),
                    ),
                    if (_canTrack)
                      const Text('Tap to track', style: TextStyle(fontSize: 10, color: SRColors.purple700)),
                  ],
                ),
              ],
            ),

            if (t.from.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'From: ${t.from}',
                style: const TextStyle(fontSize: 11, color: SRColors.ink500),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ],

            if (_hasActions) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: SRColors.border),
              const SizedBox(height: 10),
              if (_acting)
                const Center(child: SizedBox(height: 22, width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: SRColors.purple700)))
              else
                Row(
                  children: [
                    if (_canAcceptReject) ...[
                      Expanded(
                        child: _Btn(
                          label: 'Accept ₦${t.price}',
                          color: SRColors.green500,
                          onTap: _accept,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Btn(
                          label: 'Reject',
                          color: SRColors.coral500,
                          onTap: _reject,
                        ),
                      ),
                    ] else if (_canWithdraw)
                      _Btn(label: 'Withdraw', color: SRColors.coral500, onTap: _withdraw)
                    else if (_canCancelActive)
                      _Btn(label: 'Cancel ride', color: SRColors.coral500, onTap: _cancelActive),
                    if (_canMessage) ...[
                      if (_canWithdraw || _canAcceptReject || _canCancelActive) const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _openChat,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: SRColors.purple100,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Icon(Icons.chat_bubble_outline_rounded,
                              color: SRColors.purple700, size: 18),
                        ),
                      ),
                    ],
                    if (_canRebook)
                      Expanded(
                        child: _Btn(
                          label: 'Rebook',
                          color: SRColors.purple700,
                          onTap: () => context.push('/search', extra: {
                            'from': t.from.isNotEmpty ? t.from : null,
                            'to': t.destination,
                          }),
                        ),
                      ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  ({Color color, Color bg, IconData icon}) _statusInfo(_TripStatus s) {
    switch (s) {
      case _TripStatus.active:
        return (color: SRColors.purple700, bg: SRColors.purple100, icon: Icons.directions_car_rounded);
      case _TripStatus.priceOffered:
        return (color: SRColors.amber600, bg: const Color(0xFFFFF8E1), icon: Icons.local_offer_rounded);
      case _TripStatus.requesting:
        return (color: SRColors.ink500, bg: SRColors.lavenderBg, icon: Icons.search_rounded);
      case _TripStatus.completed:
        return (color: SRColors.green600, bg: SRColors.green100, icon: Icons.check_circle_rounded);
      case _TripStatus.cancelled:
        return (color: SRColors.coral500, bg: SRColors.coral100, icon: Icons.cancel_rounded);
      case _TripStatus.rejected:
        return (color: SRColors.ink500, bg: SRColors.border, icon: Icons.close_rounded);
    }
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Btn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ),
    ),
  );
}

// ─── Cancel Reason Sheet ─────────────────────────────────────────────────────

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
                  color: SRColors.border,
                  borderRadius: BorderRadius.circular(99)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Why are you cancelling?',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: SRColors.ink900)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _reasons.map((r) {
              final active = _selected == r;
              return GestureDetector(
                onTap: () => setState(() => _selected = r),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? SRColors.purple700 : Colors.white,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                        color: active ? SRColors.purple700 : SRColors.border),
                  ),
                  child: Text(r,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(99)),
                    side: const BorderSide(color: SRColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Keep ride',
                      style: TextStyle(
                          color: SRColors.ink700, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SRColors.coral500,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(99)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _selected == null
                      ? null
                      : () {
                          final reason = _selected == 'Other'
                              ? _otherCtrl.text.trim()
                              : _selected!;
                          Navigator.pop(
                              context, reason.isEmpty ? 'Other' : reason);
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

// ─── Tab Row ─────────────────────────────────────────────────────────────────

class _TabRow extends StatelessWidget {
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelect;
  const _TabRow({required this.tabs, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = i == selected;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active ? SRColors.purple700 : Colors.white,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: active ? SRColors.purple700 : SRColors.border, width: 1.5),
              ),
              child: Text(tabs[i],
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: active ? Colors.white : SRColors.ink700)),
            ),
          );
        }),
      ),
    );
  }
}

// ── Animated empty state ──────────────────────────────────────────────────────

class _EmptyTrips extends StatefulWidget {
  const _EmptyTrips();

  @override
  State<_EmptyTrips> createState() => _EmptyTripsState();
}

class _EmptyTripsState extends State<_EmptyTrips> with TickerProviderStateMixin {
  late final AnimationController _drive;
  late final AnimationController _intro;
  late final Animation<double> _carX;
  late final Animation<double> _fadeIn;
  late final Animation<double> _slideUp;

  @override
  void initState() {
    super.initState();
    _drive = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

    _carX = Tween(begin: -14.0, end: 14.0).animate(
      CurvedAnimation(parent: _drive, curve: Curves.easeInOut),
    );
    _fadeIn = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _intro, curve: const Interval(0.0, 0.7, curve: Curves.easeOut)),
    );
    _slideUp = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _intro, curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic)),
    );
    _intro.forward();
  }

  @override
  void dispose() {
    _drive.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_drive, _intro]),
      builder: (context, _) {
        return Opacity(
          opacity: _fadeIn.value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - _slideUp.value)),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Road + car illustration
                    SizedBox(
                      width: 240,
                      height: 180,
                      child: CustomPaint(
                        painter: _RoadPainter(_carX.value),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No trips yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: SRColors.ink900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your ride history will appear here.\nBook your first trip and hit the road!',
                      style: TextStyle(
                        fontSize: 14,
                        color: SRColors.ink500,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoadPainter extends CustomPainter {
  final double carX;
  _RoadPainter(this.carX);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // ── Sky background ───────────────────────────────────────────────────
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFEFE0ED), Color(0xFFF4F1FB)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(24)),
      skyPaint,
    );

    // ── Clouds ───────────────────────────────────────────────────────────
    _drawCloud(canvas, 50, 28, 28);
    _drawCloud(canvas, 180, 20, 20);

    // ── Sun ──────────────────────────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx + 70, 36),
      18,
      Paint()..color = SRColors.amber300.withValues(alpha: 0.8),
    );
    canvas.drawCircle(
      Offset(cx + 70, 36),
      13,
      Paint()..color = SRColors.amber500,
    );

    // ── Road ─────────────────────────────────────────────────────────────
    final roadY = cy + 20.0;
    final roadPaint = Paint()..color = const Color(0xFF4A4A5A);
    final roadRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(0, roadY, size.width, size.height),
      const Radius.circular(0),
    );
    canvas.drawRRect(roadRect, roadPaint);

    // Road edge line
    canvas.drawLine(
      Offset(0, roadY),
      Offset(size.width, roadY),
      Paint()
        ..color = SRColors.amber500
        ..strokeWidth = 2.5,
    );

    // Dashed center line
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 2;
    const dashW = 18.0, gapW = 12.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, roadY + 22), Offset(x + dashW, roadY + 22), dashPaint);
      x += dashW + gapW;
    }

    // ── Cartoon car ──────────────────────────────────────────────────────
    final carCx = cx + carX;
    final carBaseY = roadY - 2;

    // Wheels
    for (final wx in [carCx - 22.0, carCx + 22.0]) {
      canvas.drawCircle(
        Offset(wx, carBaseY + 2),
        9,
        Paint()..color = const Color(0xFF2D2D3A),
      );
      canvas.drawCircle(
        Offset(wx, carBaseY + 2),
        5,
        Paint()..color = const Color(0xFF9090A0),
      );
    }

    // Car body
    final bodyPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(carCx - 36, carBaseY - 18, carCx + 36, carBaseY),
        const Radius.circular(6),
      ));
    canvas.drawPath(bodyPath, Paint()..color = SRColors.purple700);

    // Car roof (rounded dome)
    final roofPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(carCx - 22, carBaseY - 34, carCx + 22, carBaseY - 14),
        const Radius.circular(10),
      ));
    canvas.drawPath(roofPath, Paint()..color = SRColors.purple700);

    // Windows
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(carCx - 18, carBaseY - 32, carCx - 4, carBaseY - 18),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFB8E8FF).withValues(alpha: 0.9),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(carCx + 4, carBaseY - 32, carCx + 18, carBaseY - 18),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFB8E8FF).withValues(alpha: 0.9),
    );

    // Headlights
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(carCx + 29, carBaseY - 12, carCx + 38, carBaseY - 7),
        const Radius.circular(2),
      ),
      Paint()..color = SRColors.amber300,
    );

    // StreetRide badge on car
    final badgePaint = TextPainter(
      text: const TextSpan(
        text: 'SR',
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    badgePaint.paint(canvas, Offset(carCx - 5, carBaseY - 14));

    // Shadow under car
    canvas.drawOval(
      Rect.fromCenter(center: Offset(carCx, carBaseY + 6), width: 72, height: 8),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    // ── Trees on side ────────────────────────────────────────────────────
    _drawTree(canvas, 16, roadY - 2);
    _drawTree(canvas, size.width - 16, roadY - 2);
  }

  void _drawCloud(Canvas canvas, double x, double y, double r) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(Offset(x, y), r, p);
    canvas.drawCircle(Offset(x + r * 0.75, y + 4), r * 0.7, p);
    canvas.drawCircle(Offset(x - r * 0.65, y + 5), r * 0.65, p);
    canvas.drawCircle(Offset(x + r * 0.2, y + 9), r * 0.8, p);
  }

  void _drawTree(Canvas canvas, double x, double groundY) {
    // Trunk
    canvas.drawRect(
      Rect.fromLTRB(x - 4, groundY - 20, x + 4, groundY),
      Paint()..color = const Color(0xFF8B6340),
    );
    // Foliage
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(x + (i - 1) * 7.0, groundY - 26 - i * 4),
        12 - i * 1.5,
        Paint()..color = const Color(0xFF4CAF50).withValues(alpha: 0.85 - i * 0.1),
      );
    }
  }

  @override
  bool shouldRepaint(_RoadPainter old) => old.carX != carX;
}

