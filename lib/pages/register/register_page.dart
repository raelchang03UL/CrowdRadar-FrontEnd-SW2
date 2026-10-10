import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../cubits/login_cubit.dart';
import '../../cubits/login_state.dart';

import '../../theme/app_colors.dart';
import '../../components/auth_form_layout.dart';
import '../../components/auth_fields.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _RegisterView();
  }
}

class _RegisterView extends StatefulWidget {
  const _RegisterView();

  @override
  State<_RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<_RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _distritoCtrl = TextEditingController();

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _telefonoCtrl.dispose();
    _distritoCtrl.dispose();
    super.dispose();
  }

  void _onRegister(BuildContext context) {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthCubit>().register(
        nombre: _nombreCtrl.text.trim(),
        apellido: _apellidoCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        telefono: _telefonoCtrl.text.trim(),
        distrito: _distritoCtrl.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthRegistered) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Cuenta creada. Ya puedes iniciar sesión con tu correo y contraseña.',
              ),
            ),
          );
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/login');
          }
        }
      },
      builder: (context, state) {
        final loading = state is AuthLoading;

        return Scaffold(
          appBar: AppBar(title: const Text('Crear cuenta')),
          body: AuthFormLayout(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Crea tu cuenta',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Todos los campos son obligatorios. Usa un correo que no hayas registrado en este entorno.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    enabled: !loading,
                    controller: _nombreCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      helperText: 'Al menos 2 caracteres.',
                    ),
                    validator: AuthValidation.name,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    enabled: !loading,
                    controller: _apellidoCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Apellido',
                      helperText: 'Al menos 2 caracteres.',
                    ),
                    validator: AuthValidation.name,
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
                      helperText: 'Debe ser único en esta base local.',
                      errorMaxLines: 2,
                    ),
                    validator: AuthValidation.email,
                  ),
                  const SizedBox(height: 16),
                  AuthPasswordField(
                    enabled: !loading,
                    registering: true,
                    controller: _passwordCtrl,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    enabled: !loading,
                    controller: _telefonoCtrl,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    maxLength: 9,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      counterText: '',
                      helperText: 'Exactamente 9 dígitos, sin espacios.',
                    ),
                    validator: AuthValidation.phone,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    enabled: !loading,
                    controller: _distritoCtrl,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!loading) _onRegister(context);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Distrito',
                      helperText:
                          'Al menos 2 caracteres, por ejemplo Miraflores.',
                    ),
                    validator: AuthValidation.name,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: loading ? null : () => _onRegister(context),
                    child: Text(loading ? 'Creando cuenta…' : 'Registrarme'),
                  ),
                  AuthFeedback(
                    loading: loading,
                    error:
                        state is AuthError &&
                            context.read<AuthCubit>().lastOperation ==
                                AuthOperation.register
                        ? state.error
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
