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
    if (index == currentIndex) return;
    context.go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.borderNav, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
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
    );
  }

  Widget _item(BuildContext context, int index, IconData icon, String label) {
    final bool active = index == currentIndex;
    final Color color = active ? AppColors.secondary : AppColors.textMuted;

    return Expanded(
      child: InkWell(
        onTap: () => _onTap(context, index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 23, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: active ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
