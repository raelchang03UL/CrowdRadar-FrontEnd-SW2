import 'package:flutter/material.dart';
import '../cubits/places/places_cubit.dart';
import '../services/session_service.dart';
import '../models/saturation_model.dart';

/// Solo presentación: la búsqueda AND y sus carreras siguen en PlacesCubit.
class PlaceMapControls extends StatefulWidget {
  final PlacesCubit cubit;
  final VoidCallback category;
  final VoidCallback saturation;
  const PlaceMapControls({
    super.key,
    required this.cubit,
    required this.category,
    required this.saturation,
  });
  @override
  State<PlaceMapControls> createState() => _PlaceMapControlsState();
}

class _PlaceMapControlsState extends State<PlaceMapControls> {
  final _search = TextEditingController();
  int _generation = SessionService.generation;
  @override
  void didUpdateWidget(covariant PlaceMapControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_generation != SessionService.generation) {
      _generation = SessionService.generation;
      _search.clear();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    widget.cubit.searchPlaces(_search.text);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = widget.cubit;
    final action = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 12),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                SizedBox(
                  width: constraints.maxWidth >= 1000
                      ? 640
                      : constraints.maxWidth,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('map-search'),
                          controller: _search,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            labelText: 'Buscar por nombre',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _search.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Limpiar búsqueda',
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      setState(_search.clear);
                                      cubit.searchPlaces('');
                                    },
                                  ),
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _submit(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _submit,
                        style: action,
                        child: const Text('Buscar'),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Tooltip(
                      message: 'Filtrar por categoría',
                      child: OutlinedButton.icon(
                        style: action,
                        onPressed: widget.category,
                        icon: const Icon(Icons.category_outlined),
                        label: const Text('Categoría'),
                      ),
                    ),
                    Tooltip(
                      message: 'Filtrar por saturación',
                      child: OutlinedButton.icon(
                        style: action,
                        onPressed: SessionService.isAuthenticated
                            ? widget.saturation
                            : null,
                        icon: const Icon(Icons.filter_alt_outlined),
                        label: const Text('Saturación'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (cubit.categoria.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Categoría: ${cubit.categoria}'),
                  TextButton(
                    onPressed: () => cubit.filterByCategory(''),
                    child: const Text('Quitar filtro'),
                  ),
                ],
              ),
            if (cubit.nivelSaturacion case final level?)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Saturación: ${level.etiqueta}',
                      key: const ValueKey('filtro-saturacion-activo'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Quitar filtro de saturación',
                    onPressed: () => cubit.filtrarPorSaturacion(null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
