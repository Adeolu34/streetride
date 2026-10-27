import 'dart:math';
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

class RouteStep {
  final String instruction;
  final String maneuver; // 'turn-right', 'turn-left', 'straight', 'uturn', etc.
  final String modifier; // 'right', 'left', 'slight right', etc.
  final String roadName;
  final double distanceMeters;
  final int durationSeconds;
  final LatLng location;

  const RouteStep({
    required this.instruction,
    required this.maneuver,
    this.modifier = '',
    required this.roadName,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.location,
  });

  String get distanceLabel => distanceMeters < 1000
      ? '${distanceMeters.round()} m'
      : '${(distanceMeters / 1000).toStringAsFixed(1)} km';
}

class RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;
  final String summary;
  final List<RouteStep> steps;

  const RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    this.summary = '',
    this.steps = const [],
  });

  String get distanceLabel => distanceKm < 1.0
      ? '${(distanceKm * 1000).round()} m'
      : '${distanceKm.toStringAsFixed(1)} km';

  String get durationLabel {
    if (durationMinutes < 1) return '1 min';
    if (durationMinutes < 60) return '$durationMinutes min';
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }
}

class RouteService {
  RouteService._();
  static final RouteService instance = RouteService._();

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// Optional Google Directions API key. When provided and non-empty,
  /// Google Directions API will be prioritized.
  String? googleApiKey;

  /// Fetches a real road driving route between [origin] and [destination].
  Future<RouteResult> getDrivingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    // 1. Try Google Directions API if key configured
    if (googleApiKey != null && googleApiKey!.isNotEmpty) {
      try {
        final googleRes = await _fetchGoogleDirections(origin, destination);
        if (googleRes != null && googleRes.points.isNotEmpty) {
          return googleRes;
        }
      } catch (_) {}
    }

    // 2. Query high-performance OSRM road routing engine
    try {
      final osrmRes = await _fetchOsrmRoute(origin, destination);
      if (osrmRes != null && osrmRes.points.isNotEmpty) {
        return osrmRes;
      }
    } catch (_) {}

