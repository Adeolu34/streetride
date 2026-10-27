import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:streetride/core/models/location_models.dart';
import 'package:streetride/core/services/recent_places_service.dart';
import 'package:streetride/core/services/route_service.dart';
import 'package:streetride/core/services/saved_places_service.dart';

void main() {
  group('formatCleanAddress tests', () {
    test('strips , Nigeria and postal codes cleanly', () {
      expect(
        formatCleanAddress('Murtala Muhammed International Airport, Ikeja, Lagos, Nigeria'),
        'Murtala Muhammed International Airport, Ikeja, Lagos',
      );
      expect(
        formatCleanAddress('11 Eletu Ogabi St, Victoria Island, 106104, Lagos, Nigeria'),
        '11 Eletu Ogabi St, Victoria Island, Lagos',
      );
    });

    test('cleans raw stringified maps with {Label: ...}', () {
      expect(
        formatCleanAddress('{Label: Palms Mall, Lekki, Lagos, Nigeria}'),
        'Palms Mall, Lekki, Lagos',
      );
    });

    test('preserves clean short landmark names', () {
      expect(formatCleanAddress('Palms Mall, Lekki'), 'Palms Mall, Lekki');
      expect(formatCleanAddress('Victoria Island'), 'Victoria Island');
    });
  });

  group('GeocodedAddress parsing tests', () {
    test('parses raw map with Label and cleans curly braces', () {
      final rawResponse = {
        'status': true,
        'address': {
          'Label': 'Barbar Lagos, 15 Victoria Arobieke St, Lekki Phase 1, Lagos, Nigeria',
          'Street': 'Victoria Arobieke St',
          'City': 'Lekki',
        },
      };

      final parsed = GeocodedAddress.fromApiResponse(rawResponse);
      expect(parsed.primaryName, 'Barbar Lagos');
      expect(parsed.secondaryAddr, '15 Victoria Arobieke St, Lekki Phase 1, Lagos');
      expect(parsed.fullAddress, contains('Barbar Lagos'));
      expect(parsed.fullAddress.contains('{Label:'), isFalse);
      expect(parsed.formattedAddress, 'Barbar Lagos, 15 Victoria Arobieke St, Lekki Phase 1, Lagos');
    });

    test('parses raw string with {Label: ...} legacy format', () {
      final rawResponse = {
        'status': true,
        'address': '{Label: Lekki Phase 1 Gate, Lekki-Epe Expressway, Lagos}',
      };

      final parsed = GeocodedAddress.fromApiResponse(rawResponse);
      expect(parsed.primaryName, 'Lekki Phase 1 Gate');
      expect(parsed.fullAddress.contains('{Label:'), isFalse);
    });

    test('handles empty or error response gracefully', () {
      final parsed = GeocodedAddress.fromApiResponse({'status': false});
      expect(parsed.primaryName, 'Selected Location');
      expect(parsed.secondaryAddr, '');
    });
  });

  group('PlaceDetailResult parsing tests', () {
    test('parses nested place object from RR2 response', () {
      final rawResponse = {
        'status': true,
        'place': {
          'Latitude': 6.44361,
          'Longitude': 3.47450,
          'Label': 'Victoria Island, Lagos, Nigeria',
        },
      };

      final parsed = PlaceDetailResult.fromApiResponse(rawResponse);
      expect(parsed.lat, 6.44361);
      expect(parsed.lng, 3.47450);
      expect(parsed.label, 'Victoria Island, Lagos, Nigeria');
      expect(parsed.cleanLabel, 'Victoria Island, Lagos');
    });

    test('parses flat lat/lng response as fallback', () {
      final rawResponse = {
        'status': true,
        'lat': 6.5000,
        'lng': 3.3500,
        'address': 'Yaba, Lagos',
      };

      final parsed = PlaceDetailResult.fromApiResponse(rawResponse);
      expect(parsed.lat, 6.5000);
      expect(parsed.lng, 3.3500);
    });
  });

  group('RecentPlace serialization tests', () {
    test('encodes and decodes RecentPlace with coordinates', () {
      const original = RecentPlace(
        primaryName: 'Murtala Muhammed Airport',
        secondaryAddr: 'Ikeja, Lagos',
        fullAddress: 'Murtala Muhammed Airport, Ikeja, Lagos',
        placeId: 'airport_123',
        lat: 6.57025,
        lng: 3.32142,
      );

      final json = original.toJson();
      final restored = RecentPlace.fromJson(json);

      expect(restored.primaryName, original.primaryName);
      expect(restored.secondaryAddr, original.secondaryAddr);
      expect(restored.fullAddress, original.fullAddress);
      expect(restored.placeId, original.placeId);
      expect(restored.lat, 6.57025);
      expect(restored.lng, 3.32142);
    });
  });

  group('SavedPlace serialization tests', () {
    test('encodes and decodes SavedPlace to/from json correctly', () {
      const original = SavedPlace(
        label: 'Home',
        address: '14 Admiralty Way, Lekki Phase 1, Lagos',
        primaryName: '14 Admiralty Way',
        secondaryAddr: 'Lekki Phase 1, Lagos',
        lat: 6.4485,
        lng: 3.4728,
        placeId: 'place_123',
      );

      final json = original.toJson();
      final restored = SavedPlace.fromJson(json);

      expect(restored.label, original.label);
      expect(restored.address, original.address);
      expect(restored.primaryName, original.primaryName);
      expect(restored.secondaryAddr, original.secondaryAddr);
      expect(restored.lat, original.lat);
      expect(restored.lng, original.lng);
      expect(restored.placeId, original.placeId);
    });
  });

  group('RouteService tests', () {
    test('fallback road interpolation generates multi-point path with distance', () {
      const from = LatLng(6.4485, 3.4728);
      const to = LatLng(6.5244, 3.3792);

      final result = RouteService.instance.getInterpolatedFallback(from: from, to: to);
      expect(result.points.length, greaterThan(5));
      expect(result.distanceKm, greaterThan(5.0));
      expect(result.durationMinutes, greaterThan(5));
    });

    test('RouteStep model and steps are properly populated in RouteResult', () {
      const from = LatLng(6.4485, 3.4728);
      const to = LatLng(6.5244, 3.3792);

      final result = RouteService.instance.getInterpolatedFallback(from: from, to: to);
      expect(result.steps.isNotEmpty, isTrue);
      expect(result.steps.first.maneuver, 'depart');
      expect(result.steps.last.maneuver, 'arrive');
      expect(result.steps.first.distanceLabel, isNotEmpty);
    });
  });
}
