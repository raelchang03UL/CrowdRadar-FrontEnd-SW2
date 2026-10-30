import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/places/categorias_cubit.dart';

class SelectorCategoria extends StatelessWidget {
  final String categoriaActual;
  const SelectorCategoria({super.key, required this.categoriaActual});

  Widget _opcion(BuildContext context, String categoria) => ListTile(
    title: Tooltip(
      message: categoria.isEmpty ? 'Todas las categorías' : categoria,
      child: Text(
        categoria.isEmpty ? 'Todas las categorías' : categoria,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    selected: categoria == categoriaActual,
    leading: Icon(
      categoria == categoriaActual
          ? Icons.radio_button_checked
          : Icons.radio_button_unchecked,
    ),
    onTap: () => Navigator.of(context).pop(categoria),
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .7,
      child: BlocBuilder<CategoriasCubit, EstadoCategorias>(
        builder: (context, estado) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            ListTile(
              title: Text(
                'Filtrar por categoría',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              trailing: IconButton(
                tooltip: 'Cerrar categorías',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
            if (estado is! CategoriasInicial) _opcion(context, ''),
            if (estado is CategoriasCargando) ...[
              const Center(child: CircularProgressIndicator()),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Cargando categorías…',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (estado is CategoriasCargadas)
              if (estado.categorias.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Aún no hay categorías disponibles.'),
                )
              else
                ...estado.categorias.map(
                  (categoria) => _opcion(context, categoria),
                ),
            if (estado is CategoriasError) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(estado.mensaje, textAlign: TextAlign.center),
              ),
              Center(
                child: OutlinedButton(
                  onPressed: context.read<CategoriasCubit>().loadCategories,
                  child: const Text('Reintentar categorías'),
                ),
              ),
            ],
            if (estado is CategoriasInicial)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Inicia sesión para ver las categorías.'),
              ),
          ],
        ),
      ),
    ),
  );
}
