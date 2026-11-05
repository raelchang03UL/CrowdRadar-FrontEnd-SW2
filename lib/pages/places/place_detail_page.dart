import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../components/place_status.dart';
import '../../components/push_transition_banner.dart';
import '../../cubits/places/place_detail_cubit.dart';
import '../../services/place_service.dart';
import '../../services/push_message_guard.dart';

class PlaceDetailPage extends StatelessWidget {
  final int id;
  final PlaceService? service;
  final AuthorizedPushTransition? pushTransition;
  const PlaceDetailPage({
    super.key,
    required this.id,
    this.service,
    this.pushTransition,
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
    key: ValueKey(id),
    create: (_) => PlaceDetailCubit(service ?? PlaceService(), id)..loadPlace(),
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Información del lugar'),
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/map'),
        ),
      ),
      body: BlocBuilder<PlaceDetailCubit, PlaceDetailState>(
        builder: (context, state) {
          if (state is PlaceDetailLoading) {
            return const PlaceStatus(
              message: 'Cargando información…',
              loading: true,
            );
          }
          if (state is PlaceDetailError) {
            return PlaceStatus(
              message: state.message,
              retry: context.read<PlaceDetailCubit>().loadPlace,
            );
          }
          if (state is! PlaceDetailLoaded) {
            return const PlaceStatus(
              message: 'Inicia sesión para ver los lugares.',
            );
          }
          final lugar = state.place;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: SizedBox(
                  width: double.infinity,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Dato(
                            titulo: 'Nombre',
                            valor: lugar.nombre,
                            prominent: true,
                          ),
                          _Dato(titulo: 'Categoría', valor: lugar.categoria),
                          if (pushTransition != null && lugar.id == id)
                            PushTransitionBanner(
                              alert: pushTransition!,
                              placeId: lugar.id,
                            ),
                          if (lugar.demostrativo) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.info_outline, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Lugar demostrativo · Datos ilustrativos, no verificados. Sin monitoreo en tiempo real.',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (lugar.esFavorito) const Text('En tus favoritos'),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: state.saving
                                ? null
                                : () async {
                                    final result = await context
                                        .read<PlaceDetailCubit>()
                                        .toggleFavorite();
                                    if (!context.mounted || result == null) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(result.message)),
                                    );
                                  },
                            icon: state.saving
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    lugar.esFavorito
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                  ),
                            label: Text(
                              lugar.esFavorito
                                  ? 'Quitar de favoritos'
                                  : 'Agregar a favoritos',
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () =>
                                context.push('/places/${lugar.id}/history'),
                            icon: const Icon(Icons.history),
                            label: const Text('Historial de saturación'),
                          ),
                          const Divider(height: 40),
                          _Dato(
                            titulo: 'Dirección',
                            valor: lugar.direccion ?? 'Dirección no registrada',
                          ),
                          if (lugar.referencia?.trim().isNotEmpty ?? false)
                            _Dato(
                              titulo: 'Referencia',
                              valor: lugar.referencia!,
                            ),
                          _Dato(
                            titulo: 'Coordenadas',
                            valor: '${lugar.latitud}, ${lugar.longitud}',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _Dato extends StatelessWidget {
  final String titulo, valor;
  final bool prominent;
  const _Dato({
    required this.titulo,
    required this.valor,
    this.prominent = false,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        SelectableText(
          valor,
          style: prominent
              ? Theme.of(context).textTheme.headlineSmall
              : Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    ),
  );
}
