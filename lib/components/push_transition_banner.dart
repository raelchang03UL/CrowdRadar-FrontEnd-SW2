import 'package:flutter/material.dart';

import '../services/push_message_guard.dart';
import '../services/session_service.dart';

class PushTransitionBanner extends StatelessWidget {
  final AuthorizedPushTransition alert;
  final int placeId;

  const PushTransitionBanner({
    super.key,
    required this.alert,
    required this.placeId,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      SessionService.changes,
      alert.authorizationChanges,
    ]),
    builder: (context, _) {
      if (!alert.isCurrentForPlace(placeId)) return const SizedBox.shrink();
      final transition = alert.transition;
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cambio que originó esta alerta',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '${transition.previousLevel.label} → ${transition.newLevel.label}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'El nivel actual puede ser distinto al de esta alerta.',
              ),
            ],
          ),
        ),
      );
    },
  );
}
