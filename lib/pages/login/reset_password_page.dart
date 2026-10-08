import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../components/auth_fields.dart';
import '../../components/auth_form_layout.dart';
import '../../cubits/login_cubit.dart';
import '../../cubits/recovery_cubit.dart';
import '../../services/recovery_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';

class ResetPasswordPage extends StatefulWidget {
  final String token;
  final RecoveryService? service;
  const ResetPasswordPage({super.key, required this.token, this.service});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _next = TextEditingController();
  final _confirmation = TextEditingController();
  late final ResetPasswordCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = ResetPasswordCubit(
      authCubit: context.read<AuthCubit>(),
      service: widget.service,
    )..validateToken(token: widget.token);
  }

  @override
  void didUpdateWidget(covariant ResetPasswordPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      _next.clear();
      _confirmation.clear();
      _cubit.validateToken(token: widget.token);
    }
  }

  @override
  void dispose() {
    _cubit.close();
    _next.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    final state = _cubit.state;
    if (state is! ResetPasswordReady || state.submitting) return;
    if (_form.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      _cubit.resetPassword(
        newPassword: _next.text,
        confirmPassword: _confirmation.text,
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<ResetPasswordCubit, ResetPasswordState>(
    bloc: _cubit,
    listener: (context, state) {
      if (state is ResetPasswordDone &&
          state.generation == SessionService.generation &&
          !SessionService.isAuthenticated) {
        _next.clear();
        _confirmation.clear();
        // Reemplaza el enlace sensible y no conserva la pantalla en la pila.
        Router.neglect(
          context,
          () => context.go('/login?notice=passwordReset'),
        );
      }
    },
    builder: (context, state) {
      final busy = state is ResetPasswordReady && state.submitting;
      return Scaffold(
        body: SafeArea(
          child: AuthFormLayout(
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
                  'Restablecer contraseña',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                if (state is ResetPasswordChecking ||
                    state is ResetPasswordDone)
                  Semantics(
                    liveRegion: true,
                    child: const Column(
                      children: [
                        SizedBox(height: 16),
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Comprobando el enlace…'),
                      ],
                    ),
                  ),
                if (state is ResetPasswordLinkError) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      state.message,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!state.invalidToken) ...[
                    ElevatedButton(
                      onPressed: _cubit.retryValidation,
                      child: const Text('Reintentar'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextButton(
                    onPressed: () => context.go('/forgot-password'),
                    child: const Text('Solicitar otro enlace'),
                  ),
                ],
                if (state is ResetPasswordReady) ...[
                  const Text(
                    'Elige una contraseña nueva. Al guardar, deberás iniciar sesión nuevamente.',
                  ),
                  const SizedBox(height: 24),
                  Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AuthPasswordField(
                          key: const ValueKey('reset-new-password'),
                          controller: _next,
                          enabled: !busy,
                          registering: true,
                          labelText: 'Nueva contraseña',
                          validator: AuthValidation.password,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        AuthPasswordField(
                          key: const ValueKey('reset-confirm-password'),
                          controller: _confirmation,
                          enabled: !busy,
                          labelText: 'Confirmar nueva contraseña',
                          helperText: 'Vuelve a escribir la contraseña nueva.',
                          validator: (value) => value == null || value.isEmpty
                              ? 'Confirma la contraseña nueva'
                              : value != _next.text
                              ? 'Las contraseñas no coinciden'
                              : null,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                        ),
                        if (busy || state.error != null) ...[
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            child: busy
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : Text(
                                    state.error!,
                                    style: const TextStyle(
                                      color: AppColors.danger,
                                    ),
                                  ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton(
                          key: const ValueKey('reset-password-submit'),
                          onPressed: busy ? null : _submit,
                          child: Text(
                            busy ? 'Guardando…' : 'Guardar contraseña',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: busy ? null : () => context.go('/login'),
                  child: const Text('Volver a iniciar sesión'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
