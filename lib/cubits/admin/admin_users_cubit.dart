import '../../models/admin_user.dart';
import '../../services/admin_user_service.dart';
import '../request_cubit.dart';

class _Search {
  String q = '', status = '';
  int page = 1;
}

class AdminUsersCubit extends RequestCubit<AdminUserPage> {
  final _Search _search;
  AdminUsersCubit(AdminUserService service) : this._(service, _Search());
  AdminUsersCubit._(AdminUserService service, _Search search)
    : _search = search,
      super(
        () =>
            service.list(q: search.q, status: search.status, page: search.page),
      );

  Future<void> search({required String q, required String status}) {
    _search.q = q.trim();
    _search.status = status;
    _search.page = 1;
    return load();
  }

  Future<void> next() async {
    if (state.loading || !(state.data?.hasNext ?? false)) return;
    _search.page++;
    await load();
  }

  Future<void> previous() async {
    if (state.loading || _search.page <= 1) return;
    _search.page--;
    await load();
  }
}
