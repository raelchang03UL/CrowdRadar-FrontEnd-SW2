import '../configs/generic_response.dart';
import '../models/admin_user.dart';
import 'api_json_client.dart';

class AdminUserService {
  final ApiJsonClient _client;
  AdminUserService({ApiJsonClient? client})
    : _client = client ?? ApiJsonClient();

  GenericResponse<T> _failure<T>(
    GenericResponse<dynamic> result,
  ) => GenericResponse(
    success: false,
    error: result.error,
    message: switch (result.error) {
      'ADMIN_REQUIRED' => 'Esta sección está disponible para administradores.',
      'ADMIN_QUERY_INVALID' => 'Revisa la búsqueda y el estado seleccionado.',
      'ADMIN_USER_ID_INVALID' ||
      'USER_NOT_FOUND' => 'No encontramos ese usuario.',
      'MODERATION_CITIZEN_ONLY' => 'Solo puedes moderar cuentas ciudadanas.',
      'ACCOUNT_STATE_CHANGED' =>
        'La cuenta cambió. Actualiza su información antes de decidir.',
      'MODERATION_INPUT_INVALID' =>
        'Revisa el motivo o la observación (máximo 500 caracteres).',
      _ => result.message,
    },
  );

  Future<GenericResponse<AdminUserPage>> list({
    String q = '',
    String status = '',
    int page = 1,
    int limit = 20,
  }) async {
    final path = Uri(
      path: '/api/admin/users',
      queryParameters: {
        if (q.trim().isNotEmpty) 'q': q.trim(),
        if (status.isNotEmpty) 'status': status,
        'page': '$page',
        'limit': '$limit',
      },
    ).toString();
    final result = await _client.request(path);
    if (!result.success) return _failure(result);
    try {
      final pagination = result.data!['pagination'] as Map<String, dynamic>;
      final users = (result.data!['data'] as List)
          .map((item) => AdminUser.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
      if (pagination['page'] != page ||
          pagination['limit'] != limit ||
          pagination['hasNext'] is! bool ||
          users.length > limit ||
          users.map((u) => u.id).toSet().length != users.length) {
        throw const FormatException('Página administrativa inválida');
      }
      return GenericResponse(
        success: true,
        data: AdminUserPage(
          users: users,
          page: page,
          limit: limit,
          hasNext: pagination['hasNext'] as bool,
        ),
      );
    } catch (_) {
      return const GenericResponse(
        success: false,
        message: 'No pudimos leer la lista de usuarios.',
      );
    }
  }

  Future<GenericResponse<AdminUser>> detail(int id) async {
    final result = await _client.request('/api/admin/users/$id');
    if (!result.success) return _failure(result);
    try {
      final user = AdminUser.fromJson(
        result.data!['data'] as Map<String, dynamic>,
      );
      if (user.id != id) {
        throw const FormatException('Usuario diferente al solicitado');
      }
      return GenericResponse(success: true, data: user);
    } catch (_) {
      return const GenericResponse(
        success: false,
        message: 'No pudimos leer la información del usuario.',
      );
    }
  }

  Future<GenericResponse<AdminUser>> transition(
    AdminUser user, {
    required bool suspend,
    required String text,
  }) async {
    final result = await _client.request(
      '/api/admin/users/${user.id}/${suspend ? 'suspend' : 'reactivate'}',
      body: {
        'expectedVersion': user.moderationVersion,
        if (suspend)
          'reason': text.trim()
        else if (text.trim().isNotEmpty)
          'note': text.trim(),
      },
    );
    const uncertain =
        'No pudimos confirmar si la decisión se guardó. Actualiza la cuenta y el historial antes de intentarlo otra vez.';
    if (!result.success) {
      if (['UNAVAILABLE', 'SERVICE_UNAVAILABLE'].contains(result.error)) {
        return const GenericResponse(
          success: false,
          error: 'MODERATION_UNCERTAIN',
          message: uncertain,
        );
      }
      return _failure(result);
    }
    try {
      final updated = AdminUser.fromJson(
        result.data!['data'] as Map<String, dynamic>,
      );
      if (updated.id != user.id ||
          updated.rol != 'USUARIO' ||
          updated.status != (suspend ? 'SUSPENDIDO' : 'ACTIVO') ||
          updated.moderationVersion != user.moderationVersion + 1) {
        throw const FormatException('Decisión incoherente');
      }
      return GenericResponse(success: true, data: updated);
    } catch (_) {
      return const GenericResponse(
        success: false,
        error: 'MODERATION_UNCERTAIN',
        message: uncertain,
      );
    }
  }

  Future<GenericResponse<AdminAccountHistory>> history(
    int id, {
    String? before,
  }) async {
    final path = Uri(
      path: '/api/admin/users/$id/history',
      queryParameters: before == null ? null : {'before': before},
    ).toString();
    final result = await _client.request(path);
    if (!result.success) return _failure(result);
    try {
      final actions = (result.data!['data'] as List)
          .map(
            (item) => AdminAccountAction.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);
      final cursor =
          (result.data!['pagination'] as Map<String, dynamic>)['nextBefore'];
      if (actions.length > 20 ||
          (cursor != null &&
              (!AdminAccountAction.validId(cursor) ||
                  actions.isEmpty ||
                  cursor != actions.last.id))) {
        throw const FormatException('Cursor inválido');
      }
      var previous = before == null
          ? BigInt.parse('9223372036854775808')
          : BigInt.parse(before);
      for (final action in actions) {
        final current = BigInt.parse(action.id);
        if (current >= previous) throw const FormatException('Orden inválido');
        previous = current;
      }
      return GenericResponse(
        success: true,
        data: AdminAccountHistory(
          actions: actions,
          nextBefore: cursor as String?,
        ),
      );
    } catch (_) {
      return const GenericResponse(
        success: false,
        message: 'No pudimos leer el historial. Actualiza la consulta.',
      );
    }
  }
}
