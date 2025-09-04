import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'stock_provider.dart';

class StockScreen extends StatelessWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context.watch<StockProvider>().items;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Stock'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Agregar producto',
            icon: const Icon(Icons.add),
            onPressed: () => _mostrarDialogoAgregar(context), // 👈 único botón para agregar
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          // Scroll horizontal para pantallas pequeñas
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: c.maxWidth),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: DataTable(
                  columnSpacing: 24,
                  headingRowHeight: 48,
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: 72,
                  columns: const [
                    DataColumn(label: Text('Producto')),
                    DataColumn(label: Text('Cantidad')),
                    DataColumn(label: Text('Precio')),
                    DataColumn(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete, size: 18),
                          SizedBox(width: 6),
                          Text('Eliminar'),
                        ],
                      ),
                    ),
                  ],
                  rows: items.map((item) {
                    return DataRow(
                      cells: [
                        // Producto: imagen/ícono + nombre
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ProductoIcono(item: item),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                item.nombre,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        )),
                        // Cantidad: botones - / + y valor
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton.outlined(
                              icon: const Icon(Icons.remove),
                              onPressed: () => context.read<StockProvider>().decrementar(item.id),
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              style: IconButton.styleFrom(padding: EdgeInsets.zero),
                              tooltip: 'Disminuir',
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '${item.cantidad}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton.outlined(
                              icon: const Icon(Icons.add),
                              onPressed: () => context.read<StockProvider>().incrementar(item.id),
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              style: IconButton.styleFrom(padding: EdgeInsets.zero),
                              tooltip: 'Aumentar',
                            ),
                          ],
                        )),
                        // Precio: valor + botón editar
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('\$${item.precio.toStringAsFixed(2)}'),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              tooltip: 'Editar precio',
                              onPressed: () async {
                                final nuevo = await _pedirNuevoPrecio(context, item.precio);
                                if (nuevo != null) {
                                  context.read<StockProvider>().actualizarPrecio(item.id, nuevo);
                                }
                              },
                            ),
                          ],
                        )),
                        // Eliminar
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Eliminar producto',
                            onPressed: () => _confirmarEliminar(context, item),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---- Diálogo: nuevo producto ----
  Future<void> _mostrarDialogoAgregar(BuildContext context) async {
    final nombreCtrl = TextEditingController();
    final precioCtrl = TextEditingController();
    final cantidadCtrl = TextEditingController(text: '0');
    final assetCtrl = TextEditingController();
    IconData? iconoSeleccionado = Icons.fastfood;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Nuevo producto'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: precioCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Precio',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: cantidadCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad inicial',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                // Ruta de imagen (opcional)
                TextField(
                  controller: assetCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ruta de imagen (assets/...) opcional',
                    hintText: 'assets/reposteria/mi_producto.png',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                // Selector sencillo de ícono
                Row(
                  children: [
                    const Text('Ícono:'),
                    const SizedBox(width: 8),
                    DropdownButton<IconData>(
                      value: iconoSeleccionado,
                      items: const [
                        DropdownMenuItem(value: Icons.fastfood, child: Icon(Icons.fastfood)),
                        DropdownMenuItem(value: Icons.cake, child: Icon(Icons.cake)),
                        DropdownMenuItem(value: Icons.cake_outlined, child: Icon(Icons.cake_outlined)),
                        DropdownMenuItem(value: Icons.icecream, child: Icon(Icons.icecream)),
                        DropdownMenuItem(value: Icons.local_cafe, child: Icon(Icons.local_cafe)),
                        DropdownMenuItem(value: Icons.cookie, child: Icon(Icons.cookie)),
                        DropdownMenuItem(value: Icons.local_fire_department, child: Icon(Icons.local_fire_department)),
                      ],
                      onChanged: (v) {
                        iconoSeleccionado = v;
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final nombre = nombreCtrl.text.trim();
                final precio = double.tryParse(precioCtrl.text.replaceAll(',', '.')) ?? 0.0;
                final cantidad = int.tryParse(cantidadCtrl.text) ?? 0;
                final asset = assetCtrl.text.trim().isEmpty ? null : assetCtrl.text.trim();

                if (nombre.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('El nombre es obligatorio')),
                  );
                  return;
                }
                if (precio < 0 || cantidad < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Precio y cantidad deben ser ≥ 0')),
                  );
                  return;
                }

                final nuevo = StockItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  nombre: nombre,
                  precio: precio,
                  cantidad: cantidad,
                  assetPath: asset,
                  icono: iconoSeleccionado,
                );

                context.read<StockProvider>().agregarProducto(nuevo);
                Navigator.pop(ctx);
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  // ---- Confirmar eliminar ----
  void _confirmarEliminar(BuildContext context, StockItem item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Seguro que deseas eliminar "${item.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              context.read<StockProvider>().eliminarProducto(item.id);
              Navigator.pop(context);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // ---- Diálogo: editar precio ----
  Future<double?> _pedirNuevoPrecio(BuildContext context, double actual) async {
    final controller = TextEditingController(text: actual.toStringAsFixed(2));
    return showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Actualizar precio'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              prefixText: '\$ ',
              hintText: 'Ej. 89.90',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.replaceAll(',', '.').trim();
                final val = double.tryParse(text);
                if (val == null || val < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Precio inválido')),
                  );
                  return;
                }
                Navigator.pop(context, val);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }
}

class _ProductoIcono extends StatelessWidget {
  const _ProductoIcono({required this.item});
  final StockItem item;

  @override
  Widget build(BuildContext context) {
    const double size = 40;
    if (item.assetPath != null && item.assetPath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          item.assetPath!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(item.icono ?? Icons.fastfood, size: size * 0.8),
        ),
      );
    }
    return Icon(item.icono ?? Icons.fastfood, size: size * 0.8);
  }
}
