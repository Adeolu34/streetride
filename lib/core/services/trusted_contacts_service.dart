import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TrustedContact {
  final String name;
  final String phone;
  const TrustedContact({required this.name, required this.phone});

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};

  factory TrustedContact.fromJson(Map<String, dynamic> j) =>
      TrustedContact(name: j['name'] as String, phone: j['phone'] as String);
}

class TrustedContactsService {
  TrustedContactsService._();
  static const _key = 'sr_trusted_contacts';
  static const maxContacts = 5;

  static Future<List<TrustedContact>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => TrustedContact.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<TrustedContact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(contacts.map((c) => c.toJson()).toList()));
  }
}
