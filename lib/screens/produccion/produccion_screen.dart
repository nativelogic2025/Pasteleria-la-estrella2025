import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../servicios/supabase_client.dart';
import './dialogo_produccion.dart';

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
        // 3. Limpiamos los datos visuales antes de mandarlos a la BD
        // Solo enviamos las columnas que realmente existen en tu tabla de Supabase
        final datosParaInsertar = resultados.map((r) {
          return {
            "id_producto": r['id_producto'],
            "id_variante": r['id_variante'], // El UUID o int de la variante
            "cantidad_original": r['cantidad'],
            "cantidad_restante": r['cantidad'],
            "fecha_produccion": r['fecha_produccion'],
            "fecha_caducidad": r['fecha_caducidad'],
          };
        }).toList();

        print(datosParaInsertar);

        // 4. Insertamos toda la lista a la vez. 
        await supabase.from('produccion').insert(datosParaInsertar);

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

  @override
  Widget build(BuildContext context) {
    if (!_categoriasCargadas || _tabController == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // Eliminamos el espaciado automático para que el buscador use bien el ancho
        titleSpacing: 10, 
        title: Row(
          children: [
            // 1. SOLUCIÓN: Usar Expanded para que el TextField no cause error de ancho
            Expanded(
              child: SizedBox(
                height: 40, // Opcional: Controla la altura para que se vea más estilizado
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por producto ...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Colors.grey[200], // Un color diferente ayuda a resaltar sobre el blanco
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty // Usar .text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              // No olvides llamar a setState si quieres que desaparezca el icono X
                              setState(() {}); 
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    // Actualiza el estado para mostrar/ocultar el icono de "clear"
                    setState(() {});
                  },
                ),
              ),
            ),
            const SizedBox(width: 15),
            SizedBox(
              child: ElevatedButton(
                onPressed: () => _agregarProduccionASupabase(),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color.fromARGB(210, 236, 231, 131),
                ),
                child: 
                  const Text(
                    "Registrar producción",
                    style: TextStyle(fontSize: 18),
                  ),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50.0),
          child: Row(
            children: [
              // El TabBar envuelto en Expanded para que tome todo el espacio izquierdo
              Expanded(
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: [
                    const Tab(text: 'Todos'),
                    ..._categorias.map((c) => Tab(text: c['nombre'].toString())),
                  ],
                ),
              ),
              // Separador visual
              Container(height: 30, width: 1, color: Colors.grey[300]),
              const SizedBox(width: 8),
              
              // Los nuevos filtros incrustados a la derecha
              _buildFiltrosDerecha(),
            ],
          ),
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

  DataTable _buildTablaVariantes(List<Map<String, dynamic>> productos) {
    return DataTable(
      columns: const [
        // DataColumn(label: Text('Producto')),
        DataColumn(label: Text('Variante')),
        DataColumn(label: Text('Cantidad Producida')),
        DataColumn(label: Text('Cantidad Disponible')),
        DataColumn(label: Text('Fecha Producción')),
        DataColumn(label: Text('Fecha Caducidad')),
      ],
      rows: productos.expand((producto) {
        final listaVariantes = producto['producto_variantes'] as List<dynamic>? ?? [];

        // Primer expand: recorre las variantes
        return listaVariantes.expand((variante) {
          final listaProduccion = variante['produccion'] as List<dynamic>? ?? [];

          // Si no hay producciones, ¿quieres mostrar la variante vacía? 
          // Si la respuesta es NO, solo retorna el map de abajo.
          // Si la respuesta es SÍ, podrías manejar un caso por defecto.

          // Segundo expand: recorre cada registro de producción dentro de la variante
          return listaProduccion.map((produccion) {
            return DataRow(
              cells: [
                // Datos de la Variante (se repetirán si hay varias producciones)
                DataCell(Text(variante['tamaño'] ?? 'Variante')), 
                
                // Datos específicos del registro de PRODUCCIÓN
                DataCell(
                  Text(
                    '${produccion['cantidad_original'] ?? 0} pzas', 
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

                DataCell(
                  Text(
                    '${produccion['cantidad_restante'] ?? 0} pzas', 
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                
                // Fechas tomadas del registro de producción, no de la variante
                DataCell(Text(produccion['fecha_produccion'] ?? 'N/A')),
                DataCell(Text(produccion['fecha_caducidad'] ?? 'N/A')),
              ],
            );
          });
        });
      }).toList(),// Expand devuelve un Iterable, lo convertimos a List
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