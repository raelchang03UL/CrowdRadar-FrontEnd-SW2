import 'package:flutter/material.dart';
import '../../components/cr_bottom_nav.dart';
import '../../services/favorito_service.dart';
import '../../services/session_service.dart'; // O auth_service.dart según tu proyecto
import '../../theme/app_colors.dart';

class FavoritosPage extends StatefulWidget {
  const FavoritosPage({super.key});

  @override
  State<FavoritosPage> createState() => _FavoritosPageState();
}

class _FavoritosPageState extends State<FavoritosPage> {
  final FavoritoService _favoritoService = FavoritoService();
  final SessionService _sessionService = SessionService();

  List<dynamic>? _favoritos; // null representa estado de error/no cargado, [] representa lista vacía
  bool _isLoading = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _inicializarYCargar();
  }

  Future<void> _inicializarYCargar() async {
    setState(() => _isLoading = true);
    _token = await _sessionService.getToken(); // Obtiene el token de la sesión activa
    
    if (_token != null && _token!.isNotEmpty) {
      await _cargarFavoritos();
    } else {
      setState(() {
        _favoritos = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _cargarFavoritos() async {
    if (_token == null) return;
    setState(() => _isLoading = true);

    final resultado = await _favoritoService.obtenerFavoritos(_token!);

    if (mounted) {
      setState(() {
        _favoritos = resultado;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favoritos'),
        backgroundColor: AppColors.surface,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favoritos == null
              ? _ErrorState(onRetry: _cargarFavoritos)
              : _favoritos!.isEmpty
                  ? const _EmptyState(
                      icon: Icons.favorite_border,
                      title: 'Sin favoritos todavía',
                      subtitle: 'Los lugares que marques como favoritos van a aparecer acá.',
                    )
                  : RefreshIndicator(
                      onRefresh: _cargarFavoritos,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _favoritos!.length,
                        itemBuilder: (context, index) {
                          final item = _favoritos![index];
                          final idLugar = item['id_lugar'] ?? item['id'] ?? 0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: AppColors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            child: ListTile(
                              leading: const Icon(Icons.place, color: AppColors.secondary),
                              title: Text(
                                item['nombre'] ?? 'Lugar Favorito',
                                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text),
                              ),
                              subtitle: Text(
                                item['categoria'] ?? 'Sin categoría',
                                style: const TextStyle(color: AppColors.textMuted),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.favorite, color: Colors.red),
                                onPressed: () => _confirmarEliminar(idLugar),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      bottomNavigationBar: const CrBottomNav(currentIndex: 2),
    );
  }

  void _confirmarEliminar(int idLugar) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar de favoritos?'),
        content: const Text('Este lugar se quitará de tu lista guardada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              if (_token != null) {
                final exito = await _favoritoService.eliminarFavorito(_token!, idLugar);
                if (exito) {
                  _cargarFavoritos();
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No se pudo eliminar el favorito. Intenta de nuevo.')),
                    );
                  }
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
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

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.amber),
            const SizedBox(height: 16),
            const Text(
              'No se pudieron cargar tus favoritos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text),
            ),
            const SizedBox(height: 8),
            const Text(
              'Verifica tu conexión a internet o la sesión del servidor.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            )
          ],
        ),
      ),
    );
  }
}