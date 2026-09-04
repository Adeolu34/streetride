import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _handlerEp = 'https://streetrideplus.com/sr/myhandler';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  final fln = FlutterLocalNotificationsPlugin();
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await fln.initialize(const InitializationSettings(android: android));

  // Create the ride-alert channel here too — needed when the service starts
  // before the main Flutter app initializes (e.g. on device boot).
  final androidPlugin =
      fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      'sr_rides_v2',
      'Ride Alerts',
      description: 'StreetRide urgent ride notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      sound: RawResourceAndroidNotificationSound('sr_alert'),
    ),
  );

  Future<void> notify(int id, String title, String body, {String? payload}) async {
    await fln.show(
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

  Future<void> poll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('sr_bg_last_poll_ms', DateTime.now().millisecondsSinceEpoch);
      final token = prefs.getString('sr_bearer_token') ?? '';
      final profileRaw = prefs.getString('sr_profile');
      if (token.isEmpty || profileRaw == null) return;

      final profile = jsonDecode(profileRaw) as Map<String, dynamic>;
      String rawPhone = (profile['phone'] ?? '').toString();
      // Normalize to international format
      String phone = rawPhone.startsWith('234')
          ? rawPhone
          : rawPhone.startsWith('0')
              ? '234${rawPhone.substring(1)}'
              : '234$rawPhone';

      final bool isDriver = prefs.getBool('sr_is_driver') ?? false;

      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 10);
      (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      };

      final res = await dio.post(
        _handlerEp,
        data: {'theKey': 'BK8', 'phone': phone},
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      final data = res.data as Map<String, dynamic>;
      final messages = data['Messages'];
      if (messages is! List) return;

      final statesRaw = prefs.getString('sr_bg_ride_states') ?? '{}';
      final states = jsonDecode(statesRaw) as Map<String, dynamic>;

      bool statesChanged = false;
      int notifId = 100;

      for (final raw in messages) {
        if (raw == null) continue;
        final m = raw as Map<String, dynamic>;
        final reqId = (m['reqid'] ?? '').toString();
        if (reqId.isEmpty) continue;

        final dphone = (m['dphone'] ?? '').toString();
        final rphone = (m['rphone'] ?? '').toString();
        final movt = (m['MovtStatus_D'] ?? '').toString();
        final price = (m['Price_D'] ?? '').toString();
        final confirmR = (m['ConfirmStatus_R'] ?? '').toString();
        final rideStatus = (m['RideStatus_R'] ?? '').toString();
        final fromText = (m['fromText'] ?? '').toString();
        final toText = (m['toText'] ?? '').toString();

        final prev = states[reqId] as Map<String, dynamic>? ?? {};
        final prevMovt = (prev['movt'] ?? '').toString();
        final prevPrice = (prev['price'] ?? '').toString();
        final prevConfirmR = (prev['confirmR'] ?? '').toString();
        final prevRideStatus = (prev['rideStatus'] ?? '').toString();
        final isNew = prev.isEmpty;

        if (isDriver && dphone == phone) {
          // ── Driver notifications ──────────────────────────────────────────
          if (isNew) {
            // New ride request appeared with no status yet
            if (movt.isEmpty && price.isEmpty && rideStatus.isEmpty) {
              final dest = toText.isNotEmpty ? toText : 'unknown destination';
              final origin = fromText.isNotEmpty ? fromText : 'unknown location';
              await notify(
                notifId++,
                'New Ride Request!',
                '$origin → $dest',
                payload: '/driver-home',
              );
            }
          } else {
            // Rider accepted the driver's price
            if (rideStatus != prevRideStatus &&
                rideStatus.toLowerCase() == 'accepted') {
              await notify(
                notifId++,
                'Rider Accepted!',
                'Head to pickup${toText.isNotEmpty ? " — going to $toText" : ""}',
                payload: '/driver-home',
              );
            }
            // Rider cancelled or withdrew
            if (rideStatus != prevRideStatus) {
              final rs = rideStatus.toLowerCase();
              if (rs == 'cancelled' || rs == 'withdraw') {
                // Only notify if driver did not initiate cancel simultaneously
                final driverInitiated = movt != prevMovt &&
                    (movt.toLowerCase().contains('cancel') ||
                        movt.toLowerCase().contains('reject'));
                if (!driverInitiated) {
                  await notify(
                    notifId++,
                    'Ride Cancelled',
                    'The rider cancelled this request',
                    payload: '/driver-home',
                  );
                }
              }
            }
          }
        } else if (!isDriver && rphone == phone) {
          // ── Rider notifications ───────────────────────────────────────────
          // Only 'arrived' and 'intransit' fire on first-seen — these are
          // genuinely mid-ride and time-sensitive. 'cancel' and 'completed'
          // are excluded because old finished rides would fire false alerts.
          const _midRideStatuses = {'arrived', 'intransit'};
          if (isNew) {
            if (movt.isNotEmpty && _midRideStatuses.contains(movt.toLowerCase().trim())) {
              final (title, body) = _riderNotifForMovt(movt, toText, fromText);
              if (title != null) {
                await notify(notifId++, title, body!, payload: '/home');
              }
            }
            // Price received but ride hasn't moved yet — driver just quoted
            if (price.isNotEmpty && movt.isEmpty) {
              await notify(
                notifId++,
                'Price Received!',
                'A driver quoted ₦$price for your trip',
                payload: '/home',
              );
            }
          } else {
            // Normal change detection
            if (price != prevPrice && price.isNotEmpty && prevPrice.isEmpty) {
              await notify(
                notifId++,
                'Price Received!',
                'A driver quoted ₦$price for your trip',
                payload: '/home',
              );
            }
            if (movt != prevMovt && movt.isNotEmpty) {
              final (title, body) = _riderNotifForMovt(movt, toText, fromText);
              if (title != null) {
                await notify(notifId++, title, body!, payload: '/home');
              }
            }
          }
        }

        states[reqId] = {
          'movt': movt,
          'price': price,
          'confirmR': confirmR,
          'rideStatus': rideStatus,
        };
        statesChanged = true;
      }

      if (statesChanged) {
        await prefs.setString('sr_bg_ride_states', jsonEncode(states));
      }
    } catch (_) {}
  }

  // Keep an active location stream so Android/TECNO treats this as a
  // protected location foreground service and does not kill it.
  StreamSubscription<Position>? _locationSub;
  try {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      _locationSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          distanceFilter: 50,
        ),
      ).listen((_) {});
    }
  } catch (_) {}

  Timer.periodic(const Duration(seconds: 10), (_) => poll());
  await poll();

  service.on('stop').listen((_) {
    _locationSub?.cancel();
    service.stopSelf();
  });
}

