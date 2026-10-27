import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/api/ride_api.dart';
import '../../../core/models/location_models.dart';
import '../../../core/services/route_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/sr_button.dart';
import '../../../shared/widgets/driver_avatar.dart';

class _Driver {
  final String phone;
  final String initials;
  final String name;
  final double rating;
  final int trips;
  final String car;
  final String distKm;
  final String minutesAway;
  final String status;
  String? photoUrl;
  bool selected;

  _Driver({
    required this.phone,
    required this.initials,
    required this.name,
    required this.rating,
    required this.trips,
    required this.car,
    required this.distKm,
    required this.minutesAway,
    required this.status,
    this.photoUrl,
  }) : selected = true;

  factory _Driver.fromJson(Map<String, dynamic> j) {
    final first = (j['firstname'] ?? j['FirstName'] ?? j['Name'] ?? '').toString().trim();
    final surname = (j['surname'] ?? j['Surname'] ?? '').toString().trim();
    final fullName = [first, surname].where((s) => s.isNotEmpty).join(' ');
    final displayName = fullName.isNotEmpty ? fullName : 'Driver';
    final parts = displayName.split(' ').where((p) => p.isNotEmpty).toList();
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : parts[0][0].toUpperCase();

    final rating = (j['avg_rating'] as num? ?? 0).toDouble();
    final trips = (j['total_rides'] as num? ?? 0).toInt();
    final phone = (j['phone'] ?? j['Phone'] ?? '').toString();
    final status = (j['status'] ?? '').toString();

    // Car description from available fields
    final vtype = (j['vtype'] ?? j['VType'] ?? '').toString().trim();
    final vmake = (j['vmake'] ?? '').toString().trim();
    final vmodel = (j['vmodel'] ?? '').toString().trim();
    final carParts = [vmake, vmodel].where((s) => s.isNotEmpty).join(' ');
    final car = carParts.isNotEmpty ? carParts : (vtype.isNotEmpty ? vtype : 'Saloon');

    // API provides distance directly — no local calculation needed
    final distKm = (j['distance_km'] as num? ?? 0) > 0
        ? '${(j['distance_km'] as num).toStringAsFixed(1)} km'
        : '—';
    final minutesAway = (j['minutes_away'] ?? '').toString();

    final photoUrl = (j['image'] ?? j['Image'] ?? j['Photo'] ?? '').toString();

    return _Driver(
      phone: phone,
      initials: initials,
      name: displayName,
      rating: rating,
      trips: trips,
      car: car,
      distKm: distKm,
      minutesAway: minutesAway,
      status: status,
      photoUrl: photoUrl.isNotEmpty ? photoUrl : null,
    );
  }
}

class SelectDriversScreen extends ConsumerStatefulWidget {
  final String from;
  final String to;
  final String fromPlaceId;
  final String toPlaceId;
  final double? fromLat;
  final double? fromLng;
  final double? toLat;
  final double? toLng;

  const SelectDriversScreen({
    super.key,
    required this.from,
    required this.to,
    this.fromPlaceId = '',
    this.toPlaceId = '',
    this.fromLat,
    this.fromLng,
    this.toLat,
    this.toLng,
  });

  @override
  ConsumerState<SelectDriversScreen> createState() => _SelectDriversScreenState();
}

