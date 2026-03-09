import 'package:flutter/material.dart';

import '../servicios/supabase_client.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});
  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _categorias = [];
  bool _categoriasCargadas = false;
  TabController? _tabController;

  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _items = []; 
  Map<String, List<Map<String, dynamic>>> _productosAgrupados = {};
  
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
      // En Supabase, .select() sin parámetros equivale a traer todas las filas y columnas
      final List<Map<String, dynamic>> records = await supabase
          .from('categorias')
          .select('*')
          .order('nombre', ascending: true);

      if (mounted) {
        setState(() {
          _categorias = records; // Ahora es una lista de Mapas
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
  // 1. Cambiamos el tipo de lista a Mapas de Dart
  List<Map<String, dynamic>> filteredList;
  
  if (_searchQuery.isEmpty) {
    filteredList = List.from(_items);
  } else {
    final query = _normalizeText(_searchQuery);
    filteredList = _items.where((item) {
      // Usamos los helpers que ya adaptamos para leer mapas directamente
      final nombre = _normalizeText(_nombre(item));
      final sku = _normalizeText(_sku(item));
      return nombre.contains(query) || sku.contains(query);
    }).toList();
  }
  
  // 2. El mapa de agrupamiento ahora usa String como llave y una lista de Mapas como valor
  final Map<String, List<Map<String, dynamic>>> mapa = {};
  
  for (final variante in filteredList) {
    // _getProductoRecord ahora devuelve el mapa del producto (id_producto)
    final productoBase = _getProductoRecord(variante);
    
    if (productoBase != null) {
      // En Supabase/Postgres el ID suele ser 'id' (UUID o Int)
      // Lo convertimos a String para la llave del mapa
      final String idBase = productoBase['id_producto'].toString();
      
      (mapa[idBase] ??= []).add(variante);
    }
  }
  
  setState(() {
    _productosAgrupados = mapa;
  });
}

  Map<String, dynamic>? _getProductoRecord(Map<String, dynamic> r) {
    if (r.containsKey('id_producto')) {
      return r;
    }
    return null;
  }
  String _nombre(Map<String, dynamic> r) {
    final producto = _getProductoRecord(r);
    return producto?['nombre']?.toString() ?? 'Producto sin nombre';
  }
  String _sku(Map<String, dynamic> r) => r['sku']?.toString() ?? '-';
  String _categoria(Map<String, dynamic> r) {
    final producto = _getProductoRecord(r);
    
    if (producto != null && producto.containsKey('id_categoria')) {
      final cat = producto['id_categoria'];
      
      // Si 'id_categoria' es un Mapa (porque hiciste un join en la select)
      if (cat is Map) {
        return cat['nombre']?.toString() ?? 'Sin categoría';
      }
      
      // Si 'id_categoria' es solo el ID (como el número 18 que vimos)
      // Buscamos el nombre en nuestra lista local de _categorias
      final categoriaEncontrada = _categorias.firstWhere(
        (c) => c['id_categoria'].toString() == cat.toString(),
        orElse: () => {},
      );

      return categoriaEncontrada['nombre']?.toString() ?? 'Sin categoría';
    }
    
    return 'Sin categoría';
  }
  int _cantidad(Map<String, dynamic> r) => (r['cantidadStock'] as num?)?.toInt() ?? 0;
  double _precio(Map<String, dynamic> r) => (r['precio_final'] as num?)?.toDouble() ?? 0.0;
  String? _iconUrl(Map<String, dynamic> r) {
    final file = r['imagen_url']; // En Repostería, 'icon' está en el primer nivel
    if (file == null || file.toString().isEmpty) return null;

    return supabase.storage
        .from('productos') 
        .getPublicUrl(file.toString());
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
      // 1. Construimos la consulta base
      var query = supabase.from('productos').select('*');

      // 2. Aplicamos filtro condicional
      if (categoriaId != null) {
        // Usamos la sintaxis de puntos para filtrar por la tabla relacionada
        query = query.eq('id_categoria', categoriaId);
      }

      // 3. Ordenamiento (nombre del producto y luego creación)
      final List<Map<String, dynamic>> res = await query
          .order('nombre');

      if (mounted) {
        _items = res;
        _filterAndGroupItems();
        _cargandoItems = false;
      }
    } catch (e) {
      if (mounted) {
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
    
    // Accedemos con ['id'] en lugar de .id
    final categoriaId = index == 0 ? null : _categorias[index - 1]['id_categoria'].toString();
    
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
            ..._categorias.map((c) => Tab(text: c['nombre'].toString())),
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

  DataTable _buildTablaVariantes(List<Map<String, dynamic>> variantes) {
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