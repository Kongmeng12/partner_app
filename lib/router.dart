import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth.dart';
import 'screens/auth_screens.dart';
import 'screens/bookings_screen.dart';
import 'screens/booking_detail_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/more_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/payouts_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/properties_screen.dart';
import 'screens/reviews_screen.dart';
import 'screens/shell.dart';
import 'screens/walk_in_screen.dart';

/// Lets go_router re-evaluate `redirect` whenever the auth stage changes.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _ref.listen(authProvider, (previous, next) {
      if (previous?.stage != next.stage) notifyListeners();
    });
  }
  // Held so the subscription lives as long as the router does.
  // ignore: unused_field
  final Ref _ref;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthListenable(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,

    /// One place decides which of the three worlds the app is in. Screens never
    /// navigate on sign-in or sign-out themselves — they change the auth state
    /// and this sends everyone to the right place.
    redirect: (context, state) {
      final stage = ref.read(authProvider).stage;
      final path = state.matchedLocation;

      final onAuthRoute = path == '/login' || path == '/register';

      switch (stage) {
        case AuthStage.restoring:
          // Hold on the splash until the stored session has been checked;
          // redirecting now would flash the login screen at every launch.
          return path == '/splash' ? null : '/splash';

        case AuthStage.signedOut:
          return onAuthRoute ? null : '/login';

        case AuthStage.pendingApproval:
          // Everything past approval answers 403, so there is nothing else to
          // show this partner yet.
          return path == '/pending' ? null : '/pending';

        case AuthStage.signedIn:
          if (onAuthRoute || path == '/pending' || path == '/splash') return '/';
          return null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/pending', builder: (_, __) => const PendingApprovalScreen()),

      // The five bottom-nav destinations share one scaffold so the bar does not
      // rebuild — and each keeps its own navigation stack.
      StatefulShellRoute.indexedStack(
        builder: (_, __, navigationShell) => PartnerShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, __) => const DashboardScreen(),
                routes: [
                  GoRoute(path: 'notifications', builder: (_, __) => const NotificationsScreen()),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/bookings',
                builder: (_, __) => const BookingsScreen(),
                routes: [
                  GoRoute(path: 'walk-in', builder: (_, __) => const WalkInScreen()),
                  GoRoute(
                    path: ':id',
                    builder: (_, s) => BookingDetailScreen(bookingId: s.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'chat',
                        builder: (_, s) => ChatScreen(bookingId: s.pathParameters['id']!),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/calendar', builder: (_, __) => const CalendarScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chats',
                builder: (_, __) => const ChatListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, s) => ChatScreen(bookingId: s.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (_, __) => const MoreScreen(),
                routes: [
                  GoRoute(path: 'properties', builder: (_, __) => const PropertiesScreen()),
                  GoRoute(path: 'payouts', builder: (_, __) => const PayoutsScreen()),
                  GoRoute(path: 'reviews', builder: (_, __) => const ReviewsScreen()),
                  GoRoute(path: 'profile', builder: (_, __) => const ProfileScreen()),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      appBar: AppBar(title: const Text('ບໍ່ພົບໜ້ານີ້')),
      body: Center(child: Text('ບໍ່ພົບເສັ້ນທາງ ${state.uri}')),
    ),
  );
});
