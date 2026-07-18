import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../cubits/profile/profile_cubit.dart';
import '../../cubits/profile/profile_state.dart';

import '../../models/user_model.dart';

import '../../services/user_service.dart';

import '../../theme/app_colors.dart';

class EditProfilePage extends StatelessWidget {
  final UserModel? user;

  const EditProfilePage({super.key, this.user});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProfileCubit(UserService()),
      child: _EditProfileView(user: user),
    );
  }
}

class _EditProfileView extends StatefulWidget {
  final UserModel? user;

  const _EditProfileView({this.user});

  @override
  State<_EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<_EditProfileView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _apellidoCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _distritoCtrl;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.user?.nombre ?? '');
    _apellidoCtrl = TextEditingController(text: widget.user?.apellido ?? '');
    _telefonoCtrl = TextEditingController(text: widget.user?.telefono ?? '');
    _distritoCtrl = TextEditingController(text: widget.user?.distrito ?? '');
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _telefonoCtrl.dispose();
    _distritoCtrl.dispose();
    super.dispose();
  }

  void _onGuardar(BuildContext context) {
    if (_formKey.currentState?.validate() ?? false) {
      final cambios = {
        'nombre': _nombreCtrl.text.trim(),
        'apellido': _apellidoCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim(),
        'distrito': _distritoCtrl.text.trim(),
      };
      context.read<ProfileCubit>().updateProfile(cambios);
    }
  }

  String? _requerido(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es obligatorio';
    }
    return null;
  }

  String? _nombreApellido(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es obligatorio';
    }
    if (value.trim().length < 2) {
      return 'Mínimo 2 caracteres';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileCubit, ProfileState>(
      listener: (context, state) {
        if (state is ProfileLoaded) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perfil actualizado correctamente')),
          );
          context.pop();
        } else if (state is ProfileError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        if (state is ProfileLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Editar perfil')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: _nombreApellido,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _apellidoCtrl,
                    decoration: const InputDecoration(labelText: 'Apellido'),
                    validator: _nombreApellido,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    enabled: false,
                    initialValue: widget.user?.email ?? '',
                    decoration: const InputDecoration(labelText: 'Correo electrónico'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _telefonoCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength: 9,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      counterText: '',
                    ),
                    validator: _requerido,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _distritoCtrl,
                    decoration: const InputDecoration(labelText: 'Distrito'),
                    validator: _requerido,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _onGuardar(context),
                    child: const Text('Guardar cambios'),
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
