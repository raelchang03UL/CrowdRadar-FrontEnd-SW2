import 'package:flutter/material.dart';
import '../../components/cr_bottom_nav.dart';
import '../../services/favorito_service.dart';
import '../../theme/app_colors.dart';

class FavoritosPage extends StatefulWidget {
  final int idUsuario;
  const FavoritosPage({super.key, this.idUsuario = 1}); // ID por defecto para pruebas

  @override
  State<FavoritosPage> createState() => _FavoritosPageState();
}

class _FavoritosPageState extends State<FavoritosPage> {
  final FavoritoService _favoritoService = FavoritoService();
  bool _alertasActivadas = true;
  List<dynamic> _favoritos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarFavoritos();
  }

  Future<void> _cargarFavoritos() async {
    setState(() => _isLoading = true);
    final lista = await _favoritoService.obtenerFavoritos(widget.idUsuario);
    setState(() {
      _favoritos = lista;
      _isLoading = false;
    });
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
          : Column(
              children: [
                // HU 8.3: Switch de Alertas
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Alertas de saturación',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.text,
                              ),
                            ),
                            Text(
                              'Notificar cambios en mis lugares',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _alertasActivadas,
                        onChanged: (val) async {
                          setState(() => _alertasActivadas = val);
                          await _favoritoService.cambiarAlertas(widget.idUsuario, val);
                        },
                      ),
                    ],
                  ),
                ),
                // HU 8.2 & HU 8.4: Lista o Estado Vacío
                Expanded(
                  child: _favoritos.isEmpty
                      ? const _MockEmptyState(
                          icon: Icons.favorite_border,
                          title: 'Sin favoritos todavía',
                          subtitle: 'Los lugares que marques como favoritos van a aparecer acá.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _favoritos.length,
                          itemBuilder: (context, index) {
                            final item = _favoritos[index];
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
                                  onPressed: () => _confirmarEliminar(item['id_lugar'] ?? 0),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: const CrBottomNav(currentIndex: 2),
    );
  }

  void _confirmarEliminar(int idLugar) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar de favoritos?'),
        content: const Text('Dejarás de recibir alertas de este lugar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _favoritoService.eliminarFavorito(widget.idUsuario, idLugar);
              _cargarFavoritos();
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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