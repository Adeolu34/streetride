import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/ride_api.dart';
import '../../core/models/location_models.dart';
import '../../core/services/route_service.dart';
import '../../core/services/session_service.dart';
import '../../core/theme/app_theme.dart';

enum _Phase { enRoute, arrived, inTransit }

class DriverNavigateScreen extends ConsumerStatefulWidget {
  final String reqId;
  final String riderName;
  final String riderPhone;
  final String fromText;
  final String toText;
  final double fromLat;
  final double fromLng;
  final double toLat;
  final double toLng;

  const DriverNavigateScreen({
    super.key,
    required this.reqId,
    this.riderName = 'Rider',
    this.riderPhone = '',
    this.fromText = '',
    this.toText = '',
    this.fromLat = 0.0,
    this.fromLng = 0.0,
    this.toLat = 0.0,
    this.toLng = 0.0,
  });

  @override
  ConsumerState<DriverNavigateScreen> createState() =>
      _DriverNavigateScreenState();
}

class _DriverNavigateScreenState extends ConsumerState<DriverNavigateScreen> {
  late LatLng _pickup;
  late LatLng _dropoff;
  LatLng _driverPos = const LatLng(6.4580, 3.4850);
  Timer? _locationTimer;
  final _mapController = MapController();
  bool _mapReady = false;
  String? _distLabel;
  _Phase _phase = _Phase.enRoute;
  bool _actionBusy = false;
  List<LatLng> _routePoints = [];

  // In-App Turn-By-Turn Navigation State
  List<RouteStep> _routeSteps = [];
  int _currentStepIndex = 0;
  bool _voiceEnabled = true;
  double _driverBearing = 0.0;
  bool _autoFollow = true;
  FlutterTts? _tts;
  String _lastSpokenInstruction = '';

  @override
  void initState() {
    super.initState();
    _initTts();
    _pickup = (widget.fromLat != 0.0 && widget.fromLng != 0.0)
        ? LatLng(widget.fromLat, widget.fromLng)
        : const LatLng(6.4510, 3.4780);

    _dropoff = (widget.toLat != 0.0 && widget.toLng != 0.0)
        ? LatLng(widget.toLat, widget.toLng)
        : const LatLng(0.0, 0.0);

    _startLocationUpdates();
    if (_dropoff.latitude == 0.0 && widget.toText.isNotEmpty) {
      _resolveDropoffAddress();
    }
    // Immediately signal driver is en route
    if (widget.reqId.isNotEmpty) {
      RideApi.instance
          .setDriverMovementStatus(widget.reqId, 'Started')
          .catchError((_) => <String, dynamic>{});
    }
  }

  Future<void> _initTts() async {
    try {
      _tts = FlutterTts();
      await _tts?.setLanguage('en-US');
      await _tts?.setSpeechRate(0.5);
      await _tts?.setVolume(1.0);
    } catch (_) {}
  }

  Future<void> _speak(String text) async {
    if (!_voiceEnabled || _tts == null || text.isEmpty) return;
    if (_lastSpokenInstruction == text) return;
    _lastSpokenInstruction = text;
    try {
      await _tts?.stop();
      await _tts?.speak(text);
    } catch (_) {}
  }

  RouteStep? get _currentStep =>
      (_routeSteps.isNotEmpty && _currentStepIndex < _routeSteps.length)
          ? _routeSteps[_currentStepIndex]
          : null;

  RouteStep? get _nextStep =>
      (_routeSteps.isNotEmpty && _currentStepIndex + 1 < _routeSteps.length)
          ? _routeSteps[_currentStepIndex + 1]
          : null;

  double get _distToStepMeters {
    final step = _currentStep;
    if (step == null) return 0.0;
    if (step.location.latitude == 0.0 && step.location.longitude == 0.0) {
      return step.distanceMeters;
    }
    return Geolocator.distanceBetween(
      _driverPos.latitude,
      _driverPos.longitude,
      step.location.latitude,
      step.location.longitude,
    );
  }

  void _checkStepProgress() {
    if (_routeSteps.isEmpty) return;
    final dist = _distToStepMeters;
    if (dist > 0 && dist < 35 && _currentStepIndex < _routeSteps.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
      final s = _currentStep;
      if (s != null) {
        _speak(s.instruction);
      }
    } else if (dist > 0 && dist < 120 && dist >= 35) {
      final s = _currentStep;
      if (s != null) {
        _speak('In ${(dist / 10).round() * 10} meters, ${s.instruction}');
      }
    }
  }

