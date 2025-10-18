import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'pb_client.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});
  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> with TickerProviderStateMixin {
  List<RecordModel> _categorias = [];
  bool _categoriasCargadas = false;
  TabController? _tabController;

  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<RecordModel> _items = []; 
  Map<String, List<RecordModel>> _productosAgrupados = {};
  
  bool _cargandoItems = true;

  @override
  void initState() {
    super.initState();
    _inicializar();
    
    _searchController.addListener(() {
      if (_searchQuery != _searchController.text) {
        setState(() {
          _searchQuery = _searchController.text;
          _filterAndGroupItems();
        });
      }
    });
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
    _searchController.dispose();
    super.dispose();
  }

  String _normalizeText(String input) {
    return input
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  void _filterAndGroupItems() {
    List<RecordModel> filteredList;
    if (_searchQuery.isEmpty) {
      filteredList = List.from(_items);
    } else {
      final query = _normalizeText(_searchQuery);
      filteredList = _items.where((item) {
        final nombre = _normalizeText(_nombre(item));
        final sku = _normalizeText(_sku(item));
        return nombre.contains(query) || sku.contains(query);
      }).toList();
    }
    
    final Map<String, List<RecordModel>> mapa = {};
    for (final variante in filteredList) {
      final productoBase = _getProductoRecord(variante);
      if (productoBase != null) {
        (mapa[productoBase.id] ??= []).add(variante);
      }
    }
    
    setState(() {
      _productosAgrupados = mapa;
    });
  }

  RecordModel? _getProductoRecord(RecordModel r) {
    if (r.expand.containsKey('id_producto') && r.expand['id_producto']!.isNotEmpty) {
      return r.expand['id_producto']!.first;
    }
    return null;
  }
  String _nombre(RecordModel r) {
    final producto = _getProductoRecord(r);
    return producto?.data['nombre']?.toString() ?? 'Producto sin nombre';
  }
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

  Future<void> _cargarItems({String? categoriaId}) async {
    setState(() => _cargandoItems = true);
    try {
      final res = await pb.collection('productoVariante').getList(
            perPage: 200,
            filter: categoriaId == null ? '' : 'id_producto.id_categoria = "$categoriaId"',
            sort: 'id_producto.nombre, created',
            expand: 'id_producto,id_producto.id_categoria',
          );
      if (mounted) {
        _items = res.items;
        _filterAndGroupItems();
        _cargandoItems = false;
      }
    } catch (e) {
      if(mounted) {
        _items = [];
        _filterAndGroupItems();
        _cargandoItems = false;
      }
      _mostrarError('Error al cargar productos: $e');
    }
  }

  void _recargarSegunTab() {
    if (_tabController == null) return;
    final index = _tabController!.index;
    final categoriaId = index == 0 ? null : _categorias[index - 1].id;
    _cargarItems(categoriaId: categoriaId);
  }

  @override
  Widget build(BuildContext context) {
    if (!_categoriasCargadas || _tabController == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Buscar por producto o SKU...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _searchController.clear(),
                  )
                : null,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            const Tab(text: 'Todos'),
            ..._categorias.map((c) => Tab(text: c.data['nombre'].toString())),
          ],
        ),
      ),
      body: _cargandoItems
        ? const Center(child: CircularProgressIndicator())
        : _buildProductosAgrupadosList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _recargarSegunTab,
        tooltip: 'Recargar',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildProductosAgrupadosList() {
    if (_productosAgrupados.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(_searchQuery.isNotEmpty ? 'No se encontraron resultados para "$_searchQuery".' : 'No hay productos en esta categoría.'),
        ),
      );
    }
    final productoIds = _productosAgrupados.keys.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: productoIds.length,
        itemBuilder: (context, index) {
          final productoId = productoIds[index];
          final variantes = _productosAgrupados[productoId]!;
          final primerVariante = variantes.first;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            // ✨ --- CAMBIOS PARA EXPANSIÓN AUTOMÁTICA --- ✨
            child: ExpansionTile(
              // Key única para forzar la reconstrucción al buscar/limpiar
              key: ValueKey('$productoId-$_searchQuery'),
              // Se expande si hay una búsqueda activa
              initiallyExpanded: _searchQuery.isNotEmpty,
              leading: _ProductoIcono(url: _iconUrl(primerVariante)),
              title: Text(_nombre(primerVariante), style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_categoria(primerVariante)),
              children: <Widget>[
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
      ),
    );
  }

  DataTable _buildTablaVariantes(List<RecordModel> variantes) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('SKU / Variante')),
        DataColumn(label: Text('Stock')),
        DataColumn(label: Text('Precio')),
      ],
      rows: variantes.map((variante) {
        return DataRow(cells: [
          DataCell(Text(_sku(variante))),
          DataCell(
            Text(
              '${_cantidad(variante)} pzas', 
              style: const TextStyle(fontWeight: FontWeight.bold)
            )
          ),
          DataCell(Text('\$${_precio(variante).toStringAsFixed(2)}')),
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
    const Widget fallback = Icon(Icons.image_not_supported, size: 28);

    if (url != null && url!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 28)),
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