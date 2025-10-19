import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'agregar_producto.dart';
import 'detalle_producto_general_screen.dart';
import 'pb_client.dart';
import '../product_notifier.dart';

// Enum para controlar la vista principal de la pantalla
enum InventarioView { productos, materiasPrimas }

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});
  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> with TickerProviderStateMixin {
  InventarioView _currentView = InventarioView.productos;

  List<RecordModel> _categorias = [];
  bool _categoriasCargadas = false;
  TabController? _tabController;

  Map<RecordModel, List<RecordModel>> _productosAgrupados = {};
  List<RecordModel> _materiasPrimas = [];
  bool _cargando = true;

  // ✨ --- ESTADO PARA MATERIAS PRIMAS EDITABLES --- ✨
  final Map<String, TextEditingController> _stockControllers = {};
  final Map<String, double> _originalStocks = {};
  bool _hayCambiosEnStock = false;


  @override
  void initState() {
    super.initState();
    _inicializar();
    Provider.of<ProductNotifier>(context, listen: false)
        .addListener(_onProductsChanged);
  }

  void _onProductsChanged() {
    if (mounted) {
      _cargarDatosActuales();
    }
  }

  Future<void> _inicializar() async {
    await _cargarCategorias();
    if (_currentView == InventarioView.productos) {
      _reconstruirTabController();
    } else {
      _cargarDatosActuales();
    }
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
        _cargarDatosActuales();
      });
      _cargarDatosActuales();
    }
  }

  Future<void> _cargarCategorias() async {
    try {
      final records = await pb.collection('categoria').getFullList(sort: 'nombre');
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
    Provider.of<ProductNotifier>(context, listen: false).removeListener(_onProductsChanged);
    // ✨ Limpiar controladores de stock
    for (var controller in _stockControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _cargarDatosActuales() {
    if (_currentView == InventarioView.productos) {
      if (_tabController == null) return;
      final index = _tabController!.index;
      final categoriaId = index == 0 ? null : _categorias[index - 1].id;
      _cargarItemsProductos(categoriaId: categoriaId);
    } else {
      _cargarMateriasPrimas();
    }
  }

  Future<void> _cargarItemsProductos({String? categoriaId}) async {
    setState(() => _cargando = true);
    try {
      // 1. Preparamos las dos consultas para ejecutarlas en paralelo
      final filtroCategoria = categoriaId == null ? '' : 'id_categoria = "$categoriaId"';
      final productosFuture = pb.collection('producto').getFullList(filter: filtroCategoria, sort: 'nombre', expand: 'id_categoria');

      final filtroVariantes = categoriaId == null ? '' : 'id_producto.id_categoria = "$categoriaId"';
      final variantesFuture = pb.collection('productoVariante').getFullList(filter: filtroVariantes, expand: 'id_producto');

      // 2. Ejecutamos ambas consultas al mismo tiempo
      final results = await Future.wait([productosFuture, variantesFuture]);
      final todosLosProductos = results[0];
      final todasLasVariantes = results[1];

      if (mounted) {
        _agruparProductos(todosLosProductos, todasLasVariantes);
        setState(() => _cargando = false);
      }
    } catch (e) {
      if (mounted) setState(() { _cargando = false; _productosAgrupados = {}; });
      _mostrarError('Error al cargar productos: $e');
    }
  }

  void _agruparProductos(List<RecordModel> productos, List<RecordModel> variantes) {
    final Map<RecordModel, List<RecordModel>> mapa = {};
    // 1. Inicializamos el mapa con todos los productos, cada uno con una lista vacía de variantes.
    for (final producto in productos) {
      mapa[producto] = [];
    }
    // 2. Poblamos las listas con las variantes que encontramos.
    for (final variante in variantes) {
      final productoBase = _getProductoRecord(variante);
      if (productoBase != null) {
        // Buscamos la clave correcta en el mapa (la instancia del RecordModel de producto)
        final keyProducto = mapa.keys.firstWhere((p) => p.id == productoBase.id, orElse: () => productoBase);
        mapa[keyProducto]?.add(variante);
      }
    }

    // ✨ --- ORDENACIÓN ALFABÉTICA DE VARIANTES --- ✨
    // Iteramos sobre cada lista de variantes en el mapa y la ordenamos.
    mapa.forEach((_, listaVariantes) {
      listaVariantes.sort((a, b) {
        // Usamos la función _sku que extrae el nombre/identificador de la variante.
        // Se convierte a minúsculas para un ordenamiento insensible a mayúsculas/minúsculas.
        return _sku(a).toLowerCase().compareTo(_sku(b).toLowerCase());
      });
    });

    _productosAgrupados = mapa;
  }

  Future<void> _cargarMateriasPrimas() async {
    setState(() => _cargando = true);
    // Limpiar estado anterior antes de cargar
    for (var controller in _stockControllers.values) {
      controller.dispose();
    }
    _stockControllers.clear();
    _originalStocks.clear();
    _hayCambiosEnStock = false;

    try {
      final res = await pb.collection('matPrim').getFullList(
            sort: 'nombre', expand: 'id_unidMed');
      if (mounted) {
        for (final r in res) {
          final stock = (r.data['stock'] as num?)?.toDouble() ?? 0.0;
          _originalStocks[r.id] = stock;
          _stockControllers[r.id] = TextEditingController(text: stock.toString())
            ..addListener(() {
              final detectado = _detectarCambios();
              if (detectado != _hayCambiosEnStock) {
                setState(() => _hayCambiosEnStock = detectado);
              }
            });
        }
        setState(() {
          _materiasPrimas = res;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _cargando = false; _materiasPrimas = []; });
      _mostrarError('Error al cargar materias primas: $e');
    }
  }

  bool _detectarCambios() {
    for (final mp in _materiasPrimas) {
      final original = _originalStocks[mp.id];
      final actualStr = _stockControllers[mp.id]?.text;
      if (original == null || actualStr == null) continue;
      
      final actual = double.tryParse(actualStr);
      if (actual != null && actual != original) {
        return true;
      }
    }
    return false;
  }
  
  // --- HELPERS ---
  RecordModel? _getProductoRecord(RecordModel r) {
    if (r.collectionName == 'producto') return r;
    if (r.expand.containsKey('id_producto') && r.expand['id_producto']!.isNotEmpty) {
      return r.expand['id_producto']!.first;
    }
    return null;
  }
  String _nombre(RecordModel r) => _getProductoRecord(r)?.data['nombre']?.toString() ?? 'N/A';
  String _sku(RecordModel r) => r.data['sku']?.toString() ?? '-';
  String _categoria(RecordModel r) {
    final producto = _getProductoRecord(r);
    if (producto != null && producto.expand.containsKey('id_categoria') && producto.expand['id_categoria']!.isNotEmpty) {
      return producto.expand['id_categoria']!.first.data['nombre']?.toString() ?? 'Sin categoría';
    }
    return 'Sin categoría';
  }
  int _cantidad(RecordModel r) => (r.data['cantidadStock'] as num?)?.toInt() ?? 0;
  double _precio(RecordModel r) => (r.data['precio_final'] as num?)?.toDouble() ?? 0.0;
  String? _iconUrl(RecordModel r) {
    final producto = _getProductoRecord(r);
    if (producto == null) return null;
    final file = producto.data['icon'];
    if (file == null || file.toString().isEmpty) return null;
    return pb.files.getUrl(producto, file).toString();
  }
  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  // --- ACTIONS PRODUCTOS ---
  Future<void> _incrementar(RecordModel r) async {
    final nuevaCantidad = _cantidad(r) + 1;
    try {
      await pb.collection('productoVariante').update(r.id, body: {'cantidadStock': nuevaCantidad});
      if (mounted) setState(() => r.data['cantidadStock'] = nuevaCantidad);
    } catch (e) {
      _mostrarError('Error al incrementar: $e');
    }
  }
  Future<void> _decrementar(RecordModel r) async {
    final nuevaCantidad = (_cantidad(r) - 1).clamp(0, 999999);
    try {
      await pb.collection('productoVariante').update(r.id, body: {'cantidadStock': nuevaCantidad});
      if (mounted) setState(() => r.data['cantidadStock'] = nuevaCantidad);
    } catch (e) {
      _mostrarError('Error al decrementar: $e');
    }
  }
  Future<void> _actualizarPrecio(RecordModel r, double nuevo) async {
    try {
      await pb.collection('productoVariante').update(r.id, body: {'precio_final': nuevo});
      if (mounted) setState(() => r.data['precio_final'] = nuevo);
    } catch (e) {
      _mostrarError('Error al actualizar precio: $e');
    }
  }
  Future<void> _eliminarVariante(RecordModel r) async {
     final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar variante de producto'),
        content: Text('¿Estás seguro de eliminar "${_nombre(r)}" con SKU "${_sku(r)}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final ingredientesAsociados = await pb.collection('variante_ingrediente').getFullList(filter: 'id_productoVariante = "${r.id}"');
      final deleteFutures = <Future>[];
      for (final ingrediente in ingredientesAsociados) {
        deleteFutures.add(pb.collection('variante_ingrediente').delete(ingrediente.id));
      }
      await Future.wait(deleteFutures);
      await pb.collection('productoVariante').delete(r.id);
      _cargarDatosActuales();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Variante eliminada'), backgroundColor: Colors.green));
    } catch (e) {
      _mostrarError('Error al eliminar: $e');
    }
  }
  Future<double?> _pedirNuevoPrecio(BuildContext context, double actual) {
    final controller = TextEditingController(text: actual.toStringAsFixed(2));
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Actualizar precio'),
        content: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(prefixText: '\$ ', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(controller.text.replaceAll(',', '.').trim());
              if (v == null || v < 0) return;
              Navigator.pop(context, v);
            },
            child: const Text('Guardar')),
        ],
      ),
    );
  }

  // ✨ --- LÓGICA PARA GUARDAR MOVIMIENTO DE STOCK --- ✨
  Future<void> _mostrarDialogoResumenMovimiento() async {
    final Map<RecordModel, double> incrementos = {};
    final Map<RecordModel, double> decrementos = {};

    for (final mp in _materiasPrimas) {
      final original = _originalStocks[mp.id] ?? 0.0;
      final actual = double.tryParse(_stockControllers[mp.id]?.text.replaceAll(',', '.') ?? '0.0') ?? 0.0;
      
      if (actual > original) {
        incrementos[mp] = actual;
      } else if (actual < original) {
        decrementos[mp] = actual;
      }
    }

    if (incrementos.isEmpty && decrementos.isEmpty) {
      setState(() => _hayCambiosEnStock = false);
      _mostrarError("No se detectaron cambios en el stock.");
      return;
    }

    final conceptoIncrementosCtrl = TextEditingController();
    final conceptoDecrementosCtrl = TextEditingController();
    final fechaMovimiento = DateTime.now();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resumen de Movimiento de Stock'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(fechaMovimiento)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              if (incrementos.isNotEmpty) ...[
                const Divider(height: 24),
                Text('Incrementos (+)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 16)),
                const SizedBox(height: 8),
                TextFormField(controller: conceptoIncrementosCtrl, decoration: const InputDecoration(labelText: 'Concepto de Incrementos', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                ...incrementos.entries.map((entry) {
                  final original = _originalStocks[entry.key.id]!;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.key.data['nombre']),
                    trailing: Text('$original → ${entry.value} (+${(entry.value - original).toStringAsFixed(2)})'),
                  );
                }),
              ],
              if (decrementos.isNotEmpty) ...[
                const Divider(height: 24),
                Text('Decrementos (-)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700, fontSize: 16)),
                const SizedBox(height: 8),
                TextFormField(controller: conceptoDecrementosCtrl, decoration: const InputDecoration(labelText: 'Concepto de Decrementos', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                ...decrementos.entries.map((entry) {
                  final original = _originalStocks[entry.key.id]!;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.key.data['nombre']),
                    trailing: Text('$original → ${entry.value} (${(entry.value - original).toStringAsFixed(2)})'),
                  );
                }),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmar y Guardar')),
        ],
      ),
    );

    if (confirmar == true) {
      await _guardarMovimientoStock(
        incrementos, decrementos,
        conceptoIncrementosCtrl.text, conceptoDecrementosCtrl.text,
        fechaMovimiento,
      );
    }
    conceptoIncrementosCtrl.dispose();
    conceptoDecrementosCtrl.dispose();
  }

  Future<void> _guardarMovimientoStock(
    Map<RecordModel, double> incrementos, Map<RecordModel, double> decrementos,
    String conceptoIncrementos, String conceptoDecrementos,
    DateTime fecha,
  ) async {
    setState(() => _cargando = true);
    try {
      final futures = <Future>[];
      final ahoraUtc = fecha.toUtc().toIso8601String();

      for (final entry in incrementos.entries) {
        final mp = entry.key;
        final nuevoStock = entry.value;
        final stockAnterior = _originalStocks[mp.id]!;
        futures.add(pb.collection('matPrim').update(mp.id, body: {'stock': nuevoStock}));
        futures.add(pb.collection('movimiento_stock').create(body: {
          'id_matPrim': mp.id, 'tipo': 'incremento', 'cantidad': nuevoStock - stockAnterior,
          'stock_anterior': stockAnterior, 'stock_nuevo': nuevoStock,
          'concepto': conceptoIncrementos, 'fecha': ahoraUtc,
        }));
      }

      for (final entry in decrementos.entries) {
        final mp = entry.key;
        final nuevoStock = entry.value;
        final stockAnterior = _originalStocks[mp.id]!;
        futures.add(pb.collection('matPrim').update(mp.id, body: {'stock': nuevoStock}));
        futures.add(pb.collection('movimiento_stock').create(body: {
          'id_matPrim': mp.id, 'tipo': 'decremento', 'cantidad': stockAnterior - nuevoStock,
          'stock_anterior': stockAnterior, 'stock_nuevo': nuevoStock,
          'concepto': conceptoDecrementos, 'fecha': ahoraUtc,
        }));
      }

      await Future.wait(futures);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Movimientos guardados con éxito'), backgroundColor: Colors.green));
        await _cargarMateriasPrimas();
      }
    } catch (e) {
      _mostrarError('Error al guardar los movimientos: $e');
      setState(() => _cargando = false);
    }
  }

  // --- WIDGET BUILDERS ---
  PreferredSizeWidget? _buildAppBarBottom() {
    if (_currentView == InventarioView.productos && _tabController != null) {
      return TabBar(
        controller: _tabController, isScrollable: true,
        tabs: [
          const Tab(text: 'Todos'),
          ..._categorias.map((c) => Tab(text: c.data['nombre'].toString())),
        ],
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_categoriasCargadas) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    Widget bodyContent;
    if (_cargando) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (_currentView == InventarioView.materiasPrimas) {
      bodyContent = Column(
        children: [
          _buildMateriasPrimasTable(),
        ],
      );
    } else {
      bodyContent = _buildProductosAgrupadosList();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: SegmentedButton<InventarioView>(
          segments: const [
            ButtonSegment(value: InventarioView.productos, label: Text('Productos')),
            ButtonSegment(value: InventarioView.materiasPrimas, label: Text('Materia Prima')),
          ],
          selected: {_currentView},
          onSelectionChanged: (Set<InventarioView> newSelection) {
            setState(() {
              _currentView = newSelection.first;
              if (_currentView == InventarioView.productos) {
                _reconstruirTabController();
              } else {
                _tabController?.dispose(); _tabController = null;
                _cargarDatosActuales();
              }
            });
          },
        ),
        bottom: _buildAppBarBottom(),
        actions: [
          IconButton(
            tooltip: 'Agregar producto', icon: const Icon(Icons.add),
            onPressed: () {
              String? categoriaId;
              if (_currentView == InventarioView.productos && _tabController != null && _tabController!.index > 0) {
                categoriaId = _categorias[_tabController!.index - 1].id;
              }
              Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AgregarProductoScreen(categoriaInicialId: categoriaId)),
              ).then((creada) { if (creada == true) _cargarDatosActuales(); });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: bodyContent,
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_currentView == InventarioView.materiasPrimas && _hayCambiosEnStock && !_cargando) ...[
            FilledButton.icon(
              onPressed: _mostrarDialogoResumenMovimiento,
              icon: const Icon(Icons.save),
              label: const Text('Guardar Movimiento'),
            ),
            const SizedBox(height: 16),
          ],
          FloatingActionButton(
            onPressed: _cargarDatosActuales, tooltip: 'Recargar', child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Widget _buildProductosAgrupadosList() {
    if (_productosAgrupados.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('No se encontraron productos.')));
    }
    final productos = _productosAgrupados.keys.toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: productos.length,
      itemBuilder: (context, index) {
        final productoBase = productos[index];
        final variantes = _productosAgrupados[productoBase]!;

        return Card(
          color: variantes.isEmpty ? Colors.grey.shade200 : null,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: ExpansionTile(
            leading: _ProductoIcono(url: _iconUrl(productoBase)),
            title: Text(_nombre(productoBase), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(_categoria(productoBase)),
            trailing: IconButton(
              icon: const Icon(Icons.edit_note),
              tooltip: 'Editar producto y todas sus variantes',
              onPressed: () {
                  Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => DetalleProductoGeneralScreen(producto: productoBase),
                  )).then((fueActualizado) { if (fueActualizado == true) _cargarDatosActuales(); });
              },
            ),
            children: <Widget>[
              if (variantes.isEmpty)
                const ListTile(
                  title: Center(child: Text('Este producto no tiene variantes definidas.')),
                  subtitle: Center(child: Text('Puedes añadirlas desde el menú de edición.')),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: _buildTablaVariantes(variantes),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  DataTable _buildTablaVariantes(List<RecordModel> variantes) {
    return DataTable(
      dataRowMinHeight: 56, dataRowMaxHeight: 72,
      columns: const [
        DataColumn(label: Text('SKU / Variante')),
        DataColumn(label: Text('Stock')),
        DataColumn(label: Text('Precio')),
        DataColumn(label: Text('Eliminar')),
      ],
      rows: variantes.map((variante) {
        final cantidad = _cantidad(variante);
        final precio = _precio(variante);
        return DataRow(cells: [
          DataCell(Text(_sku(variante))),
          DataCell(Row(children: [
            IconButton.outlined(icon: const Icon(Icons.remove), onPressed: cantidad > 0 ? () => _decrementar(variante) : null, constraints: const BoxConstraints(minWidth: 32, minHeight: 32), style: IconButton.styleFrom(padding: EdgeInsets.zero)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('$cantidad', style: const TextStyle(fontWeight: FontWeight.bold))),
            IconButton.outlined(icon: const Icon(Icons.add), onPressed: () => _incrementar(variante), constraints: const BoxConstraints(minWidth: 32, minHeight: 32), style: IconButton.styleFrom(padding: EdgeInsets.zero)),
          ])),
          DataCell(Row(children: [
            Text('\$${precio.toStringAsFixed(2)}'),
            IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () async {
              final nuevo = await _pedirNuevoPrecio(context, precio);
              if (nuevo != null) _actualizarPrecio(variante, nuevo);
            }),
          ])),
          DataCell(IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _eliminarVariante(variante))),
        ]);
      }).toList(),
    );
  }

  Widget _buildMateriasPrimasTable() {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Materia Prima')),
        DataColumn(label: Text('Stock Disponible')),
      ],
      rows: _materiasPrimas.map((r) {
        final nombre = r.data['nombre']?.toString() ?? 'N/A';
        String unidad = '-';
        if (r.expand.containsKey('id_unidMed') && r.expand['id_unidMed']!.isNotEmpty) {
          unidad = r.expand['id_unidMed']!.first.data['abreviatura']?.toString() ?? '-';
        }
        return DataRow(cells: [
          DataCell(Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600))),
          DataCell(
            TextFormField(
              controller: _stockControllers[r.id],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                suffixText: unidad,
                border: InputBorder.none,
              ),
            ),
            showEditIcon: true,
          ),
        ]);
      }).toList(),
    );
  }
}

class _ProductoIcono extends StatelessWidget {
  const _ProductoIcono({this.url});
  final String? url;
  @override
  Widget build(BuildContext context) {
    const double size = 50;
    const Widget fallback = Icon(Icons.inventory_2_outlined, size: 28);
    if (url != null && url!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url!, width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 28)),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
          },
        ),
      );
    }
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: fallback,
    );
  }
}