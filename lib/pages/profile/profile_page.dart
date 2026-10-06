import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../cubits/profile/profile_cubit.dart';
import '../../cubits/profile/profile_state.dart';
import '../../cubits/login_cubit.dart';

import '../../services/user_service.dart';

import '../../components/cr_bottom_nav.dart';

import '../../theme/app_colors.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProfileCubit(UserService())..loadProfile(),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatefulWidget {
  const _ProfileView();

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      bottomNavigationBar: const CrBottomNav(currentIndex: 3),
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          if (state is ProfileLoading || state is ProfileInitial) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (state is ProfileError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<ProfileCubit>().loadProfile(),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          final loaded = state as ProfileLoaded;
          final user = loaded.user;

          final nombre = (user.nombre ?? '').trim();
          final apellido = (user.apellido ?? '').trim();
          final initials =
              ((nombre.isNotEmpty ? nombre[0] : '') +
                      (apellido.isNotEmpty ? apellido[0] : ''))
                  .toUpperCase();
          final fullName = '${user.nombre ?? ''} ${user.apellido ?? ''}'.trim();

          Widget eyebrow(String text) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.6,
                    color: AppColors.textMuted,
                  ),
                ),
              );

          Widget infoCard(IconData icon, String label, String value) =>
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              value,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Container(
                width: double.infinity,
                color: AppColors.primary,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Text(
                        initials.isEmpty ? '?' : initials,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email ?? '-',
                            style: const TextStyle(
                              color: AppColors.onPrimaryMuted,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              eyebrow('CUENTA'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      await context.push('/profile/edit',
                          extra: loaded.user.toJson());
                      if (context.mounted) {
                        context.read<ProfileCubit>().loadProfile();
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.edit,
                                color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'Editar perfil',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              eyebrow('INFORMACIÓN'),
              infoCard(Icons.phone, 'Teléfono', user.telefono ?? '-'),
              infoCard(
                  Icons.location_city, 'Distrito', user.distrito ?? '-'),
              infoCard(Icons.verified_user, 'Rol', user.rol ?? '-'),
              infoCard(Icons.info_outline, 'Estado', user.status ?? '-'),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      context.read<AuthCubit>().logout();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.logout,
                                color: AppColors.danger, size: 20),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'Cerrar sesión',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
