import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../components/cr_bottom_nav.dart';
import '../../cubits/places/places_cubit.dart';
import '../../cubits/places/places_state.dart';
import '../../models/place_model.dart';
import '../../services/place_service.dart';
import '../../theme/app_colors.dart';

class MapPage extends StatelessWidget {
  final PlaceService? service;
  final TileProvider? tileProvider;
  const MapPage({super.key, this.service, this.tileProvider});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => PlacesCubit(service ?? PlaceService())..loadPlaces(),
    child: _MapView(tileProvider: tileProvider),
  );
}

class _MapView extends StatelessWidget {
  final TileProvider? tileProvider;
  const _MapView({this.tileProvider});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Lugares'),
      centerTitle: false,
      actions: [
        BlocBuilder<PlacesCubit, PlacesState>(
          builder: (context, state) => IconButton(
            tooltip: 'Actualizar lugares',
            icon: const Icon(Icons.refresh),
            onPressed: state is PlacesLoading
                ? null
                : context.read<PlacesCubit>().loadPlaces,
          ),
        ),
      ],
    ),
    body: BlocBuilder<PlacesCubit, PlacesState>(
      builder: (context, state) {
        if (state is PlacesLoading) {
          return const _MapStatus(message: 'Cargando lugares…', loading: true);
        }
        if (state is PlacesError) {
          return _MapStatus(
            message: state.message,
            icon: Icons.cloud_off_outlined,
            retry: context.read<PlacesCubit>().loadPlaces,
          );
        }
        if (state is PlacesLoaded) {
          if (state.places.isEmpty) {
            return _MapStatus(
              message: 'Aún no hay lugares disponibles.',
              icon: Icons.map_outlined,
              retry: context.read<PlacesCubit>().loadPlaces,
            );
          }
          return _PlacesMap(places: state.places, tileProvider: tileProvider);
        }
        return const _MapStatus(
          message: 'Inicia sesión para ver los lugares.',
          icon: Icons.lock_outline,
        );
      },
    ),
    bottomNavigationBar: const CrBottomNav(currentIndex: 0),
  );
}

class _MapStatus extends StatelessWidget {
  final String message;
  final bool loading;
  final IconData? icon;
  final VoidCallback? retry;
  const _MapStatus({
    required this.message,
    this.loading = false,
    this.icon,
    this.retry,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const CircularProgressIndicator()
                else
                  Icon(icon, size: 44, color: AppColors.primary),
                const SizedBox(height: 20),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (retry != null) ...[
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PlacesMap extends StatefulWidget {
  final List<PlaceModel> places;
  final TileProvider? tileProvider;
  const _PlacesMap({required this.places, this.tileProvider});
  @override
  State<_PlacesMap> createState() => _PlacesMapState();
}

class _PlacesMapState extends State<_PlacesMap> {
  PlaceModel? _selected;

  @override
  Widget build(BuildContext context) {
    final points = widget.places
        .map((p) => LatLng(p.latitud, p.longitud))
        .toList();
    final demo = widget.places.any((p) => p.demostrativo);
    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.borderNav)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.places.length} lugares disponibles',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                demo
                    ? 'Datos demostrativos · Sin monitoreo en tiempo real'
                    : 'Selecciona un marcador para identificar el lugar.',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: points.first,
                  initialZoom: 14,
                  initialCameraFit: points.length > 1
                      ? CameraFit.bounds(
                          bounds: LatLngBounds.fromPoints(points),
                          padding: const EdgeInsets.all(60),
                          maxZoom: 15,
                        )
                      : null,
                  onTap: (_, _) => setState(() => _selected = null),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.crowdradar',
                    tileProvider: widget.tileProvider,
                  ),
                  MarkerLayer(
                    markers: widget.places
                        .map(
                          (place) => Marker(
                            key: ValueKey('marker-${place.id}'),
                            point: LatLng(place.latitud, place.longitud),
                            width: 48,
                            height: 48,
                            alignment: Alignment.topCenter,
                            child: IconButton(
                              key: ValueKey('select-place-${place.id}'),
                              tooltip: place.nombre,
                              padding: EdgeInsets.zero,
                              onPressed: () =>
                                  setState(() => _selected = place),
                              icon: Icon(
                                Icons.location_on,
                                size: 44,
                                color: _selected?.id == place.id
                                    ? AppColors.secondary
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ),
              Positioned(
                left: 8,
                bottom: 4,
                right: 8,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: ColoredBox(
                    color: AppColors.surface,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        '© OpenStreetMap contributors · openstreetmap.org/copyright',
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(fontSize: 9),
                      ),
                    ),
                  ),
                ),
              ),
              if (_selected case final place?)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 34,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Material(
                        elevation: 2,
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.place_outlined,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      place.nombre,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${place.categoria}${place.demostrativo ? ' · Demostrativo' : ''}',
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Cerrar identificación',
                                onPressed: () =>
                                    setState(() => _selected = null),
                                icon: const Icon(Icons.close, size: 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
