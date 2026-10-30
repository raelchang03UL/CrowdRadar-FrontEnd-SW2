import 'session_service.dart';

// Un binding de servidor cambia incluso al volver a entrar con la misma cuenta.
int? authorizedPushPlace(Map<String, dynamic> data, String? registrationId) {
  if (!SessionService.isAuthenticated ||
      registrationId == null ||
      data['registrationId'] != registrationId ||
      data['userId']?.toString() !=
          SessionService.currentUser?.id?.toString()) {
    return null;
  }
  final id = int.tryParse(data['placeId']?.toString() ?? '');
  if (id == null || id == 0 || id < -2147483648 || id > 2147483647) return null;
  return id;
}
