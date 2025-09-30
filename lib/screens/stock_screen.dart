import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'agregar_producto.dart';
import 'editar_producto_screen.dart';
import 'pb_client.dart';
import '../product_notifier.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});
  @override
  State<StockScreen> createState() => _StockScreenState();
}

// ✨ ÚNICO CAMBIO: Se usa TickerProviderStateMixin para soportar la recreación del TabController
class _StockScreenState extends State<StockScreen> with TickerProviderStateMixin {
  List<RecordModel> _categorias = [];
  bool _categoriasCargadas = false;

  TabController? _tabController;
  List<RecordModel> _items = [];
  bool _cargandoItems = true;

  @override
  void initState() {
    super.initState();
    _inicializar();

    Provider.of<ProductNotifier>(context, listen: false)
        .addListener(_onProductsChanged);
  }

  void _onProductsChanged() {
    print(">>> Notificación recibida en StockScreen: Recargando productos...");
    if (mounted) {
      _recargarSegunTab();
    }
  }

  Future<void> _inicializar() async {
    await _cargarCategorias();
    _reconstruirTabController();
  }

  void _reconstruirTabController() {
    if (mounted && _categoriasCargadas) {
      final oldIndex = _tabController?.index ?? 0;
      _tabController?.dispose();

      _tabController = TabController(
        length: _categorias.length + 1,
        vsync: this,
        initialIndex: oldIndex < (_categorias.length + 1) ? oldIndex : 0,
      );

      _tabController!.addListener(() {
        if (_tabController!.indexIsChanging) return;
        _recargarSegunTab();
      });
      _recargarSegunTab();
    }
  }

  Future<void> _cargarCategorias() async {
    try {
      final records = await pb.collection('categorias').getFullList(sort: 'nombre');
      if (mounted) {
        setState(() {
          _categorias = records;
          _categoriasCargadas = true;
        });
      }
    } catch (e) {
      _mostrarError('No se pudieron cargar las categorías: $e');
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    Provider.of<ProductNotifier>(context, listen: false)
        .removeListener(_onProductsChanged);
    super.dispose();
  }

  // ---------- Helpers (lectura de campos) ----------
  String _nombre(RecordModel r) => r.data['Nombre']?.toString() ?? '';

  String _categoria(RecordModel r) {
    if (r.expand.containsKey('Categoria') && r.expand['Categoria']!.isNotEmpty) {
      return r.expand['Categoria']!.first.data['nombre']?.toString() ?? 'Sin categoría';
    }
    return 'Sin categoría';
  }

  int _cantidad(RecordModel r) => (r.data['cantidad'] as num?)?.toInt() ?? 0;
  double _precio(RecordModel r) => (r.data['precio'] as num?)?.toDouble() ?? 0.0;

  String? _iconUrl(RecordModel r) {
    final file = r.data['icon'];
    if (file == null || file.toString().isEmpty) return null;
    return pb.files.getUrl(r, file).toString();
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  // ---------- Data (PB) ----------
  Future<void> _cargarItems({String? categoriaId}) async {
    setState(() => _cargandoItems = true);
    try {
      final res = await pb.collection('productos').getList(
            perPage: 200,
            filter: categoriaId == null ? '' : 'Categoria = "$categoriaId"',
            sort: 'Nombre',
            expand: 'Categoria',
          );
      if (mounted) {
        setState(() {
          _items = res.items;
          _cargandoItems = false;
        });
      }
    } catch (e) {
      setState(() => _cargandoItems = false);
      _mostrarError('Error al cargar productos: $e');
    }
  }

  void _recargarSegunTab() {
    if (_tabController == null) return;
    final index = _tabController!.index;
    final categoriaId = index == 0 ? null : _categorias[index - 1].id;
    _cargarItems(categoriaId: categoriaId);
  }

  Future<void> _editarProducto(RecordModel productoAEditar) async {
    final bool? fueActualizado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditarProductoScreen(producto: productoAEditar)),
    );
    if (fueActualizado == true) {
      _recargarSegunTab();
    }
  }

