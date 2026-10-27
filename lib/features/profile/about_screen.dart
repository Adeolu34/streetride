import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SRColors.lavenderBg,
      appBar: AppBar(
        backgroundColor: SRColors.purple700,
        foregroundColor: Colors.white,
        title: const Text(
          'About StreetRide',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: SRColors.purple700,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 48),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'StreetRide',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: SRColors.ink900),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'Version 1.0.0',
              style: TextStyle(fontSize: 13, color: SRColors.ink500),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Your ride, your price.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: SRColors.purple700,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: SRColors.border, width: 1.5),
            ),
            child: const Text(
              'StreetRide is a Nigerian ride-hailing platform built on a unique driver-led pricing model. Riders choose their drivers and drivers name their own price — no surge pricing, no hidden fees. Just transparent, fair rides across Nigeria.',
              style: TextStyle(fontSize: 14, color: SRColors.ink500, height: 1.6),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          _LinkTile(
            icon: Icons.gavel_rounded,
            title: 'Terms of Service',
            onTap: () => _open('https://streetrideplus.com/terms'),
          ),
          const SizedBox(height: 10),
          _LinkTile(
            icon: Icons.privacy_tip_rounded,
            title: 'Privacy Policy',
            onTap: () => _open('https://streetrideplus.com/privacy'),
          ),
          const SizedBox(height: 10),
          _LinkTile(
            icon: Icons.public_rounded,
            title: 'Visit our website',
            onTap: () => _open('https://streetrideplus.com'),
          ),
          const SizedBox(height: 40),
          const Center(
            child: Text(
              '© 2025 StreetRide Plus. All rights reserved.',
              style: TextStyle(fontSize: 12, color: SRColors.ink500),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _LinkTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SRColors.border, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: SRColors.purple700, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: SRColors.ink900),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: SRColors.ink500),
          ],
        ),
      ),
    );
  }
}
