import 'package:flutter/material.dart';

/// Explica la política aprobada; el saldo siempre llega del DTO del backend.
class CitizenPointsCard extends StatelessWidget {
  final int points;
  const CitizenPointsCard({super.key, required this.points});

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.stars_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Tus puntos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              Text(
                '$points ${points == 1 ? 'punto' : 'puntos'}',
                key: const ValueKey('citizen-points-balance'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (points == 0) ...[
            const Text(
              'Empiezas en 0. El saldo cambia cuando el servidor confirma un premio.',
            ),
            const SizedBox(height: 8),
          ],
          const Text(
            'Un reporte aceptado por el servidor suma 10 puntos una sola vez. Si el intento se rechaza porque ya tienes un reporte reciente del lugar, no añade puntos.',
          ),
        ],
      ),
    ),
  );
}
