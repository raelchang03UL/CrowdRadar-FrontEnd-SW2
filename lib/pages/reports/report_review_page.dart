import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../components/cr_bottom_nav.dart';
import '../../components/place_status.dart';
import '../../configs/lima_time.dart';
import '../../cubits/request_cubit.dart';
import '../../models/citizen_report.dart';
import '../../services/report_review_service.dart';

class ReportHubPage extends StatelessWidget {
  final ReportReviewService? service;
  const ReportHubPage({super.key, this.service});
  @override
  Widget build(BuildContext context) {
    final api = service ?? ReportReviewService();
    return BlocProvider(
      create: (_) => RequestCubit<List<CitizenReport>>(api.list)..load(),
      child: const _ReportList(),
    );
  }
}

class _ReportList extends StatelessWidget {
  const _ReportList();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Validar')),
    bottomNavigationBar: const CrBottomNav(currentIndex: 1),
    body:
        BlocBuilder<
          RequestCubit<List<CitizenReport>>,
          RequestState<List<CitizenReport>>
        >(
          builder: (context, state) {
            final cubit = context.read<RequestCubit<List<CitizenReport>>>();
            if (state.loading) {
              return const PlaceStatus(
                message: 'Cargando reportes…',
                loading: true,
              );
            }
            if (state.message != null) {
              return PlaceStatus(message: state.message!, retry: cubit.load);
            }
            final items = state.data ?? [];
            if (items.isEmpty) {
              return PlaceStatus(
                message: 'Todavía no hay reportes disponibles para revisar.',
                retry: cubit.load,
              );
            }
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Reportes ciudadanos',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Últimos 50 reportes. Revisa la información antes de confirmar, rechazar o denunciar. Tu participación es única.',
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: cubit.load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Actualizar'),
                      ),
                    ),
                    for (final report in items)
                      Card(
                        child: ListTile(
                          title: Text(report.placeName),
                          subtitle: Text(
                            '${report.level} · ${limaDate(report.createdAt)} (Lima)\n${report.confirmations} confirmaciones · ${report.rejections} rechazos${report.isOwn ? ' · Tu reporte' : ''}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          isThreeLine: true,
                          onTap: () => context.push('/reports/${report.id}'),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
  );
}

class ReportReviewPage extends StatelessWidget {
  final String id;
  final bool ownOnly;
  final ReportReviewService? service;
  const ReportReviewPage({
    super.key,
    required this.id,
    this.ownOnly = false,
    this.service,
  });
  @override
  Widget build(BuildContext context) {
    final api = service ?? ReportReviewService();
    return BlocProvider(
      create: (_) =>
          RequestCubit<CitizenReport>(() => api.detail(id, ownOnly: ownOnly))
            ..load(),
      child: _ReportReview(api: api, id: id),
    );
  }
}

class _ReportReview extends StatelessWidget {
  final ReportReviewService api;
  final String id;
  const _ReportReview({required this.api, required this.id});
  Future<void> _denounce(BuildContext context) async {
    var text = '';
    final cubit = context.read<RequestCubit<CitizenReport>>();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Denunciar reporte'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Envía una denuncia si consideras que la información es fraudulenta. No se ocultará automáticamente.',
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (value) => text = value,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Motivo (opcional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, text),
            child: const Text('Enviar denuncia'),
          ),
        ],
      ),
    );
    if (reason == null || !context.mounted || cubit.isClosed) return;
    final sent = await cubit.perform(() => api.denounce(id, reason));
    if (sent && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Denuncia enviada correctamente.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Revisar reporte'),
      leading: IconButton(
        tooltip: 'Volver',
        icon: const Icon(Icons.arrow_back),
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/validar'),
      ),
    ),
    body: BlocBuilder<RequestCubit<CitizenReport>, RequestState<CitizenReport>>(
      builder: (context, state) {
        final cubit = context.read<RequestCubit<CitizenReport>>();
        if (state.loading) {
          return const PlaceStatus(
            message: 'Consultando reporte…',
            loading: true,
          );
        }
        final report = state.data;
        if (report == null) {
          return PlaceStatus(
            message: state.message ?? 'El reporte no está disponible.',
            retry: cubit.load,
          );
        }
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  report.placeName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text('${report.level} · ${limaDate(report.createdAt)} (Lima)'),
                const SizedBox(height: 24),
                Text(
                  'Estado de validación',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  '${report.confirmations} confirmaciones · ${report.rejections} rechazos',
                ),
                if (report.confirmations + report.rejections == 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Todavía no existen validaciones registradas.'),
                  ),
                const Divider(height: 32),
                Text(
                  'Confiabilidad',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  report.reliability == null
                      ? 'Sin información suficiente: se necesitan 3 validadores distintos.'
                      : 'Nivel ${report.reliability!.toLowerCase()} · Apoyo ponderado ${report.confirmWeight}/${report.totalWeight}',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Política provisional: votos ponderados por karma al participar. No es una probabilidad certificada.',
                ),
                const SizedBox(height: 24),
                if (report.isOwn)
                  const Text(
                    'Este es tu reporte. Puedes consultar su estado, pero no validarlo ni denunciarlo.',
                  )
                else if (report.ownDecision != null)
                  Text(
                    'Ya participaste: ${report.ownDecision == 'CONFIRM' ? 'Confirmaste' : 'Rechazaste'} este reporte.',
                  )
                else ...[
                  const Text(
                    'Tu elección se registra una sola vez y no se puede cambiar.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: state.working
                            ? null
                            : () =>
                                  cubit.perform(() => api.vote(id, 'CONFIRM')),
                        icon: const Icon(Icons.check),
                        label: const Text('Confirmar reporte'),
                      ),
                      OutlinedButton.icon(
                        onPressed: state.working
                            ? null
                            : () => cubit.perform(() => api.vote(id, 'REJECT')),
                        icon: const Icon(Icons.close),
                        label: const Text('Rechazar reporte'),
                      ),
                    ],
                  ),
                ],
                if (state.working)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  ),
                if (state.message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        state.message!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                if (!report.isOwn)
                  TextButton.icon(
                    onPressed: state.working || report.alreadyDenounced
                        ? null
                        : () => _denounce(context),
                    icon: const Icon(Icons.flag_outlined),
                    label: Text(
                      report.alreadyDenounced
                          ? 'Denuncia ya registrada'
                          : 'Denunciar reporte',
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: state.working ? null : cubit.load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar estado'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
