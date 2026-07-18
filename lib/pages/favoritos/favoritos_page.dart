import 'package:flutter/material.dart';

import '../../components/cr_bottom_nav.dart';

import '../../theme/app_colors.dart';

class FavoritosPage extends StatelessWidget {
  const FavoritosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
      body: const _MockEmptyState(
        icon: Icons.favorite_border,
        title: 'Sin favoritos todavía',
        subtitle: 'Los lugares que marques como favoritos van a aparecer acá.',
      ),
      bottomNavigationBar: const CrBottomNav(currentIndex: 2),
    );
  }
}

class _MockEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _MockEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: Icon(icon, size: 40, color: AppColors.secondary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
