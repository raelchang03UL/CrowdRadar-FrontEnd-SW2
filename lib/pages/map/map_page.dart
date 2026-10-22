import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import '../../components/selector_categoria.dart';
import '../../cubits/places/categorias_cubit.dart';
import '../../components/cr_bottom_nav.dart';
import '../../components/place_catalog.dart';
import '../../components/place_map_controls.dart';
import '../../components/report_place_sheet.dart';
import '../../services/saturation_report_service.dart'
    show SaturationReportService;
import '../../components/saturation_panel.dart';
import '../../components/selector_saturacion.dart';
import '../../cubits/places/places_cubit.dart';
import '../../cubits/places/places_state.dart';
import '../../cubits/places/saturation_cubit.dart';
import '../../models/place_model.dart';
import '../../models/saturation_model.dart';
import '../../services/place_service.dart';
import '../../services/saturation_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';

class MapPage extends StatelessWidget {
  final PlaceService? service;
  final SaturationReportService? reportService;
  final TileProvider? tileProvider;
  final SaturationService? saturationService;
  const MapPage({
    super.key,
    this.service,
    this.reportService,
    this.tileProvider,
    this.saturationService,
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => PlacesCubit(service ?? PlaceService())..loadPlaces(),
    child: _MapView(
      service: service ?? PlaceService(),
      reportService: reportService ?? SaturationReportService(),
      tileProvider: tileProvider,
      saturationService: saturationService ?? SaturationService(),
    ),
  );
}

class _MapView extends StatelessWidget {
  final TileProvider? tileProvider;
  final SaturationService saturationService;
  final PlaceService service;
  final SaturationReportService reportService;
  const _MapView({
    this.tileProvider,
    required this.saturationService,
    required this.service,
    required this.reportService,
  });
  Future<void> _seleccionarCategoria(BuildContext context) async {
    final cubit = context.read<PlacesCubit>();
    final generacion = SessionService.generation;
    final categoria = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider(
        create: (_) => CategoriasCubit(service)..loadCategories(),
        child: SelectorCategoria(categoriaActual: cubit.categoria),
      ),
    );
    if (!context.mounted ||
        categoria == null ||
        generacion != SessionService.generation) {
      return;
    }
    await cubit.filterByCategory(categoria);
  }

  Future<void> _elegirNivel(BuildContext context) async {
    final cubit = context.read<PlacesCubit>();
    final generacion = SessionService.generation;
    final seleccion = await showModalBottomSheet<SeleccionNivelSaturacion>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (_) => SelectorSaturacion(nivelActual: cubit.nivelSaturacion),
    );
    if (!context.mounted ||
        cubit.isClosed ||
        !SessionService.isAuthenticated ||
        generacion != SessionService.generation ||
        seleccion == null) {
      return;
    }
    await cubit.filtrarPorSaturacion(seleccion.nivel);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Lugares'),
      centerTitle: false,
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Más opciones de lugares',
          onSelected: (_) => context.push('/places/search'),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'search', child: Text('Buscar en lista')),
          ],
        ),
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
        final nivel = context.read<PlacesCubit>().nivelSaturacion;
        final contenido = _contenido(context, state, nivel);
        return LayoutBuilder(
          builder: (context, espacio) => Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: espacio.maxHeight * 0.38,
                ),
                child: SingleChildScrollView(
                  key: const ValueKey('map-controls-scroll'),
                  child: PlaceMapControls(
                    cubit: context.read<PlacesCubit>(),
                    category: () => _seleccionarCategoria(context),
                    saturation: () => _elegirNivel(context),
                  ),
                ),
              ),
              Expanded(child: contenido),
            ],
          ),
        );
      },
    ),
    bottomNavigationBar: const CrBottomNav(currentIndex: 0),
  );

  Widget _contenido(
    BuildContext context,
    PlacesState state,
    SaturationLevel? nivel,
  ) {
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
          message:
              context.read<PlacesCubit>().consulta.isNotEmpty ||
                  (context.read<PlacesCubit>().categoria.isNotEmpty &&
                      nivel != null)
              ? 'No hay lugares que coincidan con los filtros.'
              : context.read<PlacesCubit>().categoria.isNotEmpty
              ? 'No hay lugares disponibles para esta categoría.'
              : nivel == null
              ? 'Aún no hay lugares disponibles.'
              : 'No hay lugares que coincidan con ese nivel de saturación.',
          icon: Icons.map_outlined,
          retry: context.read<PlacesCubit>().loadPlaces,
        );
      }
      return _PlacesMap(
        reportService: reportService,
        // Cada lista consultada retira la selección previa, incluso si la
        // respuesta inmediata no llegó a dibujar el estado de carga.
        key: ValueKey(state),
        places: state.places,
        tileProvider: tileProvider,
        saturationService: saturationService,
      );
    }
    return const _MapStatus(
      message: 'Inicia sesión para ver los lugares.',
      icon: Icons.lock_outline,
    );
  }
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
  final SaturationReportService reportService;
  final TileProvider? tileProvider;
  final SaturationService saturationService;
  const _PlacesMap({
    super.key,
    required this.places,
    required this.reportService,
    this.tileProvider,
    required this.saturationService,
  });
  @override
  State<_PlacesMap> createState() => _PlacesMapState();
}

