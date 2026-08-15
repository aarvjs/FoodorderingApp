import 'package:go_router/go_router.dart';

import '../features/splash/splash_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/home/nav_base.dart';
import '../features/home/home_screen.dart';
import '../features/search/search_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/restaurant/restaurant_details_screen.dart';
import '../features/product/product_details_screen.dart';
import '../features/cart/cart_screen.dart';
import '../features/checkout/checkout_screen.dart';
import '../features/orders/order_success_screen.dart';
import '../features/address/address_screen.dart';
import '../features/offers/offers_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/premium/premium_screen.dart';
import '../auth/screens/login/login_screen.dart';
import '../auth/screens/otp/otp_screen.dart';
import '../auth/screens/location/location_permission_screen.dart';
import '../auth/screens/location/location_confirm_screen.dart';
import '../auth/screens/profile/complete_profile_screen.dart';
import '../features/bookings/my_bookings_screen.dart';

import '../features/referral/referral_screen.dart';
import '../features/rewards/rewards_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String otp = '/otp';
  static const String locationPermission = '/location-permission';
  static const String locationConfirm = '/location-confirm';
  static const String completeProfile = '/complete-profile';

  static const String home = '/home';
  static const String search = '/search';
  static const String orders = '/orders';
  static const String profile = '/profile';
  static const String restaurantDetails = '/restaurant/:id';
  static const String productDetails = '/product/:resId/:foodId';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String orderSuccess = '/order-success';
  static const String address = '/address';
  static const String offers = '/offers';
  static const String rewards = '/rewards';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String premium = '/premium';
  static const String bookings = '/bookings';
  static const String referral = '/referral';

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: otp,
        builder: (context, state) => const OtpScreen(),
      ),
      GoRoute(
        path: locationPermission,
        builder: (context, state) => const LocationPermissionScreen(),
      ),
      GoRoute(
        path: locationConfirm,
        builder: (context, state) => const LocationConfirmScreen(),
      ),
      GoRoute(
        path: completeProfile,
        builder: (context, state) => const CompleteProfileScreen(),
      ),

      // Bottom navigation shell routing
      ShellRoute(
        builder: (context, state, child) {
          return NavBase(child: child);
        },
        routes: [
          GoRoute(
            path: home,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: search,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SearchScreen(),
            ),
          ),
          GoRoute(
            path: cart,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CartScreen(),
            ),
          ),
          GoRoute(
            path: orders,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: OrdersScreen(),
            ),
          ),
          GoRoute(
            path: profile,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),

      // Stack details routes
      GoRoute(
        path: restaurantDetails,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return RestaurantDetailsScreen(restaurantId: id);
        },
      ),
      GoRoute(
        path: productDetails,
        builder: (context, state) {
          final resId = state.pathParameters['resId'] ?? '';
          final foodId = state.pathParameters['foodId'] ?? '';
          return ProductDetailsScreen(restaurantId: resId, foodId: foodId);
        },
      ),
      GoRoute(
        path: checkout,
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: orderSuccess,
        builder: (context, state) => const OrderSuccessScreen(),
      ),
      GoRoute(
        path: address,
        builder: (context, state) => const AddressScreen(),
      ),
      GoRoute(
        path: offers,
        builder: (context, state) => const OffersScreen(),
      ),
      GoRoute(
        path: rewards,
        builder: (context, state) => const RewardsScreen(),
      ),
      GoRoute(
        path: notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: premium,
        builder: (context, state) => const PremiumScreen(),
      ),
      GoRoute(
        path: bookings,
        builder: (context, state) => const MyBookingsScreen(),
      ),
      GoRoute(
        path: referral,
        builder: (context, state) => const ReferralScreen(),
      ),
    ],
  );
}

