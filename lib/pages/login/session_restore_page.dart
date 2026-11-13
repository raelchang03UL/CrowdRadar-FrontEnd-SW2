import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/session_service.dart';

class SessionRestorePage extends StatelessWidget {
  const SessionRestorePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListenableBuilder(
              listenable: SessionService.changes,
              builder: (context, _) {
                final retry =
                    SessionService.restoreStatus ==
                    SessionRestoreStatus.retryRequired;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!retry) const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      retry
                          ? 'No pudimos comprobar tu sesión'
                          : 'Comprobando tu sesión',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      retry
                          ? 'Revisa tu conexión e inténtalo de nuevo. Tus datos se mostrarán cuando confirmemos la sesión.'
                          : 'Espera un momento para continuar.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (retry)
                      FilledButton(
                        onPressed: () => unawaited(SessionService.restore()),
                        child: const Text('Reintentar'),
                      ),
                    TextButton(
                      onPressed: SessionService.clear,
                      child: const Text('Iniciar sesión con otra cuenta'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