  Future<void> _incrementar(RecordModel r) async {
    final nuevaCantidad = _cantidad(r) + 1;
    try {
      await pb.collection('productos').update(r.id, body: {
        'cantidad': nuevaCantidad,
      });
      if (mounted) {
        setState(() => r.data['cantidad'] = nuevaCantidad);
      }
    } catch (e) {
      _mostrarError('Error al incrementar: $e');
    }
  }

  Future<void> _decrementar(RecordModel r) async {
    final nuevaCantidad = (_cantidad(r) - 1).clamp(0, 999999);
    try {
      await pb.collection('productos').update(r.id, body: {'cantidad': nuevaCantidad});
      if (mounted) {
        setState(() => r.data['cantidad'] = nuevaCantidad);
      }
    } catch (e) {
      _mostrarError('Error al decrementar: $e');
    }
  }

  Future<void> _actualizarPrecio(RecordModel r, double nuevo) async {
    try {
      await pb.collection('productos').update(r.id, body: {'precio': nuevo});
      if (mounted) {
        setState(() => r.data['precio'] = nuevo);
      }
    } catch (e) {
      _mostrarError('Error al actualizar precio: $e');
    }
  }

  Future<void> _eliminar(RecordModel r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "${_nombre(r)}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await pb.collection('productos').delete(r.id);
      if (mounted) {
        setState(() => _items.removeWhere((item) => item.id == r.id));
      }
    } catch (e) {
      _mostrarError('Error al eliminar: $e');
    }
  }

  Future<double?> _pedirNuevoPrecio(BuildContext context, double actual) async {
    final controller = TextEditingController(text: actual.toStringAsFixed(2));
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
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
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final t = controller.text.replaceAll(',', '.').trim();
              final v = double.tryParse(t);
              if (v == null || v < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Precio inválido')),
                );
                return;
              }
              Navigator.pop(context, v);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // ---------- GESTIÓN DE CATEGORÍAS ----------

  Future<String?> _mostrarDialogoNombreCategoria({String? nombreInicial}) async {
    final controller = TextEditingController(text: nombreInicial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(nombreInicial == null ? 'Nueva Categoría' : 'Editar Categoría'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nombre de la categoría'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _agregarCategoria() async {
    final nombre = await _mostrarDialogoNombreCategoria();
    if (nombre == null) return;

    try {
      await pb.collection('categorias').create(body: {'nombre': nombre});
      await _cargarCategorias();
      _reconstruirTabController();
    } catch (e) {
      _mostrarError('Error al crear categoría: $e');
    }
  }

  Future<void> _editarCategoria() async {
    if (_tabController == null || _tabController!.index == 0) {
      _mostrarError('Selecciona una categoría para editarla');
      return;
    }

    final categoriaAEditar = _categorias[_tabController!.index - 1];
    final nuevoNombre = await _mostrarDialogoNombreCategoria(
      nombreInicial: categoriaAEditar.data['nombre'],
    );
    if (nuevoNombre == null) return;

    try {
      await pb.collection('categorias').update(categoriaAEditar.id, body: {'nombre': nuevoNombre});
      await _cargarCategorias();
      _reconstruirTabController();
    } catch (e) {
      _mostrarError('Error al editar categoría: $e');
    }
  }

  Future<void> _eliminarCategoria() async {
    if (_tabController == null || _tabController!.index == 0) {
      _mostrarError('Selecciona una categoría para eliminarla');
      return;
    }

    final categoriaAEliminar = _categorias[_tabController!.index - 1];

    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar Categoría?'),
        content: Text(
          'Estás a punto de eliminar la categoría "${categoriaAEliminar.data['nombre']}".\n\n'
          'Esto NO eliminará los productos asociados, pero quedarán sin categoría. ¿Continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmacion != true) return;

    try {
      await pb.collection('categorias').delete(categoriaAEliminar.id);
      await _cargarCategorias();
      _reconstruirTabController();
    } catch (e) {
      _mostrarError('Error al eliminar categoría: $e');
    }
  }
  
  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    if (!_categoriasCargadas) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final table = _cargandoItems
        ? const Center(child: CircularProgressIndicator())
        : DataTable(
            columnSpacing: 24,
            headingRowHeight: 48,
            dataRowMinHeight: 56,
            dataRowMaxHeight: 72,
            columns: const [
              DataColumn(label: Text('Producto')),
              DataColumn(label: Text('Categoría')),
              DataColumn(label: Text('Cantidad')),
              DataColumn(label: Text('Precio')),
              DataColumn(label: Text('Editar')),
              DataColumn(label: Text('Eliminar')),
            ],
            rows: _items.map((r) {
              final nombre = _nombre(r);
              final cantidad = _cantidad(r);
              final precio = _precio(r);
              final url = _iconUrl(r);

              return DataRow(cells: [
                DataCell(Row(
                  children: [
                    _ProductoIcono(url: url),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        nombre,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                )),
                DataCell(Text(_categoria(r))),
                DataCell(Row(
                  children: [
                    IconButton.outlined(
                      icon: const Icon(Icons.remove),
                      onPressed: cantidad > 0 ? () => _decrementar(r) : null,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      style: IconButton.styleFrom(padding: EdgeInsets.zero),
                      tooltip: 'Disminuir',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '$cantidad',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    IconButton.outlined(
                      icon: const Icon(Icons.add),
                      onPressed: () => _incrementar(r),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      style: IconButton.styleFrom(padding: EdgeInsets.zero),
                      tooltip: 'Aumentar',
                    ),
                  ],
                )),
                DataCell(Row(
                  children: [
                    Text('\$${precio.toStringAsFixed(2)}'),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      tooltip: 'Editar precio',
                      onPressed: () async {
                        final nuevo = await _pedirNuevoPrecio(context, precio);
                        if (nuevo != null) _actualizarPrecio(r, nuevo);
                      },
                    ),
                  ],
                )),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.edit_note),
                    tooltip: 'Editar producto completo',
                    onPressed: () => _editarProducto(r),
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Eliminar producto',
                    onPressed: () => _eliminar(r),
                  ),
                ),
              ]);
            }).toList(),
          );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Stock'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            const Tab(text: 'Todos'),
            ..._categorias.map((c) => Tab(text: c.data['nombre'].toString())),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Agregar producto',
            icon: const Icon(Icons.add),
            onPressed: () async {
              if (_tabController == null) return;
              final index = _tabController!.index;
              final categoriaId = index == 0 ? null : _categorias[index - 1].id;

              final creada = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => AgregarProductoScreen(categoriaInicialId: categoriaId),
                ),
              );
              if (creada == true) _recargarSegunTab();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.category),
            tooltip: 'Gestionar categorías',
            onSelected: (value) {
              if (value == 'add') {
                _agregarCategoria();
              } else if (value == 'edit') {
                _editarCategoria();
              } else if (value == 'delete') {
                _eliminarCategoria();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'add',
                child: ListTile(
                  leading: Icon(Icons.add_circle_outline),
                  title: Text('Añadir Categoría'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Editar Categoría Actual'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_forever_outlined, color: Colors.red),
                  title: Text('Eliminar Categoría Actual', style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: c.maxWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: table,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _recargarSegunTab,
        tooltip: 'Recargar',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

class _ProductoIcono extends StatelessWidget {
  const _ProductoIcono({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    const double size = 50;
    const Widget fallback = Icon(Icons.image_not_supported, size: 28);

    if (url != null && url!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Center(child: Icon(Icons.broken_image, size: 28)),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
          },
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: fallback,
    );
  }
}