  Future<void> _resolveDropoffAddress() async {
    try {
      final res = await RideApi.instance.resolveAddress(widget.toText);
      if (res != null && res.lat != null && res.lng != null && mounted) {
        setState(() {
          _dropoff = LatLng(res.lat!, res.lng!);
        });
        if (_phase == _Phase.inTransit) {
          _updateRoute();
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _tts?.stop();
    super.dispose();
  }

  Future<void> _callRider() async {
    final phone = widget.riderPhone.trim();
    if (phone.isEmpty) return;
    final formatted = phone.startsWith('+') ? phone : '+$phone';
    final uri = Uri.parse('tel:$formatted');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  /// Open external Google Maps / Apple Maps turn-by-turn navigation
  Future<void> _openExternalNavigation() async {
    final target = _phase == _Phase.inTransit ? _dropoff : _pickup;
    final fallbackLabel = _phase == _Phase.inTransit ? 'Drop-off' : 'Pickup';
    final rawLabel = _phase == _Phase.inTransit ? widget.toText : widget.fromText;
    final label = rawLabel.isNotEmpty ? rawLabel : fallbackLabel;
    final hasCoords = target.latitude != 0.0 && target.longitude != 0.0;

    final Uri uri;
    if (Platform.isIOS) {
      if (hasCoords) {
        uri = Uri.parse(
          'maps://?daddr=${target.latitude},${target.longitude}&q=${Uri.encodeComponent(label)}',
        );
      } else {
        uri = Uri.parse(
          'maps://?q=${Uri.encodeComponent(label)}',
        );
      }
    } else {
      if (hasCoords) {
        uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=${target.latitude},${target.longitude}&travelmode=driving',
        );
      } else {
        uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(label)}&travelmode=driving',
        );
      }
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _startLocationUpdates() async {
    await _sendLocation();
    _locationTimer = Timer.periodic(
      const Duration(seconds: 6),
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
          perm == LocationPermission.deniedForever) {
        return;
      }

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

      // Compute heading bearing
      if (_driverPos.latitude != newPos.latitude ||
          _driverPos.longitude != newPos.longitude) {
        final dLng = (newPos.longitude - _driverPos.longitude) * pi / 180;
        final y = sin(dLng) * cos(newPos.latitude * pi / 180);
        final x = cos(_driverPos.latitude * pi / 180) * sin(newPos.latitude * pi / 180) -
            sin(_driverPos.latitude * pi / 180) * cos(newPos.latitude * pi / 180) * cos(dLng);
        _driverBearing = (atan2(y, x) * 180 / pi + 360) % 360;
      }

      setState(() => _driverPos = newPos);

      // Check step advancement & voice triggers
      _checkStepProgress();

      // Fetch or update road route if missing
      if (_routePoints.isEmpty) {
        _updateRoute();
      }

      if (_mapReady && _autoFollow) {
        _mapController.move(newPos, 16.5);
      }
    } catch (_) {}
  }

  Future<void> _updateRoute() async {
    final target = _phase == _Phase.inTransit ? _dropoff : _pickup;
    if (target.latitude == 0.0 && target.longitude == 0.0) return;

    try {
      final route = await RouteService.instance.getDrivingRoute(
        origin: _driverPos,
        destination: target,
      );

      if (mounted) {
        setState(() {
          _routePoints = route.points;
          _routeSteps = route.steps;
          _currentStepIndex = 0;
          _distLabel = '${route.distanceLabel} · ~${route.durationLabel}';
        });
        if (_routeSteps.isNotEmpty) {
          _speak(_routeSteps.first.instruction);
        }
      }
    } catch (_) {
      final metres = Geolocator.distanceBetween(
        _driverPos.latitude,
        _driverPos.longitude,
        target.latitude,
        target.longitude,
      );
      if (mounted) {
        setState(() {
          _distLabel = metres < 1000
              ? '${metres.round()} m away'
              : '${(metres / 1000).toStringAsFixed(1)} km away';
        });
      }
    }
  }

  Future<void> _onArrived() async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    if (widget.reqId.isNotEmpty) {
      await RideApi.instance
          .setDriverMovementStatus(widget.reqId, 'Arrived')
          .catchError((_) => <String, dynamic>{});
    }
    _speak('You have arrived at the pickup location.');
    if (mounted) setState(() { _phase = _Phase.arrived; _actionBusy = false; });
  }

  Future<void> _onStartTrip() async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    if (widget.reqId.isNotEmpty) {
      await Future.wait([
        RideApi.instance
            .setDriverMovementStatus(widget.reqId, 'InTransit')
            .catchError((_) => <String, dynamic>{}),
        RideApi.instance
            .setRiderStatus(widget.reqId, 'Boarded')
            .catchError((_) => <String, dynamic>{}),
      ]);
    }
    _speak('Trip started. Navigating to destination.');
    if (mounted) {
      setState(() {
        _phase = _Phase.inTransit;
        _actionBusy = false;
      });
      _updateRoute();
    }
  }

