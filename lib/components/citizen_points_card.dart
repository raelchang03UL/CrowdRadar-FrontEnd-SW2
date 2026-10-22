import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Explica la política aprobada; el saldo siempre llega del DTO del backend.
class CitizenPointsCard extends StatelessWidget {
  final int points;
  const CitizenPointsCard({super.key, required this.points});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.stars_outlined, color: AppColors.primary),
              SizedBox(width: 12),
              Expanded(child: Text('Tus puntos')),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$points ${points == 1 ? 'punto' : 'puntos'}',
            key: const ValueKey('citizen-points-balance'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
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
