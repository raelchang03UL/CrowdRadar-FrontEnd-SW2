import 'package:flutter/material.dart';
import '../models/saturation_model.dart';

// Un resultado nulo del diálogo cancela; este objeto con nivel null elige Todos.
class SeleccionNivelSaturacion {
  final SaturationLevel? nivel;
  const SeleccionNivelSaturacion(this.nivel);
}

class SelectorSaturacion extends StatelessWidget {
  final SaturationLevel? nivelActual;
  const SelectorSaturacion({super.key, required this.nivelActual});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Filtrar por saturación',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Cerrar filtro',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Solo se muestran lugares cuyo nivel coincide con la estimación del servidor. Todos incluye los lugares sin información suficiente.',
          ),
          const SizedBox(height: 16),
          for (final nivel in <SaturationLevel?>[
            null,
            ...SaturationLevel.values,
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MergeSemantics(
                key: ValueKey(
                  'semantica-saturacion-${nivel?.valorApi ?? 'TODOS'}',
                ),
                child: Semantics(
                  selected: nivel == nivelActual,
                  child: OutlinedButton.icon(
                    key: ValueKey(
                      'opcion-saturacion-${nivel?.valorApi ?? 'TODOS'}',
                    ),
                    onPressed: () =>
                        Navigator.pop(context, SeleccionNivelSaturacion(nivel)),
                    icon: Icon(
                      nivel == nivelActual ? Icons.check : Icons.people_outline,
                    ),
                    label: Text(nivel?.etiqueta ?? 'Todos'),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
