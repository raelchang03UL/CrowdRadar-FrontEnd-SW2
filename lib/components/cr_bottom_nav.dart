import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';

class CrBottomNav extends StatelessWidget {
  final int currentIndex;

  const CrBottomNav({super.key, required this.currentIndex});

  static const List<String> _routes = [
    '/map',
    '/validar',
    '/favoritos',
    '/profile',
  ];

  void _onTap(BuildContext context, int index) {
    // Una sección activa puede mostrar una subruta (p. ej., Mis reportes).
    if (index == currentIndex &&
        GoRouterState.of(context).uri.path == _routes[index]) {
      return;
    }
    context.go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.borderNav, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, minHeight: 64),
            child: Row(
              children: [
                _item(context, 0, Icons.map_outlined, 'Mapa'),
                _item(context, 1, Icons.shield_outlined, 'Validar'),
                _item(context, 2, Icons.favorite_border, 'Favoritos'),
                _item(context, 3, Icons.person_outline, 'Perfil'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, int index, IconData icon, String label) {
    final bool active = index == currentIndex;
    final Color color = active ? AppColors.primary : AppColors.textMuted;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Semantics(
          selected: active,
          child: Material(
            color: active ? AppColors.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _onTap(context, index),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ExcludeSemantics(child: Icon(icon, size: 22, color: color)),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: color,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
