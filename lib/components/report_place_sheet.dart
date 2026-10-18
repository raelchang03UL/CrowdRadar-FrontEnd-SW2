import 'package:flutter/material.dart';
import '../models/place_model.dart';
import '../services/saturation_report_service.dart';
import '../services/session_service.dart';

// Presentación del contrato de Manu: la recompensa solo procede del servidor.
class ReportPlaceSheet extends StatefulWidget {
  final PlaceModel place;
  final SaturationReportService service;
  const ReportPlaceSheet({super.key, required this.place, required this.service});

  @override
  State<ReportPlaceSheet> createState() => _ReportPlaceSheetState();
}

class _ReportPlaceSheetState extends State<ReportPlaceSheet> {
  final int _generation = SessionService.generation;
  SaturationLevel? _level;
  bool _sending = false;
  bool _sent = false;
  String? _error;
  SaturationReportReward? _reward;

  Future<void> _submit() async {
    if (_sending || _sent || _level == null || !SessionService.isAuthenticated ||
        _generation != SessionService.generation) return;
    setState(() { _sending = true; _error = null; });
    try {
      final result = await widget.service.createReport(placeId: widget.place.id, level: _level!);
      if (!mounted || _generation != SessionService.generation || !SessionService.isAuthenticated) return;
      setState(() {
        _sending = false;
        _sent = result.success;
        _reward = result.success ? result.data : null;
        _error = result.success ? null : result.message;
      });
    } catch (_) {
      if (!mounted || _generation != SessionService.generation) return;
      setState(() { _sending = false; _error = SaturationReportService.genericError; });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sending,
    child: SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(_sent ? 'Reporte enviado' : '¿Cómo está este lugar?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(widget.place.nombre),
          const SizedBox(height: 20),
          if (_sent) ...[
            const Text('Gracias por compartir lo que observaste.'),
            if (_reward != null) Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('+${_reward!.pointsAwarded} karma · Total: ${_reward!.karmaPoints}'),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Listo')),
          ] else ...[
            const Text('Elige el nivel que observas ahora. Puedes reportar este lugar cada 3 minutos.'),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: SaturationLevel.values.map((level) => ChoiceChip(
              label: Text(level.label), selected: _level == level,
              onSelected: _sending ? null : (_) => setState(() { _level = level; _error = null; }),
            )).toList()),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 16), child: Semantics(
              liveRegion: true, child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            )),
            const SizedBox(height: 24),
            FilledButton(onPressed: _sending || _level == null ? null : _submit,
              child: _sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Enviar reporte')),
            TextButton(onPressed: _sending ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ],
        ]),
      ),
    ),
  );
}
