class AdminUser {
  final int id;
  final String? nombre, apellido, email, rol, status;
  final int denouncedReportCount;
  final int moderationVersion;

  const AdminUser({
    required this.id,
    this.nombre,
    this.apellido,
    this.email,
    this.rol,
    this.status,
    required this.denouncedReportCount,
    this.moderationVersion = 0,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'],
        count = json['denouncedReportCount'],
        version = json['moderationVersion'];
    if (id is! int ||
        id < 1 ||
        id > 2147483647 ||
        count is! int ||
        count < 0 ||
        version is! int ||
        version < 0 ||
        version > 2147483647) {
      throw const FormatException('Usuario administrativo inválido');
    }
    return AdminUser(
      id: id,
      nombre: json['nombre'] as String?,
      apellido: json['apellido'] as String?,
      email: json['email'] as String?,
      rol: json['rol'] as String?,
      status: json['status'] as String?,
      denouncedReportCount: count,
      moderationVersion: version,
    );
  }

  String get fullName {
    final name = '${nombre ?? ''} ${apellido ?? ''}'.trim();
    return name.isEmpty ? 'Nombre no registrado' : name;
  }

  String get statusLabel => switch (status) {
    'ACTIVO' => 'Activa',
    'SUSPENDIDO' => 'Suspendida',
    _ => 'Estado no registrado',
  };
}

class AdminAccountAction {
  final String id, action, previousStatus, newStatus, adminName;
  final String? reason;
  final DateTime createdAt;
  final int adminId, moderationVersion;
  const AdminAccountAction({
    required this.id,
    required this.action,
    required this.reason,
    required this.previousStatus,
    required this.newStatus,
    required this.adminId,
    required this.adminName,
    required this.createdAt,
    required this.moderationVersion,
  });
  static bool validId(dynamic id) =>
      id is String &&
      RegExp(r'^[1-9]\d{0,18}$').hasMatch(id) &&
      BigInt.parse(id) <= BigInt.parse('9223372036854775807');
  factory AdminAccountAction.fromJson(Map<String, dynamic> json) {
    final action = json['action'],
        reason = json['reason'],
        date = json['createdAt'];
    if (!validId(json['id']) ||
        !['SUSPEND', 'REACTIVATE'].contains(action) ||
        (reason != null &&
            (reason is! String ||
                reason.trim().isEmpty ||
                reason.runes.length > 500)) ||
        (action == 'SUSPEND' && reason == null) ||
        date is! String ||
        !date.endsWith('Z') ||
        json['adminId'] is! int ||
        (json['adminId'] as int) < 1 ||
        json['adminName'] is! String ||
        (json['adminName'] as String).trim().isEmpty ||
        json['moderationVersion'] is! int ||
        (json['moderationVersion'] as int) < 1 ||
        json['previousStatus'] !=
            (action == 'SUSPEND' ? 'ACTIVO' : 'SUSPENDIDO') ||
        json['newStatus'] != (action == 'SUSPEND' ? 'SUSPENDIDO' : 'ACTIVO')) {
      throw const FormatException('Historial administrativo inválido');
    }
    return AdminAccountAction(
      id: json['id'] as String,
      action: action as String,
      reason: reason as String?,
      previousStatus: json['previousStatus'] as String,
      newStatus: json['newStatus'] as String,
      adminId: json['adminId'] as int,
      adminName: json['adminName'] as String,
      createdAt: DateTime.parse(date),
      moderationVersion: json['moderationVersion'] as int,
    );
  }
}

class AdminAccountHistory {
  final List<AdminAccountAction> actions;
  final String? nextBefore;
  const AdminAccountHistory({required this.actions, required this.nextBefore});
}

class AdminUserPage {
  final List<AdminUser> users;
  final int page, limit;
  final bool hasNext;
  const AdminUserPage({
    required this.users,
    required this.page,
    required this.limit,
    required this.hasNext,
  });
}
