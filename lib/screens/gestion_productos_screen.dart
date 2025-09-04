import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'stock_provider.dart';

class GestionProductosScreen extends StatelessWidget {
  const GestionProductosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context.watch<StockProvider>().items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar productos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context), // 👈 botón regresar
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Agregar producto',
            onPressed: () => _mostrarDialogoAgregar(context),
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final p = items[i];
          return ListTile(
            leading: p.assetPath != null
                ? Image.asset(p.assetPath!, width: 40, height: 40)
                : Icon(p.icono ?? Icons.fastfood),
            title: Text(p.nombre),
            subtitle: Text('Stock: ${p.cantidad} | \$${p.precio.toStringAsFixed(2)}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                _confirmarEliminar(context, p);
              },
            ),
          );
        },
      ),
    );
  }

  void _confirmarEliminar(BuildContext context, StockItem p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Seguro que deseas eliminar "${p.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              context.read<StockProvider>().eliminarProducto(p.id);
              Navigator.pop(context);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoAgregar(BuildContext context) async {
    final nombreCtrl = TextEditingController();
    final precioCtrl = TextEditingController();
    final cantidadCtrl = TextEditingController(text: "0");

    return showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Nuevo producto'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: precioCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Precio'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: cantidadCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cantidad inicial'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final nombre = nombreCtrl.text.trim();
                final precio = double.tryParse(precioCtrl.text.replaceAll(',', '.')) ?? 0.0;
                final cantidad = int.tryParse(cantidadCtrl.text) ?? 0;

                if (nombre.isEmpty) return;

                final nuevo = StockItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  nombre: nombre,
                  cantidad: cantidad,
                  precio: precio,
                  icono: Icons.fastfood, // 👈 ícono default (puedes mejorar con selector)
                );

                context.read<StockProvider>().agregarProducto(nuevo);
                Navigator.pop(context);
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }
}
