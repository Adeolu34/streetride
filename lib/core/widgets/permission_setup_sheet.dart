import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

const _packageId = 'com.streetrideplus.streetride';

class PermissionSetupSheet extends StatefulWidget {
  const PermissionSetupSheet({super.key});

  /// Automatically fires native dialogs for notification, location, and battery,
  /// then shows the sheet only if overlay still needs granting.
  static Future<void> showIfNeeded(BuildContext context) async {
    if (!Platform.isAndroid) return;

    if (!await _hasNotification()) {
      await Permission.notification.request();
    }
    if (!await _hasLocation()) {
      await Permission.locationWhenInUse.request();
      await Permission.locationAlways.request();
    }
    if (!await _hasBatteryExempt()) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    final notif = await _hasNotification();
    final location = await _hasLocation();
    final overlay = await _hasOverlay();
    final battery = await _hasBatteryExempt();
    if (notif && location && overlay && battery) return;

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PermissionSetupSheet(),
    );
  }

  static Future<bool> _hasNotification() async {
    return (await Permission.notification.status).isGranted;
  }

  static Future<bool> _hasLocation() async {
    return (await Permission.locationAlways.status).isGranted;
  }

  static Future<bool> _hasOverlay() async {
    return (await Permission.systemAlertWindow.status).isGranted;
  }

  static Future<bool> _hasBatteryExempt() async {
    return (await Permission.ignoreBatteryOptimizations.status).isGranted;
  }

  @override
  State<PermissionSetupSheet> createState() => _PermissionSetupSheetState();
}