class _PlacesMapState extends State<_PlacesMap> {
  PlaceModel? _selected;
  final MapController _mapController = MapController();
  bool _picking = false;
  bool _reporting = false;
  bool _catalogVisible = true;

  Future<void> _choosePlace({
    bool forReport = false,
    List<PlaceModel>? candidates,
  }) async {
    if (_picking || _reporting || !SessionService.isAuthenticated) return;
    _picking = true;
    final generation = SessionService.generation;
    PlaceModel? place;
    try {
      place = await showModalBottomSheet<PlaceModel>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 560),
        builder: (_) => PlacePickerSheet(
          places: candidates ?? widget.places,
          forReport: forReport,
        ),
      );
    } finally {
      _picking = false;
    }
    // Un selector abierto en una sesión anterior no puede iniciar un reporte.
    if (!mounted ||
        place == null ||
        !SessionService.isAuthenticated ||
        generation != SessionService.generation) {
      return;
    }
    _select(place);
    if (forReport) await _report(place);
  }

  Future<void> _report(PlaceModel place) async {
    if (_reporting || !SessionService.isAuthenticated) return;
    _reporting = true;
    final generation = SessionService.generation;
    bool? sent;
    try {
      sent = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        constraints: const BoxConstraints(maxWidth: 520),
        builder: (_) =>
            ReportPlaceSheet(place: place, service: widget.reportService),
      );
    } finally {
      _reporting = false;
    }
    if (!mounted ||
        generation != SessionService.generation ||
        !SessionService.isAuthenticated ||
        sent != true) {
      return;
    }
    await _saturationCubit.loadPlace(place.id);
  }

  late final SaturationCubit _saturationCubit;

  @override
  void initState() {
    super.initState();
    _saturationCubit = SaturationCubit(widget.saturationService);
  }

  void _select(PlaceModel place) {
    setState(() => _selected = place);
    _mapController.move(LatLng(place.latitud, place.longitud), 15);
    _saturationCubit.loadPlace(place.id);
  }

  void _clearSelection() {
    setState(() => _selected = null);
    _saturationCubit.clearSelection();
  }

  @override
  void dispose() {
    _saturationCubit.close();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Coincidencia exacta, no agrupación por proximidad ni desplazamiento de GPS.
    final groups = <String, List<PlaceModel>>{};
    for (final place in widget.places) {
      (groups['${place.latitud},${place.longitud}'] ??= []).add(place);
    }
    final points = groups.values
        .map((group) => LatLng(group.first.latitud, group.first.longitud))
        .toList();
    final demo = widget.places.any((p) => p.demostrativo);
    // El tema de formularios ocupa todo el ancho; las acciones del mapa son
    // compactas, pero conservan su tipografía, colores y formas compartidos.
    final compactButton = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12),
      ),
      textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.labelLarge),
    );
    final primaryAction = Theme.of(context).elevatedButtonTheme.style?.copyWith(
      minimumSize: compactButton.minimumSize,
      padding: compactButton.padding,
      textStyle: compactButton.textStyle,
    );
    final secondaryAction = Theme.of(context).outlinedButtonTheme.style
        ?.copyWith(
          minimumSize: compactButton.minimumSize,
          padding: compactButton.padding,
          textStyle: compactButton.textStyle,
        );
    return LayoutBuilder(
      builder: (context, espacio) => Column(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: espacio.maxHeight * 0.45),
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    bottom: BorderSide(color: AppColors.borderNav),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: (espacio.maxWidth - 48).clamp(0, 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.places.length == 1
                                ? '1 lugar disponible'
                                : '${widget.places.length} lugares disponibles',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            demo
                                ? 'Datos demostrativos · Sin monitoreo en tiempo real'
                                : 'Reportes ciudadanos sobre lugares registrados.',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        if (_selected == null)
                          FilledButton.icon(
                            key: const ValueKey('add-report'),
                            style: primaryAction,
                            onPressed: () => _choosePlace(forReport: true),
                            icon: const Icon(Icons.add_location_alt_outlined),
                            label: const Text('Agregar reporte'),
                          ),
                        if (espacio.maxWidth < 1100)
                          OutlinedButton.icon(
                            style: secondaryAction,
                            onPressed: _choosePlace,
                            icon: const Icon(Icons.format_list_bulleted),
                            label: const Text('Ver lista'),
                          ),
                        if (espacio.maxWidth >= 1100)
                          OutlinedButton.icon(
                            key: const ValueKey('toggle-catalog'),
                            style: secondaryAction,
                            onPressed: () => setState(
                              () => _catalogVisible = !_catalogVisible,
                            ),
                            icon: Icon(
                              _catalogVisible
                                  ? Icons.chevron_left
                                  : Icons.view_sidebar_outlined,
                            ),
                            label: Text(
                              _catalogVisible
                                  ? 'Ocultar catálogo'
                                  : 'Mostrar catálogo',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                if (espacio.maxWidth >= 1100 && _catalogVisible)
                  SizedBox(
                    width: 300,
                    child: PlaceCatalogPanel(
                      places: widget.places,
                      selectedId: _selected?.id,
                      onSelect: _select,
                    ),
                  ),
                Expanded(
                  key: const ValueKey('places-map-stage'),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: points.first,
                            initialZoom: 14,
                            initialCameraFit: points.length > 1
                                ? CameraFit.bounds(
                                    bounds: LatLngBounds.fromPoints(points),
                                    padding: EdgeInsets.all(
                                      (constraints.maxHeight * 0.15).clamp(
                                        8,
                                        60,
                                      ),
                                    ),
                                    maxZoom: 15,
                                  )
                                : null,
                            onTap: (_, _) => _clearSelection(),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.crowdradar',
                              tileProvider: widget.tileProvider,
                            ),
                            MarkerLayer(
                              markers: groups.values
                                  .map(
                                    (group) => Marker(
                                      key: ValueKey('marker-${group.first.id}'),
                                      point: LatLng(
                                        group.first.latitud,
                                        group.first.longitud,
                                      ),
                                      width: 48,
                                      height: 48,
                                      alignment: Alignment.topCenter,
                                      child: IconButton(
                                        key: ValueKey(
                                          'select-place-${group.first.id}',
                                        ),
                                        tooltip: group.length == 1
                                            ? group.first.nombre
                                            : '${group.length} lugares en este punto',
                                        padding: EdgeInsets.zero,
                                        onPressed: () => group.length == 1
                                            ? _select(group.first)
                                            : _choosePlace(candidates: group),
                                        icon: Badge(
                                          isLabelVisible: group.length > 1,
                                          label: Text('${group.length}'),
                                          child: Icon(
                                            Icons.location_on,
                                            size: 44,
                                            color:
                                                group.any(
                                                  (place) =>
                                                      _selected?.id == place.id,
                                                )
                                                ? AppColors.secondary
                                                : AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ],
                        ),
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Material(
                            color: AppColors.surface,
                            elevation: 2,
                            borderRadius: BorderRadius.circular(12),
                            child: IconButton(
                              tooltip: 'Ver todos los lugares',
                              icon: const Icon(Icons.fit_screen),
                              onPressed: () {
                                if (points.length == 1) {
                                  _mapController.move(points.first, 14);
                                } else {
                                  _mapController.fitCamera(
                                    CameraFit.bounds(
                                      bounds: LatLngBounds.fromPoints(points),
                                      padding: const EdgeInsets.all(48),
                                      maxZoom: 15,
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
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
                                constraints: BoxConstraints(
                                  maxWidth: 480,
                                  maxHeight:
                                      (constraints.maxHeight *
                                              (constraints.maxHeight < 400
                                                  ? 0.85
                                                  : 0.60))
                                          .clamp(0, 480),
                                ),
                                child: Material(
                                  elevation: 2,
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  child: SingleChildScrollView(
                                    key: const ValueKey(
                                      'saturation-selection-scroll',
                                    ),
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(
                                              Icons.place_outlined,
                                              color: AppColors.primary,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    place.nombre,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${place.categoria}${place.demostrativo ? ' · Demostrativo' : ''}',
                                                    style: const TextStyle(
                                                      color:
                                                          AppColors.textMuted,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  if (place.direccion ??
                                                          place.referencia
                                                      case final location?)
                                                    Tooltip(
                                                      message: location,
                                                      child: Text(
                                                        location,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: Theme.of(
                                                          context,
                                                        ).textTheme.bodySmall,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Cerrar identificación',
                                              onPressed: _clearSelection,
                                              icon: const Icon(
                                                Icons.close,
                                                size: 20,
                                              ),
                                            ),
                                          ],
                                        ),
                                        BlocBuilder<
                                          SaturationCubit,
                                          SaturationState
                                        >(
                                          bloc: _saturationCubit,
                                          builder: (context, state) => Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  FilledButton.icon(
                                                    style: primaryAction,
                                                    onPressed: () =>
                                                        _report(place),
                                                    icon: const Icon(
                                                      Icons
                                                          .add_location_alt_outlined,
                                                    ),
                                                    label: const Text(
                                                      'Reportar saturación',
                                                    ),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        context.push(
                                                          '/places/${place.id}',
                                                        ),
                                                    child: const Text(
                                                      'Ver detalles',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  TextButton(
                                                    onPressed: () => context.push(
                                                      '/places/${place.id}/history',
                                                    ),
                                                    child: const Text(
                                                      'Historial del lugar',
                                                    ),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        context.push(
                                                          '/profile/reports',
                                                        ),
                                                    child: const Text(
                                                      'Mis reportes',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SaturationPanel(
                                                compact: true,
                                                location:
                                                    place.direccion ??
                                                    place.referencia,
                                                key: ValueKey(
                                                  'saturation-panel-${place.id}',
                                                ),
                                                state: state.placeId == place.id
                                                    ? state
                                                    : const SaturationState(),
                                                retry: () => _saturationCubit
                                                    .loadPlace(place.id),
                                              ),
                                            ],
                                          ),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
