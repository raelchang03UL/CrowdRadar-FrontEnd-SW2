import 'package:go_router/go_router.dart';

import '../models/user_model.dart';
import '../services/session_service.dart';

import '../pages/login/login_page.dart';
import '../pages/register/register_page.dart';
import '../pages/map/map_page.dart';
import '../pages/validar/validar_page.dart';
import '../pages/favoritos/favoritos_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/profile/edit_profile_page.dart';
import '../pages/profile/change_password_page.dart';

final appRouter = createAppRouter();

GoRouter createAppRouter({String initialLocation = '/login'}) => GoRouter(
  initialLocation: initialLocation,
  refreshListenable: SessionService.changes,
  redirect: (context, state) {
    final isPublic =
        state.uri.path == '/login' || state.uri.path == '/register';
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
          'sessionExpired' => LoginNotice.sessionExpired,
          _ => null,
        },
      ),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(path: '/map', builder: (context, state) => const MapPage()),
    GoRoute(path: '/validar', builder: (context, state) => const ValidarPage()),
    GoRoute(
      path: '/favoritos',
      builder: (context, state) => const FavoritosPage(),
    ),
    GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
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
