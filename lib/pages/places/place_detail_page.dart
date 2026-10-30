import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../components/place_status.dart';
import '../../cubits/places/place_detail_cubit.dart';
import '../../services/place_service.dart';

class PlaceDetailPage extends StatelessWidget {
  final int id;
  final PlaceService? service;
  const PlaceDetailPage({super.key, required this.id, this.service});

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
            padding: const EdgeInsets.all(24),
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
                          if (lugar.demostrativo) ...[
                            const Text(
                              'Lugar demostrativo · Datos ilustrativos, no verificados. Sin monitoreo en tiempo real.',
                            ),
                            const SizedBox(height: 24),
                          ],
                          _Dato(titulo: 'Nombre', valor: lugar.nombre),
                          _Dato(
                            titulo: 'Dirección',
                            valor: lugar.direccion ?? 'Dirección no registrada',
                          ),
                          _Dato(titulo: 'Categoría', valor: lugar.categoria),
                          _Dato(
                            titulo: 'Coordenadas',
                            valor: '${lugar.latitud}, ${lugar.longitud}',
                          ),
                          if (lugar.esFavorito) const Text('En tus favoritos'),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
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
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () =>
                                context.push('/places/${lugar.id}/history'),
                            icon: const Icon(Icons.history),
                            label: const Text('Historial de saturación'),
                          ),
                          const SizedBox(height: 16),
                          if (lugar.referencia?.trim().isNotEmpty ?? false)
                            _Dato(
                              titulo: 'Referencia',
                              valor: lugar.referencia!,
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
  const _Dato({required this.titulo, required this.valor});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SelectableText(valor, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}
