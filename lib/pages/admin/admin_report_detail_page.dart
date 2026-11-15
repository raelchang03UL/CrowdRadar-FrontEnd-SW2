import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../configs/lima_time.dart';
import '../../cubits/admin/admin_reports_cubit.dart';
import '../../cubits/request_cubit.dart';
import '../../models/admin_report.dart';
import '../../services/admin_report_service.dart';
import '../../services/session_service.dart';
import 'admin_report_decision_dialog.dart';
import 'admin_users_page.dart';

class AdminReportDetailPage extends StatelessWidget {
  final String id;
  final AdminReportService? service;
  const AdminReportDetailPage({super.key, required this.id, this.service});
  @override
  Widget build(BuildContext context) {
    final api = service ?? AdminReportService();
    return BlocProvider(
      create: (_) => AdminReportCubit(api, id)..load(),
      child: _DetailView(api: api),
    );
  }
}

class _DetailView extends StatelessWidget {
  final AdminReportService api;
  const _DetailView({required this.api});
  Future<void> _decide(
    BuildContext context,
    AdminReport report,
    String decision,
  ) async {
    final cubit = context.read<AdminReportCubit>(),
        generation = SessionService.generation;
    if (cubit.state.working) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) =>
          AdminReportDecisionDialog(report: report, decision: decision),
    );
    if (reason == null ||
        !context.mounted ||
        cubit.isClosed ||
        generation != SessionService.generation ||
        !SessionService.isAuthenticated) {
      return;
    }
    await cubit.decide(api, report, decision, reason);
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<AdminReportCubit, RequestState<AdminReportDetail>>(
    builder: (context, state) {
      final cubit = context.read<AdminReportCubit>(),
          detail = state.data,
          report = detail?.report;
      return PopScope(
        canPop: !state.working,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Revisión del reporte'),
            leading: IconButton(
              tooltip: 'Volver a reportes',
              onPressed: state.working
                  ? null
                  : () => context.canPop()
                        ? context.pop()
                        : context.go('/admin/reports'),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (state.loading)
                      const Center(child: CircularProgressIndicator())
                    else if (state.message != null)
                      AdminReadError(
                        message: state.message!,
                        retry: cubit.recent,
                        retryLabel: 'Actualizar reporte e historial',
                      )
                    else if (report != null && detail != null) ...[
                      Text(
                        report.placeName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 20),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('Total de denuncias recibidas'),
                              const SizedBox(height: 8),
                              Text(
                                '${report.denunciationCount}',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 16),
                              Text('Revisión: ${report.stateLabel}'),
                              const SizedBox(height: 8),
                              Text(
                                'Autor: ${report.authorName} (ID ${report.authorId})',
                              ),
                              const SizedBox(height: 8),
                              Text('Nivel reportado: ${report.level}'),
                              const SizedBox(height: 8),
                              Text('${limaDate(report.createdAt)} (Lima)'),
                              if (report.reviewState == 'PENDING' &&
                                  report.reviewedDenunciationCount > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    'Denuncias posteriores a la última revisión: ${report.denunciationCount - report.reviewedDenunciationCount}.',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Motivos recibidos',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      for (final group in detail.reasons)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                '${group.count} ${group.count == 1 ? 'denuncia' : 'denuncias'} · ${group.reason ?? 'Sin motivo'}',
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (report.isPublic &&
                          report.authorRole == 'USUARIO') ...[
                        if (report.reviewState == 'PENDING')
                          ElevatedButton(
                            onPressed: state.working
                                ? null
                                : () => _decide(context, report, 'KEEP'),
                            child: const Text('Conservar reporte'),
                          ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: state.working
                              ? null
                              : () => _decide(context, report, 'REMOVE'),
                          child: const Text('Retirar de vista pública'),
                        ),
                      ] else
                        Text(
                          report.isPublic
                              ? 'Solo se moderan reportes de cuentas ciudadanas.'
                              : 'Reporte retirado: la evidencia se conserva para consulta.',
                        ),
                      if (state.working)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: LinearProgressIndicator(),
                        ),
                      const SizedBox(height: 28),
                      Text(
                        'Historial de decisiones',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (detail.history.isEmpty)
                        const Text(
                          'Aún no hay decisiones registradas sobre este reporte.',
                        ),
                      for (final action in detail.history)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    action.decision == 'KEEP'
                                        ? 'Reporte conservado'
                                        : 'Reporte retirado',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text('${limaDate(action.createdAt)} (Lima)'),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Administrador: ${action.adminName} (ID ${action.adminId})',
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Motivo: ${action.reason}'),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Denuncias consideradas: ${action.reviewedDenunciationCount}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (detail.nextHistoryBefore != null)
                        OutlinedButton(
                          onPressed: state.working ? null : cubit.older,
                          child: const Text('Ver decisiones más antiguas'),
                        ),
                      if (cubit.hasOlderHistory)
                        TextButton(
                          onPressed: state.working ? null : cubit.recent,
                          child: const Text('Volver a decisiones recientes'),
                        ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: state.working ? null : cubit.recent,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Actualizar revisión'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
