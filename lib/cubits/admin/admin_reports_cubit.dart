import '../../models/admin_report.dart';
import '../../services/admin_report_service.dart';
import '../request_cubit.dart';

class _ListQuery {
  String state;
  String? before;
  final int? authorId;
  _ListQuery(this.authorId) : state = authorId == null ? 'PENDING' : 'ALL';
}

class AdminReportsCubit extends RequestCubit<AdminReportPage> {
  final _ListQuery _query;
  AdminReportsCubit(AdminReportService service, {int? authorId})
    : this._(service, _ListQuery(authorId));
  AdminReportsCubit._(AdminReportService service, _ListQuery query)
    : _query = query,
      super(
        () => service.list(
          state: query.state,
          authorId: query.authorId,
          before: query.before,
        ),
      );
  bool get hasOlderPage => _query.before != null;
  Future<void> filter(String state) {
    _query.state = state;
    return recent();
  }

  Future<void> recent() {
    _query.before = null;
    return load();
  }

  Future<void> older() async {
    if (state.loading || state.data?.nextBefore == null) return;
    _query.before = state.data!.nextBefore;
    await load();
  }
}

class _HistoryQuery {
  String? before;
}

class AdminReportCubit extends RequestCubit<AdminReportDetail> {
  final _HistoryQuery _query;
  AdminReportCubit(AdminReportService service, String id)
    : this._(service, id, _HistoryQuery());
  AdminReportCubit._(AdminReportService service, String id, _HistoryQuery query)
    : _query = query,
      super(() => service.detail(id, beforeHistory: query.before));
  bool get hasOlderHistory => _query.before != null;
  Future<void> recent() {
    _query.before = null;
    return load();
  }

  Future<bool> decide(
    AdminReportService service,
    AdminReport report,
    String decision,
    String reason,
  ) {
    _query.before = null;
    return perform(() => service.decide(report, decision, reason));
  }

  Future<void> older() async {
    if (state.loading || state.working || state.data?.nextHistoryBefore == null) {
      return;
    }
    _query.before = state.data!.nextHistoryBefore;
    await load();
  }
}
