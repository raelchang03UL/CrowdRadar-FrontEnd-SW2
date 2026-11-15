import 'package:flutter/material.dart';
import '../../models/admin_report.dart';
import '../../services/session_service.dart';

class AdminReportDecisionDialog extends StatefulWidget {
  final AdminReport report;
  final String decision;
  const AdminReportDecisionDialog({
    super.key,
    required this.report,
    required this.decision,
  });
  @override
  State<AdminReportDecisionDialog> createState() => _DialogState();
}

class _DialogState extends State<AdminReportDecisionDialog> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  @override
  void initState() {
    super.initState();
    SessionService.changes.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    SessionService.changes.removeListener(_sessionChanged);
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.decision == 'KEEP'
          ? 'Conservar reporte'
          : 'Retirar de vista pública',
    ),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.report.placeName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Text(
                widget.decision == 'KEEP'
                    ? 'El reporte seguirá visible. Se guardará tu decisión y, si recibe denuncias nuevas, volverá a Pendiente.'
                    : 'El reporte dejará de aparecer en las consultas y cálculos públicos, incluso en gráficos de períodos anteriores. Se conservará la evidencia y el historial del autor. Su cuenta y el karma otorgado se mantienen.',
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _reason,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Motivo de la decisión',
                ),
                validator: (value) {
                  final reason = (value ?? '').trim();
                  if (reason.isEmpty) {
                    return 'Escribe el motivo de la decisión.';
                  }
                  if (reason.runes.length > 500 || reason.contains('\u0000')) {
                    return 'Usa un motivo válido de hasta 500 caracteres.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _reason.text.trim());
          }
        },
        child: Text(
          widget.decision == 'KEEP'
              ? 'Confirmar conservación'
              : 'Confirmar retiro',
        ),
      ),
    ],
  );
}
