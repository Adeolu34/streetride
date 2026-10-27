import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/ride_api.dart';
import '../../../core/models/location_models.dart';
import '../../../core/theme/app_theme.dart';

class _Suggestion {
  final String primaryName;
  final String secondaryAddr;
  final String fullAddress;
  final String placeId;

  _Suggestion({
    required this.primaryName,
    required this.secondaryAddr,
    required this.fullAddress,
    required this.placeId,
  });

  factory _Suggestion.fromApi(Map<String, dynamic> e) {
    final full = formatCleanAddress(
        (e['Address'] ?? e['description'] ?? e['Description'] ?? '').toString());
    final commaIdx = full.indexOf(',');
    final primary = commaIdx > 0 ? full.substring(0, commaIdx).trim() : full;
    final secondary = commaIdx > 0 ? full.substring(commaIdx + 1).trim() : '';

    return _Suggestion(
      primaryName: primary,
      secondaryAddr: secondary,
      fullAddress: full,
      placeId: (e['PlaceId'] ?? e['placeId'] ?? '').toString(),
    );
  }
}

class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialAddress;

  const MapPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialAddress,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final _mapController = MapController();
  final _searchCtr = TextEditingController();
  final _searchFocus = FocusNode();

  LatLng _center = const LatLng(6.5244, 3.3792);
  String _address = '';
  String _primaryName = '';
  String _secondaryAddr = '';
  String _selectedPlaceId = '';
  bool _geocoding = false;
  bool _pinLifted = false;

  List<_Suggestion> _suggestions = [];
  bool _searching = false;
  Timer? _geoDebounce;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _address = formatCleanAddress(widget.initialAddress!);
      final parts = _address.split(',');
      _primaryName = parts.first.trim();
      _secondaryAddr =
          parts.length > 1 ? parts.sublist(1).join(',').trim() : '';
    }
    if (widget.initialLat != null && widget.initialLng != null) {
      _center = LatLng(widget.initialLat!, widget.initialLng!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_address.isEmpty) _geocodeCenter();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _goToCurrentLocation();
      });
    }
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
        (p) async =>
            p ??
            await Geolocator.getCurrentPosition(
              locationSettings:
                  const LocationSettings(accuracy: LocationAccuracy.medium),
            ).timeout(const Duration(seconds: 10)),
      ));

      if (!mounted) return;
      final c = LatLng(pos.latitude, pos.longitude);
      setState(() => _center = c);
      _mapController.move(c, 16);
      _geocodeCenter();
    } catch (_) {}
  }

  void _onPositionChanged(MapPosition position, bool hasGesture) {
    if (!hasGesture || position.center == null) return;
    _center = position.center!;
    _selectedPlaceId = ''; // Reset placeId on manual drag
    setState(() => _pinLifted = true);
    _geoDebounce?.cancel();
    _geoDebounce = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _pinLifted = false);
      _geocodeCenter();
    });
  }

  Future<void> _geocodeCenter() async {
    setState(() => _geocoding = true);
    try {
      final geo = await RideApi.instance.reverseGeocodeClean(
        lat: _center.latitude.toStringAsFixed(6),
        long: _center.longitude.toStringAsFixed(6),
      );
      if (mounted) {
        final formatted = geo.formattedAddress;
        if (formatted.isNotEmpty) {
          setState(() {
            _address = formatted;
            _primaryName = geo.primaryName;
            _secondaryAddr = geo.secondaryAddr;
          });
        }
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
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final data =
            await ApiClient.instance.post({'theKey': 'RR1', 'Address': val});
        final raw = data['predictions'];
        if (raw is List && mounted) {
          setState(() {
            _suggestions = raw
                .take(6)
                .map((e) => _Suggestion.fromApi(e as Map<String, dynamic>))
                .where((s) => s.fullAddress.isNotEmpty)
                .toList();
          });
        }
      } catch (_) {}
    });
  }

  Future<void> _selectSuggestion(_Suggestion s) async {
    FocusScope.of(context).unfocus();
    _searchCtr.clear();
    final cleanAddr = formatCleanAddress(s.fullAddress);
    setState(() {
      _suggestions = [];
      _searching = false;
      _primaryName = s.primaryName;
      _secondaryAddr = s.secondaryAddr;
      _address = cleanAddr;
      _selectedPlaceId = s.placeId;
    });

    // Move map to selected place coordinates without overriding clean place name
    if (s.placeId.isNotEmpty) {
      try {
        final detail =
            await RideApi.instance.getPlaceDetailClean(s.placeId);
        if (detail.latitude != null && detail.longitude != null && mounted) {
          final c = LatLng(detail.latitude!, detail.longitude!);
          setState(() => _center = c);
          _mapController.move(c, 16);
          // Do NOT call _geocodeCenter() to avoid replacing the user's selected landmark
        }
      } catch (_) {}
    }
  }

  void _confirm() {
    if (_address.isEmpty) return;
    context.pop({
      'address': formatCleanAddress(_address),
      'primaryName': _primaryName.isNotEmpty
          ? _primaryName
          : _address.split(',').first.trim(),
      'secondaryAddr': _secondaryAddr,
      'lat': _center.latitude,
      'lng': _center.longitude,
      'placeId': _selectedPlaceId,
    });
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    final showSuggestions = _suggestions.isNotEmpty && _searching;

    final displayTitle = _primaryName.isNotEmpty
        ? _primaryName
        : (_address.isNotEmpty ? _address.split(',').first.trim() : '');
    final displaySubtitle = _secondaryAddr.isNotEmpty
        ? _secondaryAddr
        : (_address.contains(',')
            ? _address.substring(_address.indexOf(',') + 1).trim()
            : '');

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── Map (CartoDB Positron / OSM) ───────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 16,
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
                        Matrix4.translationValues(0, _pinLifted ? -12 : 0, 0),
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
                    width: _pinLifted ? 12 : 7,
                    height: _pinLifted ? 3 : 5,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 24), // Center icon anchor offset
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
                      // Back button
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
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.arrow_back_rounded,
                              color: SRColors.ink900, size: 20),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Search input
                      Expanded(
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              const Icon(Icons.search_rounded,
                                  color: SRColors.purple700, size: 20),
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
                                    hintText: 'Search place or street…',
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
                                        size: 18, color: SRColors.ink500),
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
                    padding: const EdgeInsets.fromLTRB(66, 0, 14, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 16,
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
                          return InkWell(
                            onTap: () => _selectSuggestion(s),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on_rounded,
                                      size: 20, color: SRColors.purple700),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.primaryName,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: SRColors.ink900,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (s.secondaryAddr.isNotEmpty)
                                          Text(
                                            s.secondaryAddr,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: SRColors.ink500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
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

          // ── Map controls (zoom & current location) ────────────────────────
          Positioned(
            bottom: bottom + 180,
            right: 14,
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(_center, zoom + 1);
                  },
                  child: Container(
                    width: 42,
                    height: 42,
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
                    child: const Icon(Icons.add_rounded,
                        color: SRColors.ink900, size: 22),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(_center, zoom - 1);
                  },
                  child: Container(
                    width: 42,
                    height: 42,
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
                    child: const Icon(Icons.remove_rounded,
                        color: SRColors.ink900, size: 22),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _goToCurrentLocation,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: SRColors.purple700.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.my_location_rounded,
                        color: SRColors.purple700, size: 24),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom Sheet: Address display + Confirm ──────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(18, 14, 18, bottom + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle indicator
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: SRColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Address info row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: SRColors.purple100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.location_on_rounded,
                            color: SRColors.purple700, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _geocoding
                            ? const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: SRColors.purple700,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Finding address details…',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: SRColors.ink500),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayTitle.isNotEmpty
                                        ? displayTitle
                                        : 'Move map to pick location',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: displayTitle.isNotEmpty
                                          ? SRColors.ink900
                                          : SRColors.ink500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (displaySubtitle.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      displaySubtitle,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: SRColors.ink500,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Confirm button
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
                        boxShadow: (_geocoding || _address.isEmpty)
                            ? null
                            : [
                                BoxShadow(
                                  color: SRColors.purple700
                                      .withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Center(
                        child: Text(
                          'Confirm this location',
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
