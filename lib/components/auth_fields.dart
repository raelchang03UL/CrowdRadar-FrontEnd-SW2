import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AuthValidation {
  static String? name(String? value) =>
      (value?.trim().length ?? 0) < 2 ? 'Escribe al menos 2 caracteres' : null;
  static String? email(String? value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')
      ? null
      : 'Escribe un correo válido, por ejemplo nombre@correo.com';
  static String? password(String? value) {
    if (value == null || value.trim().isEmpty || value.length < 8) {
      return 'Usa al menos 8 caracteres';
    }
    if (utf8.encode(value).length > 72) return 'No superes 72 bytes';
    return null;
  }

  static String? phone(String? value) =>
      RegExp(r'^\d{9}$').hasMatch(value ?? '')
      ? null
      : 'Escribe exactamente 9 dígitos';
}

class AuthPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool registering;
  final ValueChanged<String>? onSubmitted;
  const AuthPasswordField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.registering = false,
    this.onSubmitted,
  });
  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _visible = false;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    enabled: widget.enabled,
    obscureText: !_visible,
    autocorrect: false,
    enableSuggestions: false,
    enableIMEPersonalizedLearning: false,
    textInputAction: widget.registering
        ? TextInputAction.next
        : TextInputAction.done,
    onFieldSubmitted: widget.onSubmitted,
    decoration: InputDecoration(
      labelText: 'Contraseña',
      helperText: widget.registering
          ? 'Mínimo 8 caracteres y máximo 72 bytes.'
          : 'La que elegiste al crear tu cuenta.',
      helperMaxLines: 2,
      errorMaxLines: 2,
      suffixIcon: IconButton(
        tooltip: _visible ? 'Ocultar contraseña' : 'Mostrar contraseña',
        onPressed: widget.enabled
            ? () => setState(() => _visible = !_visible)
            : null,
        icon: Icon(
          _visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
      ),
    ),
    validator: widget.registering
        ? AuthValidation.password
        : (value) =>
              value == null || value.isEmpty ? 'Escribe tu contraseña' : null,
  );
}

class AuthFeedback extends StatelessWidget {
  final bool loading;
  final String? error;
  const AuthFeedback({super.key, required this.loading, this.error});
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.only(top: 12),
      child: loading
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Flexible(child: Text('Conectando con el servidor…')),
              ],
            )
          : error == null
          ? const SizedBox.shrink()
          : Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger),
            ),
    ),
  );
}
