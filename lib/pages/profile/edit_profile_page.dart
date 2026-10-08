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
  final UserService? userService;
  const EditProfilePage({super.key, this.user, this.userService});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final cubit = ProfileCubit(userService ?? UserService());
      if (user == null) cubit.loadProfile();
      return cubit;
    },
    child: _EditProfileView(user: user),
  );
}

class _EditProfileView extends StatefulWidget {
  final UserModel? user;
  const _EditProfileView({this.user});

  @override
  State<_EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<_EditProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _distritoCtrl = TextEditingController();
  late bool _loadingProfile;
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadingProfile = widget.user == null;
    if (widget.user != null) _fill(widget.user!);
  }

  void _fill(UserModel user) {
    _user = user;
    _nombreCtrl.text = user.nombre ?? '';
    _apellidoCtrl.text = user.apellido ?? '';
    _telefonoCtrl.text = user.telefono ?? '';
    _distritoCtrl.text = user.distrito ?? '';
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _telefonoCtrl.dispose();
    _distritoCtrl.dispose();
    super.dispose();
  }

  void _save(BuildContext context) {
    if (context.read<ProfileCubit>().state is ProfileLoading) return;
    if (_formKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      context.read<ProfileCubit>().updateProfile({
        'nombre': _nombreCtrl.text.trim(),
        'apellido': _apellidoCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim(),
        'distrito': _distritoCtrl.text.trim(),
      });
    }
  }

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profile');
    }
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? 'Este campo es obligatorio'
      : null;

  String? _name(String? value) =>
      _required(value) ??
      ((value?.trim().length ?? 0) < 2 ? 'Mínimo 2 caracteres' : null);

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<ProfileCubit, ProfileState>(
    listener: (context, state) {
      if (state is ProfileLoaded) {
        if (_loadingProfile) {
          _fill(state.user);
          _loadingProfile = false;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perfil actualizado correctamente')),
          );
          _back(context);
        }
      }
    },
    builder: (context, state) {
      final busy = state is ProfileLoading;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Editar perfil'),
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
                child: _loadingProfile
                    ? _initialLoad(context, state)
                    : Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Tu información personal',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Actualiza tus datos y guarda los cambios al terminar.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 24),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TextFormField(
                                      controller: _nombreCtrl,
                                      enabled: !busy,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      textInputAction: TextInputAction.next,
                                      decoration: const InputDecoration(
                                        labelText: 'Nombre',
                                        helperText: 'Mínimo 2 caracteres.',
                                      ),
                                      validator: _name,
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _apellidoCtrl,
                                      enabled: !busy,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      textInputAction: TextInputAction.next,
                                      decoration: const InputDecoration(
                                        labelText: 'Apellido',
                                        helperText: 'Mínimo 2 caracteres.',
                                      ),
                                      validator: _name,
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      enabled: false,
                                      initialValue: _user?.email ?? '',
                                      decoration: const InputDecoration(
                                        labelText: 'Correo electrónico',
                                        helperText:
                                            'El correo no se puede editar.',
                                        helperMaxLines: 2,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _telefonoCtrl,
                                      enabled: !busy,
                                      keyboardType: TextInputType.phone,
                                      textInputAction: TextInputAction.next,
                                      maxLength: 9,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'Teléfono',
                                        helperText: 'Hasta 9 dígitos.',
                                        counterText: '',
                                      ),
                                      validator: _required,
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _distritoCtrl,
                                      enabled: !busy,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: busy
                                          ? null
                                          : (_) => _save(context),
                                      decoration: const InputDecoration(
                                        labelText: 'Distrito',
                                      ),
                                      validator: _required,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (busy || state is ProfileError) ...[
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
                                              'Guardando tus cambios…',
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        (state as ProfileError).message,
                                        style: const TextStyle(
                                          color: AppColors.danger,
                                        ),
                                      ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: busy ? null : () => _save(context),
                              icon: const Icon(Icons.check),
                              label: Text(
                                busy ? 'Guardando…' : 'Guardar cambios',
                              ),
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

  Widget _initialLoad(BuildContext context, ProfileState state) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state is ProfileError) ...[
            Semantics(
              liveRegion: true,
              child: Text(state.message, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.read<ProfileCubit>().loadProfile(),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ] else ...[
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 16),
            const Text('Cargando tus datos…', textAlign: TextAlign.center),
          ],
        ],
      ),
    ),
  );
}
