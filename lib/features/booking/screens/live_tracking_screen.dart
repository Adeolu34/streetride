import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/ride_api.dart';
import '../../../core/models/ride_model.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/ride_provider.dart';

class LiveTrackingScreen extends ConsumerStatefulWidget {
  final String driverName;
  final String driverInitials;
  final String car;
  final double rating;
  final int price;
  final String from;
  final String to;
  final String reqId;

  const LiveTrackingScreen({
    super.key,
    required this.driverName,
    required this.driverInitials,
    required this.car,
    required this.rating,
    required this.price,
    required this.from,
    required this.to,
    required this.reqId,
  });

  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen> {
  LatLng _pickup = const LatLng(6.4510, 3.4780);
  LatLng _dropoff = const LatLng(6.4281, 3.4219);
  LatLng _driverPos = const LatLng(6.4530, 3.4800);

  final _mapController = MapController();
  bool _mapReady = false;
  bool _sheetExpanded = true;
  Timer? _locationTimer;
  bool _didNavigate = false;
  String _driverPhone = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(rideProvider.notifier).poll();
      _startLocationPolling();
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  void _startLocationPolling() {
    _fetchDriverLocation();
    _locationTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _fetchDriverLocation(),
    );
  }

  Future<void> _fetchDriverLocation() async {
    final messages = ref.read(rideProvider).messages;
    RideMessage? ride;
    try {
      ride = messages.firstWhere((m) => m.reqId == widget.reqId);
    } catch (_) {
      return;
    }

    final driverPhone = ride.driverPhone.trim();
    if (driverPhone.isEmpty) return;
    if (_driverPhone.isEmpty) setState(() => _driverPhone = driverPhone);

    try {
      final raw = await RideApi.instance.getLocation(driverPhone);
      // Response wraps coords inside "Data": { latitude, longitude }
      final inner = (raw['Data'] as Map<String, dynamic>?) ?? raw;
      final lat = double.tryParse((inner['latitude'] ?? inner['Latitude'] ?? '').toString());
      final lng = double.tryParse((inner['longitude'] ?? inner['Longitude'] ?? '').toString());
      // lat/lng of 0,0 means no GPS fix recorded yet — skip
      if (lat == null || lng == null || (lat == 0.0 && lng == 0.0) || !mounted) return;

      final newDriverPos = LatLng(lat, lng);

      // Update pickup/dropoff from real ride data when available
      final fromLat = double.tryParse(ride.fromLat.toString());
      final fromLng = double.tryParse(ride.fromLng.toString());
      final toLat = double.tryParse(ride.toLat.toString());
      final toLng = double.tryParse(ride.toLng.toString());

      setState(() {
        _driverPos = newDriverPos;
        if (fromLat != null && fromLng != null) {
          _pickup = LatLng(fromLat, fromLng);
        }
        if (toLat != null && toLng != null) {
          _dropoff = LatLng(toLat, toLng);
        }
      });

      if (_mapReady) {
        _mapController.move(newDriverPos, 14.0);
      }
    } catch (_) {}
  }

  String _statusLabel(String movt) {
    switch (movt.toLowerCase().trim()) {
      case 'started':
        return 'Driver en route to pickup';
      case 'arrived':
        return 'Driver arrived — board now';
      case 'intransit':
        return 'On trip · heading to destination';
      case 'completed':
        return 'Trip completed';
      case 'cancel':
        return 'Driver cancelled';
      default:
        return 'Driver confirmed — on the way';
    }
  }

