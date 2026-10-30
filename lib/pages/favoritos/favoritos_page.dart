import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../components/cr_bottom_nav.dart';
import '../../cubits/favorites/favorites_cubit.dart';
import '../../cubits/favorites/favorites_state.dart';
import '../../services/place_service.dart';
import '../../theme/app_colors.dart';

class FavoritosPage extends StatelessWidget {
  final PlaceService? service;

  const FavoritosPage({super.key, this.service});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => FavoritesCubit(service ?? PlaceService())..loadFavorites(),
    child: Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
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
                subtitle: 'Los lugares que marques como favoritos van a aparecer acá.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.places.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final place = state.places[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.favorite,
                      color: AppColors.secondary,
                    ),
                    title: Text(place.nombre),
                    subtitle: Text(
                      '${place.categoria}${place.demostrativo ? ' · Demostrativo' : ''}',
                    ),
                  ),
                );
              },
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
