import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class EngagementService {
  EngagementService._();
  static final instance = EngagementService._();

  static const _keyLastOpen     = 'sr_last_app_open';
  static const _keyLastDest     = 'sr_last_destination';
  static const _keyStreakCount  = 'sr_streak_count';
  static const _keyStreakDate   = 'sr_streak_last_date';
  static const _keyMorningDate  = 'sr_morning_notif_date';
  static const _keyEveningDate  = 'sr_evening_notif_date';

  // ── Instance methods (called from main isolate) ──────────────────────────

  Future<void> recordAppOpen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastOpen, _today());
  }

  Future<void> recordTripCompleted(String toText) async {
    if (toText.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastDest, toText);
    await _updateStreak(prefs);
  }

  Future<String?> getLastDestination() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastDest);
  }

  Future<int> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString(_keyStreakDate) ?? '';
    final count = prefs.getInt(_keyStreakCount) ?? 0;
    if (lastDate != _today() && lastDate != _yesterday()) return 0;
    return count;
  }

  Future<void> _updateStreak(SharedPreferences prefs) async {
    final today = _today();
    final lastDate = prefs.getString(_keyStreakDate) ?? '';
    final streak = prefs.getInt(_keyStreakCount) ?? 0;
    if (lastDate == today) return;
    final newStreak = (lastDate == _yesterday()) ? streak + 1 : 1;
    await prefs.setInt(_keyStreakCount, newStreak);
    await prefs.setString(_keyStreakDate, today);
  }

  // ── Static methods (safe to call from background isolate) ────────────────

  static Future<bool> shouldSendMorningNotif() async {
    final hour = DateTime.now().hour;
    if (hour != 9) return false;
    final prefs = await SharedPreferences.getInstance();
    final today = _today();
    if ((prefs.getString(_keyLastOpen) ?? '') == today) return false;
    if ((prefs.getString(_keyMorningDate) ?? '') == today) return false;
    return true;
  }

  static Future<void> markMorningNotifSent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMorningDate, _today());
  }

  static Future<bool> shouldSendEveningNotif() async {
    final hour = DateTime.now().hour;
    if (hour != 18) return false;
    final prefs = await SharedPreferences.getInstance();
    final today = _today();
    if ((prefs.getString(_keyLastOpen) ?? '') == today) return false;
    if ((prefs.getString(_keyEveningDate) ?? '') == today) return false;
    return true;
  }

  static Future<void> markEveningNotifSent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEveningDate, _today());
  }

  static Future<String> getUserFirstName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('sr_profile');
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final name = (data['FirstName'] ?? data['firstname'] ?? '').toString().trim();
        if (name.isNotEmpty) return name;
      }
    } catch (_) {}
    return 'there';
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${_p(now.month)}-${_p(now.day)}';
  }

  static String _yesterday() {
    final d = DateTime.now().subtract(const Duration(days: 1));
    return '${d.year}-${_p(d.month)}-${_p(d.day)}';
  }

  static String _p(int n) => n.toString().padLeft(2, '0');
}