  Color _statusColor(String movt) {
    switch (movt.toLowerCase().trim()) {
      case 'arrived':
        return SRColors.amber500;
      case 'intransit':
        return SRColors.green500;
      case 'completed':
        return SRColors.green600;
      case 'cancel':
        return SRColors.coral500;
      default:
        return SRColors.purple700;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Auto-react to BK8 status changes
    ref.listen<RideState>(rideProvider, (_, next) {
      if (_didNavigate || !mounted) return;
      RideMessage? ride;
      try {
        ride = next.messages.firstWhere((m) => m.reqId == widget.reqId);
      } catch (_) {
        return;
      }
      final movt = ride.movtStatusDriver.toLowerCase().trim();
      if (movt == 'completed') {
        _didNavigate = true;
        context.go('/rate-pay', extra: {
          'driverName': widget.driverName,
          'car': widget.car,
          'rating': widget.rating,
          'price': widget.price,
          'to': widget.to,
          'reqId': widget.reqId,
        });
      } else if (movt == 'cancel') {
        _didNavigate = true;
        context.go('/home');
      }
    });

    final messages = ref.watch(rideProvider).messages;
    RideMessage? activeRide;
    try {
      activeRide = messages.firstWhere((m) => m.reqId == widget.reqId);
    } catch (_) {}
    final movt = activeRide?.movtStatusDriver ?? '';
    final statusLabel = _statusLabel(movt);
    final statusColor = _statusColor(movt);
    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(6.4400, 3.4500),
              initialZoom: 13.5,
              onMapReady: () => setState(() => _mapReady = true),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.streetrideplus.streetride',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [_driverPos, _pickup],
                    color: SRColors.purple700,
                    strokeWidth: 4,
                    strokeCap: StrokeCap.round,
                  ),
                  Polyline(
                    points: [_pickup, _dropoff],
                    color: SRColors.ink500,
                    strokeWidth: 3,
                    strokeCap: StrokeCap.round,
                  ),
                ],
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _pickup,
                    radius: 9,
                    color: SRColors.green500,
                    borderStrokeWidth: 3,
                    borderColor: Colors.white,
                  ),
                  CircleMarker(
                    point: _dropoff,
                    radius: 7,
                    color: SRColors.ink900,
                    borderStrokeWidth: 3,
                    borderColor: Colors.white,
                  ),
                  CircleMarker(
                    point: _driverPos,
                    radius: 12,
                    color: SRColors.purple700,
                    borderStrokeWidth: 3,
                    borderColor: Colors.white,
                  ),
                ],
              ),
            ],
          ),

          // Status bar overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                children: [
                  // Back + Safety
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: SRColors.indigo900.withValues(alpha: 0.18),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.arrow_back_rounded,
                                color: SRColors.ink900),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => context.push('/safety'),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: SRColors.ink900,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: SRColors.indigo900.withValues(alpha: 0.28),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.health_and_safety_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Status pill
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withValues(alpha: 0.32),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.navigation_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            statusLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _DriverSheet(
              driverName: widget.driverName,
              driverInitials: widget.driverInitials,
              car: widget.car,
              rating: widget.rating,
              price: widget.price,
              from: widget.from,
              to: widget.to,
              reqId: widget.reqId,
              movt: movt,
              expanded: _sheetExpanded,
              driverPhone: _driverPhone,
              dropoffLat: _dropoff.latitude,
              dropoffLng: _dropoff.longitude,
              dropoffLabel: widget.to,
              onToggle: () =>
                  setState(() => _sheetExpanded = !_sheetExpanded),
              onRateAndPay: () => context.go('/rate-pay', extra: {
                'driverName': widget.driverName,
                'car': widget.car,
                'rating': widget.rating,
                'price': widget.price,
                'to': widget.to,
                'reqId': widget.reqId,
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverSheet extends StatelessWidget {
  final String driverName;
  final String driverInitials;
  final String car;
  final double rating;
  final int price;
  final String from;
  final String to;
  final String reqId;
  final String movt;
  final bool expanded;
  final String driverPhone;
  final double dropoffLat;
  final double dropoffLng;
  final String dropoffLabel;
  final VoidCallback onToggle;
  final VoidCallback onRateAndPay;

  const _DriverSheet({
    required this.driverName,
    required this.driverInitials,
    required this.car,
    required this.rating,
    required this.price,
    required this.from,
    required this.to,
    required this.reqId,
    required this.movt,
    required this.expanded,
    required this.driverPhone,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.dropoffLabel,
    required this.onToggle,
    required this.onRateAndPay,
  });

  Future<void> _callDriver() async {
    final phone = driverPhone.startsWith('+') ? driverPhone : '+$driverPhone';
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openMap() async {
    final label = Uri.encodeComponent(dropoffLabel);
    final Uri uri;
    if (Platform.isIOS) {
      uri = Uri.parse('maps://?ll=$dropoffLat,$dropoffLng&q=$label');
    } else {
      uri = Uri.parse('geo:$dropoffLat,$dropoffLng?q=$dropoffLat,$dropoffLng($label)');
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Color(0x301E1133),
            blurRadius: 40,
            offset: Offset(0, -12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: SRColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Driver info row
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: SRColors.purple700,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    driverInitials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: SRColors.ink900,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 14, color: SRColors.amber500),
                        const SizedBox(width: 3),
                        Text(
                          '$rating · 2,140 trips',
                          style: const TextStyle(
                              fontSize: 12, color: SRColors.ink500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'ABC 123 XY',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: SRColors.ink900,
                    ),
                  ),
                  Text(
                    'Silver $car',
                    style: const TextStyle(
                        fontSize: 12, color: SRColors.ink500),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              _ActionBtn(icon: Icons.call_rounded, label: 'Call', onTap: _callDriver),
              const SizedBox(width: 10),
              _ActionBtn(
                icon: Icons.chat_bubble_rounded,
                label: 'Message',
                onTap: () => context.push('/chat', extra: {
                  'driverName': driverName,
                  'driverInitials': driverInitials,
                  'driverPhone': driverPhone,
                  'reqId': reqId,
                }),
              ),
              const SizedBox(width: 10),
              _ActionBtn(icon: Icons.map_rounded, label: 'Map', onTap: _openMap),
            ],
          ),

          const SizedBox(height: 14),

          // Route summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SRColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(top: 3),
                      decoration: const BoxDecoration(
                        color: SRColors.purple700,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 18,
                      color: SRColors.border,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                    ),
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: SRColors.ink900,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PICKUP',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: SRColors.ink500,
                              letterSpacing: 0.8)),
                      Text(from,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: SRColors.ink900)),
                      const SizedBox(height: 10),
                      const Text('DROP-OFF',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: SRColors.ink500,
                              letterSpacing: 0.8)),
                      Text(to,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: SRColors.ink900)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          _RatePayButton(movt: movt, onRateAndPay: onRateAndPay),
        ],
      ),
    );
  }
}

