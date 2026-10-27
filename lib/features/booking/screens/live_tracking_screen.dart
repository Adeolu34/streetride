import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/ride_api.dart';
import '../../../core/models/location_models.dart';
import '../../../core/models/ride_model.dart';
import '../../../core/services/route_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/driver_avatar.dart';
import '../providers/ride_provider.dart';

class LiveTrackingScreen extends ConsumerStatefulWidget {
  final String driverName;
  final String driverInitials;
  final String driverPhotoUrl;
  final String car;
  final double rating;
  final int price;
  final String from;
  final String to;
  final String reqId;
  final double? fromLat;
  final double? fromLng;
  final double? toLat;
  final double? toLng;

  const LiveTrackingScreen({
    super.key,
    required this.driverName,
    required this.driverInitials,
    this.driverPhotoUrl = '',
    required this.car,
    required this.rating,
    required this.price,
    required this.from,
    required this.to,
    required this.reqId,
    this.fromLat,
    this.fromLng,
    this.toLat,
    this.toLng,
  });

  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen> {
  LatLng _pickup = const LatLng(6.4510, 3.4780);
  LatLng _dropoff = const LatLng(0.0, 0.0);
  LatLng _driverPos = const LatLng(6.4530, 3.4800);
  List<LatLng> _tripRoutePoints = [];
  double _driverBearing = 0.0;

  final _mapController = MapController();
  bool _mapReady = false;
  bool _sheetExpanded = true;
  Timer? _locationTimer;
  bool _didNavigate = false;
  String _driverPhone = '';
  String? _driverPhotoUrl;
  String _driverColor = '';
  String _driverPlate = '';
  int _driverTotalRides = 0;

  int _etaMinutes = 9;
  String _pickupNotes = '';

  @override
  void initState() {
    super.initState();
    if (widget.driverPhotoUrl.isNotEmpty) {
      _driverPhotoUrl = widget.driverPhotoUrl;
    }
    if (widget.fromLat != null && widget.fromLng != null && widget.fromLat != 0.0 && widget.fromLng != 0.0) {
      _pickup = LatLng(widget.fromLat!, widget.fromLng!);
    }
    if (widget.toLat != null && widget.toLng != null && widget.toLat != 0.0 && widget.toLng != 0.0) {
      _dropoff = LatLng(widget.toLat!, widget.toLng!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(rideProvider.notifier).poll();
      _startLocationPolling();
      if (_dropoff.latitude == 0.0 && widget.to.isNotEmpty) {
        _resolveDropoffAddress();
      } else {
        _updateTripRoute();
      }
    });
  }

  Future<void> _resolveDropoffAddress() async {
    try {
      final res = await RideApi.instance.resolveAddress(widget.to);
      if (res != null && res.lat != null && res.lng != null && mounted) {
        setState(() {
          _dropoff = LatLng(res.lat!, res.lng!);
        });
        _updateTripRoute();
      }
    } catch (_) {}
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

  Future<void> _updateTripRoute() async {
    final messages = ref.read(rideProvider).messages;
    RideMessage? ride;
    try {
      ride = messages.firstWhere((m) => m.reqId == widget.reqId);
    } catch (_) {}
    final movt = (ride?.movtStatusDriver ?? '').toLowerCase().trim();
    final isInTransit = movt == 'intransit';

    final origin = _driverPos;
    final destination = isInTransit ? _dropoff : _pickup;

    if (origin.latitude == 0.0 || destination.latitude == 0.0) return;
    try {
      final route = await RouteService.instance.getDrivingRoute(
        origin: origin,
        destination: destination,
      );
      if (mounted && route.points.isNotEmpty) {
        setState(() {
          _tripRoutePoints = route.points;
          _etaMinutes = max(1, route.durationMinutes);
        });
      }
    } catch (_) {}
  }

  void _fitRouteBounds() {
    if (!_mapReady) return;
    final points = <LatLng>[_driverPos, _pickup];
    if (_dropoff.latitude != 0.0 && _dropoff.longitude != 0.0) {
      points.add(_dropoff);
    }
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(40, 100, 40, 320),
      ),
    );
  }

