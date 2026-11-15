import '../../models/admin_user.dart';
import '../../services/admin_user_service.dart';
import '../request_cubit.dart';

class _HistoryQuery {
  String? before;
}

class AdminHistoryCubit extends RequestCubit<AdminAccountHistory> {
  final _HistoryQuery _query;
  AdminHistoryCubit(AdminUserService service, int id)
    : this._(service, id, _HistoryQuery());
  AdminHistoryCubit._(AdminUserService service, int id, _HistoryQuery query)
    : _query = query,
      super(() => service.history(id, before: query.before));
  bool get hasOlderPage => _query.before != null;
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
