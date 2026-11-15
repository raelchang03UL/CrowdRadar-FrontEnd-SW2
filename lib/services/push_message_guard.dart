import 'package:flutter/foundation.dart';

import '../models/push_saturation_transition.dart';
import 'session_service.dart';

// Un binding de servidor cambia incluso al volver a entrar con la misma cuenta.
int? authorizedPushPlace(Map<String, dynamic> data, String? registrationId) {
  if (!SessionService.isAuthenticated ||
      registrationId == null ||
      registrationId.isEmpty ||
      data['registrationId'] != registrationId ||
      data['userId']?.toString() !=
          SessionService.currentUser?.id?.toString()) {
    return null;
  }
  final id = int.tryParse(data['placeId']?.toString() ?? '');
  if (id == null || id == 0 || id < -2147483648 || id > 2147483647) return null;
  return id;
}

// Solo vive en memoria: no contiene JWT ni se reconstruye desde la URL.
class AuthorizedPushTransition {
  final int placeId;
  final PushSaturationTransition transition;
  final Listenable authorizationChanges;
  final int _userId;
  final int _generation;
  final String _registrationId;
  final String? Function() _currentRegistrationId;

  const AuthorizedPushTransition._({
    required this.placeId,
    required this.transition,
    required this.authorizationChanges,
    required int userId,
    required int generation,
    required String registrationId,
    required String? Function() currentRegistrationId,
  }) : _userId = userId,
       _generation = generation,
       _registrationId = registrationId,
       _currentRegistrationId = currentRegistrationId;

  bool isCurrentForPlace(int id) =>
      id == placeId &&
      SessionService.isAuthenticated &&
      SessionService.currentUser?.id == _userId &&
      SessionService.generation == _generation &&
      _currentRegistrationId() == _registrationId;
}

AuthorizedPushTransition? authorizedPushTransition(
  Map<String, dynamic> data,
  String? registrationId, {
  required String? Function() currentRegistrationId,
  required Listenable authorizationChanges,
}) {
  final placeId = authorizedPushPlace(data, registrationId);
  final transition = PushSaturationTransition.fromPayload(data);
  final userId = SessionService.currentUser?.id;
  if (placeId == null || transition == null || userId == null) return null;
  final context = AuthorizedPushTransition._(
    placeId: placeId,
    transition: transition,
    authorizationChanges: authorizationChanges,
    userId: userId,
    generation: SessionService.generation,
    registrationId: registrationId!,
    currentRegistrationId: currentRegistrationId,
  );
  return context.isCurrentForPlace(placeId) ? context : null;
}