class _RatePayButton extends StatelessWidget {
  final String movt;
  final VoidCallback onRateAndPay;
  const _RatePayButton({required this.movt, required this.onRateAndPay});

  @override
  Widget build(BuildContext context) {
    final m = movt.toLowerCase().trim();
    final isCompleted = m == 'completed';
    final isArrived = m == 'arrived';
    final isCancelled = m == 'cancel';

    if (isCancelled) {
      return Container(
        height: 52,
        decoration: BoxDecoration(
          color: SRColors.coral100,
          borderRadius: BorderRadius.circular(99),
        ),
        child: const Center(
          child: Text(
            'Driver cancelled this ride',
            style: TextStyle(
              color: SRColors.coral600,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (isCompleted) {
      return GestureDetector(
        onTap: onRateAndPay,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: SRColors.green500,
            borderRadius: BorderRadius.circular(99),
          ),
          child: const Center(
            child: Text(
              'Rate & Pay',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    // In progress or arrived — show status
    final label = isArrived
        ? 'Driver arrived — waiting for you'
        : 'Trip in progress…';
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: isArrived
            ? SRColors.amber500.withValues(alpha: 0.12)
            : SRColors.purple100,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: isArrived ? SRColors.amber500 : SRColors.purple300,
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: isArrived ? SRColors.amber600 : SRColors.purple700,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            border: Border.all(color: SRColors.border),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            children: [
              Icon(icon, color: SRColors.purple700, size: 22),
              const SizedBox(height: 5),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: SRColors.ink900)),
            ],
          ),
        ),
      ),
    );
  }
}