  void _showPickupNotesSheet(BuildContext context) {
    final textController = TextEditingController(text: _pickupNotes);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E142B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Pickup Notes for Driver',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Provide specific details to help your driver find you quickly.',
                style: TextStyle(color: Color(0xFFA59AB8), fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: textController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'e.g. Waiting by main gate, opposite pharmacy',
                  hintStyle: const TextStyle(color: Color(0xFF756A88), fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF281C38),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  "I'm at the gate",
                  "Opposite the pharmacy",
                  "Wearing dark jacket",
                  "Call when nearby",
                ].map((preset) {
                  return GestureDetector(
                    onTap: () {
                      textController.text = preset;
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF281C38),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Text(
                        preset,
                        style: const TextStyle(color: Color(0xFFD6CEE6), fontSize: 12),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SRColors.amber500,
                    foregroundColor: SRColors.ink900,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    setState(() => _pickupNotes = textController.text.trim());
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    'Save Note',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
    if (_driverPhone.isEmpty) {
      setState(() => _driverPhone = driverPhone);
      _fetchDriverImage(driverPhone);
    }

    try {
      final raw = await RideApi.instance.getLocation(driverPhone);
      // Response wraps coords inside "Data": { latitude, longitude }
      final inner = (raw['Data'] as Map<String, dynamic>?) ?? raw;
      final lat = double.tryParse((inner['latitude'] ?? inner['Latitude'] ?? '').toString());
      final lng = double.tryParse((inner['longitude'] ?? inner['Longitude'] ?? '').toString());
      // lat/lng of 0,0 means no GPS fix recorded yet — skip
      if (lat == null || lng == null || (lat == 0.0 && lng == 0.0) || !mounted) return;

      final newDriverPos = LatLng(lat, lng);

      // Compute heading bearing
      if (_driverPos.latitude != newDriverPos.latitude ||
          _driverPos.longitude != newDriverPos.longitude) {
        final dLng = (newDriverPos.longitude - _driverPos.longitude) * pi / 180;
        final y = sin(dLng) * cos(newDriverPos.latitude * pi / 180);
        final x = cos(_driverPos.latitude * pi / 180) * sin(newDriverPos.latitude * pi / 180) -
            sin(_driverPos.latitude * pi / 180) * cos(newDriverPos.latitude * pi / 180) * cos(dLng);
        _driverBearing = (atan2(y, x) * 180 / pi + 360) % 360;
      }

      // Update pickup/dropoff from real ride data when available
      final fromLat = double.tryParse(ride.fromLat.toString());
      final fromLng = double.tryParse(ride.fromLng.toString());
      final toLat = double.tryParse(ride.toLat.toString());
      final toLng = double.tryParse(ride.toLng.toString());

      final hadNoRoute = _tripRoutePoints.isEmpty;

      setState(() {
        _driverPos = newDriverPos;
        if (fromLat != null && fromLng != null && fromLat != 0.0 && fromLng != 0.0) {
          _pickup = LatLng(fromLat, fromLng);
        }
        if (toLat != null && toLng != null && toLat != 0.0 && toLng != 0.0) {
          _dropoff = LatLng(toLat, toLng);
        }
      });

      if (hadNoRoute) {
        _updateTripRoute();
      }

      if (_mapReady) {
        _mapController.move(newDriverPos, 14.5);
      }
    } catch (_) {}
  }

  Future<void> _fetchDriverImage(String phone) async {
    if (phone.isEmpty) return;
    final passedUrl = widget.driverPhotoUrl;
    try {
      final data = await RideApi.instance.getUserDetail(phone);
      final profile = data['Data'] as Map<String, dynamic>?;
      if (profile == null || !mounted) return;
      final url = passedUrl.isNotEmpty
          ? passedUrl
          : (profile['Image'] ?? profile['Photo'] ?? '').toString();
      final color = (profile['VColor'] ?? profile['vcolor'] ?? '').toString();
      final plate = (profile['VPlate'] ?? profile['vplate'] ?? profile['Plate'] ?? '').toString();
      final totalRides = (profile['TotalRides'] ?? profile['total_rides'] ?? 0) as num;
      setState(() {
        if (url.isNotEmpty) _driverPhotoUrl = url;
        if (color.isNotEmpty) _driverColor = color;
        if (plate.isNotEmpty) _driverPlate = plate;
        if (totalRides > 0) _driverTotalRides = totalRides.toInt();
      });
    } catch (_) {
      if (passedUrl.isNotEmpty && mounted) setState(() => _driverPhotoUrl = passedUrl);
    }
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
          // Full-screen dark mode map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _driverPos,
              initialZoom: 15.0,
              onMapReady: () {
                setState(() => _mapReady = true);
                _updateTripRoute();
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.streetrideplus.streetride',
              ),

              // Translucent pickup accuracy/beacon halo
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _pickup,
                    radius: 46,
                    color: const Color(0xFF4C8DFF).withValues(alpha: 0.16),
                    borderStrokeWidth: 1.5,
                    borderColor: const Color(0xFF4C8DFF).withValues(alpha: 0.35),
                  ),
                ],
              ),

              // Road Route Polylines
              if (_tripRoutePoints.isNotEmpty) ...[
                PolylineLayer(
                  polylines: [
                    // Outer white glow casing
                    Polyline(
                      points: _tripRoutePoints,
                      color: Colors.white.withValues(alpha: 0.9),
                      strokeWidth: 8,
                      strokeCap: StrokeCap.round,
                    ),
                    // Road primary polyline
                    Polyline(
                      points: _tripRoutePoints,
                      color: SRColors.purple700,
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                    ),
                  ],
                ),
              ] else ...[
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_driverPos, _pickup],
                      color: Colors.white.withValues(alpha: 0.7),
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                    ),
                    if (_dropoff.latitude != 0.0 && _dropoff.longitude != 0.0)
                      Polyline(
                        points: [_pickup, _dropoff],
                        color: SRColors.purple300.withValues(alpha: 0.5),
                        strokeWidth: 3,
                        strokeCap: StrokeCap.round,
                      ),
                  ],
                ),
              ],

              // Pins & Rotating Driver Vehicle Marker
              MarkerLayer(
                markers: [
                  // Pickup marker with waving rider indicator
                  Marker(
                    point: _pickup,
                    width: 44,
                    height: 48,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x60000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.hail_rounded,
                                color: Color(0xFF1E142B), size: 20),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4C8DFF),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Drop-off marker
                  if (_dropoff.latitude != 0.0 && _dropoff.longitude != 0.0)
                    Marker(
                      point: _dropoff,
                      width: 32,
                      height: 32,
                      child: Container(
                        decoration: BoxDecoration(
                          color: SRColors.amber500,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x60000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.flag_rounded,
                              color: SRColors.ink900, size: 16),
                        ),
                      ),
                    ),

                  // Rotating Driver Car Marker
                  Marker(
                    point: _driverPos,
                    width: 52,
                    height: 52,
                    child: Transform.rotate(
                      angle: _driverBearing * pi / 180,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B1429),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x80000000),
                                  blurRadius: 10,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              'assets/images/illustration-car-night.png',
                              width: 38,
                              height: 38,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.navigation_rounded,
                                color: SRColors.amber500,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Floating Map Controls on right
          Positioned(
            right: 14,
            bottom: _sheetExpanded ? 340 : 160,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Fit route button
                GestureDetector(
                  onTap: _fitRouteBounds,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F172E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.alt_route_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(height: 10),

                // Recenter on driver button
                GestureDetector(
                  onTap: () => _mapController.move(_driverPos, 15.5),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F172E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.my_location_rounded,
                        color: SRColors.amber500, size: 20),
                  ),
                ),
                const SizedBox(height: 10),

                // Safety pill button (matching the guide)
                GestureDetector(
                  onTap: () => context.push('/safety'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F172E),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user_rounded,
                            color: Color(0xFF4C8DFF), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Safety',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Top Header overlay with Back & Quick Safety
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F172E),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white),
                      ),
                    ),
                    const Spacer(),
                    // Status Badge
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.navigation_rounded,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            statusLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
              driverPhotoUrl: _driverPhotoUrl,
              car: widget.car,
              driverColor: _driverColor,
              driverPlate: _driverPlate,
              totalRides: _driverTotalRides,
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
              etaMinutes: _etaMinutes,
              pickupNote: _pickupNotes,
              onOpenNotes: () => _showPickupNotesSheet(context),
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
  final String? driverPhotoUrl;
  final String car;
  final String driverColor;
  final String driverPlate;
  final int totalRides;
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
  final int etaMinutes;
  final String pickupNote;
  final VoidCallback onOpenNotes;
  final VoidCallback onToggle;
  final VoidCallback onRateAndPay;

  const _DriverSheet({
    required this.driverName,
    required this.driverInitials,
    this.driverPhotoUrl,
    required this.car,
    required this.driverColor,
    required this.driverPlate,
    this.totalRides = 0,
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
    required this.etaMinutes,
    required this.pickupNote,
    required this.onOpenNotes,
    required this.onToggle,
    required this.onRateAndPay,
  });

  Future<void> _callDriver() async {
    final phone = driverPhone.startsWith('+') ? driverPhone : '+$driverPhone';
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final m = movt.toLowerCase().trim();
    final isArrived = m == 'arrived';
    final isInTransit = m == 'intransit';
    final isCompleted = m == 'completed';

    final headerText = isArrived
        ? 'Driver has arrived at pickup'
        : isInTransit
            ? 'On trip · ~$etaMinutes min to destination'
            : isCompleted
                ? 'Trip completed'
                : 'Driver is arriving in ~$etaMinutes min';

    final vehicleDesc = [
      driverColor.isNotEmpty ? driverColor : 'Black',
      car.isNotEmpty ? car : 'Toyota Corolla',
    ].join(' ');

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF181126),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Color(0x60000000),
            blurRadius: 30,
            offset: Offset(0, -8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: GestureDetector(
              onTap: onToggle,
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF3E3256),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),

          // 1. Status Headline (Bolt style)
          Text(
            headerText,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),

          // 2. Vehicle Description & License Plate & Car Render
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicleDesc,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD6CEE6),
                      ),
                    ),
                    const SizedBox(height: 5),
                    // High-contrast Plate Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF281C38),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Text(
                        driverPlate.isNotEmpty ? driverPlate : 'ABJ623RW',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Car illustration
              Image.asset(
                'assets/images/illustration-car-night.png',
                height: 48,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Color(0xFF291F3A), height: 1),
          const SizedBox(height: 16),

          // 3. Driver Info Row + Contact & Safety buttons
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  DriverAvatar(
                    initials: driverInitials,
                    photoUrl: driverPhotoUrl,
                    size: 52,
                    fontSize: 19,
                  ),
                  Positioned(
                    top: -4,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF241A35),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: SRColors.amber500.withValues(alpha: 0.6),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 12, color: SRColors.amber500),
                          const SizedBox(width: 2),
                          Text(
                            (rating > 0 ? rating : 4.67).toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      totalRides > 0 ? '$totalRides completed trips' : 'Verified driver',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFA59AB8),
                      ),
                    ),
                  ],
                ),
              ),

              // Green circular "Contact driver" button
              GestureDetector(
                onTap: () {
                  _showContactOptions(context);
                },
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: SRColors.green600,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.call_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Contact',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD6CEE6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Circular "Safety" button
              GestureDetector(
                onTap: () => context.push('/safety'),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFF86EFAC),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shield_rounded, color: Color(0xFF14532D), size: 22),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: SRColors.coral500,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Safety',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD6CEE6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 4. Pickup Notes Card
          GestureDetector(
            onTap: onOpenNotes,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF221735),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.chat_bubble_outline_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      pickupNote.isNotEmpty
                          ? 'Note: $pickupNote'
                          : 'Any pickup notes for driver?',
                      style: TextStyle(
                        color: pickupNote.isNotEmpty
                            ? Colors.white
                            : const Color(0xFFA59AB8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFFA59AB8), size: 20),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 5. Payment Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF221735),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: SRColors.green600.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.payments_rounded,
                      color: SRColors.green500, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pay to driver NGN ${NumberFormat('#,###').format(price > 0 ? price : 10000)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Ask the driver for the Bank Transfer details',
                        style: TextStyle(
                          color: Color(0xFFA59AB8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (expanded) ...[
            const SizedBox(height: 12),
            // Route Address Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1D142E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: SRColors.green500,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 2,
                        height: 16,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: SRColors.amber500,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatCleanAddress(from).isNotEmpty ? formatCleanAddress(from) : from,
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatCleanAddress(to).isNotEmpty ? formatCleanAddress(to) : to,
                          style: const TextStyle(fontSize: 12, color: Color(0xFFA59AB8)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          _RatePayButton(movt: movt, onRateAndPay: onRateAndPay),
        ],
      ),
    );
  }

  void _showContactOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E142B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Contact $driverName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: SRColors.green600.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call_rounded, color: SRColors.green500),
                  ),
                  title: const Text('Voice Call', style: TextStyle(color: Colors.white)),
                  subtitle: Text(driverPhone.isNotEmpty ? driverPhone : 'Direct cellular call',
                      style: const TextStyle(color: Color(0xFFA59AB8), fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _callDriver();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: SRColors.purple700.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat_bubble_rounded, color: SRColors.purple300),
                  ),
                  title: const Text('In-App Chat', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Send a message within StreetRide',
                      style: TextStyle(color: Color(0xFFA59AB8), fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/chat', extra: {
                      'driverName': driverName,
                      'driverInitials': driverInitials,
                      'driverPhone': driverPhone,
                      'reqId': reqId,
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
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
            boxShadow: [
              BoxShadow(
                color: SRColors.green500.withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
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
            ? SRColors.amber500.withValues(alpha: 0.15)
            : const Color(0xFF281C38),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: isArrived ? SRColors.amber500 : Colors.white.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: isArrived ? SRColors.amber500 : const Color(0xFFD6CEE6),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
