import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../components/cr_bottom_nav.dart';
import '../../cubits/favorites/favorites_cubit.dart';
import '../../cubits/favorites/favorites_state.dart';
import '../../services/place_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';

class FavoritosPage extends StatelessWidget {
  final PlaceService? service;

  const FavoritosPage({super.key, this.service});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => FavoritesCubit(service ?? PlaceService())..loadFavorites(),
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Favoritos'),
        actions: const [_AlertsButton()],
      ),
      body: BlocBuilder<FavoritesCubit, FavoritesState>(
        builder: (context, state) {
          if (state is FavoritesLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is FavoritesError) {
            return _FavoritesMessage(
              icon: Icons.cloud_off_outlined,
              title: state.message,
              action: TextButton.icon(
                onPressed: context.read<FavoritesCubit>().loadFavorites,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            );
          }
          if (state is FavoritesLoaded) {
            if (state.places.isEmpty) {
              return const _FavoritesMessage(
                icon: Icons.favorite_border,
                title: 'Sin favoritos todavía',
                subtitle:
                    'Los lugares que marques como favoritos van a aparecer acá.',
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.places.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final place = state.places[index];
                    return Card(
                      child: ListTile(
                        key: ValueKey('favorite-place-${place.id}'),
                        leading: const Icon(
                          Icons.favorite,
                          color: AppColors.secondary,
                        ),
                        title: Text(place.nombre),
                        subtitle: Text(
                          '${place.categoria}${place.demostrativo ? ' · Demostrativo' : ''}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Quitar de favoritos',
                          onPressed: state.removing.contains(place.id)
                              ? null
                              : () async {
                                  final result = await context
                                      .read<FavoritesCubit>()
                                      .removeFavorite(place.id);
                                  if (!context.mounted || result == null) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(result.message)),
                                  );
                                },
                          icon: state.removing.contains(place.id)
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.heart_broken_outlined),
                        ),
                        onTap: state.removing.contains(place.id)
                            ? null
                            : () =>
                                  context.push('/places/${place.id}').then((_) {
                                    if (context.mounted) {
                                      context
                                          .read<FavoritesCubit>()
                                          .loadFavorites();
                                    }
                                  }),
                      ),
                    );
                  },
                ),
              ),
            );
          }
          return const _FavoritesMessage(
            icon: Icons.lock_outline,
            title: 'Inicia sesión para ver tus favoritos.',
          );
        },
      ),
      bottomNavigationBar: const CrBottomNav(currentIndex: 2),
    ),
  );
}

class _AlertsButton extends StatefulWidget {
  const _AlertsButton();

  @override
  State<_AlertsButton> createState() => _AlertsButtonState();
}

class _AlertsButtonState extends State<_AlertsButton> {
  bool _enabling = false;

  Future<void> _enable() async {
    final generation = SessionService.generation;
    final push = PushNotificationService.instance;
    final configured = push.isConfigured;
    setState(() => _enabling = true);
    final enabled = configured && await push.enableForCurrentSession();
    if (!mounted) return;
    setState(() => _enabling = false);
    if (generation != SessionService.generation) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !configured
              ? 'Las alertas aún no están disponibles.'
              : enabled
              ? 'Alertas activadas en este dispositivo.'
              : 'No se pudieron activar las alertas. Revisa los permisos del navegador.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Activar alertas',
    onPressed: _enabling ? null : _enable,
    icon: _enabling
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.notifications_outlined),
  );
}

class _FavoritesMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const _FavoritesMessage({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Icon(icon, size: 40, color: AppColors.secondary),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    ),
  );
}
