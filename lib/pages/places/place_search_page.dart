import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../components/place_status.dart';
import '../../cubits/places/places_cubit.dart';
import '../../cubits/places/places_state.dart';
import '../../services/place_service.dart';

class PlaceSearchPage extends StatelessWidget {
  final PlaceService? service;
  const PlaceSearchPage({super.key, this.service});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => PlacesCubit(service ?? PlaceService())..loadPlaces(),
    child: const _Busqueda(),
  );
}

class _Busqueda extends StatefulWidget {
  const _Busqueda();
  @override
  State<_Busqueda> createState() => _BusquedaState();
}

class _BusquedaState extends State<_Busqueda> {
  final _nombre = TextEditingController();
  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  void _buscar() {
    FocusScope.of(context).unfocus();
    context.read<PlacesCubit>().searchPlaces(_nombre.text);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Buscar lugares'),
      leading: IconButton(
        tooltip: 'Volver',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.canPop() ? context.pop() : context.go('/map'),
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _nombre,
                maxLength: 160,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _buscar(),
                decoration: InputDecoration(
                  labelText: 'Nombre del lugar',
                  hintText: 'Nombre completo o parcial',
                  suffixIcon: IconButton(
                    tooltip: 'Limpiar búsqueda',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _nombre.clear();
                      _buscar();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _buscar,
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar'),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: BlocBuilder<PlacesCubit, PlacesState>(
                  builder: (context, state) {
                    final cubit = context.read<PlacesCubit>();
                    if (state is PlacesLoading) {
                      return const PlaceStatus(
                        message: 'Buscando lugares…',
                        loading: true,
                      );
                    }
                    if (state is PlacesError) {
                      return PlaceStatus(
                        message: state.message,
                        retry: cubit.loadPlaces,
                      );
                    }
                    if (state is! PlacesLoaded) {
                      return const PlaceStatus(
                        message: 'Inicia sesión para ver los lugares.',
                      );
                    }
                    if (state.places.isEmpty) {
                      return PlaceStatus(
                        message: cubit.consulta.isEmpty
                            ? 'Aún no hay lugares disponibles.'
                            : 'No se encontraron lugares con ese nombre.',
                      );
                    }
                    return ListView(
                      children: [
                        Text(
                          '${state.places.length} ${state.places.length == 1 ? 'resultado' : 'resultados'}${cubit.consulta.isEmpty ? '' : ' para “${cubit.consulta}”'}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        for (final lugar in state.places)
                          Card(
                            child: ListTile(
                              key: ValueKey('result-place-${lugar.id}'),
                              title: Text(lugar.nombre),
                              subtitle: Text(
                                '${lugar.categoria}${lugar.demostrativo ? ' · Demostrativo' : ''}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push('/places/${lugar.id}'),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
