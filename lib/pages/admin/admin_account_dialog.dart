import 'package:flutter/material.dart';
import '../../models/admin_user.dart';
import '../../services/session_service.dart';

class AdminAccountDialog extends StatefulWidget {
  final AdminUser user;
  final bool suspend;
  const AdminAccountDialog({
    super.key,
    required this.user,
    required this.suspend,
  });
  @override
  State<AdminAccountDialog> createState() => _AdminAccountDialogState();
}

class _AdminAccountDialogState extends State<AdminAccountDialog> {
  final _form = GlobalKey<FormState>();
  final _text = TextEditingController();
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
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.suspend ? 'Suspender cuenta' : 'Reactivar cuenta'),
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
                widget.user.fullName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Text(
                widget.suspend
                    ? 'La cuenta quedará suspendida hasta que un administrador la reactive. Se cerrarán sus sesiones anteriores.'
                    : 'La cuenta volverá a estar activa. La persona deberá iniciar sesión de nuevo. Su historial se conservará.',
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _text,
                autofocus: true,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: widget.suspend
                      ? 'Motivo obligatorio'
                      : 'Observación opcional',
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (widget.suspend && text.isEmpty) {
                    return 'Escribe el motivo de la suspensión.';
                  }
                  if (text.runes.length > 500 || text.contains('\u0000')) {
                    return 'Usa un texto válido de hasta 500 caracteres.';
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
            Navigator.pop(context, _text.text.trim());
          }
        },
        child: Text(
          widget.suspend ? 'Confirmar suspensión' : 'Confirmar reactivación',
        ),
      ),
    ],
  );
}
