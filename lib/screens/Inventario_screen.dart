import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'agregar_producto.dart';
import 'detalle_producto_general_screen.dart';
import '../product_notifier.dart';

// Cliente global de Supabase
final supabase = Supabase.instance.client;

enum InventarioView { productos, materiasPrimas }

class ConsumoMateriaPrima {
  final Map<String, dynamic> matPrim;
  final double cantidadRequerida;
  ConsumoMateriaPrima({required this.matPrim, required this.cantidadRequerida});
}

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});
  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> with TickerProviderStateMixin {
  InventarioView _currentView = InventarioView.productos;
  List<Map<String, dynamic>> _categorias = [];
  bool _categoriasCargadas = false;
  TabController? _tabController;
  Map<Map<String, dynamic>, List<Map<String, dynamic>>> _productosAgrupados = {};
  List<Map<String, dynamic>> _materiasPrimas = [];
  bool _cargando = true;

  // --- ESTADO PARA EDICIÓN DE STOCK ---
  final Map<String, TextEditingController> _stockMateriaPrimaCtrls = {};
  final Map<String, double> _originalStockMateriaPrima = {};
  bool _hayCambiosMateriaPrima = false;

  final Map<String, TextEditingController> _stockProductoCtrls = {};
  final Map<String, int> _originalStockProducto = {};
  bool _hayCambiosProducto = false;

  @override
  void initState() {
    super.initState();
    _inicializar();
    Provider.of<ProductNotifier>(context, listen: false).addListener(_onProductsChanged);
  }

  // --- MÉTODOS FALTANTES EN INVENTARIO ---
  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  PreferredSizeWidget? _buildAppBarBottom() {
    if (_currentView == InventarioView.productos && _tabController != null) {
      return TabBar(
        controller: _tabController, 
        isScrollable: true,
        tabs: [
          const Tab(text: 'Todos'),
          ..._categorias.map((c) => Tab(text: c['nombre']?.toString() ?? 'Categoría')),
        ],
      );
    }
    return null;
  }

  Future<double?> _pedirNuevoPrecio(BuildContext context, double actual) {
    final controller = TextEditingController(text: actual.toStringAsFixed(2));
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Actualizar precio'),
        content: TextField(
          controller: controller, 
          keyboardType: const TextInputType.numberWithOptions(decimal: true), 
          decoration: const InputDecoration(prefixText: '\$ ', border: OutlineInputBorder())
        ),
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

  void _onProductsChanged() { if (mounted) _cargarDatosActuales(); }

  Future<void> _inicializar() async {
    await _cargarCategorias();
    await _cargarMateriasPrimas(silencioso: true); 
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
        if (!_tabController!.indexIsChanging) _cargarDatosActuales();
      });
      _cargarDatosActuales();
    }
  }

  Future<void> _cargarCategorias() async {
    try {
      final records = await supabase.from('categoria').select('*').order('nombre');
      if (mounted) setState(() { _categorias = records; _categoriasCargadas = true; });
    } catch (e) { _mostrarError('Error categorías: $e'); }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    Provider.of<ProductNotifier>(context, listen: false).removeListener(_onProductsChanged);
    for (var c in _stockMateriaPrimaCtrls.values) c.dispose();
    for (var c in _stockProductoCtrls.values) c.dispose();
    super.dispose();
  }

  void _cargarDatosActuales() {
    if (_currentView == InventarioView.productos) {
      if (_tabController == null) return;
      final index = _tabController!.index;
      final String? catId = (index == 0) ? null : _categorias[index - 1]['id']?.toString();
      _cargarItemsProductos(categoriaId: catId);
    } else {
      _cargarMateriasPrimas();
    }
  }

  Future<void> _cargarItemsProductos({String? categoriaId}) async {
    setState(() => _cargando = true);
    for (var c in _stockProductoCtrls.values) c.dispose();
    _stockProductoCtrls.clear();
    _originalStockProducto.clear();
    _hayCambiosProducto = false;

    try {
      var queryProd = supabase.from('producto').select('*, id_categoria(*)');
      if (categoriaId != null) queryProd = queryProd.eq('id_categoria', categoriaId);

      var queryVar = supabase.from('productoVariante').select('*, id_producto(*, id_categoria(*))');
      if (categoriaId != null) queryVar = queryVar.eq('id_producto.id_categoria', categoriaId);

      final results = await Future.wait([queryProd.order('nombre'), queryVar]);
      final todosP = List<Map<String, dynamic>>.from(results[0]);
      final todasV = List<Map<String, dynamic>>.from(results[1]);

      if (mounted) {
        for (final v in todasV) {
          final id = v['id'].toString();
          final stock = (v['cantidadStock'] as num?)?.toInt() ?? 0;
          _originalStockProducto[id] = stock;
          _stockProductoCtrls[id] = TextEditingController(text: stock.toString())
            ..addListener(() {
              final det = _detectarCambiosProducto();
              if (det != _hayCambiosProducto) setState(() => _hayCambiosProducto = det);
            });
        }
        _agruparProductos(todosP, todasV);
        setState(() => _cargando = false);
      }
    } catch (e) { _mostrarError('Error productos: $e'); }
  }

  void _agruparProductos(List<Map<String, dynamic>> productos, List<Map<String, dynamic>> variantes) {
    final Map<Map<String, dynamic>, List<Map<String, dynamic>>> mapa = {};
    for (var p in productos) mapa[p] = [];
    for (var v in variantes) {
      final pBase = v['id_producto'] as Map<String, dynamic>?;
      if (pBase != null) {
        try {
          final key = mapa.keys.firstWhere((p) => p['id'].toString() == pBase['id'].toString());
          mapa[key]?.add(v);
        } catch (e) { mapa[pBase] = [v]; }
      }
    }
    mapa.forEach((_, list) => list.sort((a, b) => _sku(a).toLowerCase().compareTo(_sku(b).toLowerCase())));
    _productosAgrupados = mapa;
  }

  Future<void> _cargarMateriasPrimas({bool silencioso = false}) async {
    if (!silencioso) setState(() => _cargando = true);
    for (var c in _stockMateriaPrimaCtrls.values) c.dispose();
    _stockMateriaPrimaCtrls.clear();
    _originalStockMateriaPrima.clear();
    _hayCambiosMateriaPrima = false;

    try {
      final res = await supabase.from('matPrim').select('*, id_unidMed(*)').order('nombre');
      if (mounted) {
        for (var r in res) {
          final id = r['id'].toString();
          final stock = (r['stock'] as num?)?.toDouble() ?? 0.0;
          _originalStockMateriaPrima[id] = stock;
          _stockMateriaPrimaCtrls[id] = TextEditingController(text: stock.toString())
            ..addListener(() {
              final det = _detectarCambiosMateriaPrima();
              if (det != _hayCambiosMateriaPrima) setState(() => _hayCambiosMateriaPrima = det);
            });
        }
        _materiasPrimas = res;
        if (!silencioso) setState(() => _cargando = false);
      }
    } catch (e) { _mostrarError('Error materias primas: $e'); }
  }

  bool _detectarCambiosMateriaPrima() {
    for (var mp in _materiasPrimas) {
      final id = mp['id'].toString();
      final original = _originalStockMateriaPrima[id];
      final actual = double.tryParse(_stockMateriaPrimaCtrls[id]?.text.replaceAll(',', '.') ?? '');
      if (original != null && actual != null && actual != original) return true;
    }
    return false;
  }

  bool _detectarCambiosProducto() {
    for (var entry in _stockProductoCtrls.entries) {
      final original = _originalStockProducto[entry.key];
      final actual = int.tryParse(entry.value.text);
      if (original != null && actual != null && actual != original) return true;
    }
    return false;
  }

  // --- HELPERS ---
  Map<String, dynamic>? _getProductoRecord(Map<String, dynamic> r) => 
      r.containsKey('id_categoria') ? r : r['id_producto'] as Map<String, dynamic>?;

  String _nombre(Map<String, dynamic> r) => _getProductoRecord(r)?['nombre']?.toString() ?? 'N/A';
  String _sku(Map<String, dynamic> r) => r['sku']?.toString() ?? '-';
  String _categoria(Map<String, dynamic> r) => 
      _getProductoRecord(r)?['id_categoria']?['nombre']?.toString() ?? 'Sin categoría';
  double _precio(Map<String, dynamic> r) => (r['precio_final'] as num?)?.toDouble() ?? 0.0;

  String? _iconUrl(Map<String, dynamic> r) {
    final p = _getProductoRecord(r);
    final file = p?['icon'];
    if (file == null) return null;
    return supabase.storage.from('productos').getPublicUrl(file.toString());
  }

  // --- ACTIONS ---
  Future<void> _actualizarPrecio(Map<String, dynamic> r, double nuevo) async {
    try {
      await supabase.from('productoVariante').update({'precio_final': nuevo}).eq('id', r['id']);
      _cargarDatosActuales();
    } catch (e) { _mostrarError('Error precio: $e'); }
  }

  Future<void> _eliminarVariante(Map<String, dynamic> r) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Eliminar variante'),
      content: Text('¿Eliminar ${_nombre(r)} (${_sku(r)})?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Eliminar')),
      ],
    ));
    if (ok != true) return;
    try {
      await supabase.from('variante_ingrediente').delete().eq('id_productoVariante', r['id']);
      await supabase.from('productoVariante').delete().eq('id', r['id']);
      _cargarDatosActuales();
    } catch (e) { _mostrarError('Error eliminar: $e'); }
  }

  // --- LÓGICA DE PRODUCCIÓN Y STOCK ---
  Future<void> _mostrarDialogoResumenMovimientoMateriaPrima() async {
    final Map<Map<String, dynamic>, double> inc = {};
    final Map<Map<String, dynamic>, double> dec = {};

    for (var mp in _materiasPrimas) {
      final id = mp['id'].toString();
      final original = _originalStockMateriaPrima[id] ?? 0.0;
      final actual = double.tryParse(_stockMateriaPrimaCtrls[id]?.text.replaceAll(',', '.') ?? '0.0') ?? 0.0;
      if (actual > original) inc[mp] = actual; else if (actual < original) dec[mp] = actual;
    }

    if (inc.isEmpty && dec.isEmpty) return;

    final cInc = TextEditingController();
    final cDec = TextEditingController();
    final fecha = DateTime.now();

    final confirmar = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Resumen Stock'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(fecha)}'),
        if (inc.isNotEmpty) ...[
          const Divider(),
          const Text('Incrementos', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          TextFormField(controller: cInc, decoration: const InputDecoration(labelText: 'Concepto')),
          ...inc.entries.map((e) => ListTile(title: Text(e.key['nombre']), trailing: Text('${_originalStockMateriaPrima[e.key['id'].toString()]} -> ${e.value}')))
        ],
        if (dec.isNotEmpty) ...[
          const Divider(),
          const Text('Decrementos', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          TextFormField(controller: cDec, decoration: const InputDecoration(labelText: 'Concepto')),
          ...dec.entries.map((e) => ListTile(title: Text(e.key['nombre']), trailing: Text('${_originalStockMateriaPrima[e.key['id'].toString()]} -> ${e.value}')))
        ],
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
      ],
    ));

    if (confirmar == true) {
      await _guardarMovimientoStockMateriaPrima(inc, dec, cInc.text, cDec.text, fecha);
    }
  }

  Future<void> _guardarMovimientoStockMateriaPrima(Map<Map<String, dynamic>, double> inc, Map<Map<String, dynamic>, double> dec, String concInc, String concDec, DateTime fecha) async {
    setState(() => _cargando = true);
    try {
      final futures = <Future>[];
      final isoDate = fecha.toUtc().toIso8601String();

      void addMoves(Map<Map<String, dynamic>, double> map, String tipo, String conc) {
        for (var entry in map.entries) {
          final id = entry.key['id'].toString();
          final stockAnterior = _originalStockMateriaPrima[id]!;
          futures.add(supabase.from('matPrim').update({'stock': entry.value}).eq('id', id));
          futures.add(supabase.from('movimiento_stock').insert({
            'id_matPrim': id, 'tipo': tipo, 'cantidad': (entry.value - stockAnterior).abs(),
            'stock_anterior': stockAnterior, 'stock_nuevo': entry.value, 'concepto': conc, 'fecha': isoDate,
          }));
        }
      }

      addMoves(inc, 'incremento', concInc);
      addMoves(dec, 'decremento', concDec);
      await Future.wait(futures);
      await _cargarMateriasPrimas();
    } catch (e) { _mostrarError('Error guardado: $e'); }
  }

  Future<void> _guardarMovimientoProduccion(
    Map<Map<String, dynamic>, int> incrementos, 
    Map<String, ConsumoMateriaPrima> consumo,
    String concepto, 
    DateTime fecha,
  ) async {
    try {
      final futures = <Future>[];
      final ahoraUtc = fecha.toUtc().toIso8601String(); // Formato compatible con timestamptz

      // 1. PROCESAR INCREMENTOS DE PRODUCTOS TERMINADOS
      for (final entry in incrementos.entries) {
        final variante = entry.key;
        final String idVariante = variante['id'].toString(); // Aseguramos el ID como String
        final nuevoStock = entry.value;
        final stockAnterior = _originalStockProducto[idVariante]!;

        // Actualización del stock de la variante
        futures.add(
          supabase.from('productoVariante')
            .update({'cantidadStock': nuevoStock})
            .eq('id', idVariante)
        );

        // Registro en el historial de productos
        futures.add(
          supabase.from('movimiento_producto').insert({
            'id_productoVariante': idVariante,
            'tipo': 'incremento',
            'cantidad': nuevoStock - stockAnterior,
            'stock_anterior': stockAnterior,
            'stock_nuevo': nuevoStock,
            'concepto': concepto,
            'fecha': ahoraUtc,
          })
        );
      }

      // 2. PROCESAR DECREMENTOS DE MATERIA PRIMA (RECETA)
      for (final entry in consumo.values) {
        final matPrim = entry.matPrim;
        final String idMatPrim = matPrim['id'].toString();
        final stockAnterior = _originalStockMateriaPrima[idMatPrim]!;
        final nuevoStock = stockAnterior - entry.cantidadRequerida;

        // Actualización del stock de la materia prima
        futures.add(
          supabase.from('matPrim')
            .update({'stock': nuevoStock})
            .eq('id', idMatPrim)
        );

        // Registro en el historial de materias primas
        futures.add(
          supabase.from('movimiento_stock').insert({
            'id_matPrim': idMatPrim,
            'tipo': 'decremento',
            'cantidad': entry.cantidadRequerida,
            'stock_anterior': stockAnterior,
            'stock_nuevo': nuevoStock,
            'concepto': 'Producción: $concepto',
            'fecha': ahoraUtc,
          })
        );
      }

      // Ejecución paralela de todas las operaciones para optimizar rendimiento
      await Future.wait(futures);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producción guardada y stock actualizado correctamente'), 
            backgroundColor: Colors.green
          )
        );
        // Sincronizamos la interfaz con los datos frescos de la base de datos
        await _cargarItemsProductos();
        await _cargarMateriasPrimas(silencioso: true);
      }
    } catch (e) {
      _mostrarError('Error al guardar la producción: $e');
    }
  }

  Future<void> _mostrarDialogoResumenProduccion() async {
  setState(() => _cargando = true);
  final Map<Map<String, dynamic>, int> incrementos = {};
  final Map<String, ConsumoMateriaPrima> consumoTotal = {};
  String errorValidacion = '';

  try {
    for (final entry in _stockProductoCtrls.entries) {
      final varianteId = entry.key; // ID de Supabase
      final original = _originalStockProducto[varianteId] ?? 0;
      final actual = int.tryParse(entry.value.text.replaceAll(',', '')) ?? original;

      if (actual > original) {
        // Buscar la variante en los datos locales
        final varianteRecord = _productosAgrupados.values
            .expand((v) => v)
            .firstWhere((v) => v['id'].toString() == varianteId);
        
        final producto = varianteRecord['id_producto'] as Map<String, dynamic>?;
        final categoria = producto?['id_categoria'] as Map<String, dynamic>?;
        
        if (categoria?['receta'] != true) continue;

        incrementos[varianteRecord] = actual;
        final cantidadAProducir = actual - original;
        
        // Consultar ingredientes con Joins de Supabase
        final List<Map<String, dynamic>> ingredientes = await supabase
            .from('variante_ingrediente')
            .select('*, id_matPrim(*, id_unidMed(*))')
            .eq('id_productoVariante', varianteId);

        if (ingredientes.isEmpty) {
          errorValidacion = 'La variante "${_sku(varianteRecord)}" no tiene receta configurada.';
          break;
        }

        for (final ing in ingredientes) {
          final matPrim = ing['id_matPrim'] as Map<String, dynamic>;
          final matPrimId = matPrim['id'].toString();
          final cantidadNec = (ing['cantidadNecesaria'] as num).toDouble() * cantidadAProducir;

          if (consumoTotal.containsKey(matPrimId)) {
            consumoTotal[matPrimId] = ConsumoMateriaPrima(
              matPrim: matPrim,
              cantidadRequerida: consumoTotal[matPrimId]!.cantidadRequerida + cantidadNec,
            );
          } else {
            consumoTotal[matPrimId] = ConsumoMateriaPrima(matPrim: matPrim, cantidadRequerida: cantidadNec);
          }
        }
      }
    }

    if (errorValidacion.isNotEmpty) {
      _mostrarError(errorValidacion);
      return;
    }

    if (incrementos.isEmpty) {
      _mostrarError("No hay incrementos de producción detectados.");
      return;
    }
    
    // Validación de stock disponible
    await _cargarMateriasPrimas(silencioso: true);
    for (final consumo in consumoTotal.values) {
      final idMp = consumo.matPrim['id'].toString();
      final disponible = _originalStockMateriaPrima[idMp] ?? 0.0;
      if (disponible < consumo.cantidadRequerida) {
        _mostrarError('Falta stock de "${consumo.matPrim['nombre']}". Necesario: ${consumo.cantidadRequerida}, Disponible: $disponible.');
        return;
      }
    }
    
    // Si todo está bien, mostrar el diálogo de confirmación
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Producción'),
        content: const Text('¿Deseas descontar la materia prima e incrementar el stock de los productos?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmar')),
        ],
      ),
    );

    if (confirmar == true) {
      await _guardarMovimientoProduccion(incrementos, consumoTotal, 'Producción manual', DateTime.now());
    }
  } catch (e) {
    _mostrarError('Error en producción: $e');
  } finally {
    if (mounted) setState(() => _cargando = false);
  }
}

  @override
  Widget build(BuildContext context) {
    if (!_categoriasCargadas) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    Widget bodyContent = _cargando 
      ? const Center(child: CircularProgressIndicator()) 
      : (_currentView == InventarioView.materiasPrimas ? _buildMateriasPrimasTable() : _buildProductosAgrupadosList());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: SegmentedButton<InventarioView>(
          segments: const [
            ButtonSegment(value: InventarioView.productos, label: Text('Productos')),
            ButtonSegment(value: InventarioView.materiasPrimas, label: Text('Materia Prima')),
          ],
          selected: {_currentView},
          onSelectionChanged: (set) {
            setState(() {
              _currentView = set.first;
              if (_currentView == InventarioView.productos) _reconstruirTabController();
              else { _tabController?.dispose(); _tabController = null; _cargarDatosActuales(); }
            });
          },
        ),
        bottom: _buildAppBarBottom(),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () {
            String? catId = (_currentView == InventarioView.productos && _tabController != null && _tabController!.index > 0)
              ? _categorias[_tabController!.index - 1]['id'].toString() : null;
            Navigator.push(context, MaterialPageRoute(builder: (_) => AgregarProductoScreen(categoriaInicialId: catId))).then((v) { if (v == true) _cargarDatosActuales(); });
          })
        ],
      ),
      body: SingleChildScrollView(padding: const EdgeInsets.all(12), child: bodyContent),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_currentView == InventarioView.materiasPrimas && _hayCambiosMateriaPrima && !_cargando)
            FilledButton.icon(onPressed: _mostrarDialogoResumenMovimientoMateriaPrima, icon: const Icon(Icons.inventory_2), label: const Text('Guardar Movimiento')),
          if (_currentView == InventarioView.productos && _hayCambiosProducto && !_cargando)
            FilledButton.icon(onPressed: _mostrarDialogoResumenProduccion, icon: const Icon(Icons.bakery_dining), label: const Text('Confirmar Producción')),
          const SizedBox(height: 16),
          FloatingActionButton(onPressed: _cargarDatosActuales, child: const Icon(Icons.refresh)),
        ],
      ),
    );
  }

  // --- BUILDERS DE UI ADAPTADOS ---
  Widget _buildMateriasPrimasTable() {
    return DataTable(
      columns: const [DataColumn(label: Text('Materia Prima')), DataColumn(label: Text('Stock'))],
      rows: _materiasPrimas.map((r) {
        final id = r['id'].toString();
        final unid = r['id_unidMed']?['abreviatura'] ?? '-';
        return DataRow(cells: [
          DataCell(Text(r['nombre'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(TextFormField(controller: _stockMateriaPrimaCtrls[id], decoration: InputDecoration(suffixText: unid, border: InputBorder.none))),
        ]);
      }).toList(),
    );
  }

  Widget _buildProductosAgrupadosList() {
    final prods = _productosAgrupados.keys.toList();
    return ListView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      itemCount: prods.length,
      itemBuilder: (context, i) {
        final p = prods[i];
        final vars = _productosAgrupados[p]!;
        return Card(
          child: ExpansionTile(
            leading: _ProductoIcono(url: _iconUrl(p)),
            title: Text(_nombre(p), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(_categoria(p)),
            trailing: IconButton(icon: const Icon(Icons.edit_note), onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => DetalleProductoGeneralScreen(producto: p))).then((v) { if (v == true) _cargarDatosActuales(); });
            }),
            children: [_buildTablaVariantes(vars)],
          ),
        );
      },
    );
  }

  DataTable _buildTablaVariantes(List<Map<String, dynamic>> vars) {
    return DataTable(
      columns: const [DataColumn(label: Text('SKU')), DataColumn(label: Text('Stock')), DataColumn(label: Text('Acciones'))],
      rows: vars.map((v) {
        final id = v['id'].toString();
        final reqReceta = v['id_producto']?['id_categoria']?['receta'] ?? false;
        return DataRow(cells: [
          DataCell(Text(_sku(v))),
          DataCell(TextFormField(controller: _stockProductoCtrls[id], readOnly: !reqReceta, decoration: const InputDecoration(border: InputBorder.none))),
          DataCell(Row(children: [
            IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () async {
              final n = await _pedirNuevoPrecio(context, _precio(v));
              if (n != null) _actualizarPrecio(v, n);
            }),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _eliminarVariante(v)),
          ])),
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
    if (url != null) return ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(url!, width: 40, height: 40, fit: BoxFit.cover));
    return const Icon(Icons.inventory_2, size: 40);
  }
}

// (Faltan _pedirNuevoPrecio y _mostrarDialogoResumenProduccion que siguen la misma lógica de los otros diálogos migrados)