(String?, String?) _riderNotifForMovt(String movt, String toText, String fromText) {
  final dest = toText.isNotEmpty ? toText : 'your destination';
  final origin = fromText.isNotEmpty ? fromText : 'your location';
  switch (movt.toLowerCase().trim()) {
    case 'started':
      return ('Driver is on the way!', 'Heading to pick you up at $origin');
    case 'arrived':
      return ('Driver has arrived!', 'Head outside — they are waiting for you');
    case 'intransit':
      return ('Trip started!', 'On the way to $dest');
    case 'completed':
      return ('Trip completed', 'Rate your driver when ready');
    case 'cancel':
      return ('Driver cancelled', 'Please look for another driver');
    case 'reject price':
      return ('Price rejected', 'The driver declined your counter-offer');
  }
  return (null, null);
}

class BackgroundPollService {
  static Future<void> init() async {
    try {
      final service = FlutterBackgroundService();
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: true,
          isForegroundMode: true,
          notificationChannelId: 'sr_bg_service',
          initialNotificationTitle: 'StreetRide',
          initialNotificationContent: 'Monitoring ride updates...',
          foregroundServiceNotificationId: 999,
          foregroundServiceTypes: [AndroidForegroundType.location],
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onStart,
          onBackground: _onIosBackground,
        ),
      );
    } catch (_) {}
  }

  static Future<void> start() async {
    try {
      final service = FlutterBackgroundService();
      if (!await service.isRunning()) {
        await service.startService();
      }
    } catch (_) {}
  }

  static void stop() {
    try {
      FlutterBackgroundService().invoke('stop');
    } catch (_) {}
  }

  static Future<bool> get isRunning => FlutterBackgroundService().isRunning();
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}
