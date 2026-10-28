import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../configs/lima_time.dart';
import '../../cubits/admin/admin_reports_cubit.dart';
import '../../cubits/request_cubit.dart';
import '../../models/admin_report.dart';
import '../../services/admin_report_service.dart';
import 'admin_users_page.dart';

class AdminReportsPage extends StatelessWidget {
  final int? authorId;
  final AdminReportService? service;
  const AdminReportsPage({super.key, this.authorId, this.service});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        AdminReportsCubit(service ?? AdminReportService(), authorId: authorId)
          ..load(),
    child: _ReportsView(authorId: authorId),
  );
}

class _ReportsView extends StatefulWidget {
  final int? authorId;
  const _ReportsView({this.authorId});
  @override
  State<_ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<_ReportsView> {
  late String _state;
  @override
  void initState() {
    super.initState();
    _state = widget.authorId == null ? 'PENDING' : 'ALL';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Reportes denunciados'),
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
          child: BlocBuilder<AdminReportsCubit, RequestState<AdminReportPage>>(
            builder: (context, state) {
              final cubit = context.read<AdminReportsCubit>();
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Revisar reportes denunciados',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Una denuncia solicita revisión; no demuestra por sí sola que hubo una infracción.',
                  ),
                  if (widget.authorId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text('Reportes del usuario ID ${widget.authorId}'),
                    ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => context.go('/admin/users'),
                    icon: const Icon(Icons.people_outline),
                    label: const Text('Gestionar usuarios'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _state,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Estado de revisión',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'PENDING',
                        child: Text('Pendientes'),
                      ),
                      DropdownMenuItem(
                        value: 'KEPT',
                        child: Text('Conservados'),
                      ),
                      DropdownMenuItem(
                        value: 'REMOVED',
                        child: Text('Retirados'),
                      ),
                      DropdownMenuItem(
                        value: 'ALL',
                        child: Text('Todos los estados'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _state = value ?? 'PENDING'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => cubit.filter(_state),
                    icon: const Icon(Icons.filter_list),
                    label: const Text('Aplicar filtro'),
                  ),
                  const SizedBox(height: 24),
                  if (state.loading)
                    const Center(child: CircularProgressIndicator())
                  else if (state.message != null)
                    AdminReadError(message: state.message!, retry: cubit.load)
                  else if (state.data != null) ...[
                    if (state.data!.reports.isEmpty)
                      const Text(
                        'No hay reportes denunciados con estos criterios.',
                      ),
                    for (final report in state.data!.reports)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: InkWell(
                            onTap: () async {
                              await context.push('/admin/reports/${report.id}');
                              if (context.mounted && !cubit.isClosed) {
                                await cubit.load();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    report.placeName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${report.denunciationCount} ${report.denunciationCount == 1 ? 'denuncia recibida' : 'denuncias recibidas'} · ${report.stateLabel}',
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Autor: ${report.authorName} (ID ${report.authorId})',
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${report.level} · ${limaDate(report.createdAt)} (Lima)',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (state.data!.nextBefore != null)
                      OutlinedButton(
                        onPressed: cubit.older,
                        child: const Text('Ver reportes más antiguos'),
                      ),
                    if (cubit.hasOlderPage)
                      TextButton(
                        onPressed: cubit.recent,
                        child: const Text('Volver a los más recientes'),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
