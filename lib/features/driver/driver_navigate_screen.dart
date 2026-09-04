import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../core/api/ride_api.dart';
import '../../core/services/session_service.dart';
import '../../core/theme/app_theme.dart';

enum _Phase { enRoute, arrived, inTransit }

class DriverNavigateScreen extends ConsumerStatefulWidget {
  final String reqId;
  const DriverNavigateScreen({super.key, required this.reqId});

  @override
  ConsumerState<DriverNavigateScreen> createState() =>
      _DriverNavigateScreenState();
}

class _DriverNavigateScreenState extends ConsumerState<DriverNavigateScreen> {
  static const _pickup = LatLng(6.4510, 3.4780);
  LatLng _driverPos = const LatLng(6.4580, 3.4850);
  Timer? _locationTimer;
  final _mapController = MapController();
  bool _mapReady = false;
  String? _distLabel;
  _Phase _phase = _Phase.enRoute;
  bool _actionBusy = false;

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
    // Immediately signal driver is en route
    if (widget.reqId.isNotEmpty) {
      RideApi.instance
          .setDriverMovementStatus(widget.reqId, 'Started')
          .catchError((_) => <String, dynamic>{});
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _startLocationUpdates() async {
    await _sendLocation();
    _locationTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _sendLocation(),
    );
  }

  Future<void> _sendLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final phone = SessionService.instance.profile?.phone ?? '';
      if (phone.isNotEmpty) {
        RideApi.instance
            .updateLocation(
              phone: phone,
              lat: pos.latitude.toString(),
              long: pos.longitude.toString(),
              isDriver: true,
            )
            .catchError((_) => <String, dynamic>{});
      }

      if (!mounted) return;
      final newPos = LatLng(pos.latitude, pos.longitude);
      final metres = Geolocator.distanceBetween(
          pos.latitude, pos.longitude, _pickup.latitude, _pickup.longitude);
      setState(() {
        _driverPos = newPos;
        _distLabel = metres < 1000
            ? '${metres.round()} m to pickup'
            : '${(metres / 1000).toStringAsFixed(1)} km to pickup';
      });
      if (_mapReady) _mapController.move(newPos, 14.5);
    } catch (_) {}
  }

  Future<void> _onArrived() async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    if (widget.reqId.isNotEmpty) {
      await RideApi.instance
          .setDriverMovementStatus(widget.reqId, 'Arrived')
          .catchError((_) => <String, dynamic>{});
    }
    if (mounted) setState(() { _phase = _Phase.arrived; _actionBusy = false; });
  }

  Future<void> _onStartTrip() async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    if (widget.reqId.isNotEmpty) {
      // Rider boards: BK4=InTransit + BK5=Boarded in sync
      await Future.wait([
        RideApi.instance
            .setDriverMovementStatus(widget.reqId, 'InTransit')
            .catchError((_) => <String, dynamic>{}),
        RideApi.instance
            .setRiderStatus(widget.reqId, 'Boarded')
            .catchError((_) => <String, dynamic>{}),
      ]);
    }
    if (mounted) setState(() { _phase = _Phase.inTransit; _actionBusy = false; });
  }

  Future<void> _onEndTrip() async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    if (widget.reqId.isNotEmpty) {
      // Trip done: BK4=Completed + BK5=Completed in sync
      await Future.wait([
        RideApi.instance
            .setDriverMovementStatus(widget.reqId, 'Completed')
            .catchError((_) => <String, dynamic>{}),
        RideApi.instance
            .setRiderStatus(widget.reqId, 'Completed')
            .catchError((_) => <String, dynamic>{}),
      ]);
    }
    if (mounted) context.go('/driver-home');
  }

  String get _headerTitle {
    switch (_phase) {
      case _Phase.enRoute:
        return 'Heading to pickup';
      case _Phase.arrived:
        return 'Arrived at pickup';
      case _Phase.inTransit:
        return 'Trip in progress';
    }
  }

  String get _headerSub {
    switch (_phase) {
      case _Phase.enRoute:
        return _distLabel ?? 'Getting location…';
      case _Phase.arrived:
        return 'Waiting for rider to board';
      case _Phase.inTransit:
        return 'Heading to destination';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _driverPos,
              initialZoom: 14.0,
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
                ],
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _pickup,
                    radius: 12,
                    color: SRColors.green500,
                    borderStrokeWidth: 3,
                    borderColor: Colors.white,
                  ),
                  CircleMarker(
                    point: _driverPos,
                    radius: 10,
                    color: SRColors.purple700,
                    borderStrokeWidth: 3,
                    borderColor: Colors.white,
                  ),
                ],
              ),
            ],
          ),

          // Navigation header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: _phase == _Phase.inTransit
                    ? SRColors.green600
                    : SRColors.indigo900,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Row(
                    children: [
                      if (_phase == _Phase.enRoute)
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white, size: 20),
                          ),
                        )
                      else
                        const SizedBox(width: 38),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _headerTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              _headerSub,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _phase == _Phase.inTransit
                            ? Icons.directions_car_rounded
                            : Icons.navigation_rounded,
                        color: SRColors.amber500,
                        size: 32,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: SRColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Row(
                    children: [
                      _RiderAvatar(),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rider',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: SRColors.ink900,
                              ),
                            ),
                            Text(
                              'Confirmed ride',
                              style: TextStyle(
                                fontSize: 12,
                                color: SRColors.ink500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.call_rounded,
                          color: SRColors.purple700, size: 24),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _PhaseButton(
                    phase: _phase,
                    busy: _actionBusy,
                    onArrived: _onArrived,
                    onStartTrip: _onStartTrip,
                    onEndTrip: _onEndTrip,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseButton extends StatelessWidget {
  final _Phase phase;
  final bool busy;
  final VoidCallback onArrived;
  final VoidCallback onStartTrip;
  final VoidCallback onEndTrip;

  const _PhaseButton({
    required this.phase,
    required this.busy,
    required this.onArrived,
    required this.onStartTrip,
    required this.onEndTrip,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    final VoidCallback action;

    switch (phase) {
      case _Phase.enRoute:
        color = SRColors.green500;
        label = 'Arrived at pickup';
        action = onArrived;
      case _Phase.arrived:
        color = SRColors.purple700;
        label = 'Rider boarded — Start trip';
        action = onStartTrip;
      case _Phase.inTransit:
        color = SRColors.indigo900;
        label = 'End trip';
        action = onEndTrip;
    }

    return GestureDetector(
      onTap: busy ? null : action,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 52,
        decoration: BoxDecoration(
          color: busy ? color.withValues(alpha: 0.5) : color,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Center(
          child: busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

class _RiderAvatar extends StatelessWidget {
  const _RiderAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: SRColors.purple700,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text(
          'R',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
