import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../main.dart';
import '../../features/authentication/presentation/login_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/focus_now/presentation/focus_now_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../shared/providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final token = ref.watch(authTokenProvider);
  final user = ref.watch(authUserProvider);
  final isLoggedIn = token != null || user != null;

  // The personalize / onboarding section should ONLY show to NEW accounts.
  // Existing accounts (isNewUser != true) must NEVER see the personalize section.
  bool isNewAccountNeedingPersonalization = false;

  if (isLoggedIn && user != null) {
    final isNewUserFlag = user['isNewUser'] == true;
    final userEmail = user['email'] ?? user['id'] ?? 'guest';

    String? localCompleted;
    if (kIsWeb) {
      try {
        localCompleted = html.window.localStorage['remell_onboarding_completed_$userEmail'];
      } catch (_) {}
    }

    // ONLY show personalize if the account is explicitly marked as new (isNewUser == true)
    // AND has not completed the personalize section yet.
    if (isNewUserFlag && localCompleted != 'true') {
      isNewAccountNeedingPersonalization = true;
    }
  }

  return GoRouter(
    initialLocation: !isLoggedIn
        ? '/login'
        : (isNewAccountNeedingPersonalization ? '/onboarding' : '/home'),
    redirect: (BuildContext context, GoRouterState state) {
      final currentPath = state.uri.path;
      final isLoggingIn = currentPath == '/login';
      final isOnboarding = currentPath == '/onboarding';

      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }

      if (isLoggedIn) {
        if (isNewAccountNeedingPersonalization) {
          // New account must complete the personalize section first
          if (!isOnboarding) {
            return '/onboarding';
          }
        } else {
          // Existing account or already personalized: NEVER show personalize or login screen
          if (isLoggingIn || isOnboarding) {
            return '/home';
          }
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const MainNavigationShell(),
      ),
      GoRoute(
        path: '/focus',
        builder: (context, state) => const FocusNowScreen(),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});

// Legacy router instance for backward compatibility
final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const MainNavigationShell(),
    ),
    GoRoute(
      path: '/focus',
      builder: (context, state) => const FocusNowScreen(),
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
