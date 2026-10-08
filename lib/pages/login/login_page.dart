import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../cubits/login_cubit.dart';
import '../../cubits/login_state.dart';

import '../../theme/app_colors.dart';
import '../../components/auth_form_layout.dart';
import '../../components/auth_fields.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LoginView();
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _onLogin(BuildContext context) {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthCubit>().login(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthLoggedIn) {
          context.go('/map');
        }
      },
      builder: (context, state) {
        final loading = state is AuthLoading;

        return Scaffold(
          backgroundColor: AppColors.bg,
          body: SafeArea(
            child: AuthFormLayout(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/images/crowdradar-logo-transparent.png',
                        height: 130,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Iniciar sesión',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Usa el correo y la contraseña con los que te registraste.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      enabled: !loading,
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        hintText: 'nombre@correo.com',
                        errorMaxLines: 2,
                      ),
                      validator: AuthValidation.email,
                    ),
                    const SizedBox(height: 16),
                    AuthPasswordField(
                      enabled: !loading,
                      controller: _passwordCtrl,
                      onSubmitted: (_) {
                        if (!loading) _onLogin(context);
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: loading ? null : () => _onLogin(context),
                      child: Text(loading ? 'Ingresando…' : 'Iniciar sesión'),
                    ),
                    AuthFeedback(
                      loading: loading,
                      error:
                          state is AuthError &&
                              context.read<AuthCubit>().lastOperation ==
                                  AuthOperation.login
                          ? state.error
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: TextButton(
                        onPressed: loading
                            ? null
                            : () => context.push('/register'),
                        child: Text.rich(
                          TextSpan(
                            text: '¿No tienes cuenta? ',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            children: const [
                              TextSpan(
                                text: 'Regístrate',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
}
