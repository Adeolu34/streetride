import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RecentPlace {
  final String primaryName;
  final String secondaryAddr;
  final String fullAddress;
  final String placeId;

  const RecentPlace({
    required this.primaryName,
    required this.secondaryAddr,
    required this.fullAddress,
    this.placeId = '',
  });

  Map<String, dynamic> toJson() => {
        'primaryName': primaryName,
        'secondaryAddr': secondaryAddr,
        'fullAddress': fullAddress,
        'placeId': placeId,
      };

  factory RecentPlace.fromJson(Map<String, dynamic> j) => RecentPlace(
        primaryName: j['primaryName']?.toString() ?? '',
        secondaryAddr: j['secondaryAddr']?.toString() ?? '',
        fullAddress: j['fullAddress']?.toString() ?? '',
        placeId: j['placeId']?.toString() ?? '',
      );
}

class RecentPlacesService {
  static const _key = 'sr_recent_places';
  static const _max = 15;

  static Future<List<RecentPlace>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => RecentPlace.fromJson(e as Map<String, dynamic>))
          .where((p) => p.fullAddress.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(RecentPlace place) async {
    if (place.fullAddress.isEmpty ||
        place.fullAddress == 'Current location') return;
    final all = await load();
    all.removeWhere((p) => p.fullAddress == place.fullAddress);
    all.insert(0, place);
    if (all.length > _max) all.removeRange(_max, all.length);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(all.map((p) => p.toJson()).toList()));
  }

  static Future<List<RecentPlace>> search(String query) async {
    final all = await load();
    if (query.trim().length < 2) return all.take(6).toList();
    final q = query.toLowerCase();
    return all
        .where((p) =>
            p.fullAddress.toLowerCase().contains(q) ||
            p.primaryName.toLowerCase().contains(q))
        .take(6)
        .toList();
  }
}
