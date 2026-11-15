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
                child: FocusTraversalGroup(child: child),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Cabecera de tarea compartida sin duplicar los estilos del tema.
class AuthFormHeader extends StatelessWidget {
  final String title;
  final String? description;
  final bool showBrand;

  const AuthFormHeader({
    super.key,
    required this.title,
    this.description,
    this.showBrand = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (showBrand) ...[
        Center(
          child: Image.asset(
            'assets/images/crowdradar-logo-transparent.png',
            height: 64,
            semanticLabel: 'CrowdRadar',
          ),
        ),
        const SizedBox(height: 16),
      ],
      Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
      ),
      if (description != null) ...[
        const SizedBox(height: 8),
        Text(
          description!,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ],
  );
}
