import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../servicios/supabase_client.dart';
import './dialogo_produccion.dart';
import 'package:flutter_animate/flutter_animate.dart';

final supabase = Supabase.instance.client;

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

  // --- VARIABLES PARA EL FILTRO ---
  DateTime _fechaInicio = DateTime.now().subtract(const Duration(days: 7));
  DateTime _fechaFin = DateTime.now().add(const Duration(days: 7));
  bool _soloConStock = false;

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

  Future<void> _agregarProduccionASupabase() async {
    // 1. Ahora esperamos una LISTA de mapas
    final List<Map<String, dynamic>>? resultados = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const DialogoRegistrarProduccion(),
    );

    // 2. Si hay resultados y la lista no está vacía
    if (resultados != null && resultados.isNotEmpty) {
      try {
        // 3. Iteramos y llamamos al RPC para cada registro de producción para descontar BOM
        for (var r in resultados) {
          await supabase.rpc('registrar_produccion_bom', params: {
            'p_id_producto': r['id_producto'],
            'p_id_variante': r['id_variante'],
            'p_cantidad': r['cantidad'],
            'p_observaciones': r['observaciones'] ?? '',
            'p_fecha_produccion': r['fecha_produccion'],
            'p_fecha_caducidad': r['fecha_caducidad'],
          });
        }

        _recargarSegunTab();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${resultados.length} registros guardados con éxito')),
        );
        
      } catch (e) {
        print("Error al guardar producción: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _actualizarObservaciones(
      Map<String, dynamic> variante, String nuevo) async {
    try {
      await supabase
          .from('produccion')
          .update({'observaciones': nuevo})
          .eq('id_produccion', variante['id_produccion']);

      _recargarSegunTab();
    } catch (e) {
      _mostrarError('Error al actualizar observaciones: $e');
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
    final Map<String, List<Map<String, dynamic>>> mapa = {};
    final query = _normalizeText(_searchQuery);

    for (final producto in _items) {
      // 1. Filtro de búsqueda por texto
      final nombreProd = _normalizeText(_nombre(producto));
      if (_searchQuery.isNotEmpty && !nombreProd.contains(query)) {
        continue; // Si no coincide el texto, saltamos al siguiente producto
      }

      // 2. FILTRADO PROFUNDO (Variantes y Producción)
      List<dynamic> variantesOriginales = producto['producto_variantes'] ?? [];
      List<Map<String, dynamic>> variantesFiltradas = [];

      for (var v in variantesOriginales) {
        List<dynamic> produccionesOriginales = v['produccion'] ?? [];
        List<Map<String, dynamic>> produccionesFiltradas = [];

        for (var p in produccionesOriginales) {
          // A. Filtrar por Fechas
          DateTime? fechaProd = DateTime.tryParse(p['fecha_produccion'] ?? '');
          if (fechaProd == null) continue;

          // Normalizamos las fechas para ignorar horas y comparar solo los días
          DateTime fProdOnly = DateTime(fechaProd.year, fechaProd.month, fechaProd.day);
          DateTime fIniOnly = DateTime(_fechaInicio.year, _fechaInicio.month, _fechaInicio.day);
          DateTime fFinOnly = DateTime(_fechaFin.year, _fechaFin.month, _fechaFin.day);

          bool enRango = !fProdOnly.isBefore(fIniOnly) && !fProdOnly.isAfter(fFinOnly);

          // B. Filtrar por Stock
          int stockRestante = p['cantidad_restante'] ?? 0;
          bool stockOk = _soloConStock ? stockRestante > 0 : true;

          // Si cumple ambos filtros, lo agregamos a las producciones válidas
          if (enRango && stockOk) {
            produccionesFiltradas.add(Map<String, dynamic>.from(p));
          }
        }

        // Si la variante tiene al menos una producción válida, la conservamos
        if (produccionesFiltradas.isNotEmpty) {
          Map<String, dynamic> vClon = Map<String, dynamic>.from(v);
          vClon['produccion'] = produccionesFiltradas; // Le asignamos solo lo filtrado
          variantesFiltradas.add(vClon);
        }
      }

      // 3. Si el producto sobrevivió a los filtros con al menos una variante
      if (variantesFiltradas.isNotEmpty) {
        Map<String, dynamic> pClon = Map<String, dynamic>.from(producto);
        pClon['producto_variantes'] = variantesFiltradas;
        
        // Lo agrupamos (la lógica que ya tenías)
        final String idBase = pClon['id_producto'].toString();
        (mapa[idBase] ??= []).add(pClon);
      }
    }

    setState(() {
      _productosAgrupados = mapa;
    });
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().substring(2)}";
  }

  Future<void> _seleccionarFecha(bool isInicio) async {
    final initialDate = isInicio ? _fechaInicio : _fechaFin;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color.fromARGB(255, 165, 106, 224)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isInicio) {
          _fechaInicio = picked;
          if (_fechaInicio.isAfter(_fechaFin)) _fechaFin = _fechaInicio; // Autocorrección
        } else {
          _fechaFin = picked;
          if (_fechaFin.isBefore(_fechaInicio)) _fechaInicio = _fechaFin; // Autocorrección
        }
        _filterAndGroupItems(); // Disparamos el filtro al cambiar la fecha
      });
    }
  }

  // --- WIDGET DE LA BARRA DE FILTROS ---
  Widget _buildFiltrosDerecha() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilterChip(
          label: const Text('Stock > 0', style: TextStyle(fontSize: 13)),
          selected: _soloConStock,
          showCheckmark: false,
          selectedColor: const Color.fromARGB(150, 236, 231, 131),
          onSelected: (val) {
            setState(() {
              _soloConStock = val;
              _filterAndGroupItems();
            });
          },
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: () => _seleccionarFecha(true),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.black87),
                const SizedBox(width: 6),
                Text(_formatDate(_fechaInicio), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Text("-", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
        InkWell(
          onTap: () => _seleccionarFecha(false),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.event, size: 16, color: Colors.black87),
                const SizedBox(width: 6),
                Text(_formatDate(_fechaFin), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16), // Espacio final
      ],
    );
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
      var query = supabase.from('productos').select(''' *, producto_variantes ( *, produccion (*) ) ''');

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

  String? _selectedProductId;

  @override
  Widget build(BuildContext context) {
    if (!_categoriasCargadas || _tabController == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
        titleSpacing: 20,
        title: Row(
          children: [
            const Icon(Icons.inventory_2_outlined, color: Color(0xFF8C5535)),
            const SizedBox(width: 12),
            const Text('Producción', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(width: 30),
            
            // Search Bar
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 42,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por producto...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                              _filterAndGroupItems();
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ),
            const Spacer(),
            
            // TabBar (Categories)
            SizedBox(
              width: 500,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: const Color(0xFF8C5535),
                labelColor: const Color(0xFF8C5535),
                unselectedLabelColor: Colors.grey,
                dividerColor: Colors.transparent,
                tabs: [
                  const Tab(text: 'Todos'),
                  ..._categorias.map((c) => Tab(text: c['nombre'].toString())),
                ],
              ),
            ),
            const SizedBox(width: 20),
            
            ElevatedButton.icon(
              onPressed: () => _agregarProduccionASupabase(),
              icon: const Icon(Icons.add, size: 20),
              label: const Text("Registrar Producción", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8C5535),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PANEL IZQUIERDO (Lista de Productos y Filtros)
          Container(
            width: 360,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                _buildFiltrosDecorados(),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                Expanded(
                  child: _cargandoItems
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF8C5535)))
                      : _buildListaProductos(),
                ),
              ],
            ),
          ),
          
          // PANEL DERECHO (Detalle y Tabla)
          Expanded(
            child: Container(
              color: const Color(0xFFFAFAFA),
              child: _selectedProductId == null || !_productosAgrupados.containsKey(_selectedProductId)
                  ? _buildEmptyState()
                  : _buildDetalleProducto(_selectedProductId!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Selecciona un producto', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text('Para ver su historial de producción y variantes', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildFiltrosDecorados() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFFFCF5EE),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Filtros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF8C5535))),
              Row(
                children: [
                  const Text('Solo con Stock', style: TextStyle(fontSize: 13, color: Colors.black87)),
                  const SizedBox(width: 8),
                  Switch(
                    value: _soloConStock,
                    activeColor: const Color(0xFF8C5535),
                    onChanged: (val) {
                      setState(() {
                        _soloConStock = val;
                        _filterAndGroupItems();
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _dateChip('Desde', _fechaInicio, () => _seleccionarFecha(true)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dateChip('Hasta', _fechaFin, () => _seleccionarFecha(false)),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _dateChip(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5CEB3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today, size: 14, color: Color(0xFF8C5535)),
            const SizedBox(width: 6),
            Text(_formatDate(date), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildListaProductos() {
    if (_productosAgrupados.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(_searchQuery.isNotEmpty ? 'No se encontraron resultados.' : 'No hay productos.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
        ),
      );
    }

    final keys = _productosAgrupados.keys.toList();

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: keys.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final id = keys[index];
        final p = _productosAgrupados[id]!.first;
        final selected = _selectedProductId == id;

        int totalStock = 0;
        final variantes = p['producto_variantes'] as List<dynamic>? ?? [];
        for (var v in variantes) {
           final producciones = v['produccion'] as List<dynamic>? ?? [];
           for (var prod in producciones) {
              totalStock += (prod['cantidad_restante'] as num?)?.toInt() ?? 0;
           }
        }

        return InkWell(
          onTap: () => setState(() => _selectedProductId = id),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFCF5EE) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? const Color(0xFF8C5535) : Colors.grey.shade200),
            ),
            child: Row(
              children: [
                _ProductoIcono(url: _iconUrl(p)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_nombre(p), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? const Color(0xFF8C5535) : Colors.black87)),
                      const SizedBox(height: 4),
                      Text(_categoria(p), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: totalStock > 0 ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalStock',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: totalStock > 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828)),
                  ),
                )
              ],
            ),
          ),
        ).animate(key: ValueKey(id))
         .fade(duration: 300.ms, delay: (40 * index).ms)
         .slideX(begin: -0.05, duration: 300.ms, delay: (40 * index).ms);
      },
    );
  }

  Widget _buildDetalleProducto(String id) {
    final pList = _productosAgrupados[id]!;
    final p = pList.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header del detalle
        Container(
          padding: const EdgeInsets.all(24),
          color: Colors.white,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ClipOval(
                  child: _iconUrl(p) != null 
                      ? Image.network(_iconUrl(p)!, width: 60, height: 60, fit: BoxFit.cover)
                      : Container(width: 60, height: 60, color: Colors.grey.shade100, child: const Icon(Icons.cake, color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_nombre(p), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text(_categoria(p), style: const TextStyle(fontSize: 16, color: Color(0xFF8C5535))),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _recargarSegunTab,
                tooltip: 'Actualizar datos',
              )
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFEEEEEE)),
        
        // Tabla de Variantes
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildTablaPremium(pList),
              ),
            ),
          ),
        ),
      ],
    ).animate(key: ValueKey(id)).fade(duration: 400.ms).slideY(begin: 0.05);
  }

  Widget _buildTablaPremium(List<Map<String, dynamic>> productos) {
    final List<DataRow> rows = [];
    
    for (var producto in productos) {
      final listaVariantes = producto['producto_variantes'] as List<dynamic>? ?? [];
      for (var variante in listaVariantes) {
        final listaProduccion = variante['produccion'] as List<dynamic>? ?? [];
        for (var produccion in listaProduccion) {
          final int rest = (produccion['cantidad_restante'] as num?)?.toInt() ?? 0;
          
          rows.add(DataRow(
            cells: [
              DataCell(Text(variante['tamaño'] ?? 'Variante', style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text('${produccion['cantidad_original'] ?? 0} pzas')),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: rest > 0 ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$rest pzas', 
                    style: TextStyle(fontWeight: FontWeight.bold, color: rest > 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828)),
                  ),
                )
              ),
              DataCell(Text(produccion['fecha_produccion'] ?? 'N/A')),
              DataCell(Text(produccion['fecha_caducidad'] ?? 'N/A')),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Text(
                        produccion['observaciones']?.toString() ?? '', 
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_note, size: 20, color: Color(0xFF8C5535)),
                      tooltip: 'Editar observación',
                      splashRadius: 20,
                      onPressed: () => _editarObs(produccion),
                    )
                  ],
                )
              ),
            ]
          ));
        }
      }
    }

    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(30),
        child: Center(child: Text("No hay registros de producción que coincidan con los filtros.", style: TextStyle(color: Colors.grey))),
      );
    }

    return DataTable(
      headingRowColor: MaterialStateProperty.all(const Color(0xFFF9F9F9)),
      dataRowMaxHeight: 56,
      columnSpacing: 20,
      columns: const [
        DataColumn(label: Text('Variante', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Producido', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Restante', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Fecha Prod.', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Caducidad', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Observaciones', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
      rows: rows,
    );
  }

  Future<void> _editarObs(Map<String,dynamic> produccion) async {
    final String valorInicial = produccion['observaciones']?.toString() ?? '';
    final controller = TextEditingController(text: valorInicial);

    final nuevo = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Actualizar observaciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Escribe una observación...',
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8C5535),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Guardar'),
          )
        ],
      ),
    );

    if (nuevo != null && nuevo != valorInicial) {
      _actualizarObservaciones(produccion, nuevo);
    }
  }
}

class _ProductoIcono extends StatelessWidget {
  const _ProductoIcono({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    const double size = 40;
    const Widget fallback = Icon(Icons.image_not_supported, size: 20, color: Colors.grey);

    if (url != null && url!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url!, width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 20)),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)));
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