class _SelectDriversScreenState extends ConsumerState<SelectDriversScreen> {
  bool _askAll = true;
  List<_Driver> _drivers = [];
  bool _loading = true;
  String? _error;
  Position? _position;
  bool _cashPayment = false;
  String? _fareEstimate;
  double? _destLat;
  double? _destLng;
  String _routeKm = '0';
  String _routeEta = '0';

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() { _loading = true; _error = null; });
    try {
      Position? pos;
      if (widget.fromLat != null && widget.fromLng != null) {
        pos = Position(
          latitude: widget.fromLat!,
          longitude: widget.fromLng!,
          timestamp: DateTime.now(),
          accuracy: 10,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
        _position = pos;
      } else {
        try {
          pos = await Geolocator.getLastKnownPosition();
          if (pos != null) _position = pos;
        } catch (_) {}
      }

      final lat = widget.fromLat?.toString() ?? pos?.latitude.toString() ?? '6.5244';
      final long = widget.fromLng?.toString() ?? pos?.longitude.toString() ?? '3.3792';

      final data = await RideApi.instance.getNearbyDrivers(lat: lat, long: long);
      final rawUsers = data['Users'];

      final list = <_Driver>[];
      if (rawUsers is List) {
        for (final u in rawUsers) {
          if (u is Map<String, dynamic> && u['isDriver'] == true) {
            list.add(_Driver.fromJson(u));
          }
        }
      }

      setState(() { _drivers = list; _loading = false; });
      _estimateFare(pos);
      _loadDriverImages(list);
    } catch (e) {
      setState(() { _error = 'Could not load nearby drivers.'; _loading = false; });
    }
  }

  Future<void> _loadDriverImages(List<_Driver> drivers) async {
    final futures = drivers
        .where((d) => d.phone.isNotEmpty && d.photoUrl == null)
        .map((d) async {
      try {
        final data = await RideApi.instance.getUserDetail(d.phone);
        final profile = data['Data'] as Map<String, dynamic>?;
        if (profile == null) return;
        final url = (profile['Image'] ?? profile['Photo'] ?? '').toString();
        if (url.isNotEmpty && mounted) {
          setState(() => d.photoUrl = url);
        }
      } catch (_) {}
    });
    await Future.wait(futures);
  }

  Future<void> _estimateFare(Position? pickup) async {
    try {
      double? destLat = widget.toLat;
      double? destLng = widget.toLng;

      // If dest coordinates not provided directly, fetch from placeId
      if ((destLat == null || destLng == null) && widget.toPlaceId.isNotEmpty) {
        final detail = await RideApi.instance.getPlaceDetailClean(widget.toPlaceId);
        destLat = detail.latitude;
        destLng = detail.longitude;
      }

      // If still missing, resolve from address text
      if ((destLat == null || destLng == null) && widget.to.isNotEmpty) {
        final resolved = await RideApi.instance.resolveAddress(widget.to);
        if (resolved?.lat != null && resolved?.lng != null) {
          destLat = resolved!.lat;
          destLng = resolved.lng;
        }
      }

      if (destLat == null || destLng == null) return;
      _destLat = destLat;
      _destLng = destLng;

      final originLat = widget.fromLat ?? pickup?.latitude ?? 6.5244;
      final originLng = widget.fromLng ?? pickup?.longitude ?? 3.3792;

      // Query real road driving route with OSRM
      final route = await RouteService.instance.getDrivingRoute(
        origin: LatLng(originLat, originLng),
        destination: LatLng(destLat, destLng),
      );

      final km = route.distanceKm;
      _routeKm = km.toStringAsFixed(1);
      _routeEta = '${route.durationMinutes} min';

      // Realistic Nigerian pricing: base fare ₦800 + ₦180–₦320 per km
      final low = (800 + km * 180).round();
      final high = (1200 + km * 320).round();

      if (mounted) {
        setState(() => _fareEstimate =
            '₦${_fmt(low)} – ₦${_fmt(high)} · ${route.distanceLabel} (~${route.durationLabel})');
      }
    } catch (_) {}
  }

  static String _fmt(int n) =>
      n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  int get _selectedCount => _drivers.where((d) => d.selected).length;

  Future<void> _requestPrices() async {
    final session = SessionService.instance;
    final riderPhone = session.profile?.phone ?? '';
    final lat = widget.fromLat?.toString() ?? _position?.latitude.toString() ?? '6.5244';
    final long = widget.fromLng?.toString() ?? _position?.longitude.toString() ?? '3.3792';

    // Ensure destination coordinates are resolved before sending BK1
    double? destLat = _destLat ?? widget.toLat;
    double? destLng = _destLng ?? widget.toLng;
    if ((destLat == null || destLng == null || destLat == 0.0) && widget.toPlaceId.isNotEmpty) {
      try {
        final detail = await RideApi.instance.getPlaceDetailClean(widget.toPlaceId);
        destLat = detail.latitude;
        destLng = detail.longitude;
      } catch (_) {}
    }
    if ((destLat == null || destLng == null || destLat == 0.0) && widget.to.isNotEmpty) {
      try {
        final resolved = await RideApi.instance.resolveAddress(widget.to);
        if (resolved?.lat != null && resolved?.lng != null) {
          destLat = resolved!.lat;
          destLng = resolved.lng;
        }
      } catch (_) {}
    }

    final dLat = (destLat ?? 0.0).toString();
    final dLong = (destLng ?? 0.0).toString();

    final selected = _drivers.where((d) => d.selected && d.phone.isNotEmpty).toList();
    if (selected.isEmpty) return;

    final cleanFrom = formatCleanAddress(widget.from);
    final cleanTo = formatCleanAddress(widget.to);
    final displayFrom = cleanFrom.isNotEmpty ? cleanFrom : widget.from;
    final displayTo = cleanTo.isNotEmpty ? cleanTo : widget.to;

    // Book each selected driver (BK1) — fire in parallel with real coordinates & km & eta
    final futures = selected.map((d) => RideApi.instance.bookRide(
      riderPhone: riderPhone,
      driverPhone: d.phone,
      fromLat: lat,
      fromLong: long,
      toLat: dLat,
      toLong: dLong,
      fromText: displayFrom,
      toText: displayTo,
      km: _routeKm,
      eta: _routeEta,
    ).catchError((_) => <String, dynamic>{}));

    final results = await Future.wait(futures);

    // Capture reqIds so downstream screens only show THIS session's rides
    final reqIds = results
        .map((r) => (r['reqid'] ?? r['ReqId'] ?? r['ReqID'] ?? r['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();

    if (!mounted) return;
    context.push('/request-pending', extra: {
      'from': displayFrom,
      'to': displayTo,
      'selectedCount': selected.length,
      'reqIds': reqIds,
      'cashPayment': _cashPayment,
      'fromLat': double.tryParse(lat),
      'fromLng': double.tryParse(long),
      'toLat': destLat,
      'toLng': destLng,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: SRColors.ink900, size: 24),
                  ),
                  const SizedBox(width: 11),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Who should quote you?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: SRColors.ink900,
                        ),
                      ),
                      Text(
                        '${widget.from} → ${widget.to}',
                        style: const TextStyle(fontSize: 12, color: SRColors.ink500),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _loadDrivers,
                    child: const Icon(Icons.refresh_rounded,
                        color: SRColors.purple700, size: 22),
                  ),
                ],
              ),
            ),

            // Mode toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: SRColors.purple100,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  children: [
                    _Toggle(
                      label: 'Ask nearby',
                      active: _askAll,
                      onTap: () => setState(() => _askAll = true),
                    ),
                    _Toggle(
                      label: 'One driver',
                      active: !_askAll,
                      onTap: () => setState(() => _askAll = false),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Fare estimate
            if (_fareEstimate != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: SRColors.green100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_money_rounded,
                          color: SRColors.green600, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Est. $_fareEstimate based on distance',
                          style: const TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: SRColors.green600,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Payment method toggle
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Row(
                children: [
                  const Text('Pay with:',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: SRColors.ink700)),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => setState(() => _cashPayment = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: !_cashPayment ? SRColors.purple700 : Colors.white,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                            color: !_cashPayment ? SRColors.purple700 : SRColors.border),
                      ),
                      child: Row(children: [
                        Icon(Icons.account_balance_wallet_rounded,
                            size: 14,
                            color: !_cashPayment ? Colors.white : SRColors.ink500),
                        const SizedBox(width: 5),
                        Text('Wallet',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: !_cashPayment ? Colors.white : SRColors.ink500)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _cashPayment = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: _cashPayment ? SRColors.purple700 : Colors.white,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                            color: _cashPayment ? SRColors.purple700 : SRColors.border),
                      ),
                      child: Row(children: [
                        Icon(Icons.payments_rounded,
                            size: 14,
                            color: _cashPayment ? Colors.white : SRColors.ink500),
                        const SizedBox(width: 5),
                        Text('Cash',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _cashPayment ? Colors.white : SRColors.ink500)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),

            // Info banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: SRColors.amber100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.gavel_rounded, color: Color(0xFFB26A00), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No fixed fare. Drivers send their own price — you pick the one you like.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Color(0xFF7A4A00),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // List header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Nearby drivers',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SRColors.ink900),
                  ),
                  if (!_loading && _drivers.isNotEmpty)
                    Text(
                      '$_selectedCount selected',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SRColors.purple700),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Driver list
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: SRColors.purple700))
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, style: const TextStyle(color: SRColors.ink500)),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: _loadDrivers,
                                child: const Text('Try again',
                                    style: TextStyle(color: SRColors.purple700, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        )
                      : _drivers.isEmpty
                          ? const Center(
                              child: Text('No drivers nearby right now.',
                                  style: TextStyle(color: SRColors.ink500, fontSize: 14)),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              itemCount: _drivers.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final d = _drivers[i];
                                return _DriverCard(
                                  driver: d,
                                  onTap: () => setState(() => d.selected = !d.selected),
                                );
                              },
                            ),
            ),

            // CTA
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withValues(alpha: 0), Colors.white],
                ),
              ),
              child: SRButton(
                label: _selectedCount > 0
                    ? 'Request price from $_selectedCount driver${_selectedCount == 1 ? '' : 's'}'
                    : 'Select at least one driver',
                onTap: _selectedCount > 0 ? _requestPrices : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Toggle({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
            boxShadow: active
                ? [BoxShadow(color: SRColors.indigo900.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? SRColors.purple700 : SRColors.ink500,
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final _Driver driver;
  final VoidCallback onTap;

  const _DriverCard({required this.driver, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: driver.selected ? const Color(0xFFFAF4F9) : SRColors.surfaceAlt,
          border: Border.all(
            color: driver.selected ? SRColors.purple700 : Colors.transparent,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            DriverAvatar(
              initials: driver.initials,
              photoUrl: driver.photoUrl,
              size: 42,
              fontSize: 14,
              bgColor: driver.selected ? SRColors.purple700 : SRColors.border,
              textColor: driver.selected ? Colors.white : SRColors.ink700,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    driver.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: SRColors.ink900),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 12, color: SRColors.amber500),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          '${driver.rating > 0 ? driver.rating.toStringAsFixed(1) : '—'} · ${driver.trips} trips · ${driver.car}',
                          style: const TextStyle(fontSize: 11, color: SRColors.ink500),
                          overflow: TextOverflow.ellipsis,
                        ),
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
                  driver.distKm,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SRColors.ink900),
                ),
                if (driver.minutesAway.isNotEmpty && driver.minutesAway != '0')
                  Text(
                    '~${driver.minutesAway} min',
                    style: const TextStyle(fontSize: 10, color: SRColors.ink500),
                  ),
                const SizedBox(height: 4),
                Icon(
                  driver.selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: driver.selected ? SRColors.purple700 : SRColors.border,
                  size: 22,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
