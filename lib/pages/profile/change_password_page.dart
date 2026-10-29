import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../components/auth_fields.dart';
import '../../cubits/login_cubit.dart';
import '../../cubits/password_change_cubit.dart';
import '../../services/password_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';

class ChangePasswordPage extends StatelessWidget {
  final PasswordService? service;
  const ChangePasswordPage({super.key, this.service});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => PasswordChangeCubit(
      authCubit: context.read<AuthCubit>(),
      service: service,
    ),
    child: const _ChangePasswordView(),
  );
}

class _ChangePasswordView extends StatefulWidget {
  const _ChangePasswordView();

  @override
  State<_ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<_ChangePasswordView> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (context.read<PasswordChangeCubit>().state is PasswordChangeLoading) {
      return;
    }
    if (_form.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      context.read<PasswordChangeCubit>().changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
        confirmPassword: _confirmation.text,
      );
    }
  }

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profile');
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<PasswordChangeCubit, PasswordChangeState>(
    listener: (context, state) {
      if (state is PasswordChangeSignedOut &&
          state.generation == SessionService.generation &&
          !SessionService.isAuthenticated) {
        context.go(
          '/login?notice=${state.changed ? 'passwordChanged' : 'sessionExpired'}',
        );
      }
    },
    builder: (context, state) {
      final busy = state is PasswordChangeLoading;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Cambiar contraseña'),
          leading: BackButton(onPressed: () => _back(context)),
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Protege tu cuenta',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Al guardar, se cerrarán tus sesiones anteriores y deberás iniciar sesión con la contraseña nueva.',
                      ),
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              AuthPasswordField(
                                key: const ValueKey('current-password'),
                                controller: _current,
                                enabled: !busy,
                                labelText: 'Contraseña actual',
                                helperText: 'La que usas para iniciar sesión.',
                                textInputAction: TextInputAction.next,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Escribe tu contraseña actual';
                                  }
                                  return utf8.encode(value).length > 72
                                      ? 'No superes 72 bytes'
                                      : null;
                                },
                              ),
                              const SizedBox(height: 16),
                              AuthPasswordField(
                                key: const ValueKey('new-password'),
                                controller: _next,
                                enabled: !busy,
                                labelText: 'Nueva contraseña',
                                helperText:
                                    'Mínimo 8 caracteres y máximo 72 bytes. Debe ser diferente de la actual.',
                                textInputAction: TextInputAction.next,
                                validator: (value) =>
                                    AuthValidation.password(value) ??
                                    (value == _current.text
                                        ? 'Elige una contraseña diferente de la actual'
                                        : null),
                              ),
                              const SizedBox(height: 16),
                              AuthPasswordField(
                                key: const ValueKey('confirm-password'),
                                controller: _confirmation,
                                enabled: !busy,
                                labelText: 'Confirmar nueva contraseña',
                                helperText:
                                    'Vuelve a escribir la contraseña nueva.',
                                textInputAction: TextInputAction.done,
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Confirma la contraseña nueva'
                                    : value != _next.text
                                    ? 'Las contraseñas no coinciden'
                                    : null,
                                onSubmitted: busy
                                    ? null
                                    : (_) => _submit(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (busy || state is PasswordChangeError) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          child: busy
                              ? const Row(
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Actualizando tu contraseña…',
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  (state as PasswordChangeError).message,
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                  ),
                                ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        key: const ValueKey('change-password-submit'),
                        onPressed: busy ? null : () => _submit(context),
                        icon: const Icon(Icons.lock_reset),
                        label: Text(busy ? 'Guardando…' : 'Guardar contraseña'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: busy ? null : () => _back(context),
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