class _PermissionSetupSheetState extends State<PermissionSetupSheet> {
  bool _notifGranted = false;
  bool _locationGranted = false;
  bool _overlayGranted = false;
  bool _batteryGranted = false;
  String _serviceStatus = 'Checking...';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final notif = await PermissionSetupSheet._hasNotification();
    final location = await PermissionSetupSheet._hasLocation();
    final overlay = await PermissionSetupSheet._hasOverlay();
    final battery = await PermissionSetupSheet._hasBatteryExempt();
    final serviceStatus = await _getServiceStatus();
    if (mounted) {
      setState(() {
        _notifGranted = notif;
        _locationGranted = location;
        _overlayGranted = overlay;
        _batteryGranted = battery;
        _serviceStatus = serviceStatus;
        _loading = false;
      });
    }
  }

  Future<String> _getServiceStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt('sr_bg_last_poll_ms');
      if (ms == null) return 'Not started yet';
      final diff = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(ms),
      ).inSeconds;
      if (diff < 30) return 'Running (polled ${diff}s ago)';
      if (diff < 120) return 'Possibly stopped (${diff}s since last poll)';
      return 'STOPPED (${(diff / 60).toStringAsFixed(0)}m since last poll)';
    } catch (_) {
      return 'Unknown';
    }
  }

  Future<void> _requestNotification() async {
    await Permission.notification.request();
    await _checkStatus();
  }

  Future<void> _requestLocation() async {
    await Permission.locationWhenInUse.request();
    await Permission.locationAlways.request();
    await _checkStatus();
  }

  Future<void> _requestOverlay() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _StepGuideDialog(
        icon: Icons.layers_rounded,
        iconColor: SRColors.purple700,
        title: 'Display over other apps',
        steps: const [
          'A settings screen will open',
          'Find "StreetRide" and tap it',
          'Turn the toggle ON',
          'Press back to return here',
        ],
      ),
    );
    if (proceed != true) return;
    final uri = Uri.parse(
      'intent:#Intent;action=android.settings.action.MANAGE_OVERLAY_PERMISSION'
      ';data=package%3A$_packageId;end',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication)
        .catchError((_) => false);
    if (!launched) await openAppSettings();
    await _checkStatus();
  }

  Future<void> _requestBattery() async {
    await Permission.ignoreBatteryOptimizations.request();
    await _checkStatus();
  }

  @override
  Widget build(BuildContext context) {
    final allDone = _notifGranted && _locationGranted && _overlayGranted && _batteryGranted;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: _loading
          ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: SRColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: SRColors.purple700.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_active_rounded,
                          color: SRColors.purple700, size: 26),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Stay updated on every ride',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: SRColors.ink900)),
                          SizedBox(height: 3),
                          Text('Allow these settings so alerts always reach you',
                              style: TextStyle(fontSize: 12, color: SRColors.ink500)),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                _PermissionItem(
                  icon: Icons.notifications_rounded,
                  iconColor: SRColors.indigo900,
                  title: 'Notifications',
                  subtitle: 'Required for ride alerts — without this, no notification can appear',
                  granted: _notifGranted,
                  onEnable: _requestNotification,
                ),

                const SizedBox(height: 12),

                _PermissionItem(
                  icon: Icons.location_on_rounded,
                  iconColor: Colors.blue,
                  title: 'Location (always)',
                  subtitle: 'Keeps the background service alive so ride alerts reach you even when the app is closed',
                  granted: _locationGranted,
                  onEnable: _requestLocation,
                ),

                const SizedBox(height: 12),

                _PermissionItem(
                  icon: Icons.battery_charging_full_rounded,
                  iconColor: SRColors.green600,
                  title: 'Run in background',
                  subtitle: 'Prevents the phone from sleeping StreetRide so you never miss a ride update',
                  granted: _batteryGranted,
                  onEnable: _requestBattery,
                ),

                const SizedBox(height: 12),

                _PermissionItem(
                  icon: Icons.layers_rounded,
                  iconColor: SRColors.purple700,
                  title: 'Display over other apps',
                  subtitle: 'Shows ride alerts on top of your screen even when another app is open',
                  granted: _overlayGranted,
                  onEnable: _requestOverlay,
                ),

                const SizedBox(height: 16),

                // Service status indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: SRColors.lavenderBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _serviceStatus.startsWith('Running')
                            ? Icons.wifi_tethering_rounded
                            : Icons.wifi_tethering_off_rounded,
                        size: 16,
                        color: _serviceStatus.startsWith('Running')
                            ? SRColors.green500
                            : SRColors.ink500,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Background service: $_serviceStatus',
                          style: TextStyle(
                            fontSize: 11,
                            color: _serviceStatus.startsWith('Running')
                                ? SRColors.green600
                                : _serviceStatus.contains('STOPPED')
                                    ? Colors.red.shade600
                                    : SRColors.ink500,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _checkStatus,
                        child: const Icon(Icons.refresh_rounded,
                            size: 16, color: SRColors.ink500),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 52,
                    decoration: BoxDecoration(
                      color: allDone ? SRColors.green500 : SRColors.purple700,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            allDone ? Icons.check_circle_rounded : Icons.close_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            allDone ? 'All set — you\'re good to go!' : 'Skip for now',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (!allDone) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'You can always change these later in Settings',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: SRColors.ink500),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _PermissionItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool granted;
  final VoidCallback onEnable;

  const _PermissionItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.onEnable,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: granted ? SRColors.green500.withValues(alpha: 0.06) : SRColors.lavenderBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: granted ? SRColors.green500.withValues(alpha: 0.3) : SRColors.border,
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: granted
                  ? SRColors.green500.withValues(alpha: 0.12)
                  : iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              granted ? Icons.check_rounded : icon,
              color: granted ? SRColors.green500 : iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: granted ? SRColors.green600 : SRColors.ink900)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(fontSize: 12, color: SRColors.ink500)),
                if (!granted) ...[
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: onEnable,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                    label: const Text('Enable'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: iconColor,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(99)),
                      elevation: 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepGuideDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> steps;

  const _StepGuideDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: SRColors.ink900)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Follow these steps:',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: SRColors.ink500)),
            const SizedBox(height: 12),
            ...List.generate(steps.length, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('${i + 1}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: iconColor)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(steps[i],
                        style: const TextStyle(
                            fontSize: 13, color: SRColors.ink700, height: 1.4)),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel',
                        style: TextStyle(color: SRColors.ink500)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: iconColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(99)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Open Settings',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
