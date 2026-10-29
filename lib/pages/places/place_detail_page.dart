import 'package:flutter/material.dart';

import '../../models/place_model.dart';
import '../../services/place_service.dart';
import '../../theme/app_colors.dart';

class PlaceDetailPage extends StatefulWidget {
  final int placeId;
  final PlaceService service;

  const PlaceDetailPage({
    super.key,
    required this.placeId,
    this.service = const PlaceService(),
  });

  @override
  State<PlaceDetailPage> createState() => _PlaceDetailPageState();
}

class _PlaceDetailPageState extends State<PlaceDetailPage> {
  late Future<PlaceModel?> _place;
  String? _error;

  @override
  void initState() {
    super.initState();
    _place = _load();
  }

  Future<PlaceModel?> _load() async {
    final response = await widget.service.getPlace(widget.placeId);
    if (!response.success || response.data == null) {
      _error = response.message;
      return null;
    }
    _error = null;
    return response.data;
  }

  void _retry() => setState(() => _place = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Información del lugar')),
    body: FutureBuilder<PlaceModel?>(
      future: _place,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final place = snapshot.data;
        if (place == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? 'No se encontró el lugar.'),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.nombre,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 20),
                      _PlaceDetailRow(
                        label: 'Categoría',
                        value: place.categoria,
                      ),
                      if (place.referencia?.trim().isNotEmpty ?? false) ...[
                        const SizedBox(height: 16),
                        _PlaceDetailRow(
                          label: 'Referencia',
                          value: place.referencia!,
                        ),
                      ],
                      const SizedBox(height: 16),
                      _PlaceDetailRow(
                        label: 'Coordenadas',
                        value: '${place.latitud}, ${place.longitud}',
                      ),
                      if (place.demostrativo) ...[
                        const SizedBox(height: 16),
                        const Chip(
                          avatar: Icon(Icons.science_outlined, size: 18),
                          label: Text('Lugar demostrativo'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _PlaceDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _PlaceDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
      ),
      const SizedBox(height: 4),
      SelectableText(value, style: Theme.of(context).textTheme.bodyLarge),
    ],
  );
}
