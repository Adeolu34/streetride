import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  static const _keyProfile = 'sr_profile';
  static const _keyIsDriver = 'sr_is_driver';
  static const _keyToken = 'sr_user_token';
  static const _keyRememberPhone = 'sr_remember_phone';
  static const _keyRememberPassword = 'sr_remember_password';

  UserProfile? _profile;
  bool _isDriver = false;
  String _token = '';

  UserProfile? get profile => _profile;
  bool get isDriver => _isDriver;
  String get token => _token;
  bool get isLoggedIn => _token.isNotEmpty && _profile != null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_keyToken) ?? '';
    _isDriver = prefs.getBool(_keyIsDriver) ?? false;
    final raw = prefs.getString(_keyProfile);
    if (raw != null) {
      _profile = UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
  }

  Future<void> save({
    required UserProfile profile,
    required bool isDriver,
    required String token,
  }) async {
    _profile = profile;
    _isDriver = isDriver;
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfile, jsonEncode(profile.toJson()));
    await prefs.setBool(_keyIsDriver, isDriver);
    await prefs.setString(_keyToken, token);
  }

  Future<void> saveCredentials(String phone, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRememberPhone, phone);
    await prefs.setString(_keyRememberPassword, password);
  }

  Future<({String phone, String password})?> loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_keyRememberPhone);
    final password = prefs.getString(_keyRememberPassword);
    if (phone == null || password == null) return null;
    return (phone: phone, password: password);
  }

  Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRememberPhone);
    await prefs.remove(_keyRememberPassword);
  }

  Future<void> updateProfile(UserProfile updated) async {
    _profile = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfile, jsonEncode(updated.toJson()));
  }

  Future<void> clear() async {
    _profile = null;
    _isDriver = false;
    _token = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyProfile);
    await prefs.remove(_keyIsDriver);
    await prefs.remove(_keyToken);
  }
}
