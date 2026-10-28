import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../cubits/request_cubit.dart';
import '../../models/admin_user.dart';
import '../../services/admin_user_service.dart';
import 'admin_users_page.dart';
import 'admin_account_panel.dart';

class AdminUserDetailPage extends StatelessWidget {
  final int id;
  final AdminUserService? service;
  const AdminUserDetailPage({super.key, required this.id, this.service});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => RequestCubit<AdminUser>(
      () => (service ?? AdminUserService()).detail(id),
    )..load(),
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de usuario'),
        leading: BlocBuilder<RequestCubit<AdminUser>, RequestState<AdminUser>>(
          builder: (context, state) => IconButton(
            tooltip: 'Volver a usuarios',
            onPressed: state.working
                ? null
                : () => context.canPop()
                      ? context.pop()
                      : context.go('/admin/users'),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: BlocBuilder<RequestCubit<AdminUser>, RequestState<AdminUser>>(
              builder: (context, state) => PopScope(
                canPop: !state.working,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (state.loading)
                      const Center(child: CircularProgressIndicator())
                    else if (state.message != null)
                      AdminReadError(
                        message: state.message!,
                        retry: context.read<RequestCubit<AdminUser>>().load,
                        retryLabel: 'Actualizar cuenta e historial',
                      )
                    else if (state.data != null) ...[
                      Text(
                        state.data!.fullName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _datum(
                                context,
                                'Correo',
                                state.data!.email ?? 'No registrado',
                              ),
                              _datum(
                                context,
                                'Estado de la cuenta',
                                state.data!.statusLabel,
                              ),
                              _datum(
                                context,
                                'Tipo de cuenta',
                                switch (state.data!.rol) {
                                  'ADMIN' => 'Administrador',
                                  'USUARIO' => 'Ciudadano',
                                  _ => 'No registrado',
                                },
                              ),
                              _datum(
                                context,
                                'Reportes denunciados',
                                '${state.data!.denouncedReportCount}',
                              ),
                              const Text(
                                'Reportes distintos que recibieron al menos una denuncia. Una denuncia no implica una infracción confirmada.',
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (state.data!.denouncedReportCount > 0)
                        TextButton.icon(
                          onPressed: () => context.push(
                            '/admin/reports?authorId=${state.data!.id}',
                          ),
                          icon: const Icon(Icons.fact_check_outlined),
                          label: const Text(
                            'Ver reportes denunciados de esta cuenta',
                          ),
                        ),
                      AdminAccountPanel(
                        key: ValueKey(
                          '${state.data!.id}:${state.data!.moderationVersion}',
                        ),
                        user: state.data!,
                        service: service,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _datum(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Text(value),
      ],
    ),
  );
}
