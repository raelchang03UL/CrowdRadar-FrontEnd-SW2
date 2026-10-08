import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../components/auth_fields.dart';
import '../../components/auth_form_layout.dart';
import '../../cubits/recovery_cubit.dart';
import '../../services/recovery_service.dart';
import '../../theme/app_colors.dart';

class ForgotPasswordPage extends StatelessWidget {
  final RecoveryService? service;
  const ForgotPasswordPage({super.key, this.service});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ForgotPasswordCubit(service: service),
    child: const _ForgotPasswordView(),
  );
}

class _ForgotPasswordView extends StatefulWidget {
  const _ForgotPasswordView();
  @override
  State<_ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<_ForgotPasswordView> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    final state = context.read<ForgotPasswordCubit>().state;
    if (state is ForgotPasswordLoading || state is ForgotPasswordConfirmed) {
      return;
    }
    if (_form.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      context.read<ForgotPasswordCubit>().requestReset(email: _email.text);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ForgotPasswordCubit, ForgotPasswordState>(
    builder: (context, state) {
      final busy = state is ForgotPasswordLoading;
      final confirmed = state is ForgotPasswordConfirmed;
      return Scaffold(
        body: SafeArea(
          child: AuthFormLayout(
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/images/crowdradar-logo-transparent.png',
                      height: 72,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Recuperar contraseña',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Escribe tu correo para solicitar un enlace de recuperación.',
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _email,
                    enabled: !busy && !confirmed,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      hintText: 'nombre@correo.com',
                      errorMaxLines: 3,
                    ),
                    validator: AuthValidation.email,
                    onFieldSubmitted: (_) => _submit(context),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    key: const ValueKey('forgot-password-submit'),
                    onPressed: busy || confirmed
                        ? null
                        : () => _submit(context),
                    child: Text(busy ? 'Solicitando…' : 'Enviar enlace'),
                  ),
                  if (busy || confirmed || state is ForgotPasswordError) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: busy
                          ? const Center(child: CircularProgressIndicator())
                          : Text(
                              confirmed
                                  ? RecoveryService.requestedMessage
                                  : (state as ForgotPasswordError).message,
                              style: TextStyle(
                                color: confirmed
                                    ? AppColors.text
                                    : AppColors.danger,
                              ),
                            ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: busy ? null : () => context.go('/login'),
                    child: const Text('Volver a iniciar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
