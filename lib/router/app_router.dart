import 'package:go_router/go_router.dart';
import 'package:flutter/widgets.dart';

import '../models/user_model.dart';
import '../services/session_service.dart';
import '../services/recovery_service.dart';
import '../services/place_service.dart';
import '../pages/places/place_search_page.dart';
import '../pages/places/place_detail_page.dart';

import '../pages/login/login_page.dart';
import '../pages/register/register_page.dart';
import '../pages/login/forgot_password_page.dart';
import '../pages/login/reset_password_page.dart';
import '../pages/map/map_page.dart';
import '../pages/validar/validar_page.dart';
import '../pages/favoritos/favoritos_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/profile/edit_profile_page.dart';
import '../pages/profile/change_password_page.dart';
import '../pages/reports/report_history_page.dart';
import '../pages/reports/report_review_page.dart';
import '../pages/places/place_history_page.dart';

final appRouter = createAppRouter();

GoRouter createAppRouter({
  String initialLocation = '/login',
  RecoveryService? recoveryService,
  PlaceService? placeService,
}) => GoRouter(
  initialLocation: initialLocation,
  refreshListenable: SessionService.changes,
  redirect: (context, state) {
    final isPublic =
        state.uri.path == '/login' ||
        state.uri.path == '/register' ||
        state.uri.path == '/forgot-password' ||
        state.uri.path == '/reset-password';
    if (!SessionService.isAuthenticated && !isPublic) {
      return '/login';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => LoginPage(
        notice: switch (state.uri.queryParameters['notice']) {
          'passwordChanged' => LoginNotice.passwordChanged,
          'passwordReset' => LoginNotice.passwordReset,
          'sessionExpired' => LoginNotice.sessionExpired,
          _ => null,
        },
      ),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => ForgotPasswordPage(service: recoveryService),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => ResetPasswordPage(
        token: state.uri.queryParameters['token'] ?? '',
        service: recoveryService,
      ),
    ),
    GoRoute(
      path: '/map',
      builder: (context, state) => MapPage(service: placeService),
    ),
    GoRoute(
      path: '/places/search',
      builder: (context, state) => PlaceSearchPage(service: placeService),
    ),
    GoRoute(
      path: '/places/:id',
      builder: (context, state) => PlaceDetailPage(
        id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        service: placeService,
      ),
    ),
    GoRoute(
      path: '/reports/:id',
      builder: (context, state) => ReportReviewPage(
        key: ValueKey(state.uri.path),
        id: state.pathParameters['id'] ?? '',
      ),
    ),
    GoRoute(
      path: '/profile/reports/:id/validation',
      builder: (context, state) => ReportReviewPage(
        key: ValueKey(state.uri.path),
        id: state.pathParameters['id'] ?? '',
        ownOnly: true,
      ),
    ),
    GoRoute(
      path: '/places/:id/history',
      builder: (context, state) => PlaceHistoryPage(
        key: ValueKey(state.uri.path),
        id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
      ),
    ),
    GoRoute(path: '/validar', builder: (context, state) => const ValidarPage()),
    GoRoute(
      path: '/favoritos',
      builder: (context, state) => const FavoritosPage(),
    ),
    GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
    GoRoute(
      path: '/profile/reports',
      builder: (context, state) => const ReportHistoryPage(),
    ),
    GoRoute(
      path: '/profile/password',
      builder: (context, state) => const ChangePasswordPage(),
    ),
    GoRoute(
      path: '/profile/edit',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return EditProfilePage(
          user: extra != null ? UserModel.fromJson(extra) : null,
        );
      },
    ),
  ],
);
