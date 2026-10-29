import 'package:crowdradar/models/place_model.dart';
import 'package:crowdradar/services/place_service.dart';
import 'package:flutter/material.dart';

import '../../components/cr_bottom_nav.dart';
import '../../theme/app_colors.dart';

class FavoritosPage extends StatefulWidget {
  final PlaceService? service;

  const FavoritosPage({super.key, this.service});

  @override
  State<FavoritosPage> createState() => _FavoritosPageState();
}

class _FavoritosPageState extends State<FavoritosPage> {
  late final PlaceService _service = widget.service ?? PlaceService();
  List<PlaceModel> _places = [];
  final Set<int> _removingPlaceIds = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _service.getFavorites();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.success && result.data != null) {
        _places = result.data!;
      } else {
        _error = result.message;
      }
    });
  }

  Future<void> _removeFavorite(PlaceModel place) async {
    setState(() => _removingPlaceIds.add(place.id));
    final result = await _service.removeFavorite(place.id);
    if (!mounted) return;
    setState(() {
      _removingPlaceIds.remove(place.id);
      if (result.success) {
        _places = _places.where((item) => item.id != place.id).toList();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success ? 'Lugar eliminado de tus favoritos.' : result.message,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
      body: _body(),
      bottomNavigationBar: const CrBottomNav(currentIndex: 2),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _FavoritesMessage(
        icon: Icons.cloud_off_outlined,
        title: _error!,
        action: TextButton.icon(
          onPressed: _loadFavorites,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      );
    }
    if (_places.isEmpty) {
      return const _FavoritesMessage(
        icon: Icons.favorite_border,
        title: 'Sin favoritos todavía',
        subtitle: 'Los lugares que marques como favoritos van a aparecer acá.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _places.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final place = _places[index];
        final removing = _removingPlaceIds.contains(place.id);
        return Card(
          child: ListTile(
            key: ValueKey('favorite-place-${place.id}'),
            leading: const Icon(Icons.favorite, color: AppColors.secondary),
            title: Text(place.nombre),
            subtitle: Text(
              '${place.categoria}${place.demostrativo ? ' · Demostrativo' : ''}',
            ),
            trailing: IconButton(
              tooltip: 'Quitar de favoritos',
              onPressed: removing ? null : () => _removeFavorite(place),
              icon: removing
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.heart_broken_outlined),
            ),
          ),
        );
      },
    );
  }
}

class _FavoritesMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const _FavoritesMessage({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}
