bool validAdminReportId(dynamic value) =>
    value is String &&
    RegExp(r'^[1-9]\d{0,18}$').hasMatch(value) &&
    BigInt.parse(value) <= BigInt.parse('9223372036854775807');
int _count(dynamic value, {int minimum = 0}) {
  if (value is! int || value < minimum || value > 2147483647) {
    throw const FormatException('Conteo inválido');
  }
  return value;
}

String _text(dynamic value) {
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Texto inválido');
  }
  return value;
}

DateTime _date(dynamic value) {
  if (value is! String || !value.endsWith('Z')) {
    throw const FormatException('Fecha inválida');
  }
  return DateTime.parse(value);
}

class AdminReport {
  final String id, placeName, level, authorName, reviewState;
  final String? authorRole;
  final int placeId,
      authorId,
      denunciationCount,
      reviewedDenunciationCount,
      moderationVersion;
  final DateTime createdAt;
  final bool isPublic;
  const AdminReport({
    required this.id,
    required this.placeId,
    required this.placeName,
    required this.level,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.createdAt,
    required this.reviewState,
    required this.denunciationCount,
    required this.reviewedDenunciationCount,
    required this.moderationVersion,
    required this.isPublic,
  });
  factory AdminReport.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>,
        state = json['reviewState'],
        isPublic = json['isPublic'];
    if (!validAdminReportId(json['id']) ||
        json['placeId'] is! int ||
        !['TRANQUILO', 'MODERADO', 'SATURADO'].contains(json['level']) ||
        !['PENDING', 'KEPT', 'REMOVED'].contains(state) ||
        isPublic is! bool ||
        (state == 'REMOVED') == isPublic) {
      throw const FormatException('Reporte administrativo inválido');
    }
    final total = _count(json['denunciationCount'], minimum: 1),
        reviewed = _count(json['reviewedDenunciationCount']);
    if (reviewed > total || (state == 'KEPT' && reviewed != total)) {
      throw const FormatException('Revisión incoherente');
    }
    return AdminReport(
      id: json['id'] as String,
      placeId: json['placeId'] as int,
      placeName: _text(json['placeName']),
      level: json['level'] as String,
      authorId: _count(author['id'], minimum: 1),
      authorName: _text(author['name']),
      authorRole: author['rol'] as String?,
      createdAt: _date(json['createdAt']),
      reviewState: state as String,
      isPublic: isPublic,
      denunciationCount: total,
      reviewedDenunciationCount: reviewed,
      moderationVersion: _count(json['moderationVersion']),
    );
  }
  String get stateLabel => switch (reviewState) {
    'PENDING' => 'Pendiente',
    'KEPT' => 'Conservado',
    _ => 'Retirado de la vista pública',
  };
}

class AdminReasonGroup {
  final String? reason;
  final int count;
  const AdminReasonGroup(this.reason, this.count);
}

class AdminReportAction {
  final String id, decision, reason, adminName;
  final int adminId, reviewedDenunciationCount, moderationVersion;
  final DateTime createdAt;
  const AdminReportAction({
    required this.id,
    required this.decision,
    required this.reason,
    required this.adminId,
    required this.adminName,
    required this.reviewedDenunciationCount,
    required this.moderationVersion,
    required this.createdAt,
  });
  factory AdminReportAction.fromJson(Map<String, dynamic> json) {
    if (!validAdminReportId(json['id']) ||
        !['KEEP', 'REMOVE'].contains(json['decision'])) {
      throw const FormatException('Decisión inválida');
    }
    final reason = _text(json['reason']);
    if (reason.runes.length > 500) {
      throw const FormatException('Motivo inválido');
    }
    return AdminReportAction(
      id: json['id'] as String,
      decision: json['decision'] as String,
      reason: reason,
      adminId: _count(json['adminId'], minimum: 1),
      adminName: _text(json['adminName']),
      createdAt: _date(json['createdAt']),
      reviewedDenunciationCount: _count(
        json['reviewedDenunciationCount'],
        minimum: 1,
      ),
      moderationVersion: _count(json['moderationVersion'], minimum: 1),
    );
  }
}

class AdminReportPage {
  final List<AdminReport> reports;
  final String? nextBefore;
  const AdminReportPage(this.reports, this.nextBefore);
}

class AdminReportDetail {
  final AdminReport report;
  final List<AdminReasonGroup> reasons;
  final List<AdminReportAction> history;
  final String? nextHistoryBefore;
  const AdminReportDetail(
    this.report,
    this.reasons,
    this.history,
    this.nextHistoryBefore,
  );
  factory AdminReportDetail.fromJson(
    Map<String, dynamic> json, {
    String? beforeHistory,
  }) {
    final data = json['data'] as Map<String, dynamic>,
        report = AdminReport.fromJson(data);
    final reasons = (data['reasons'] as List)
        .map((item) {
          final reason = item['reason'];
          if (reason != null &&
              (reason is! String ||
                  reason.trim() != reason ||
                  reason.isEmpty ||
                  reason.runes.length > 500)) {
            throw const FormatException('Motivo inválido');
          }
          return AdminReasonGroup(
            reason as String?,
            _count(item['count'], minimum: 1),
          );
        })
        .toList(growable: false);
    if (reasons.fold<int>(0, (sum, g) => sum + g.count) !=
            report.denunciationCount ||
        reasons.map((g) => g.reason).toSet().length != reasons.length) {
      throw const FormatException('Desglose inconsistente');
    }
    final history = (json['history'] as List)
        .map((e) => AdminReportAction.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    final next =
        (json['historyPagination'] as Map<String, dynamic>)['nextBefore'];
    if (history.length > 20 ||
        (next != null &&
            (!validAdminReportId(next) ||
                history.isEmpty ||
                next != history.last.id))) {
      throw const FormatException('Página de historial inválida');
    }
    var previous = beforeHistory == null
        ? BigInt.parse('9223372036854775808')
        : BigInt.parse(beforeHistory);
    for (final entry in history) {
      final id = BigInt.parse(entry.id);
      if (id >= previous ||
          entry.moderationVersion > report.moderationVersion ||
          entry.reviewedDenunciationCount > report.denunciationCount) {
        throw const FormatException('Historial incoherente');
      }
      previous = id;
    }
    return AdminReportDetail(report, reasons, history, next as String?);
  }
}
