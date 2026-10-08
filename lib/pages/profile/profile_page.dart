import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../components/cr_bottom_nav.dart';
import '../../cubits/login_cubit.dart';
import '../../cubits/profile/profile_cubit.dart';
import '../../cubits/profile/profile_state.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../theme/app_colors.dart';

class ProfilePage extends StatelessWidget {
  final UserService? userService;
  const ProfilePage({super.key, this.userService});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ProfileCubit(userService ?? UserService())..loadProfile(),
    child: const _ProfileView(),
  );
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mi perfil')),
    bottomNavigationBar: const CrBottomNav(currentIndex: 3),
    body: SafeArea(
      child: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (state is ProfileLoading || state is ProfileInitial)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Cargando tu perfil…'),
                      ],
                    ),
                  )
                else if (state is ProfileError)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(Icons.person_outline, size: 32),
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              state.message,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () =>
                                context.read<ProfileCubit>().loadProfile(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (state is ProfileLoaded)
                  ..._profile(context, state.user),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  List<Widget> _profile(BuildContext context, UserModel user) {
    final name = (user.nombre ?? '').trim();
    final surname = (user.apellido ?? '').trim();
    final initials =
        '${name.isEmpty ? '' : name.characters.first}${surname.isEmpty ? '' : surname.characters.first}'
            .toUpperCase();
    final fullName = '$name $surname'.trim();
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                foregroundColor: AppColors.primary,
                child: Text(
                  initials.isEmpty ? '?' : initials,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                fullName.isEmpty ? 'Ciudadano' : fullName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _value(user.email),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      Text(
        'Datos de tu cuenta',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      Text(
        'Revisa y mantén actualizada tu información personal.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
      ),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            children: [
              _ProfileDatum(
                Icons.phone_outlined,
                'Teléfono',
                _value(user.telefono),
              ),
              const Divider(height: 1),
              _ProfileDatum(
                Icons.location_city_outlined,
                'Distrito',
                _value(user.distrito),
              ),
              const Divider(height: 1),
              _ProfileDatum(Icons.badge_outlined, 'Rol', _value(user.rol)),
              const Divider(height: 1),
              _ProfileDatum(
                Icons.verified_user_outlined,
                'Estado',
                _value(user.status),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Editar perfil'),
        onPressed: () async {
          await context.push('/profile/edit', extra: user.toJson());
          if (context.mounted) context.read<ProfileCubit>().loadProfile();
        },
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        icon: const Icon(Icons.lock_outline),
        label: const Text('Cambiar contraseña'),
        onPressed: () => context.push('/profile/password'),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        icon: const Icon(Icons.logout),
        label: const Text('Cerrar sesión'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: const BorderSide(color: AppColors.danger),
        ),
        onPressed: () => context.read<AuthCubit>().logout(),
      ),
    ];
  }

  String _value(String? value) =>
      value == null || value.trim().isEmpty ? 'No registrado' : value;
}

class _ProfileDatum extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ProfileDatum(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: Icon(icon, color: AppColors.primary, size: 22)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    ),
  );
}
