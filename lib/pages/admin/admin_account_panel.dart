import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../configs/lima_time.dart';
import '../../cubits/admin/admin_history_cubit.dart';
import '../../cubits/request_cubit.dart';
import '../../models/admin_user.dart';
import '../../services/admin_user_service.dart';
import '../../services/session_service.dart';
import 'admin_account_dialog.dart';
import 'admin_users_page.dart';

class AdminAccountPanel extends StatelessWidget {
  final AdminUser user;
  final AdminUserService? service;
  const AdminAccountPanel({super.key, required this.user, this.service});

  Future<void> _decide(BuildContext context, bool suspend) async {
    final generation = SessionService.generation;
    final cubit = context.read<RequestCubit<AdminUser>>();
    if (cubit.state.working) return;
    final text = await showDialog<String>(
      context: context,
      builder: (_) => AdminAccountDialog(user: user, suspend: suspend),
    );
    if (text == null ||
        !context.mounted ||
        generation != SessionService.generation ||
        !SessionService.isAuthenticated) {
      return;
    }
    await cubit.perform(
      () => (service ?? AdminUserService()).transition(
        user,
        suspend: suspend,
        text: text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        AdminHistoryCubit(service ?? AdminUserService(), user.id)..load(),
    child: Builder(
      builder: (context) {
        final working = context.watch<RequestCubit<AdminUser>>().state.working;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            if (user.rol == 'USUARIO' &&
                ['ACTIVO', 'SUSPENDIDO'].contains(user.status)) ...[
              ElevatedButton.icon(
                onPressed: working
                    ? null
                    : () => _decide(context, user.status == 'ACTIVO'),
                icon: Icon(
                  user.status == 'ACTIVO'
                      ? Icons.block
                      : Icons.check_circle_outline,
                ),
                label: Text(
                  working
                      ? 'Guardando decisión…'
                      : user.status == 'ACTIVO'
                      ? 'Suspender cuenta'
                      : 'Reactivar cuenta',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Toda decisión se guarda en el historial. La suspensión continúa hasta una reactivación manual.',
              ),
            ] else
              const Text(
                'Las acciones de moderación solo están disponibles para cuentas ciudadanas con estado registrado.',
              ),
            const SizedBox(height: 32),
            Text(
              'Historial de la cuenta',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Fechas en hora de Lima. Se conserva quién tomó cada decisión y su motivo u observación.',
            ),
            const SizedBox(height: 16),
            BlocBuilder<AdminHistoryCubit, RequestState<AdminAccountHistory>>(
              builder: (context, state) {
                final cubit = context.read<AdminHistoryCubit>();
                if (state.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.message != null) {
                  return AdminReadError(
                    message: state.message!,
                    retry: cubit.load,
                  );
                }
                final history = state.data;
                if (history == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (history.actions.isEmpty)
                      const Text(
                        'No hay decisiones registradas desde que se habilitó este historial.',
                      ),
                    for (final action in history.actions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  action.action == 'SUSPEND'
                                      ? 'Cuenta suspendida'
                                      : 'Cuenta reactivada',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text('${limaDate(action.createdAt)} · Lima'),
                                const SizedBox(height: 8),
                                Text(
                                  'Administrador: ${action.adminName} (ID ${action.adminId})',
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${action.action == 'SUSPEND' ? 'Motivo' : 'Observación'}: ${action.reason ?? 'Sin observación'}',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (history.nextBefore != null)
                      OutlinedButton(
                        onPressed: working ? null : cubit.older,
                        child: const Text('Ver decisiones más antiguas'),
                      ),
                    if (cubit.hasOlderPage) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: working ? null : cubit.recent,
                        child: const Text('Volver a las decisiones recientes'),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        );
      },
    ),
  );
}
