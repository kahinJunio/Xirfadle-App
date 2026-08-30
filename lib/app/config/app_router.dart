import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/user_role.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/customer/presentation/create_request_screen.dart';
import '../../features/customer/presentation/customer_home_screen.dart';
import '../../features/customer/presentation/customer_request_detail_screen.dart';
import '../../features/customer/presentation/customer_request_history_screen.dart';
import '../../features/customer/presentation/provider_detail_screen.dart';
import '../../features/customer/presentation/request_confirmation_screen.dart';
import '../../features/provider/presentation/active_job_screen.dart';
import '../../features/provider/presentation/job_detail_screen.dart';
import '../../features/provider/presentation/provider_dashboard.dart';
import '../../features/provider/presentation/provider_requests_screen.dart';
import '../../features/shared/presentation/app_shell.dart';
import '../../features/shared/presentation/profile_screen.dart';
import 'app_routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Bridges the Riverpod auth state into go_router's refresh mechanism.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) {
        // Only a change of identity or role can alter routing.
        if (previous?.status != next.status ||
            previous?.user?.activeRole != next.user?.activeRole) {
          notifyListeners();
        }
      },
      fireImmediately: true,
    );
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshNotifier,
    debugLogDiagnostics: false,

    /// Navigation guard: keeps signed-out users in the auth flow and sends
    /// signed-in users to the dashboard matching their JWT role claim.
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      // Session still being restored — hold on the splash screen.
      if (auth.isResolving) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final onAuthScreen = location == AppRoutes.login ||
          location == AppRoutes.register ||
          location == AppRoutes.splash;

      if (!auth.isAuthenticated) {
        return onAuthScreen && location != AppRoutes.splash
            ? null
            : AppRoutes.login;
      }

      final home = auth.user!.activeRole == UserRole.provider
          ? AppRoutes.providerHome
          : AppRoutes.customerHome;

      if (onAuthScreen) return home;

      // Keep each role inside its own section of the app.
      final isProviderArea = location.startsWith('/provider');
      final isCustomerArea = location.startsWith('/customer');
      final wantsProvider = auth.user!.activeRole == UserRole.provider;
      if (wantsProvider && isCustomerArea) return home;
      if (!wantsProvider && isProviderArea) return home;

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProfileScreen(),
      ),

      // ---- Customer mode --------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(
          navigationShell: navigationShell,
          destinations: customerDestinations,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.customerHome,
                builder: (context, state) => const CustomerHomeScreen(),
                routes: [
                  GoRoute(
                    path: 'providers/:id',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => ProviderDetailScreen(
                      providerId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.myRequests,
                builder: (context, state) =>
                    const CustomerRequestHistoryScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => CustomerRequestDetailScreen(
                      requestId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.createRequest,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateRequestScreen(),
      ),
      GoRoute(
        path: AppRoutes.requestConfirmation,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RequestConfirmationScreen(),
      ),

      // ---- Skilled person mode -------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(
          navigationShell: navigationShell,
          destinations: providerDestinations,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.providerHome,
                builder: (context, state) => const ProviderDashboard(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.providerRequests,
                builder: (context, state) => const ProviderRequestsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => JobDetailScreen(
                      requestId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.providerActiveJob,
                builder: (context, state) => const ActiveJobScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_rounded, size: 48),
              const SizedBox(height: 12),
              Text(
                'No screen matches ${state.uri}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => context.go(AppRoutes.splash),
                child: const Text('Go home'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});