    // 3. Fallback: Straight-line interpolation with realistic road factor
    return _fallbackRoute(origin, destination);
  }

  /// Generates a realistic road fallback interpolation route
  RouteResult getInterpolatedFallback({required LatLng from, required LatLng to}) =>
      _fallbackRoute(from, to);

  Future<RouteResult?> _fetchOsrmRoute(LatLng origin, LatLng destination) async {
    final url =
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude.toStringAsFixed(5)},${origin.latitude.toStringAsFixed(5)};'
        '${destination.longitude.toStringAsFixed(5)},${destination.latitude.toStringAsFixed(5)}'
        '?overview=full&geometries=geojson&steps=true';

    final res = await _dio.get(url);
    if (res.statusCode == 200 && res.data is Map) {
      final data = res.data as Map<String, dynamic>;
      if (data['code'] == 'Ok' && data['routes'] is List && (data['routes'] as List).isNotEmpty) {
        final route = (data['routes'] as List).first as Map<String, dynamic>;
        final geometry = route['geometry'] as Map<String, dynamic>?;
        final coords = geometry?['coordinates'] as List?;
        if (coords != null && coords.isNotEmpty) {
          final points = coords.map<LatLng>((c) {
            final lng = (c[0] as num).toDouble();
            final lat = (c[1] as num).toDouble();
            return LatLng(lat, lng);
          }).toList();

          final distanceM = (route['distance'] as num?)?.toDouble() ?? 0.0;
          final durationS = (route['duration'] as num?)?.toDouble() ?? 0.0;
          final distKm = distanceM / 1000.0;
          // In Lagos / Nigerian traffic, road duration is often higher than base free-flow speed
          final durationMin = max(1, (durationS / 60.0).round());

          // Parse navigation steps
          final steps = <RouteStep>[];
          final legs = route['legs'] as List?;
          if (legs != null && legs.isNotEmpty) {
            final rawSteps = legs[0]['steps'] as List?;
            if (rawSteps != null) {
              for (final s in rawSteps) {
                if (s is! Map) continue;
                final m = s['maneuver'] as Map<String, dynamic>?;
                final type = (m?['type'] ?? 'turn').toString();
                final modifier = (m?['modifier'] ?? '').toString();
                final loc = m?['location'] as List?;
                final stepLat = loc != null && loc.length >= 2 ? (loc[1] as num).toDouble() : 0.0;
                final stepLng = loc != null && loc.length >= 2 ? (loc[0] as num).toDouble() : 0.0;
                final name = (s['name'] ?? '').toString();
                final dist = (s['distance'] as num?)?.toDouble() ?? 0.0;
                final dur = (s['duration'] as num?)?.toInt() ?? 0;

                String instruction;
                if (type == 'depart') {
                  instruction = name.isNotEmpty ? 'Head on $name' : 'Head towards destination';
                } else if (type == 'arrive') {
                  instruction = 'Arrive at destination';
                } else {
                  final action = modifier.isNotEmpty ? 'Turn ${modifier.replaceAll('sharp ', '').replaceAll('slight ', '')}' : 'Continue';
                  instruction = name.isNotEmpty ? '$action onto $name' : action;
                }

                steps.add(RouteStep(
                  instruction: instruction,
                  maneuver: type,
                  modifier: modifier,
                  roadName: name,
                  distanceMeters: dist,
                  durationSeconds: dur,
                  location: LatLng(stepLat, stepLng),
                ));
              }
            }
          }

          return RouteResult(
            points: points,
            distanceKm: distKm,
            durationMinutes: durationMin,
            summary: (legs != null && legs.isNotEmpty)
                ? (legs[0]['summary'] ?? '').toString()
                : '',
            steps: steps,
          );
        }
      }
    }
    return null;
  }

  Future<RouteResult?> _fetchGoogleDirections(LatLng origin, LatLng destination) async {
    final url =
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=driving&key=$googleApiKey';

    final res = await _dio.get(url);
    if (res.statusCode == 200 && res.data is Map) {
      final data = res.data as Map<String, dynamic>;
      if (data['status'] == 'OK' && data['routes'] is List && (data['routes'] as List).isNotEmpty) {
        final route = data['routes'][0] as Map<String, dynamic>;
        final overview = route['overview_polyline'] as Map<String, dynamic>?;
        final encoded = overview?['points'] as String?;
        if (encoded != null && encoded.isNotEmpty) {
          final points = _decodePolyline(encoded);
          final legs = route['legs'] as List?;
          final leg = (legs != null && legs.isNotEmpty) ? legs[0] as Map<String, dynamic>? : null;
          final distM = (leg?['distance']?['value'] as num?)?.toDouble() ?? 0.0;
          final durS = (leg?['duration']?['value'] as num?)?.toDouble() ?? 0.0;

          final steps = <RouteStep>[];
          final rawSteps = leg?['steps'] as List?;
          if (rawSteps != null) {
            for (final s in rawSteps) {
              if (s is! Map) continue;
              final html = (s['html_instructions'] ?? '').toString().replaceAll(RegExp(r'<[^>]*>'), ' ');
              final man = (s['maneuver'] ?? 'turn').toString();
              final endLoc = s['end_location'] as Map<String, dynamic>?;
              final sLat = (endLoc?['lat'] as num?)?.toDouble() ?? 0.0;
              final sLng = (endLoc?['lng'] as num?)?.toDouble() ?? 0.0;
              final sDist = (s['distance']?['value'] as num?)?.toDouble() ?? 0.0;
              final sDur = (s['duration']?['value'] as num?)?.toInt() ?? 0;
              steps.add(RouteStep(
                instruction: html.trim(),
                maneuver: man,
                roadName: '',
                distanceMeters: sDist,
                durationSeconds: sDur,
                location: LatLng(sLat, sLng),
              ));
            }
          }

          return RouteResult(
            points: points,
            distanceKm: distM / 1000.0,
            durationMinutes: max(1, (durS / 60.0).round()),
            summary: route['summary']?.toString() ?? '',
            steps: steps,
          );
        }
      }
    }
    return null;
  }

  /// Google encoded polyline decoder
  List<LatLng> _decodePolyline(String encoded) {
    final poly = <LatLng>[];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return poly;
  }

  /// Fallback when offline or services unreachable: generates a multi-segment line
  /// with a 1.25 road winding factor
  RouteResult _fallbackRoute(LatLng origin, LatLng destination) {
    const r = 6371.0;
    final dLat = (destination.latitude - origin.latitude) * pi / 180;
    final dLon = (destination.longitude - origin.longitude) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(origin.latitude * pi / 180) *
            cos(destination.latitude * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final straightKm = r * 2 * atan2(sqrt(a), sqrt(1 - a));

    // Road winding factor: 1.25x straight line
    final roadKm = straightKm * 1.25;
    // Estimate 25 km/h in city traffic
    final minutes = max(1, (roadKm / 25.0 * 60).round());

    // Generate 5 intermediate interpolated points
    final pts = <LatLng>[origin];
    for (var i = 1; i <= 4; i++) {
      final fraction = i / 5.0;
      pts.add(LatLng(
        origin.latitude + (destination.latitude - origin.latitude) * fraction,
        origin.longitude + (destination.longitude - origin.longitude) * fraction,
      ));
    }
    pts.add(destination);

    final steps = <RouteStep>[
      RouteStep(
        instruction: 'Head towards destination',
        maneuver: 'depart',
        modifier: 'straight',
        roadName: 'Main Road',
        distanceMeters: roadKm * 1000 * 0.7,
        durationSeconds: (minutes * 60 * 0.7).round(),
        location: origin,
      ),
      RouteStep(
        instruction: 'Arrive at destination',
        maneuver: 'arrive',
        modifier: '',
        roadName: '',
        distanceMeters: roadKm * 1000 * 0.3,
        durationSeconds: (minutes * 60 * 0.3).round(),
        location: destination,
      ),
    ];

    return RouteResult(
      points: pts,
      distanceKm: roadKm,
      durationMinutes: minutes,
      summary: 'Estimated route',
      steps: steps,
    );
  }
}
