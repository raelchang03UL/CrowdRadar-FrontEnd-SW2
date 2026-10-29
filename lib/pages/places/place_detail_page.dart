import 'package:flutter/material.dart';

import '../../models/place_model.dart';
import '../../theme/app_colors.dart';

class PlaceDetailPage extends StatelessWidget {
  final PlaceModel place;

  const PlaceDetailPage({super.key, required this.place});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Información del lugar')),
    body: SingleChildScrollView(
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        color: AppColors.primary,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          place.nombre,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _PlaceDetailRow(
                    icon: Icons.category_outlined,
                    label: 'Categoría',
                    value: place.categoria,
                  ),
                  if (place.referencia != null &&
                      place.referencia!.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _PlaceDetailRow(
                      icon: Icons.info_outline,
                      label: 'Referencia',
                      value: place.referencia!,
                    ),
                  ],
                  const SizedBox(height: 16),
                  _PlaceDetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'Coordenadas',
                    value: '${place.latitud}, ${place.longitud}',
                  ),
                  const SizedBox(height: 24),
                  if (place.demostrativo)
                    const Chip(
                      avatar: Icon(Icons.science_outlined, size: 18),
                      label: Text('Lugar demostrativo'),
                    ),
                  if (place.esFavorito)
                    const Chip(
                      avatar: Icon(
                        Icons.favorite,
                        size: 18,
                        color: AppColors.secondary,
                      ),
                      label: Text('En tus favoritos'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _PlaceDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PlaceDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppColors.secondary),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
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
        ),
      ),
    ],
  );
}
