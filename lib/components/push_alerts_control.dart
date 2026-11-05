import 'package:flutter/material.dart';

import '../services/push_notification_service.dart';
import '../services/session_service.dart';

/// Control compartido del registro de este dispositivo, nunca de los favoritos.
class PushAlertsControl extends StatefulWidget {
  final PushNotificationService? service;

  const PushAlertsControl({super.key, this.service});

  @override
  State<PushAlertsControl> createState() => _PushAlertsControlState();
}

class _PushAlertsControlState extends State<PushAlertsControl> {
  int? _interactionGeneration;
  bool get _interacting => _interactionGeneration == SessionService.generation;

  PushNotificationService get _push =>
      widget.service ?? PushNotificationService.instance;

  Future<void> _change() async {
    if (_interacting || _push.status.value.isBusy) return;
    final generation = SessionService.generation;
    final push = _push;
    final initialStatus = push.status.value;
    setState(() => _interactionGeneration = generation);
    try {
      final disabling =
          initialStatus == PushAlertStatus.active ||
          initialStatus == PushAlertStatus.disableUnconfirmed;
      if (initialStatus == PushAlertStatus.active) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => _DisableAlertsDialog(generation: generation),
        );
        if (confirmed != true) return;
      }
      if (!mounted || generation != SessionService.generation) return;
      final configured = push.isConfigured;
      final success = disabling
          ? await push.disableForCurrentSession()
          : configured && await push.enableForCurrentSession();
      if (!mounted || generation != SessionService.generation) return;
      final message = disabling
          ? success
                ? 'Alertas desactivadas en este dispositivo.'
                : 'Las alertas están bloqueadas en esta sesión, pero falta confirmar la baja en el servidor. Reintenta la desactivación.'
          : !configured
          ? 'Las alertas aún no están disponibles.'
          : success
          ? 'Alertas activadas en este dispositivo.'
          : 'No se pudieron activar las alertas. Revisa los permisos y la conexión e inténtalo de nuevo.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted && _interactionGeneration == generation) {
        setState(() => _interactionGeneration = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: SessionService.changes,
    builder: (context, _) => ValueListenableBuilder<PushAlertStatus>(
      valueListenable: _push.status,
      builder: (context, status, _) {
        final busy = _interacting || status.isBusy;
        final (description, action, icon) = switch (status) {
          PushAlertStatus.inactive => (
            'Alertas inactivas en esta sesión',
            'Activar alertas',
            Icons.notifications_outlined,
          ),
          PushAlertStatus.enabling => (
            'Activando alertas en este dispositivo…',
            'Activando…',
            Icons.notifications_outlined,
          ),
          PushAlertStatus.active => (
            'Alertas activadas en este dispositivo',
            'Desactivar alertas',
            Icons.notifications_active_outlined,
          ),
          PushAlertStatus.disabling => (
            'Alertas bloqueadas aquí. Confirmando la baja…',
            'Desactivando…',
            Icons.notifications_off_outlined,
          ),
          PushAlertStatus.disableUnconfirmed => (
            'Baja no confirmada en el servidor. Las alertas están bloqueadas en esta sesión.',
            'Reintentar desactivación',
            Icons.notifications_off_outlined,
          ),
        };
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: busy || !SessionService.isAuthenticated
                    ? null
                    : _change,
                icon: status.isBusy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(icon),
                label: Text(action),
              ),
              const SizedBox(height: 4),
              Semantics(
                liveRegion: true,
                child: Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _DisableAlertsDialog extends StatefulWidget {
  final int generation;

  const _DisableAlertsDialog({required this.generation});

  @override
  State<_DisableAlertsDialog> createState() => _DisableAlertsDialogState();
}

class _DisableAlertsDialogState extends State<_DisableAlertsDialog> {
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    SessionService.changes.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (!_closed && mounted && widget.generation != SessionService.generation) {
      _closed = true;
      final route = ModalRoute.of(context);
      if (route != null && route.isActive) {
        Navigator.of(context).removeRoute(route, false);
      }
    }
  }

  @override
  void dispose() {
    SessionService.changes.removeListener(_sessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('¿Desactivar alertas en este dispositivo?'),
    content: const Text(
      'Dejarás de recibir alertas aquí. Tus favoritos y las alertas de otros dispositivos se conservarán.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          _closed = true;
          Navigator.of(
            context,
          ).pop(widget.generation == SessionService.generation);
        },
        child: const Text('Confirmar desactivar'),
      ),
    ],
  );
}
