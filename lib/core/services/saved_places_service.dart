import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SavedPlace {
  final String label;
  final String address;
  final String primaryName;
  final String secondaryAddr;
  final double? lat;
  final double? lng;
  final String placeId;

  const SavedPlace({
    required this.label,
    required this.address,
    this.primaryName = '',
    this.secondaryAddr = '',
    this.lat,
    this.lng,
    this.placeId = '',
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'address': address,
        'primaryName': primaryName,
        'secondaryAddr': secondaryAddr,
        'lat': lat,
        'lng': lng,
        'placeId': placeId,
      };

  factory SavedPlace.fromJson(Map<String, dynamic> j) => SavedPlace(
        label: j['label']?.toString() ?? '',
        address: j['address']?.toString() ?? '',
        primaryName: j['primaryName']?.toString() ?? '',
        secondaryAddr: j['secondaryAddr']?.toString() ?? '',
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        placeId: j['placeId']?.toString() ?? '',
      );
}

class SavedPlacesService {
  static const _homeKey = 'sr_saved_place_home';
  static const _workKey = 'sr_saved_place_work';

  static Future<SavedPlace?> getHome() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_homeKey);
    if (raw == null) return null;
    try {
      return SavedPlace.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setHome(SavedPlace? place) async {
    final prefs = await SharedPreferences.getInstance();
    if (place == null) {
      await prefs.remove(_homeKey);
    } else {
      await prefs.setString(_homeKey, jsonEncode(place.toJson()));
    }
  }

  static Future<SavedPlace?> getWork() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_workKey);
    if (raw == null) return null;
    try {
      return SavedPlace.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setWork(SavedPlace? place) async {
    final prefs = await SharedPreferences.getInstance();
    if (place == null) {
      await prefs.remove(_workKey);
    } else {
      await prefs.setString(_workKey, jsonEncode(place.toJson()));
    }
  }
}
