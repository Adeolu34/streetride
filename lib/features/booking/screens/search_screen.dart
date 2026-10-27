import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/ride_api.dart';
import '../../../core/models/location_models.dart';
import '../../../core/services/recent_places_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/sr_text_field.dart';

class _PlaceSuggestion {
  final String primaryName;
  final String secondaryAddr;
  final String placeId;
  final String fullAddress;
  final double? lat;
  final double? lng;
  final bool isRecent;

  const _PlaceSuggestion({
    required this.primaryName,
    required this.secondaryAddr,
    required this.placeId,
    required this.fullAddress,
    this.lat,
    this.lng,
    this.isRecent = false,
  });

  factory _PlaceSuggestion.fromApi(Map<String, dynamic> e) {
    final full = formatCleanAddress((e['Address'] ?? e['description'] ?? '').toString());
    final commaIdx = full.indexOf(',');
    final primary = commaIdx > 0 ? full.substring(0, commaIdx).trim() : full;
    final secondary = commaIdx > 0 ? full.substring(commaIdx + 1).trim() : '';
    return _PlaceSuggestion(
      primaryName: primary,
      secondaryAddr: secondary,
      placeId: (e['PlaceId'] ?? '').toString(),
      fullAddress: full,
    );
  }

  factory _PlaceSuggestion.fromRecent(RecentPlace r) => _PlaceSuggestion(
        primaryName: r.primaryName,
        secondaryAddr: r.secondaryAddr,
        placeId: r.placeId,
        fullAddress: r.fullAddress,
        lat: r.lat,
        lng: r.lng,
        isRecent: true,
      );
}

enum _Field { pickup, destination }

class SearchScreen extends ConsumerStatefulWidget {
  final String? initialFrom;
  final String? initialTo;
  final double? initialFromLat;
  final double? initialFromLng;
  final double? initialToLat;
  final double? initialToLng;

  const SearchScreen({
    super.key,
    this.initialFrom,
    this.initialTo,
    this.initialFromLat,
    this.initialFromLng,
    this.initialToLat,
    this.initialToLng,
  });

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _pickupCtr = TextEditingController();
  final _destCtr = TextEditingController();
  final _pickupFocus = FocusNode();
  final _destFocus = FocusNode();

  _Field _activeField = _Field.destination;
  List<_PlaceSuggestion> _suggestions = [];
  List<RecentPlace> _recentPlaces = [];
  Timer? _debounce;
  bool _loading = false;

  String _pickupPlaceId = '';
  String _destPlaceId = '';
  double? _pickupLat;
  double? _pickupLng;
  double? _destLat;
  double? _destLng;
  bool _locating = false;

  static const _quickPlaces = [
    (name: 'Palms Shopping Mall', address: 'Bisway St, Lekki', lat: 6.4357, lng: 3.4414),
    (name: 'Murtala Muhammed Airport', address: 'Ikeja, Lagos', lat: 6.57025, lng: 3.32142),
    (name: 'Oshodi Bus Terminal', address: 'Oshodi, Lagos', lat: 6.5492, lng: 3.3556),
    (name: 'Victoria Island', address: 'Lagos Island, Lagos', lat: 6.4281, lng: 3.4219),
  ];

