/// Models for geocoding, place resolution, and address handling.

/// Cleans raw geocoded/autocomplete address strings by:
/// 1. Stripping trailing country (e.g. ", Nigeria")
/// 2. Removing postal codes (e.g. 100001)
/// 3. Cleaning curly braces / JSON artifacts
/// 4. Deduplicating identical adjacent segments (e.g. "Ikeja, Ikeja, Lagos")
String formatCleanAddress(String raw) {
  if (raw.isEmpty) return '';
  var s = raw.trim();
  if (s.startsWith('{') && s.endsWith('}')) {
    s = s.replaceAll(RegExp(r'[{}]'), '');
  }
  s = s.replaceAll(RegExp(r'^Label:\s*', caseSensitive: false), '');

  final parts = s
      .split(',')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  final cleaned = <String>[];
  for (final part in parts) {
    final lower = part.toLowerCase();
    if (lower == 'nigeria') continue;
    if (RegExp(r'^\d{4,}$').hasMatch(part)) continue;
    if (cleaned.isNotEmpty && cleaned.last.toLowerCase() == lower) continue;
    cleaned.add(part);
  }
  return cleaned.join(', ');
}

class GeocodedAddress {
  final String label;
  final String street;
  final String city;
  final String state;
  final String country;
  final double? latitude;
  final double? longitude;

  const GeocodedAddress({
    required this.label,
    this.street = '',
    this.city = '',
    this.state = '',
    this.country = '',
    this.latitude,
    this.longitude,
  });

  /// Primary landmark / street title (e.g. "Barbar Lagos" or "11 Eletu Ogabi St")
  String get primaryName {
    if (street.isNotEmpty) {
      if (label.isNotEmpty && !label.startsWith(street)) {
        final commaIdx = label.indexOf(',');
        if (commaIdx > 0) return formatCleanAddress(label.substring(0, commaIdx));
      }
      return formatCleanAddress(street);
    }
    if (label.isNotEmpty) {
      final commaIdx = label.indexOf(',');
      return commaIdx > 0
          ? formatCleanAddress(label.substring(0, commaIdx))
          : formatCleanAddress(label);
    }
    return 'Selected Location';
  }

  /// Secondary area/city subtitle (e.g. "Victoria Island, Lagos")
  String get secondaryAddr {
    final parts = <String>[];
    if (label.isNotEmpty) {
      final split = label.split(',').map((s) => s.trim()).toList();
      if (split.length > 1) {
        // Skip first part (primary name), keep area/city parts
        for (var i = 1; i < split.length; i++) {
          final p = split[i];
          final lower = p.toLowerCase();
          if (lower == 'nigeria') continue;
          if (RegExp(r'^\d{4,}$').hasMatch(p)) continue;
          if (parts.isNotEmpty && parts.last.toLowerCase() == lower) continue;
          if (!parts.contains(p)) parts.add(p);
        }
      }
    }
    if (parts.isEmpty) {
      if (city.isNotEmpty) parts.add(city);
      if (state.isNotEmpty && state.toLowerCase() != city.toLowerCase()) parts.add(state);
    }
    return parts.join(', ');
  }

  /// Full clean address without technical artifacts (e.g. "Barbar Lagos, Victoria Arobieke St, Lagos")
  String get formattedAddress {
    final primary = primaryName;
    final secondary = secondaryAddr;
    if (secondary.isEmpty) return primary;
    if (primary.isEmpty) return secondary;
    if (primary.contains(secondary)) return primary;
    return '$primary, $secondary';
  }

  /// Alias for formattedAddress
  String get fullAddress => formattedAddress;

  /// Convenience getters
  double? get lat => latitude;
  double? get lng => longitude;

  factory GeocodedAddress.fromApiResponse(Map<String, dynamic> res) {
    final rawAddr = res['address'] ?? res['Address'];
    if (rawAddr is Map<String, dynamic>) {
      final stateVal = rawAddr['State'];
      final stateName = stateVal is Map
          ? (stateVal['Name'] ?? stateVal['name'] ?? '').toString()
          : (stateVal ?? '').toString();
      return GeocodedAddress(
        label: (rawAddr['Label'] ?? rawAddr['label'] ?? '').toString().trim(),
        street: (rawAddr['Street'] ?? rawAddr['street'] ?? '').toString().trim(),
        city: (rawAddr['City'] ?? rawAddr['city'] ?? '').toString().trim(),
        state: stateName.trim(),
        country:
            (rawAddr['Country'] ?? rawAddr['country'] ?? '').toString().trim(),
        latitude: double.tryParse(
            (rawAddr['Latitude'] ?? rawAddr['latitude'] ?? '').toString()),
        longitude: double.tryParse(
            (rawAddr['Longitude'] ?? rawAddr['longitude'] ?? '').toString()),
      );
    } else if (rawAddr is String && rawAddr.isNotEmpty) {
      // Clean fallback if raw string was returned
      var cleaned = rawAddr;
      if (cleaned.startsWith('{') && cleaned.endsWith('}')) {
        // Was stringified map
        cleaned = cleaned.replaceAll(RegExp(r'[{}]'), '');
      }
      cleaned = cleaned.replaceAll(RegExp(r'^Label:\s*', caseSensitive: false), '');
      return GeocodedAddress(label: cleaned.trim());
    }
    return const GeocodedAddress(label: '');
  }
}

class PlaceDetailResult {
  final String placeId;
  final String label;
  final String street;
  final String city;
  final double? latitude;
  final double? longitude;

  const PlaceDetailResult({
    required this.placeId,
    required this.label,
    this.street = '',
    this.city = '',
    this.latitude,
    this.longitude,
  });

  double? get lat => latitude;
  double? get lng => longitude;
  String get cleanLabel => formatCleanAddress(label);

  factory PlaceDetailResult.fromApiResponse(Map<String, dynamic> res) {
    final raw = res['place'] ?? res['Place'] ?? res;
    if (raw is Map<String, dynamic>) {
      return PlaceDetailResult(
        placeId: (raw['PlaceId'] ?? raw['placeId'] ?? '').toString(),
        label: (raw['Label'] ??
                raw['label'] ??
                raw['Address'] ??
                raw['address'] ??
                '')
            .toString()
            .trim(),
        street: (raw['Street'] ?? raw['street'] ?? '').toString().trim(),
        city: (raw['City'] ?? raw['city'] ?? '').toString().trim(),
        latitude: double.tryParse((raw['Latitude'] ??
                raw['latitude'] ??
                raw['lat'] ??
                raw['Lat'] ??
                '')
            .toString()),
        longitude: double.tryParse((raw['Longitude'] ??
                raw['longitude'] ??
                raw['lng'] ??
                raw['Lng'] ??
                '')
            .toString()),
      );
    }
    return PlaceDetailResult(
      placeId: '',
      label: '',
      latitude: double.tryParse(
          (res['lat'] ?? res['Lat'] ?? res['latitude'] ?? '').toString()),
      longitude: double.tryParse(
          (res['lng'] ?? res['Lng'] ?? res['longitude'] ?? '').toString()),
    );
  }
}
