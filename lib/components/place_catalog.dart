import 'package:flutter/material.dart';

import '../models/place_model.dart';
import '../theme/app_colors.dart';

/// El catálogo y el selector utilizan los mismos lugares devueltos por la API.
/// Elegir un punto no crea un lugar ni fabrica una estimación de saturación.
class PlaceCatalogPanel extends StatelessWidget {
  final List<PlaceModel> places;
  final int? selectedId;
  final ValueChanged<PlaceModel> onSelect;

  const PlaceCatalogPanel({
    super.key,
    required this.places,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    child: CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lugares del catálogo',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Selecciona uno para ver su información o reportar.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: Divider(height: 1)),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final place = places[index];
            return ListTile(
              key: ValueKey('catalog-place-${place.id}'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              selected: selectedId == place.id,
              selectedTileColor: AppColors.primary.withValues(alpha: 0.06),
              leading: const Icon(Icons.place_outlined),
              title: Text(place.nombre),
              subtitle: Text(place.categoria),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => onSelect(place),
            );
          }, childCount: places.length),
        ),
      ],
    ),
  );
}

class PlacePickerSheet extends StatefulWidget {
  final List<PlaceModel> places;
  final bool forReport;

  const PlacePickerSheet({
    super.key,
    required this.places,
    this.forReport = false,
  });

  @override
  State<PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends State<PlacePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final matches = widget.places
        .where(
          (place) => '${place.nombre} ${place.categoria}'
              .toLowerCase()
              .contains(_query),
        )
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.75,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.forReport
                                  ? '¿Dónde quieres reportar?'
                                  : 'Elegir un lugar',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cerrar selector de lugares',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Selecciona un lugar registrado del catálogo actual.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Buscar en estos lugares',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
                      ),
                    ),
                  ],
                ),
              ),
              if (matches.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text('No hay coincidencias en este catálogo.'),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final place = matches[index];
                    return ListTile(
                      key: ValueKey('pick-place-${place.id}'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      leading: const Icon(
                        Icons.place_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(place.nombre),
                      subtitle: Text(place.categoria),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(context, place),
                    );
                  }, childCount: matches.length),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
