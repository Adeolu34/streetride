import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _rideUpdates = true;
  bool _priceOffers = true;
  bool _chatMessages = true;
  bool _promotions = false;

  static const _keyRide = 'notif_ride_updates';
  static const _keyPrice = 'notif_price_offers';
  static const _keyChat = 'notif_chat_messages';
  static const _keyPromo = 'notif_promotions';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _rideUpdates = prefs.getBool(_keyRide) ?? true;
      _priceOffers = prefs.getBool(_keyPrice) ?? true;
      _chatMessages = prefs.getBool(_keyChat) ?? true;
      _promotions = prefs.getBool(_keyPromo) ?? false;
    });
  }

  Future<void> _set(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SRColors.lavenderBg,
      appBar: AppBar(
        backgroundColor: SRColors.purple700,
        foregroundColor: Colors.white,
        title: const Text(
          'Notifications',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionLabel('Ride Alerts'),
          const SizedBox(height: 12),
          _NotifTile(
            icon: Icons.directions_car_rounded,
            title: 'Ride updates',
            subtitle: 'Driver arrival, trip start, and completion',
            value: _rideUpdates,
            onChanged: (v) {
              setState(() => _rideUpdates = v);
              _set(_keyRide, v);
            },
          ),
          const SizedBox(height: 10),
          _NotifTile(
            icon: Icons.local_offer_rounded,
            title: 'Price offers',
            subtitle: 'When a driver names a price for your trip',
            value: _priceOffers,
            onChanged: (v) {
              setState(() => _priceOffers = v);
              _set(_keyPrice, v);
            },
          ),
          const SizedBox(height: 10),
          _NotifTile(
            icon: Icons.chat_bubble_rounded,
            title: 'Chat messages',
            subtitle: 'Messages from your driver',
            value: _chatMessages,
            onChanged: (v) {
              setState(() => _chatMessages = v);
              _set(_keyChat, v);
            },
          ),
          const SizedBox(height: 24),
          _SectionLabel('Marketing'),
          const SizedBox(height: 12),
          _NotifTile(
            icon: Icons.campaign_rounded,
            title: 'Promotions & offers',
            subtitle: 'Deals, discounts, and StreetRide news',
            value: _promotions,
            onChanged: (v) {
              setState(() => _promotions = v);
              _set(_keyPromo, v);
            },
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SRColors.purple100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: SRColors.purple700, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ride-critical alerts (e.g. driver arrived) are always delivered even when notifications are off.',
                    style: TextStyle(fontSize: 13, color: SRColors.purple700, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: SRColors.ink500,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotifTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SRColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: SRColors.purple100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: SRColors.purple700, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: SRColors.ink900),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: SRColors.ink500),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: SRColors.purple700,
          ),
        ],
      ),
    );
  }
}
