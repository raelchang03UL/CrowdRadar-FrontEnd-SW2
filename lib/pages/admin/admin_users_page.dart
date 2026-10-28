import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../cubits/admin/admin_users_cubit.dart';
import '../../cubits/request_cubit.dart';
import '../../models/admin_user.dart';
import '../../services/admin_user_service.dart';
import '../../theme/app_colors.dart';

class AdminUsersPage extends StatelessWidget {
  final AdminUserService? service;
  const AdminUsersPage({super.key, this.service});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => AdminUsersCubit(service ?? AdminUserService())..load(),
    child: const _UsersView(),
  );
}

class _UsersView extends StatefulWidget {
  const _UsersView();
  @override
  State<_UsersView> createState() => _UsersViewState();
}

class _UsersViewState extends State<_UsersView> {
  final _query = TextEditingController();
  String _status = '';

  void _search() =>
      context.read<AdminUsersCubit>().search(q: _query.text, status: _status);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Administración'),
      leading: IconButton(
        tooltip: 'Volver a mi perfil',
        onPressed: () => context.go('/profile'),
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: BlocBuilder<AdminUsersCubit, RequestState<AdminUserPage>>(
            builder: (context, state) => ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Usuarios registrados',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text('Busca una cuenta para consultar su información.'),
                TextButton.icon(
                  onPressed: () => context.go('/admin/reports'),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Ver reportes denunciados'),
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final search = TextField(
                      controller: _query,
                      maxLength: 160,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      decoration: const InputDecoration(
                        labelText: 'Nombre o correo',
                        prefixIcon: Icon(Icons.search),
                        counterText: '',
                      ),
                    );
                    final status = DropdownButtonFormField<String>(
                      initialValue: _status,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Estado de cuenta',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: '',
                          child: Text('Todas las cuentas'),
                        ),
                        DropdownMenuItem(
                          value: 'ACTIVO',
                          child: Text('Activas'),
                        ),
                        DropdownMenuItem(
                          value: 'SUSPENDIDO',
                          child: Text('Suspendidas'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _status = value ?? ''),
                    );
                    final button = ElevatedButton.icon(
                      onPressed: _search,
                      icon: const Icon(Icons.search),
                      label: const Text('Buscar'),
                    );
                    if (constraints.maxWidth < 700 ||
                        MediaQuery.textScalerOf(context).scale(14) > 20) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          search,
                          const SizedBox(height: 16),
                          status,
                          const SizedBox(height: 16),
                          button,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: search),
                        const SizedBox(width: 16),
                        SizedBox(width: 220, child: status),
                        const SizedBox(width: 16),
                        SizedBox(width: 140, child: button),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                if (state.loading)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state.message != null)
                  AdminReadError(
                    message: state.message!,
                    retry: context.read<AdminUsersCubit>().load,
                  )
                else if (state.data != null) ...[
                  if (state.data!.users.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Semantics(
                        liveRegion: true,
                        child: const Text(
                          'No hay resultados con estos criterios.',
                        ),
                      ),
                    ),
                  ...state.data!.users.map(
                    (user) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () async {
                            final cubit = context.read<AdminUsersCubit>();
                            await context.push('/admin/users/${user.id}');
                            if (context.mounted && !cubit.isClosed) {
                              await cubit.load();
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.fullName,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        user.email ?? 'Correo no registrado',
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Cuenta ${user.statusLabel.toLowerCase()}',
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${user.denouncedReportCount} ${user.denouncedReportCount == 1 ? 'reporte denunciado' : 'reportes denunciados'}',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                        ),
                        onPressed: state.data!.page > 1
                            ? context.read<AdminUsersCubit>().previous
                            : null,
                        child: const Text('Anterior'),
                      ),
                      Text('Página ${state.data!.page}'),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                        ),
                        onPressed: state.data!.hasNext
                            ? context.read<AdminUsersCubit>().next
                            : null,
                        child: const Text('Siguiente'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AdminReadError extends StatelessWidget {
  final String message;
  final VoidCallback retry;
  final String retryLabel;
  const AdminReadError({
    super.key,
    required this.message,
    required this.retry,
    this.retryLabel = 'Reintentar',
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(liveRegion: true, child: Text(message)),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: retry,
        icon: const Icon(Icons.refresh),
        label: Text(retryLabel),
      ),
    ],
  );
}
