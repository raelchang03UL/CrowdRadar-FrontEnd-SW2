import 'package:flutter/material.dart';

import '../../components/cr_bottom_nav.dart';
import '../../models/saturation_report_model.dart';
import '../../services/report_history_service.dart';
import '../../theme/app_colors.dart';

class ReportHistoryPage extends StatefulWidget {
  final ReportHistoryService? service;
  const ReportHistoryPage({super.key, this.service});

  @override
  State<ReportHistoryPage> createState() => _ReportHistoryPageState();
}

class _ReportHistoryPageState extends State<ReportHistoryPage> {
  late Future<List<SaturationReportModel>> _reports;

  @override
  void initState() {
    super.initState();
    _reports = _load();
  }

  Future<List<SaturationReportModel>> _load() async {
    final response = await (widget.service ?? ReportHistoryService()).getReports();
    if (!response.success || response.data == null) {
      throw Exception(response.message);
    }
    return response.data!;
  }

  void _retry() => setState(() => _reports = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mis reportes'),
      leading: const BackButton(),
    ),
    bottomNavigationBar: const CrBottomNav(currentIndex: 3),
    body: ColoredBox(
      color: const Color(0xFFF1F8E9),
      child: FutureBuilder<List<SaturationReportModel>>(
        future: _reports,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _StateMessage(
              icon: Icons.cloud_off_outlined,
              message: snapshot.error.toString().replaceFirst('Exception: ', ''),
              action: _retry,
            );
          }
          final reports = snapshot.data ?? const <SaturationReportModel>[];
          if (reports.isEmpty) {
            return const _EmptyHistory();
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              _HistorySummary(reports: reports),
              const SizedBox(height: 10),
              for (final report in reports) ...[
                _ReportCard(report: report),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    ),
  );
}

class _HistorySummary extends StatelessWidget {
  final List<SaturationReportModel> reports;
  const _HistorySummary({required this.reports});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: _SummaryItem(value: '${reports.length}', label: 'Reportes')),
      const SizedBox(width: 8),
      Expanded(
        child: _SummaryItem(
          value: '${reports.where((report) => report.level == 'TRANQUILO').length}',
          label: 'Tranquilos',
          color: AppColors.success,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _SummaryItem(
          value: '${reports.where((report) => report.level == 'SATURADO').length}',
          label: 'Saturados',
          color: AppColors.warning,
        ),
      ),
    ],
  );
}

class _SummaryItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _SummaryItem({
    required this.value,
    required this.label,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    ),
  );
}

class _ReportCard extends StatelessWidget {
  final SaturationReportModel report;
  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        builder: (_) => _ReportDetails(report: report),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.placeName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(report.createdAt),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                _LevelChip(label: report.levelLabel, color: _color),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                _StatusChip(
                  label: 'Registrado',
                  color: AppColors.success,
                ),
                const Spacer(),
                Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Color get _color => switch (report.level) {
    'TRANQUILO' => AppColors.success,
    'MODERADO' => AppColors.warning,
    'SATURADO' => AppColors.danger,
    _ => AppColors.primary,
  };

  String _formatDate(DateTime date) =>
      '${_dayName(date.weekday)}, ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  String _dayName(int weekday) => const [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom',
  ][weekday - 1];
}

class _LevelChip extends StatelessWidget {
  final String label;
  final Color color;
  const _LevelChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => _StatusChip(
    label: label,
    color: color,
  );
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📋', style: TextStyle(fontSize: 30)),
          const SizedBox(height: 12),
          Text(
            'Aún no tienes reportes',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Cuando reportes la saturación de un lugar, aparecerá aquí tu historial.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class _ReportDetails extends StatelessWidget {
  final SaturationReportModel report;
  const _ReportDetails({required this.report});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Detalle del reporte', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          _DetailRow(Icons.location_on_outlined, 'Lugar', report.placeName),
          _DetailRow(Icons.calendar_today_outlined, 'Fecha', _dateTime(report.createdAt)),
          _DetailRow(Icons.people_outline, 'Nivel de saturación', report.levelLabel),
        ],
      ),
    ),
  );

  String _dateTime(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text('$label: $value')),
      ],
    ),
  );
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? action;
  const _StateMessage({required this.icon, required this.message, this.action});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: action,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    ),
  );
}
