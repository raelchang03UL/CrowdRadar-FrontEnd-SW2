import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../components/cr_bottom_nav.dart';
import '../../components/push_alerts_control.dart';
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
        builder: (context, state) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 24,
                      runSpacing: 8,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                'Tus lugares guardados',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            if (state is FavoritesLoaded) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${state.places.length} ${state.places.length == 1 ? 'lugar' : 'lugares'}',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ],
                        ),
                        const PushAlertsControl(),
                      ],
                    ),
                  ),
                ),
                _FavoritesContent(state: state),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const CrBottomNav(currentIndex: 2),
    ),
  );
}

class _FavoritesContent extends StatelessWidget {
  final FavoritesState state;
  const _FavoritesContent({required this.state});

  @override
  Widget build(BuildContext context) {
    final current = state;
    if (current is FavoritesLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (current is FavoritesError) {
      return _FavoritesMessage(
        icon: Icons.cloud_off_outlined,
        title: current.message,
        action: TextButton.icon(
          onPressed: context.read<FavoritesCubit>().loadFavorites,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      );
    }
    if (current is FavoritesLoaded) {
      if (current.places.isEmpty) {
        return const _FavoritesMessage(
          icon: Icons.favorite_border,
          title: 'Sin favoritos todavía',
          subtitle:
              'Los lugares que marques como favoritos van a aparecer acá.',
        );
      }
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        sliver: SliverList.separated(
          itemCount: current.places.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final place = current.places[index];
            final removing = current.removing.contains(place.id);
            final openPlace = Semantics(
              button: true,
              container: true,
              child: InkWell(
                key: ValueKey('favorite-place-${place.id}'),
                onTap: removing
                    ? null
                    : () => context.push('/places/${place.id}').then((_) {
                        if (context.mounted) {
                          context.read<FavoritesCubit>().loadFavorites();
                        }
                      }),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.favorite,
                          color: Theme.of(context).colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place.nombre,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${place.categoria}${place.demostrativo ? ' · Demostrativo' : ''}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, size: 20),
                    ],
                  ),
                ),
              ),
            );
            final remove = Tooltip(
              message: 'Quitar de favoritos',
              child: TextButton.icon(
                onPressed: removing
                    ? null
                    : () async {
                        final result = await context
                            .read<FavoritesCubit>()
                            .removeFavorite(place.id);
                        if (!context.mounted || result == null) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(result.message)));
                      },
                icon: removing
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.favorite_border, size: 20),
                label: const Text('Quitar'),
              ),
            );
            return Card(
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 520 ||
                      MediaQuery.textScalerOf(context).scale(14) > 18) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        openPlace,
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: remove,
                          ),
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: openPlace),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: remove,
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      );
    }
    return const _FavoritesMessage(
      icon: Icons.lock_outline,
      title: 'Inicia sesión para ver tus favoritos.',
    );
  }
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
  Widget build(BuildContext context) => SliverFillRemaining(
    hasScrollBody: false,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    ),
  );
}
