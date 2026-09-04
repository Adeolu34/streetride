import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/services/session_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/background_poll_service.dart';
import 'core/providers/language_provider.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  await SessionService.instance.load();
  await NotificationService.instance.init();
  await BackgroundPollService.init();
  if (SessionService.instance.isLoggedIn) {
    await BackgroundPollService.start();
  }
  runApp(const ProviderScope(child: StreetRideApp()));
}

class StreetRideApp extends ConsumerStatefulWidget {
  const StreetRideApp({super.key});

  @override
  ConsumerState<StreetRideApp> createState() => _StreetRideAppState();
}

class _StreetRideAppState extends ConsumerState<StreetRideApp> {
  @override
  void initState() {
    super.initState();
    ref.read(languageProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'StreetRide',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: appRouter,
    );
  }
}
