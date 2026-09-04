import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/notification_service.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/language/language_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/kyc_screen.dart';
import '../../features/home/rider_home_screen.dart';
import '../../features/driver/driver_home_screen.dart';
import '../../features/driver/driver_name_price_screen.dart';
import '../../features/driver/driver_offer_status_screen.dart';
import '../../features/driver/driver_navigate_screen.dart';
import '../../features/driver/driver_earnings_screen.dart';
import '../../features/driver/driver_plans_screen.dart';
import '../../features/driver/driver_profile_screen.dart';
import '../../features/driver/driver_profile_edit_screen.dart';
import '../../features/driver/driver_ride_history_screen.dart';
import '../../features/booking/screens/search_screen.dart';
import '../../features/booking/screens/map_picker_screen.dart';
import '../../features/booking/screens/select_drivers_screen.dart';
import '../../features/booking/screens/request_pending_screen.dart';
import '../../features/booking/screens/driver_offers_screen.dart';
import '../../features/booking/screens/live_tracking_screen.dart';
import '../../features/booking/screens/rate_pay_screen.dart';
import '../../features/safety/safety_screen.dart';
import '../../features/chat/chat_screen.dart';

final appRouter = GoRouter(
  navigatorKey: NotificationService.navigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(
      path: '/signup',
      builder: (_, state) {
        final isDriver = state.uri.queryParameters['driver'] == 'true';
        return SignupScreen(isDriver: isDriver);
      },
    ),
    GoRoute(
      path: '/otp',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return OtpScreen(
          phone: extra['phone'] as String? ?? '',
          isDriver: extra['isDriver'] as bool? ?? false,
          isSignup: extra['isSignup'] as bool? ?? false,
        );
      },
    ),
    GoRoute(path: '/kyc', builder: (_, __) => const KycScreen()),
    GoRoute(path: '/home', builder: (_, __) => const RiderHomeScreen()),
    GoRoute(path: '/driver-home', builder: (_, __) => const DriverHomeScreen()),

    // Driver flow
    GoRoute(
      path: '/driver-name-price',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return DriverNamePriceScreen(
          reqId: extra['reqId'] as String? ?? '',
          fromText: extra['fromText'] as String? ?? '',
          toText: extra['toText'] as String? ?? '',
          riderName: extra['riderName'] as String? ?? 'Rider',
          riderInitials: extra['riderInitials'] as String? ?? 'R',
          km: extra['km'] as String? ?? '—',
          eta: extra['eta'] as String? ?? '—',
        );
      },
    ),
    GoRoute(
      path: '/driver-offer-status',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return DriverOfferStatusScreen(
          price: extra['price'] as int? ?? 0,
          reqId: extra['reqId'] as String? ?? '',
          fromText: extra['fromText'] as String? ?? '',
          toText: extra['toText'] as String? ?? '',
          riderName: extra['riderName'] as String? ?? 'Rider',
        );
      },
    ),
    GoRoute(
      path: '/driver-navigate',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return DriverNavigateScreen(
          reqId: extra['reqId'] as String? ?? '',
        );
      },
    ),
    GoRoute(
      path: '/driver-earnings',
      builder: (_, __) => const DriverEarningsScreen(),
    ),
    GoRoute(
      path: '/driver-plans',
      builder: (_, __) => const DriverPlansScreen(),
    ),
    GoRoute(
      path: '/driver-profile',
      builder: (_, __) => const DriverProfileScreen(),
    ),
    GoRoute(
      path: '/driver-edit-profile',
      builder: (_, __) => const DriverProfileEditScreen(),
    ),
    GoRoute(
      path: '/driver-ride-history',
      builder: (_, __) => const DriverRideHistoryScreen(),
    ),

    // Rider booking flow
    GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
    GoRoute(
      path: '/map-picker',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return MapPickerScreen(
          initialLat: (extra['initialLat'] as num?)?.toDouble(),
          initialLng: (extra['initialLng'] as num?)?.toDouble(),
        );
      },
    ),
    GoRoute(
      path: '/select-drivers',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return SelectDriversScreen(
          from: extra['from'] as String? ?? 'Current location',
          to: extra['to'] as String? ?? '',
        );
      },
    ),
    GoRoute(
      path: '/request-pending',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return RequestPendingScreen(
          from: extra['from'] as String? ?? 'Current location',
          to: extra['to'] as String? ?? '',
          selectedCount: extra['selectedCount'] as int? ?? 3,
          reqIds: (extra['reqIds'] as List?)?.cast<String>() ?? [],
        );
      },
    ),
    GoRoute(
      path: '/driver-offers',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return DriverOffersScreen(
          from: extra['from'] as String? ?? 'Current location',
          to: extra['to'] as String? ?? '',
          reqIds: (extra['reqIds'] as List?)?.cast<String>() ?? [],
        );
      },
    ),
    GoRoute(
      path: '/live-tracking',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return LiveTrackingScreen(
          driverName: extra['driverName'] as String? ?? '',
          driverInitials: extra['driverInitials'] as String? ?? '',
          car: extra['car'] as String? ?? '',
          rating: (extra['rating'] as num?)?.toDouble() ?? 0,
          price: extra['price'] as int? ?? 0,
          from: extra['from'] as String? ?? '',
          to: extra['to'] as String? ?? '',
          reqId: extra['reqId'] as String? ?? '',
        );
      },
    ),
    GoRoute(
      path: '/rate-pay',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return RatePayScreen(
          driverName: extra['driverName'] as String? ?? '',
          car: extra['car'] as String? ?? '',
          rating: (extra['rating'] as num?)?.toDouble() ?? 0,
          price: extra['price'] as int? ?? 0,
          to: extra['to'] as String? ?? '',
          reqId: extra['reqId'] as String? ?? '',
        );
      },
    ),

    // Shared utility screens
    GoRoute(path: '/language', builder: (_, __) => const LanguageScreen()),
    GoRoute(path: '/safety', builder: (_, __) => const SafetyScreen()),
    GoRoute(
      path: '/chat',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return ChatScreen(
          driverName: extra['driverName'] as String? ?? 'Your driver',
          driverInitials: extra['driverInitials'] as String? ?? '?',
          otherPhotoUrl: extra['otherPhotoUrl'] as String?,
          reqId: extra['reqId'] as String? ?? '',
        );
      },
    ),
  ],
  errorBuilder: (_, state) => Scaffold(
    body: Center(child: Text('Page not found: ${state.error}')),
  ),
);
