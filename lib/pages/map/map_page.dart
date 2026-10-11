import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../components/cr_bottom_nav.dart';
import '../../configs/generic_response.dart';
import '../../cubits/places/places_cubit.dart';
import '../../cubits/places/places_state.dart';
import '../../models/place_model.dart';
import '../../services/place_service.dart';
import '../../services/saturation_report_service.dart';
import '../../theme/app_colors.dart';

class MapPage extends StatelessWidget {
  final PlaceService? service;
  final SaturationReportService? reportService;
  final TileProvider? tileProvider;
  const MapPage({super.key, this.service, this.reportService, this.tileProvider});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => PlacesCubit(service ?? PlaceService())..loadPlaces(),
    child: _MapView(
      reportService: reportService ?? SaturationReportService(),
      tileProvider: tileProvider,
    ),
  );
}

class _MapView extends StatelessWidget {
  final SaturationReportService? reportService;
  final TileProvider? tileProvider;
  const _MapView({this.reportService, this.tileProvider});

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
          return _PlacesMap(
            places: state.places,
            reportService: reportService,
            tileProvider: tileProvider,
          );
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
  final SaturationReportService? reportService;
  final TileProvider? tileProvider;
  const _PlacesMap({
    required this.places,
    this.reportService,
    this.tileProvider,
  });
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
                                tooltip: 'Reportar saturación',
                                onPressed: widget.reportService == null
                                    ? null
                                    : () => _showReportDialog(place),
                                icon: const Icon(Icons.campaign_outlined),
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
  Future<void> _showReportDialog(PlaceModel place) async {
    SaturationLevel? selectedLevel;
    var sending = false;
    final result = await showModalBottomSheet<
      GenericResponse<SaturationReportReward>
    >(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => _ReportSheet(
          placeName: place.nombre,
          selectedLevel: selectedLevel,
          sending: sending,
          onSelect: (level) => setState(() => selectedLevel = level),
          onSubmit: selectedLevel == null || sending
              ? null
              : () async {
                  setState(() => sending = true);
                  final response = await widget.reportService!.createReport(
                    placeId: place.id,
                    level: selectedLevel!,
                  );
                  if (context.mounted) Navigator.pop(context, response);
                },
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (!result.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => _ReportSuccessSheet(reward: result.data),
    );
  }
}

class _ReportSheet extends StatelessWidget {
  final String placeName;
  final SaturationLevel? selectedLevel;
  final bool sending;
  final ValueChanged<SaturationLevel> onSelect;
  final VoidCallback? onSubmit;

  const _ReportSheet({
    required this.placeName,
    required this.selectedLevel,
    required this.sending,
    required this.onSelect,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 34,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '¿Qué tan lleno está?',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            placeName,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (selectedLevel == null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.06),
                border: Border.all(color: Colors.redAccent),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.error_outline, size: 17, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Selecciona un nivel de saturación para enviar tu reporte.',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          for (final level in SaturationLevel.values) ...[
            _LevelOption(
              level: level,
              selected: selectedLevel == level,
              onTap: sending ? null : () => onSelect(level),
            ),
            const SizedBox(height: 8),
          ],
          FilledButton(
            onPressed: onSubmit,
            child: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Enviar reporte'),
          ),
        ],
      ),
    ),
  );
}

class _LevelOption extends StatelessWidget {
  final SaturationLevel level;
  final bool selected;
  final VoidCallback? onTap;

  const _LevelOption({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      SaturationLevel.tranquil => const Color(0xFF2ECC71),
      SaturationLevel.moderate => const Color(0xFFFFA217),
      SaturationLevel.saturated => const Color(0xFFF04B43),
    };
    final description = switch (level) {
      SaturationLevel.tranquil => 'Hay espacio, poca gente',
      SaturationLevel.moderate => 'Algo concurrido',
      SaturationLevel.saturated => 'Lleno, mucha gente',
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            CircleAvatar(radius: 7, backgroundColor: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (selected) Icon(Icons.check, color: color),
          ],
        ),
      ),
    );
  }
}

class _ReportSuccessSheet extends StatelessWidget {
  final SaturationReportReward? reward;
  const _ReportSuccessSheet({required this.reward});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Color(0xFFF1F8E9),
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SuccessIcon(rewarded: reward != null),
            const SizedBox(height: 22),
            Text(
              reward == null ? '¡Gracias por reportar!' : '¡Sumaste karma!',
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              reward == null
                  ? 'Tu reporte fue enviado correctamente y ya ayuda a otros ciudadanos.'
                  : 'Recibiste puntos por tu reporte válido. Sigue colaborando.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            if (reward != null) ...[
              const SizedBox(height: 16),
              _KarmaChip(points: reward!.pointsAwarded),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SuccessIcon extends StatelessWidget {
  final bool rewarded;
  const _SuccessIcon({required this.rewarded});

  @override
  Widget build(BuildContext context) {
    final color = rewarded ? const Color(0xFFFFA217) : const Color(0xFF2ECC71);
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final size in [88.0, 68.0, 50.0])
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.28)),
              ),
            ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(
              rewarded ? Icons.star : Icons.check,
              color: Colors.white,
              size: 25,
            ),
          ),
        ],
      ),
    );
  }
}

class _KarmaChip extends StatelessWidget {
  final int points;
  const _KarmaChip({required this.points});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF3D7),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star, size: 16, color: Color(0xFFF39C12)),
        const SizedBox(width: 6),
        Text(
          '+$points karma',
          style: const TextStyle(
            color: Color(0xFFB56B00),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
