import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'screens/auth_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/event_create_screen.dart';
import 'screens/event_detail_screen.dart';
import 'screens/events_discovery_screen.dart';
import 'screens/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final pubkey = ref.read(Signer.activePubkeyProvider);
      final location = state.uri.path;
      
      // If not signed in and not on auth screen, redirect to auth
      if (pubkey == null && location != '/auth') {
        return '/auth';
      }
      
      // If signed in and on auth or root, redirect to calendar
      if (pubkey != null && (location == '/auth' || location == '/')) {
        return '/calendar';
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/calendar',
        builder: (context, state) => const CalendarScreen(),
      ),
      GoRoute(
        path: '/event/create',
        builder: (context, state) => const EventCreateScreen(),
      ),
      GoRoute(
        path: '/events',
        builder: (context, state) => const EventsDiscoveryScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/event/:eventId',
        builder: (context, state) {
          final eventId = state.pathParameters['eventId']!;
          final eventData = state.extra as Map<String, dynamic>?;
          return EventDetailScreen(
            eventId: eventId,
            eventData: eventData,
          );
        },
      ),
    ],
  );
});