  Future<void> _onEndTrip() async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    if (widget.reqId.isNotEmpty) {
      await Future.wait([
        RideApi.instance
            .setDriverMovementStatus(widget.reqId, 'Completed')
            .catchError((_) => <String, dynamic>{}),
        RideApi.instance
            .setRiderStatus(widget.reqId, 'Completed')
            .catchError((_) => <String, dynamic>{}),
      ]);
    }
    _speak('Trip completed. Thank you.');
    if (mounted) context.go('/driver-home');
  }

  IconData _getManeuverIcon(String maneuver, String modifier) {
    final m = maneuver.toLowerCase();
    final mod = modifier.toLowerCase();
    if (m == 'arrive') return Icons.flag_rounded;
    if (mod.contains('sharp right')) return Icons.turn_sharp_right_rounded;
    if (mod.contains('sharp left')) return Icons.turn_sharp_left_rounded;
    if (mod.contains('slight right')) return Icons.turn_slight_right_rounded;
    if (mod.contains('slight left')) return Icons.turn_slight_left_rounded;
    if (mod.contains('right')) return Icons.turn_right_rounded;
    if (mod.contains('left')) return Icons.turn_left_rounded;
    if (mod.contains('uturn')) return Icons.u_turn_left_rounded;
    if (m.contains('roundabout') || m.contains('rotary')) return Icons.roundabout_right_rounded;
    return Icons.straight_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final activeTarget = _phase == _Phase.inTransit ? _dropoff : _pickup;

    return Scaffold(
      body: Stack(
        children: [
          // ── 1. Full-Screen Dark Mode Map ────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _driverPos,
              initialZoom: 16.0,
              onMapReady: () {
                setState(() => _mapReady = true);
                _updateRoute();
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.streetrideplus.streetride',
              ),

              // Road Route Polyline (High contrast glow + driving stroke)
              if (_routePoints.isNotEmpty) ...[
                PolylineLayer(
                  polylines: [
                    // Outer white glow casing
                    Polyline(
                      points: _routePoints,
                      color: Colors.white.withValues(alpha: 0.9),
                      strokeWidth: 9,
                      strokeCap: StrokeCap.round,
                    ),
                    // Core driving polyline
                    Polyline(
                      points: _routePoints,
                      color: _phase == _Phase.inTransit
                          ? SRColors.green600
                          : SRColors.amber500,
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                    ),
                  ],
                ),
              ] else ...[
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_driverPos, activeTarget],
                      color: SRColors.purple300.withValues(alpha: 0.7),
                      strokeWidth: 4,
                      strokeCap: StrokeCap.round,
                    ),
                  ],
                ),
              ],

              // Destination and Driver Vehicle Markers
              MarkerLayer(
                markers: [
                  // Active Target Marker (Pickup or Dropoff)
                  Marker(
                    point: activeTarget,
                    width: 38,
                    height: 38,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _phase == _Phase.inTransit
                            ? SRColors.green600
                            : SRColors.purple700,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x70000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          _phase == _Phase.inTransit
                              ? Icons.flag_rounded
                              : Icons.person_pin_circle_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),

                  // Rotating Driver Vehicle Marker
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

          // ── 2. In-App Google Maps Style Turn HUD Banner ────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: _phase == _Phase.inTransit
                    ? const Color(0xFF0F442C) // driving green navigation header
                    : const Color(0xFF150E24), // deep indigo pickup header
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(22)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Row: Back button (if en route) + Target label + Voice Mute button
                      Row(
                        children: [
                          if (_phase == _Phase.enRoute)
                            GestureDetector(
                              onTap: () => context.pop(),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.arrow_back_rounded,
                                    color: Colors.white, size: 18),
                              ),
                            )
                          else
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: SRColors.green600.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.navigation_rounded,
                                  color: Colors.white, size: 18),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _phase == _Phase.inTransit
                                  ? 'Navigating to Drop-off'
                                  : 'Navigating to Pickup',
                              style: const TextStyle(
                                color: Color(0xFFD6CEE6),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          // Voice guidance toggle
                          GestureDetector(
                            onTap: () {
                              setState(() => _voiceEnabled = !_voiceEnabled);
                              if (!_voiceEnabled) _tts?.stop();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _voiceEnabled
                                        ? Icons.volume_up_rounded
                                        : Icons.volume_off_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _voiceEnabled ? 'Voice on' : 'Muted',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Main Maneuver Guidance Row (Turn arrow + Distance countdown + Road Name)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Large prominent Maneuver Icon
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: SRColors.green600,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: SRColors.green600.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                _getManeuverIcon(
                                  _currentStep?.maneuver ?? 'straight',
                                  _currentStep?.modifier ?? '',
                                ),
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Distance countdown
                                Text(
                                  _distToStepMeters > 0
                                      ? (_distToStepMeters < 35
                                          ? 'Turn now'
                                          : 'In ${(_distToStepMeters / 10).round() * 10} m')
                                      : (_currentStep?.distanceLabel ??
                                          (_distLabel ?? 'Calculating…')),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // Instruction / Road name
                                Text(
                                  _currentStep?.instruction ??
                                      (_distLabel ?? 'Proceed along road'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFF0EBF8),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_nextStep != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Then: ${_nextStep!.instruction}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFFA59AB8),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── 3. Floating Navigation & Zoom Controls ───────────────────────
          Positioned(
            right: 14,
            bottom: 240,
            child: Column(
              children: [
                // Auto-follow / Recenter Toggle
                GestureDetector(
                  onTap: () {
                    setState(() => _autoFollow = !_autoFollow);
                    _mapController.move(_driverPos, 16.5);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _autoFollow ? SRColors.amber500 : const Color(0xFF1E142B),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.navigation_rounded,
                      color: _autoFollow ? SRColors.ink900 : Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Zoom in
                GestureDetector(
                  onTap: () {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(_driverPos, zoom + 1);
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E142B),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(height: 8),

                // Zoom out
                GestureDetector(
                  onTap: () {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(_driverPos, zoom - 1);
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E142B),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.remove_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(height: 10),

                // External Maps Fallback (optional button)
                GestureDetector(
                  onTap: _openExternalNavigation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E142B),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_new_rounded,
                            color: SRColors.amber500, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Maps',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 4. Driver Bottom Action Sheet ─────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF181126),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x60000000),
                    blurRadius: 24,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B2F52),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Trip ETA stats badge
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF241A35),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_rounded,
                            color: SRColors.amber500, size: 15),
                        const SizedBox(width: 6),
                        Text(
                          _distLabel ?? 'Calculating…',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Rider details row
                  Row(
                    children: [
                      const _RiderAvatar(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.riderName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              _phase == _Phase.inTransit
                                  ? (widget.toText.isNotEmpty
                                      ? 'To: ${formatCleanAddress(widget.toText)}'
                                      : 'To destination')
                                  : (widget.fromText.isNotEmpty
                                      ? 'Pickup: ${formatCleanAddress(widget.fromText)}'
                                      : 'To pickup'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFA59AB8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          if (widget.riderPhone.isNotEmpty)
                            GestureDetector(
                              onTap: _callRider,
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: SRColors.green600.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.call_rounded,
                                    color: SRColors.green500, size: 20),
                              ),
                            ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => context.push('/chat', extra: {
                              'driverName': widget.riderName,
                              'driverInitials': widget.riderName.isNotEmpty
                                  ? widget.riderName[0].toUpperCase()
                                  : 'R',
                              'driverPhone': widget.riderPhone,
                              'reqId': widget.reqId,
                            }),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: SRColors.purple700.withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.chat_bubble_rounded,
                                  color: SRColors.purple300, size: 20),
                            ),
                          ),
                        ],
                      ),
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
    final String label;
    final Color color;
    final VoidCallback onTap;

    switch (phase) {
      case _Phase.enRoute:
        label = 'I Have Arrived';
        color = SRColors.amber500;
        onTap = onArrived;
        break;
      case _Phase.arrived:
        label = 'Start Trip (Rider Boarded)';
        color = SRColors.green600;
        onTap = onStartTrip;
        break;
      case _Phase.inTransit:
        label = 'Complete Trip';
        color = SRColors.purple700;
        onTap = onEndTrip;
        break;
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: phase == _Phase.enRoute ? SRColors.ink900 : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        onPressed: busy ? null : onTap,
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
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
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF281C38),
        shape: BoxShape.circle,
        border: Border.all(color: SRColors.purple300.withValues(alpha: 0.3), width: 1.5),
      ),
      child: const Icon(Icons.person_rounded,
          color: SRColors.purple300, size: 24),
    );
  }
}
