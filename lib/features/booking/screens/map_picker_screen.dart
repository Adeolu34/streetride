import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/ride_api.dart';
import '../../../core/theme/app_theme.dart';

class _Suggestion {
  final String address;
  final String placeId;
  _Suggestion({required this.address, required this.placeId});

  factory _Suggestion.fromApi(Map<String, dynamic> e) => _Suggestion(
        address: (e['Address'] ?? e['description'] ?? '').toString().trim(),
        placeId: (e['PlaceId'] ?? '').toString(),
      );
}

class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const MapPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final _mapController = MapController();
  final _searchCtr = TextEditingController();
  final _searchFocus = FocusNode();

  LatLng _center = const LatLng(6.5244, 3.3792);
  String _address = '';
  bool _geocoding = false;
  bool _pinLifted = false;

  List<_Suggestion> _suggestions = [];
  bool _searching = false;
  Timer? _geoDebounce;
  Timer? _searchDebounce;

  // ── Cleans reverse-geocode output ──────────────────────────────────────────
  static String _cleanAddress(String raw) {
    final parts = raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    parts.removeWhere((p) {
      final l = p.toLowerCase();
      return l == 'nigeria' ||
          l.endsWith(' state') ||
          l == 'federal capital territory' ||
          RegExp(r'^\d{5,}$').hasMatch(p);
    });
    return parts.take(3).join(', ');
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _center = LatLng(widget.initialLat!, widget.initialLng!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialLat == null) _goToCurrentLocation();
      _geocodeCenter();
    });
  }

  @override
  void dispose() {
    _geoDebounce?.cancel();
    _searchDebounce?.cancel();
    _searchCtr.dispose();
    _searchFocus.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ── Location helpers ────────────────────────────────────────────────────────

  Future<void> _goToCurrentLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return;

      final pos = await (Geolocator.getLastKnownPosition().then(
        (p) async => p ??
            await Geolocator.getCurrentPosition(
              locationSettings:
                  const LocationSettings(accuracy: LocationAccuracy.medium),
            ).timeout(const Duration(seconds: 10)),
      ));

      if (!mounted) return;
      final c = LatLng(pos.latitude, pos.longitude);
      _center = c;
      _mapController.move(c, 15);
      _geocodeCenter();
    } catch (_) {}
  }

  void _onPositionChanged(MapPosition position, bool hasGesture) {
    if (!hasGesture || position.center == null) return;
    _center = position.center!;
    setState(() => _pinLifted = true);
    _geoDebounce?.cancel();
    _geoDebounce = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _pinLifted = false);
      _geocodeCenter();
    });
  }

  Future<void> _geocodeCenter() async {
    setState(() => _geocoding = true);
    try {
      final res = await RideApi.instance.reverseGeocode(
        lat: _center.latitude.toStringAsFixed(6),
        long: _center.longitude.toStringAsFixed(6),
      );
      final raw = (res['address'] ?? res['Address'] ?? '').toString().trim();
      if (mounted && raw.isNotEmpty) {
        setState(() => _address = _cleanAddress(raw));
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  // ── Address search ──────────────────────────────────────────────────────────

  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    if (val.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final data = await ApiClient.instance
            .post({'theKey': 'RR1', 'Address': val});
        final raw = data['predictions'];
        if (raw is List && mounted) {
          setState(() {
            _suggestions = raw
                .take(6)
                .map((e) => _Suggestion.fromApi(e as Map<String, dynamic>))
                .where((s) => s.address.isNotEmpty)
                .toList();
          });
        }
      } catch (_) {}
    });
  }

  Future<void> _selectSuggestion(_Suggestion s) async {
    FocusScope.of(context).unfocus();
    _searchCtr.clear();
    setState(() {
      _suggestions = [];
      _searching = false;
      _address = _cleanAddress(s.address);
    });

    // Try to move the map to the selected place
    if (s.placeId.isNotEmpty) {
      try {
        final detail = await RideApi.instance.getPlaceDetail(s.placeId);
        final lat = double.tryParse(
            (detail['lat'] ?? detail['Lat'] ?? detail['latitude'] ?? '').toString());
        final lng = double.tryParse(
            (detail['lng'] ?? detail['Lng'] ?? detail['longitude'] ?? '').toString());
        if (lat != null && lng != null && mounted) {
          final c = LatLng(lat, lng);
          _center = c;
          _mapController.move(c, 15);
        }
      } catch (_) {}
    }
  }

  void _confirm() {
    if (_address.isEmpty) return;
    context.pop({
      'address': _address,
      'lat': _center.latitude,
      'lng': _center.longitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    final showSuggestions = _suggestions.isNotEmpty && _searching;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── Map (CartoDB Positron — clean light map) ──────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15,
              onPositionChanged: _onPositionChanged,
              onTap: (_, __) {
                if (_searching) {
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _searching = false;
                    _suggestions = [];
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.streetride.app',
              ),
            ],
          ),

          // ── Fixed centre pin ──────────────────────────────────────────────
          IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    transform:
                        Matrix4.translationValues(0, _pinLifted ? -10 : 0, 0),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: SRColors.purple700,
                      size: 52,
                      shadows: [
                        Shadow(
                          color: Color(0x40000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _pinLifted ? 10 : 7,
                    height: _pinLifted ? 3 : 5,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Top bar: back + search ────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.fromLTRB(14, top + 10, 14, 10),
                  child: Row(
                    children: [
                      // Back
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.arrow_back_rounded,
                              color: SRColors.ink900, size: 20),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Search field
                      Expanded(
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              const Icon(Icons.search_rounded,
                                  color: SRColors.ink500, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchCtr,
                                  focusNode: _searchFocus,
                                  onChanged: (v) {
                                    setState(() => _searching = true);
                                    _onSearchChanged(v);
                                  },
                                  onTap: () =>
                                      setState(() => _searching = true),
                                  cursorColor: SRColors.purple700,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: SRColors.ink900,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Search a place…',
                                    hintStyle: TextStyle(
                                        color: SRColors.ink500, fontSize: 14),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    isCollapsed: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              if (_searchCtr.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _searchCtr.clear();
                                    setState(() => _suggestions = []);
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.only(right: 10),
                                    child: Icon(Icons.close_rounded,
                                        size: 16, color: SRColors.ink500),
                                  ),
                                )
                              else
                                const SizedBox(width: 12),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search suggestions dropdown
                if (showSuggestions)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(64, 0, 14, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, __) => const Divider(
                            height: 1, color: SRColors.border, indent: 44),
                        itemBuilder: (_, i) {
                          final s = _suggestions[i];
                          return GestureDetector(
                            onTap: () => _selectSuggestion(s),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on_rounded,
                                      size: 18, color: SRColors.purple700),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _cleanAddress(s.address),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: SRColors.ink900,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── My location button ────────────────────────────────────────────
          Positioned(
            bottom: bottom + 120,
            right: 14,
            child: GestureDetector(
              onTap: _goToCurrentLocation,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.my_location_rounded,
                    color: SRColors.purple700, size: 22),
              ),
            ),
          ),

          // ── Bottom sheet: address + confirm ───────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(18, 16, 18, bottom + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          color: SRColors.purple700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _geocoding
                            ? const Row(
                                children: [
                                  SizedBox(
                                    width: 13,
                                    height: 13,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: SRColors.purple700,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Finding address…',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: SRColors.ink500),
                                  ),
                                ],
                              )
                            : Text(
                                _address.isNotEmpty
                                    ? _address
                                    : 'Move the map to pick a location',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: _address.isNotEmpty
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: _address.isNotEmpty
                                      ? SRColors.ink900
                                      : SRColors.ink500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: (_geocoding || _address.isEmpty) ? null : _confirm,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 52,
                      decoration: BoxDecoration(
                        color: (_geocoding || _address.isEmpty)
                            ? SRColors.purple100
                            : SRColors.purple700,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Center(
                        child: Text(
                          'Set this location',
                          style: TextStyle(
                            color: (_geocoding || _address.isEmpty)
                                ? SRColors.purple700
                                : Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
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
