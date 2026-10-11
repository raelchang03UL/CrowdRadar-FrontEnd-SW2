import 'package:flutter/material.dart';
import '../cubits/places/saturation_cubit.dart';
import '../models/saturation_model.dart';
import '../theme/app_colors.dart';

class SaturationPanel extends StatelessWidget {
  final SaturationState state;
  final VoidCallback retry;
  const SaturationPanel({super.key, required this.state, required this.retry});

  @override
  Widget build(BuildContext context) {
    if (state.status == SaturationStatus.initial) {
      return const SizedBox.shrink();
    }
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 24),
          Text(
            'Nivel de saturación',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (state.status == SaturationStatus.loading)
            const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(child: Text('Consultando saturación…')),
              ],
            ),
          if (state.status == SaturationStatus.error) ...[
            Text(
              state.message,
              style: const TextStyle(color: AppColors.danger),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar saturación'),
            ),
          ],
          if (state.data case final data?) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  data.level == null
                      ? Icons.info_outline
                      : Icons.people_outline,
                  color: switch (data.level) {
                    SaturationLevel.tranquilo => AppColors.primary,
                    SaturationLevel.moderado => AppColors.warning,
                    SaturationLevel.saturado => AppColors.danger,
                    null => AppColors.textMuted,
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    switch (data.level) {
                      SaturationLevel.tranquilo => 'Tranquilo',
                      SaturationLevel.moderado => 'Moderado',
                      SaturationLevel.saturado => 'Saturado',
                      null => 'Sin información suficiente',
                    },
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (data.reason == SaturationReason.insufficientReports)
              Text(
                'Se necesitan al menos ${data.minimumReports} personas distintas con reportes vigentes.',
              ),
            if (data.reason == SaturationReason.tie)
              const Text('Los niveles más votados están empatados.'),
            const SizedBox(height: 8),
            Text(
              'Estimación ciudadana · Reportes de los últimos ${data.windowMinutes} minutos.',
              style: const TextStyle(color: AppColors.textMuted),
            ),
            Text(
              '${data.reportCount} ${data.reportCount == 1 ? 'persona distinta' : 'personas distintas'} · Mínimo: ${data.minimumReports}.',
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const Text(
              'No representa un aforo exacto. Se consulta al seleccionar o actualizar.',
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            Text('Consultado: ${_localTime(data.evaluatedAt)}'),
            if (data.updatedAt case final updatedAt?)
              Text('Último reporte considerado: ${_localTime(updatedAt)}'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar saturación'),
            ),
          ],
        ],
      ),
    );
  }

  String _localTime(DateTime utc) {
    final local = utc.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }
}