  @override
  void initState() {
    super.initState();
    _pickupLat = widget.initialFromLat;
    _pickupLng = widget.initialFromLng;
    _destLat = widget.initialToLat;
    _destLng = widget.initialToLng;
    _pickupCtr.text = widget.initialFrom ?? 'Current location';
    if (widget.initialTo != null) _destCtr.text = widget.initialTo!;
    _pickupFocus.addListener(_onFocusChange);
    _destFocus.addListener(_onFocusChange);

    // If pickup is uninitialized, quietly geocode user location
    if (widget.initialFrom == null || widget.initialFrom == 'Current location' || _pickupLat == null) {
      _resolveCurrentLocationQuietly();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialTo != null && widget.initialFrom != null) {
        // Both pre-filled — go straight to select drivers
        _tryConfirm();
      } else {
        _destFocus.requestFocus();
        setState(() => _activeField = _Field.destination);
      }
    });
    _loadRecents();
  }

  Future<void> _resolveCurrentLocationQuietly() async {
    try {
      Position? pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 4));
      if (mounted) {
        _pickupLat = pos.latitude;
        _pickupLng = pos.longitude;
        final geo = await RideApi.instance.reverseGeocodeClean(
          lat: pos.latitude.toStringAsFixed(6),
          long: pos.longitude.toStringAsFixed(6),
        );
        if (mounted && geo.formattedAddress.isNotEmpty) {
          if (_pickupCtr.text == 'Current location' || _pickupCtr.text.isEmpty) {
            setState(() {
              _pickupCtr.text = geo.formattedAddress;
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadRecents() async {
    final recent = await RecentPlacesService.load();
    if (mounted) setState(() => _recentPlaces = recent);
  }

  void _onFocusChange() {
    if (_pickupFocus.hasFocus) setState(() => _activeField = _Field.pickup);
    if (_destFocus.hasFocus) setState(() => _activeField = _Field.destination);
  }

  void _onChanged(String val) {
    _debounce?.cancel();
    if (_activeField == _Field.pickup) _pickupPlaceId = '';
    if (_activeField == _Field.destination) _destPlaceId = '';

    if (val.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    // Show local recent matches immediately
    _showLocalMatches(val);
    // Then debounce API call
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(val));
  }

  void _showLocalMatches(String query) {
    final q = query.toLowerCase();
    final matches = _recentPlaces
        .where((p) =>
            p.fullAddress.toLowerCase().contains(q) ||
            p.primaryName.toLowerCase().contains(q))
        .take(4)
        .map((p) => _PlaceSuggestion.fromRecent(p))
        .toList();
    if (mounted && matches.isNotEmpty) {
      setState(() => _suggestions = matches);
    }
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.instance
          .post({'theKey': 'RR1', 'Address': query});
      final raw = data['predictions'];
      if (raw is List && mounted) {
        final apiSuggestions = raw
            .take(6)
            .map((e) => _PlaceSuggestion.fromApi(e as Map<String, dynamic>))
            .where((s) => s.primaryName.isNotEmpty)
            .toList();

        // Merge: recent matches first, then API results (no duplicates)
        final recentMatches = _recentPlaces
            .where((p) {
              final q = query.toLowerCase();
              return p.fullAddress.toLowerCase().contains(q) ||
                  p.primaryName.toLowerCase().contains(q);
            })
            .take(3)
            .map((p) => _PlaceSuggestion.fromRecent(p))
            .toList();

        final recentAddresses =
            recentMatches.map((s) => s.fullAddress).toSet();
        final apiOnly = apiSuggestions
            .where((s) => !recentAddresses.contains(s.fullAddress))
            .toList();

        setState(() => _suggestions = [...recentMatches, ...apiOnly]);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectSuggestion(_PlaceSuggestion s) async {
    FocusScope.of(context).unfocus();
    final cleanAddr = formatCleanAddress(s.fullAddress);

    double? lat = s.lat;
    double? lng = s.lng;

    // Await place details if coordinates not present
    if ((lat == null || lng == null) && s.placeId.isNotEmpty) {
      try {
        final detail = await RideApi.instance.getPlaceDetailClean(s.placeId);
        lat = detail.latitude;
        lng = detail.longitude;
      } catch (_) {}
    }

    // Save to recents with resolved coordinates
    RecentPlacesService.save(RecentPlace(
      primaryName: s.primaryName,
      secondaryAddr: s.secondaryAddr,
      fullAddress: cleanAddr,
      placeId: s.placeId,
      lat: lat,
      lng: lng,
    ));

    if (_activeField == _Field.pickup) {
      _pickupCtr.text = cleanAddr;
      _pickupPlaceId = s.placeId;
      _pickupLat = lat;
      _pickupLng = lng;
      setState(() {
        _suggestions = [];
        _activeField = _Field.destination;
      });
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _destFocus.requestFocus();
      });
    } else {
      _destCtr.text = cleanAddr;
      _destPlaceId = s.placeId;
      _destLat = lat;
      _destLng = lng;
      setState(() => _suggestions = []);
      await _tryConfirm();
    }
    _loadRecents();
  }

  void _selectQuick(String name, String addr, double lat, double lng) {
    final clean = formatCleanAddress('$name, $addr');
    RecentPlacesService.save(RecentPlace(
      primaryName: name,
      secondaryAddr: addr,
      fullAddress: clean,
      lat: lat,
      lng: lng,
    ));
    if (_activeField == _Field.destination) {
      _destCtr.text = clean;
      _destPlaceId = '';
      _destLat = lat;
      _destLng = lng;
      setState(() => _suggestions = []);
      _tryConfirm();
    } else {
      _pickupCtr.text = clean;
      _pickupPlaceId = '';
      _pickupLat = lat;
      _pickupLng = lng;
      setState(() {
        _suggestions = [];
        _activeField = _Field.destination;
      });
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _destFocus.requestFocus();
      });
    }
    _loadRecents();
  }

  Future<void> _tryConfirm() async {
    final pickup = _pickupCtr.text.trim();
    final dest = _destCtr.text.trim();
    if (pickup.isEmpty || dest.isEmpty) return;
    FocusScope.of(context).unfocus();

    // 1. Resolve pickup coordinates if missing
    if (_pickupLat == null || _pickupLng == null) {
      try {
        final pos = await Geolocator.getLastKnownPosition();
        if (pos != null) {
          _pickupLat = pos.latitude;
          _pickupLng = pos.longitude;
        }
      } catch (_) {}
      if (_pickupLat == null && pickup != 'Current location') {
        final detail = await RideApi.instance.resolveAddress(pickup);
        if (detail?.lat != null && detail?.lng != null) {
          _pickupLat = detail!.lat;
          _pickupLng = detail.lng;
        }
      }
    }

    // 2. Resolve destination coordinates if missing
    if (_destLat == null || _destLng == null) {
      if (_destPlaceId.isNotEmpty) {
        try {
          final d = await RideApi.instance.getPlaceDetailClean(_destPlaceId);
          if (d.latitude != null && d.longitude != null) {
            _destLat = d.latitude;
            _destLng = d.longitude;
          }
        } catch (_) {}
      }
      if (_destLat == null || _destLng == null) {
        final resolved = await RideApi.instance.resolveAddress(dest);
        if (resolved?.lat != null && resolved?.lng != null) {
          _destLat = resolved!.lat;
          _destLng = resolved.lng;
          if (_destPlaceId.isEmpty && resolved.placeId.isNotEmpty) {
            _destPlaceId = resolved.placeId;
          }
        }
      }
    }

    if (!mounted) return;
    context.push('/select-drivers', extra: {
      'from': pickup,
      'to': dest,
      'fromPlaceId': _pickupPlaceId,
      'toPlaceId': _destPlaceId,
      'fromLat': _pickupLat,
      'fromLng': _pickupLng,
      'toLat': _destLat,
      'toLng': _destLng,
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() => _locating = false);
        return;
      }

      // Try last known position first (instant), fall back to fresh fix
      Position? pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 12));

      _pickupLat = pos.latitude;
      _pickupLng = pos.longitude;

      final geo = await RideApi.instance.reverseGeocodeClean(
        lat: pos.latitude.toStringAsFixed(6),
        long: pos.longitude.toStringAsFixed(6),
      );
      final addr = geo.formattedAddress.isNotEmpty
          ? geo.formattedAddress
          : 'Current location';

      if (mounted) {
        _pickupCtr.text = addr;
        _pickupPlaceId = '';
        setState(() {
          _suggestions = [];
          _activeField = _Field.destination;
          _locating = false;
        });
        _destFocus.requestFocus();
      }
    } catch (_) {
      if (mounted) {
        _pickupCtr.text = 'Current location';
        setState(() => _locating = false);
      }
    }
  }

  Future<void> _pickFromMap() async {
    // Pass last known position so map opens near the user
    double? lat, lng;
    try {
      final pos = await Geolocator.getLastKnownPosition();
      lat = pos?.latitude;
      lng = pos?.longitude;
    } catch (_) {}

    if (!mounted) return;
    final result = await context.push<Map<String, dynamic>>(
      '/map-picker',
      extra: {'initialLat': lat, 'initialLng': lng},
    );
    if (result == null || !mounted) return;

    final address = formatCleanAddress((result['address'] ?? '').toString());
    if (address.isEmpty) return;

    final rLat = (result['lat'] as num?)?.toDouble();
    final rLng = (result['lng'] as num?)?.toDouble();
    final rPlaceId = (result['placeId'] ?? '').toString();

    // Save to recent places
    final primary = (result['primaryName'] ?? address.split(',').first)
        .toString()
        .trim();
    final secondary = (result['secondaryAddr'] ??
            (address.contains(',')
                ? address.substring(address.indexOf(',') + 1).trim()
                : ''))
        .toString();

    RecentPlacesService.save(RecentPlace(
      primaryName: primary,
      secondaryAddr: secondary,
      fullAddress: address,
      placeId: rPlaceId,
      lat: rLat,
      lng: rLng,
    ));
    _loadRecents();

    if (_activeField == _Field.pickup) {
      _pickupCtr.text = address;
      _pickupPlaceId = rPlaceId;
      _pickupLat = rLat;
      _pickupLng = rLng;
      setState(() {
        _suggestions = [];
        _activeField = _Field.destination;
      });
      Future.delayed(const Duration(milliseconds: 80), () {
        if (mounted) _destFocus.requestFocus();
      });
    } else {
      _destCtr.text = address;
      _destPlaceId = rPlaceId;
      _destLat = rLat;
      _destLng = rLng;
      setState(() => _suggestions = []);
      _tryConfirm();
    }
  }

  bool get _canConfirm =>
      _pickupCtr.text.trim().isNotEmpty && _destCtr.text.trim().isNotEmpty;

  @override
  void dispose() {
    _debounce?.cancel();
    _pickupCtr.dispose();
    _destCtr.dispose();
    _pickupFocus.dispose();
    _destFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentText = _activeField == _Field.pickup
        ? _pickupCtr.text
        : _destCtr.text;
    final isTyping = currentText.trim().length >= 2;
    final showSuggestions = _suggestions.isNotEmpty && isTyping;
    final showRecent = !isTyping && _recentPlaces.isNotEmpty;
    final showQuick = true; // always show below recents/suggestions

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const Divider(height: 1, color: SRColors.border),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(top: 4, bottom: 24),
                children: [
                  if (_loading && !showSuggestions)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: SRColors.purple700),
                      ),
                    )
                  else ...[
                    // Recent places
                    if (showSuggestions) ...[
                      _SectionHeader('Suggestions'),
                      ..._suggestions.map((s) => _SuggestionRow(
                            suggestion: s,
                            onTap: () => _selectSuggestion(s),
                          )),
                    ] else if (showRecent) ...[
                      _SectionHeader('Recent'),
                      ..._recentPlaces.take(6).map((r) {
                        final s = _PlaceSuggestion.fromRecent(r);
                        return _SuggestionRow(
                          suggestion: s,
                          onTap: () => _selectSuggestion(s),
                        );
                      }),
                    ],

                    // Quick / popular places
                    if (showQuick && !showSuggestions) ...[
                      _SectionHeader(
                        _activeField == _Field.pickup
                            ? 'Choose pickup'
                            : 'Popular destinations',
                      ),
                      // Use current location — always visible, always sets pickup
                      _LocationRow(
                        icon: Icons.my_location_rounded,
                        label: _locating ? 'Getting location…' : 'Use current location',
                        color: SRColors.purple700,
                        loading: _locating,
                        onTap: _locating ? () {} : _useCurrentLocation,
                      ),
                      // Pick from map — always visible, sets whichever field is active
                      _LocationRow(
                        icon: Icons.map_rounded,
                        label: 'Pick from map',
                        color: SRColors.purple700,
                        onTap: _pickFromMap,
                      ),
                      ..._quickPlaces.map((p) => _LocationRow(
                            icon: Icons.location_on_rounded,
                            label: p.name,
                            subtitle: p.address,
                            onTap: () => _selectQuick(p.name, p.address, p.lat, p.lng),
                          )),
                    ],
                  ],
                ],
              ),
            ),
            if (_canConfirm)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                child: GestureDetector(
                  onTap: _tryConfirm,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: SRColors.gradWallet,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Center(
                      child: Text(
                        'Find drivers',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: SRColors.lavenderBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: SRColors.ink900),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Plan your trip',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: SRColors.ink900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SRTextField(
            controller: _pickupCtr,
            hint: 'Pickup location',
            focusNode: _pickupFocus,
            onChanged: _onChanged,
            onTap: () {
              setState(() {
                _activeField = _Field.pickup;
                _suggestions = [];
              });
              if (_pickupCtr.text == 'Current location') {
                _pickupCtr.clear();
              }
            },
            prefix: const Icon(Icons.radio_button_checked_rounded,
                color: SRColors.purple700, size: 20),
            suffix: _pickupCtr.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _pickupCtr.clear();
                      _pickupPlaceId = '';
                      setState(() => _suggestions = []);
                      _pickupFocus.requestFocus();
                    },
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: SRColors.ink500),
                  )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Container(
              width: 1.5,
              height: 10,
              color: SRColors.border,
            ),
          ),
          SRTextField(
            controller: _destCtr,
            hint: 'Where to?',
            focusNode: _destFocus,
            onChanged: _onChanged,
            onTap: () => setState(() {
              _activeField = _Field.destination;
              _suggestions = [];
            }),
            prefix: const Icon(Icons.location_on_rounded,
                color: SRColors.ink500, size: 20),
            suffix: _destCtr.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _destCtr.clear();
                      _destPlaceId = '';
                      setState(() => _suggestions = []);
                      _destFocus.requestFocus();
                    },
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: SRColors.ink500),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: SRColors.ink500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}


// ─── Suggestion row ───────────────────────────────────────────────────────────

class _SuggestionRow extends StatelessWidget {
  final _PlaceSuggestion suggestion;
  final VoidCallback onTap;
  const _SuggestionRow({required this.suggestion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: suggestion.isRecent
                    ? SRColors.lavenderBg
                    : SRColors.lavenderBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                suggestion.isRecent
                    ? Icons.history_rounded
                    : Icons.location_on_rounded,
                color: suggestion.isRecent
                    ? SRColors.ink500
                    : SRColors.purple700,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.primaryName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: SRColors.ink900,
                    ),
                  ),
                  if (suggestion.secondaryAddr.isNotEmpty)
                    Text(
                      suggestion.secondaryAddr,
                      style:
                          const TextStyle(fontSize: 12, color: SRColors.ink500),
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
  }
}

// ─── Location row ─────────────────────────────────────────────────────────────

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color? color;
  final bool loading;
  final VoidCallback onTap;

  const _LocationRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle = '',
    this.color,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? SRColors.ink900;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color != null ? SRColors.purple100 : SRColors.lavenderBg,
                shape: BoxShape.circle,
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: SRColors.purple700),
                    )
                  : Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color ?? SRColors.ink900,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: SRColors.ink500),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
