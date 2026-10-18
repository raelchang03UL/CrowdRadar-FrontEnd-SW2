import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../components/place_status.dart';
import '../../configs/lima_time.dart';
import '../../cubits/request_cubit.dart';
import '../../services/place_history_service.dart';

class PlaceHistoryPage extends StatefulWidget {
  final int id;
  final PlaceHistoryService? service;
  const PlaceHistoryPage({super.key, required this.id, this.service});
  @override
  State<PlaceHistoryPage> createState() => _PlaceHistoryState();
}

class _PlaceHistoryState extends State<PlaceHistoryPage> {
  late final TextEditingController _from, _to, _compareFrom, _compareTo;
  late final RequestCubit<Map<String, dynamic>> _cubit;
  final _form = GlobalKey<FormState>();
  int _mode = 0;
  @override
  void initState() {
    super.initState();
    final today = DateTime.parse(limaToday());
    String date(DateTime value) => value.toIso8601String().substring(0, 10);
    _from = TextEditingController(
      text: date(today.subtract(const Duration(days: 6))),
    );
    _to = TextEditingController(text: date(today));
    _compareFrom = TextEditingController(
      text: date(today.subtract(const Duration(days: 13))),
    );
    _compareTo = TextEditingController(
      text: date(today.subtract(const Duration(days: 7))),
    );
    final service = widget.service ?? PlaceHistoryService();
    _cubit = RequestCubit(
      () => service
          .load(widget.id, ['history', 'comparison', 'quiet-hours'][_mode], {
            'from': _from.text,
            'to': _to.text,
            if (_mode == 1) 'compareFrom': _compareFrom.text,
            if (_mode == 1) 'compareTo': _compareTo.text,
          }),
    )..load();
  }

  @override
  void dispose() {
    _cubit.close();
    for (final c in [_from, _to, _compareFrom, _compareTo]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _date(String label, TextEditingController controller, bool enabled) =>
      SizedBox(
        width: 260,
        child: TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.datetime,
          decoration: InputDecoration(labelText: label, hintText: 'AAAA-MM-DD'),
          validator: (value) =>
              value != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)
              ? null
              : 'Usa AAAA-MM-DD',
          onFieldSubmitted: (_) => _consult(),
        ),
      );
  void _consult() {
    if (_form.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      _cubit.load();
    }
  }

  Widget _counts(Map<String, dynamic> data, String title) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Bloques suficientes: ${data['sufficient']}'),
          Text(
            'Tranquilos: ${data['counts']['TRANQUILO']} · Moderados: ${data['counts']['MODERADO']} · Saturados: ${data['counts']['SATURADO']}',
          ),
          Text('Sin información suficiente: ${data['insufficient']}'),
        ],
      ),
    ),
  );
  List<Widget> _results(Map<String, dynamic> data) {
    if (_mode == 1) {
      return [
        if (data['comparable'] != true)
          const Text(
            'No hay información suficiente para comparar ambos períodos.',
          ),
        _counts(data['first'] as Map<String, dynamic>, 'Período A'),
        _counts(data['second'] as Map<String, dynamic>, 'Período B'),
        const Text(
          'Se comparan conteos de bloques horarios, no aforos ni promedios de categorías.',
        ),
      ];
    }
    if (_mode == 2) {
      final items = data['recommendations'] as List;
      return [
        if (items.isEmpty)
          Text(
            data['reason'] == 'NO_QUIET_HOURS'
                ? 'Hay datos, pero no bloques tranquilos suficientes para recomendar un horario.'
                : 'No existen datos suficientes para recomendar horarios: se necesitan 3 días con datos suficientes por horario.',
          ),
        for (final item in items)
          ListTile(
            leading: Text('#${item['rank']}'),
            title: Text(
              '${item['hour'].toString().padLeft(2, '0')}:00–${((item['hour'] as int) + 1).toString().padLeft(2, '0')}:00',
            ),
            subtitle: Text(
              '${item['quietDays']}/${item['days']} días con bloque tranquilo (Lima)',
            ),
          ),
        const Text(
          'Comportamiento histórico observado. No garantiza la saturación de una visita futura.',
        ),
      ];
    }
    final blocks = (data['blocks'] as List)
        .where((item) => item['reportCount'] > 0)
        .toList();
    return [
      _counts(data, 'Resumen horario'),
      if (data['hasReports'] != true)
        const Text('No existe información histórica para este período.'),
      for (final block in blocks)
        ListTile(
          title: Text(
            '${limaDate(DateTime.parse(block['start'] as String))} (Lima)',
          ),
          subtitle: Text(
            '${block['level'] ?? 'Sin información suficiente'} · ${block['reportCount']} personas distintas',
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Historial de saturación'),
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/map'),
        ),
      ),
      body:
          BlocBuilder<
            RequestCubit<Map<String, dynamic>>,
            RequestState<Map<String, dynamic>>
          >(
            builder: (context, state) => Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'Hora de Lima · Bloques de 1 hora · Máximo 31 días por período.',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < 3; i++)
                          ChoiceChip(
                            label: Text(
                              ['Historial', 'Comparar', 'Horarios'][i],
                            ),
                            selected: _mode == i,
                            onSelected: state.loading
                                ? null
                                : (_) {
                                    setState(() => _mode = i);
                                    _consult();
                                  },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Form(
                      key: _form,
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _date('Desde (A)', _from, !state.loading),
                          _date('Hasta (A)', _to, !state.loading),
                          if (_mode == 1) ...[
                            _date('Desde (B)', _compareFrom, !state.loading),
                            _date('Hasta (B)', _compareTo, !state.loading),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: state.loading ? null : _consult,
                      icon: const Icon(Icons.search),
                      label: const Text('Consultar período'),
                    ),
                    const SizedBox(height: 24),
                    if (state.loading)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (state.message != null)
                      PlaceStatus(message: state.message!, retry: _consult)
                    else if (state.data != null)
                      ..._results(state.data!),
                  ],
                ),
              ),
            ),
          ),
    ),
  );
}
