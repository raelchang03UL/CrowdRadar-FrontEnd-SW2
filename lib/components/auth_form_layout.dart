import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Ancho legible en escritorio y desplazamiento en móvil/teclado reducido.
class AuthFormLayout extends StatelessWidget {
  final Widget child;
  const AuthFormLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: math.max(0, constraints.maxHeight - 48),
        ),
        child: Center(
          child: ConstrainedBox(
            key: const ValueKey('auth-form-width'),
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 32),
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
