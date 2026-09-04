import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Top-level handler — runs in background isolate when user taps notification
// while app is backgrounded. Writes the route to SharedPreferences so the
// home screen can navigate when it resumes.
@pragma('vm:entry-point')
void onBackgroundNotificationTap(NotificationResponse response) async {
  final route = response.payload;
  if (route == null || route.isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('sr_notif_pending_route', route);
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  /// Shared navigator key — passed to GoRouter so notification taps can
  /// navigate without needing a BuildContext.
  static final navigatorKey = GlobalKey<NavigatorState>();

  final _fln = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static final _rideChannel = AndroidNotificationChannel(
    'sr_rides_v2',
    'Ride Alerts',
    description: 'StreetRide urgent ride notifications',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    // Requires android/app/src/main/res/raw/sr_alert.mp3 (or .ogg)
    sound: const RawResourceAndroidNotificationSound('sr_alert'),
  );

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _fln.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: _onForegroundTap,
      onDidReceiveBackgroundNotificationResponse: onBackgroundNotificationTap,
    );

    final androidPlugin = _fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(_rideChannel);

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'sr_bg_service',
        'Background Service',
        description: 'StreetRide background ride monitoring',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      ),
    );

    // Request POST_NOTIFICATIONS on Android 13+
    await androidPlugin?.requestNotificationsPermission();

    // Check if the app was cold-started by a notification tap
    final launch = await _fln.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      final route = launch!.notificationResponse?.payload;
      if (route != null && route.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('sr_notif_pending_route', route);
      }
    }

    _ready = true;
  }

  void _onForegroundTap(NotificationResponse response) {
    final route = response.payload;
    if (route == null || route.isEmpty) return;
    final ctx = navigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      ctx.go(route);
    }
  }

  /// Call from SplashScreen or home screens after resume.
  /// Returns true if it triggered a navigation.
  Future<bool> consumePendingRoute(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final route = prefs.getString('sr_notif_pending_route') ?? '';
    if (route.isEmpty) return false;
    await prefs.remove('sr_notif_pending_route');
    if (context.mounted) {
      context.go(route);
      return true;
    }
    return false;
  }

  /// Show a heads-up / full-screen notification.
  /// [payload] should be a route string like '/home' or '/driver-home'.
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_ready) return;
    await _fln.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'sr_rides_v2',
          'Ride Alerts',
          channelDescription: 'StreetRide urgent ride notifications',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('sr_alert'),
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 300, 200, 300]),
          enableLights: true,
          ledColor: const Color(0xFF6B4EFF),
          fullScreenIntent: true,
          icon: '@mipmap/ic_launcher',
          ticker: title,
          autoCancel: true,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
      payload: payload,
    );
  }
}
