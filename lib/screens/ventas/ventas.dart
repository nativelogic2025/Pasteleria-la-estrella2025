import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../product_notifier.dart';

import '../carrito/carrito_provider.dart';
import '../carrito/carrito.dart';
import 'producto.dart' as producto;

import '../servicios/supabase_client.dart';

class Ventas extends StatefulWidget {
  // 1. Declaras el parámetro
  final String categoria;

  const Ventas({super.key, required this.categoria});

 @override
  State<Ventas> createState() => _VentasState();
}

class _VentasState extends State<Ventas> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _cargandoVariantes = false;

  @override
  void initState() {
    super.initState();
    _cargar();

    Provider.of<ProductNotifier>(context, listen: false)
        .addListener(_onProductsChanged);
  }

  void _onProductsChanged() {
    print(">>> Notificación recibida en Ventas: Recargando productos...");
    if (mounted) {
      _cargar();
    }
  }

  @override
  void dispose() {
    Provider.of<ProductNotifier>(context, listen: false)
        .removeListener(_onProductsChanged);
    super.dispose();
  }

  // ---------- Lectura de campos ----------
  String _nombre(Map<String, dynamic> r) =>
      (r['nombre'] ?? r['producto'] ?? '').toString();

  /*double _precio(Map<String, dynamic> r) {
    final v = r['precio_venta'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '0') ?? 0.0;
    }*/

  int _stock(Map<String, dynamic> r) {
    final v = r['stock_total'];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }

  String? _iconUrl(Map<String, dynamic> r) {
    final file = r['imagen_url']; // En Repostería, 'icon' está en el primer nivel
    if (file == null || file.toString().isEmpty) return null;

    return supabase.storage
        .from('productos') 
        .getPublicUrl(file.toString());
  }

  // ---------- Data (Supabase) ----------
  // 1. Cargar productos de la categoría
  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      // 1. Obtenemos el ID de la categoría "Extras"
      // .single() busca un único registro que coincida
      final categoriaData = await supabase
          .from('categorias')
          .select('id_categoria')
          .eq('nombre', widget.categoria.toLowerCase())
          .single();

      final categoriaExtrasId = categoriaData['id_categoria'];

      // 2. Usamos ese ID para filtrar los productos en la tabla 'producto'
      // Supabase devuelve directamente una List<Map<String, dynamic>>
      final List<Map<String, dynamic>> res = await supabase
          .from('productos')
          .select('''
            id_producto,
            id_categoria,
            nombre,
            imagen_url,
            stock_total,
            producto_variantes (
              stock,
              tamaño,
              precio_venta
            )
          ''')
          .eq('id_categoria', categoriaExtrasId)
          .order('nombre', ascending: true);

      if (!mounted) return;
      setState(() {
        _items = res; // Guardamos la lista de mapas directamente
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = []; // Limpiamos la lista en caso de error
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar ${widget.categoria}: $e')),
      );
    }
  }

  // 1. Cargar variantes del producto de la categoría
  Future<List<Map<String, dynamic>>> _cargarVariantes(int idProducto) async {
    if (!mounted) return [];
    
    setState(() => _cargandoVariantes = true);

    try {
      final List<Map<String, dynamic>> res = await supabase
          .from('producto_variantes')
          .select('stock, tamaño, precio_venta')
          .eq('id_producto', idProducto)
          .order('tamaño', ascending: true);

      if (!mounted) return res;

      // IMPORTANTE: Actualizamos el loading y retornamos el resultado
      setState(() => _cargandoVariantes = false);
      return res; 

    } catch (e) {
      if (mounted) {
        setState(() => _cargandoVariantes = false); // Apagamos el loading aunque falle
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar ${widget.categoria}: $e')),
        );
      }
      return []; // Retornamos lista vacía en caso de error
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.categoria),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CarritoScreen()),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final visibles = _items.where((r) => _stock(r) >= 0).toList();

                if (visibles.isEmpty) {
                  return Center(
                    child: Text(
                      'No hay productos disponibles en ${widget.categoria}',
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                final double spacing = 20;
                final int columnas = constraints.maxWidth > 600 ? 5 : 2;
                final double buttonSize =
                    (constraints.maxWidth - (spacing * (columnas + 1))) /
                        columnas;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    alignment: WrapAlignment.center,
                    children: visibles.map((r) {
                      final nombre = _nombre(r);
                      final stock = _stock(r);
                      final url = _iconUrl(r);
                      final assetFallback =
                          'assets/${widget.categoria.toLowerCase()}/${_slug(nombre)}.png';

                      return SizedBox(
                        width: buttonSize,
                        child: Column(
                          children: [
                            SizedBox(
                              width: buttonSize,
                              height: buttonSize,
                              child: OutlinedButton(
                                onPressed: stock != 0 ? () => _onTapProducto(context, r) : 
                                  () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Producto agotado')),
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: stock != 0 ? const Color.fromARGB(
                                      255, 245, 225, 184) : Colors.grey,
                                  side: const BorderSide(
                                      color: Colors.black, width: 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: (url != null && url.isNotEmpty)
                                      ? Image.network(
                                          url,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                                Icons.image_not_supported,
                                                size: 50,
                                              ),
                                        )
                                      : Image.asset(
                                          assetFallback,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                                Icons.image_not_supported,
                                                size: 50,
                                              ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              nombre,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
    );
  }

  // ---------- Taps + reglas especiales ----------
  void _onTapProducto(BuildContext context, Map<String, dynamic> r) async {
    final nombre = _nombre(r);
    final idproducto = r['id_producto'];

    // Obtenemos las variantes directamente de la función
    final variantes = await _cargarVariantes(idproducto);

    if (context.mounted) { // Buena práctica: verificar si el widget sigue vivo
      _mostrarDialogo(context, nombre, variantes);
    }
  }

  // ---------- Diálogo ----------
  void _mostrarDialogo(
    BuildContext context,
    String nombreDelGrupo,
    List<Map<String, dynamic>> variantesDisponibles,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogCtx) {
        return AlertDialog(
          title: Text(nombreDelGrupo, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite, // Para que el diálogo no se colapse
            child: ListView( // Cambiamos Wrap por ListView para mejor lectura en móvil
              shrinkWrap: true,
              children: variantesDisponibles.map((variante) {
                final tamano = variante['tamaño']?.toString() ?? '';
                final precio = double.tryParse(variante['precio_venta']?.toString() ?? '0') ?? 0.0;
                final stock = variante['stock'] ?? 0;
                final bool tieneStock = stock > 0;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: InkWell( // Hace que toda la tarjeta sea cliqueable
                    onTap: tieneStock ? () {
                      _agregarAlCarrito(context, variante, '$nombreDelGrupo - $tamano', precio);
                      Navigator.pop(context);
                    } : null, // Deshabilitado si no hay stock
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          // Lado izquierdo: Tamaño
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tamano, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                const SizedBox(height: 4),
                                // Badge de Stock
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: tieneStock ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "Stock: $stock",
                                    style: TextStyle(
                                      color: tieneStock ? Colors.green : Colors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Lado derecho: Precio y botón
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "\$${precio.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              if (!tieneStock)
                                const Text("Agotado", style: TextStyle(color: Colors.red, fontSize: 10)),
                            ],
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // ---------- Agregar al carrito ----------
  void _agregarAlCarrito(
      BuildContext context, Map<String, dynamic> r, String nombreMostrar, double precio) {
    final imgUrl = _iconUrl(r);
    final nombreBase = _nombre(r);
    final assetFallback = 'assets/${widget.categoria.toLowerCase()}/${_slug(nombreBase)}.png';

    Provider.of<CarritoProvider>(context, listen: false).agregarProducto(
      producto.Producto(
        nombre: nombreMostrar,
        imagen: (imgUrl != null && imgUrl.isNotEmpty) ? imgUrl : assetFallback,
        precio: precio,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$nombreMostrar agregado')),
    );
  }

  // ---------------- Formateador de nombres para imágenes ----------------
  // ---------- Utils ----------
  static String _slug(String s) {
    s = s.trim().toLowerCase();
    const from = 'áéíóúüñ';
    const to =   'aeiouun';
    for (int i = 0; i < from.length; i++) {
      s = s.replaceAll(from[i], to[i]);
    }
    return s.replaceAll(' ', '_');
  }
}