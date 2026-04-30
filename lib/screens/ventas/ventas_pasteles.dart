import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../product_notifier.dart';

import '../carrito/carrito_provider.dart';
import '../carrito/carrito.dart';
import 'producto.dart' as producto;

import '../servicios/supabase_client.dart';
import 'package:flutter_animate/flutter_animate.dart';

class VentasPasteles extends StatefulWidget {
  const VentasPasteles({super.key});

  @override
  State<VentasPasteles> createState() => _VentasPastelesState();
}

class _VentasPastelesState extends State<VentasPasteles> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _cargandoVariantes = false;

  @override
  void initState() {
    super.initState();
    _cargar();
    
    // ✨ 3. REEMPLAZA la suscripción con un listener al notificador
    Provider.of<ProductNotifier>(context, listen: false)
        .addListener(_onProductsChanged);
  }

  // ✨ 5. AÑADE esta función que será llamada por el notificador
  void _onProductsChanged() {
    print(">>> Notificación recibida en VentasPasteles: Recargando productos...");
    if (mounted) {
      _cargar();
    }
  }

  @override
  void dispose() {
    // ✨ 6. REEMPLAZA el unsubscribe con la eliminación del listener
    Provider.of<ProductNotifier>(context, listen: false)
        .removeListener(_onProductsChanged);
    super.dispose();
  }

  // ---------- Helpers lectura ----------
  String _nombre(Map<String, dynamic> r) =>
      (r['nombre'] ?? r['producto'] ?? '').toString();

  String _sabor(Map<String, dynamic> r) =>
      (r['sabor'] ?? '').toString();

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
  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      // 1. Obtenemos el ID de la categoría "Pasteles"
      // .single() busca un único registro que coincida
      final categoriaData = await supabase
          .from('categorias')
          .select('id_categoria')
          .eq('nombre', 'Pasteles')
          .limit(1)
          .single();

      final categoriaPastelesId = categoriaData['id_categoria'];

      // 2. Usamos ese ID para filtrar los productos en la tabla 'producto'
      // Supabase devuelve directamente una List<Map<String, dynamic>>
      final List<Map<String, dynamic>> res = await supabase
          .from('productos')
          .select('''
            *,
            stock_total,
            producto_variantes (
              *
            )
          ''')
          .eq('id_categoria', categoriaPastelesId)
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
        SnackBar(content: Text('Error al cargar Pasteles: $e')),
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
          .select('id_variante, id_producto, stock, tamaño, precio_venta')
          .eq('id_producto', idProducto)
          .order('tamaño', ascending: true);

      if (!mounted) return res;

      // Unificar duplicados por tamaño (sumando su stock)
      final Map<String, Map<String, dynamic>> unicos = {};
      for (var v in res) {
        final tamano = v['tamaño']?.toString().trim() ?? 'N/A';
        if (unicos.containsKey(tamano)) {
          final stockActual = (unicos[tamano]!['stock'] as num?)?.toInt() ?? 0;
          final stockNuevo = (v['stock'] as num?)?.toInt() ?? 0;
          unicos[tamano]!['stock'] = stockActual + stockNuevo;
        } else {
          unicos[tamano] = Map<String, dynamic>.from(v);
        }
      }

      final variantesFinales = unicos.values.toList();
      variantesFinales.sort((a, b) => (a['tamaño'] ?? '').toString().compareTo((b['tamaño'] ?? '').toString()));

      setState(() => _cargandoVariantes = false);
      return variantesFinales; 

    } catch (e) {
      if (mounted) {
        setState(() => _cargandoVariantes = false); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar Pasteles: $e')),
        );
      }
      return []; 
    }
  }


  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pasteles',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _cargar,
                tooltip: 'Recargar',
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) {

                    final chocolate = _items.where((r) {
                      final n = _nombre(r).trim().toLowerCase();
                      final s = _sabor(r).trim().toLowerCase();
                      return n.contains('choco') || s.contains('choco');
                    }).toList();

                    final vainilla = _items.where((r) {
                      final n = _nombre(r).trim().toLowerCase();
                      final s = _sabor(r).trim().toLowerCase();
                      return !(n.contains('choco') || s.contains('choco'));
                    }).toList();

                    if (_items.isEmpty) {
                      return const Center(
                        child: Text('No hay pasteles disponibles', style: TextStyle(fontSize: 16)),
                      );
                    }

                    final double spacing = 16;
                    final double buttonSize = (constraints.maxWidth / 2) - (spacing * 1.5);

                    return SingleChildScrollView(
                      padding: EdgeInsets.all(spacing),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildColumnaSabores(
                              titulo: 'Vainilla',
                              color: const Color.fromARGB(255, 255, 250, 230), 
                              productos: vainilla,
                              buttonSize: buttonSize,
                            ),
                          ),
                          SizedBox(width: spacing),
                          Expanded(
                            child: _buildColumnaSabores(
                              titulo: 'Chocolate',
                              color: const Color.fromARGB(255, 240, 230, 230),
                              productos: chocolate,
                              buttonSize: buttonSize,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildColumnaSabores({
  required String titulo,
  required Color color,
  required List<Map<String, dynamic>> productos,
  required double buttonSize,
}) {
  // 1. OBTENER EL ANCHO DE LA PANTALLA
  // Asumiendo que esta función está dentro de un State y tiene acceso a 'context'
  double anchoPantalla = MediaQuery.of(context).size.width;

  // 2. DEFINIR LAS COLUMNAS BASADO EN EL ANCHO
  // Menos de 600px suele ser un teléfono.
  // 👉 Cambia el '2' por un '1' si de verdad quieres una sola columna.
  int numeroColumnas = anchoPantalla < 600 ? 1 : 3;

  // 3. (OPCIONAL) AJUSTAR LA PROPORCIÓN SI USAS 1 COLUMNA
  // Si usas 1 columna, hazla rectangular (ej. 3.0) para que no sea un cuadrado gigante.
  // Si usas 2 o 3 columnas, mantenlo en 1.0 (cuadrado perfecto).
  double proporcion = (numeroColumnas == 1) ? 1.0 : 1.0;

  return Column(
    children: [
      Text(titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      
      if (productos.isEmpty)
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text('No hay productos', style: TextStyle(color: Colors.grey)),
        ),
        
      // Usamos GridView en lugar de mapear directamente en la Column
      if (productos.isNotEmpty)
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: numeroColumnas, 
          crossAxisSpacing: 10,
          mainAxisSpacing: 10, // Igualamos al horizontal para simetría
          childAspectRatio: proporcion, // 👈 1.0 GARANTIZA UN CUADRADO PERFECTO
          children: productos.asMap().entries.map((entry) {
            final int index = entry.key;
            final Map<String, dynamic> r = entry.value;
            final nombre = _nombre(r);
            final stock = _stock(r);
            final url = _iconUrl(r);
            final assetFallback = 'assets/pasteles/${_slug(nombre)}.png';

            return Column(
              children: [
                // 👈 USAMOS EXPANDED PARA QUE EL BOTÓN SEA DINÁMICO
                Expanded(
                  child: SizedBox(
                    width: double.infinity, // Fuerza al botón a usar todo el ancho de la columna
                    child: OutlinedButton(
                      onPressed: stock != 0 
                        ? () => _onTapProducto(context, r) 
                        : () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Producto agotado')),
                          ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: stock != 0 ? color : Colors.grey,
                        side: const BorderSide(color: Colors.black, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.zero,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: (url != null && url.isNotEmpty)
                            ? Image.network(
                                url,
                                fit: BoxFit.contain, // Esto asegura que la imagen no se deforme
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.image_not_supported, size: 50),
                              )
                            : Image.asset(
                                assetFallback,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.image_not_supported, size: 50),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6), // Pequeño espacio
                // El texto toma su espacio natural al fondo del cuadrado
                Text(
                  nombre,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ).animate()
             .fade(duration: 400.ms, delay: (50 * index).ms)
             .slideY(begin: 0.1, duration: 400.ms, delay: (50 * index).ms)
             .scaleXY(begin: 0.95, end: 1.0, duration: 400.ms, delay: (50 * index).ms);
          }).toList(),
        ),
    ],
  );
}

  // ---------- Taps + reglas especiales ----------
  void _onTapProducto(BuildContext context, Map<String, dynamic> r) async {
    final nombre = _nombre(r);
    final url = _iconUrl(r) ?? '';
    final idproducto = r['id_producto'];

    // Obtenemos las variantes directamente de la función
    final variantes = await _cargarVariantes(idproducto);

    if (context.mounted) { // Buena práctica: verificar si el widget sigue vivo
      _mostrarDialogo(context, nombre, url, variantes);
    }
  }

  // ---------- Diálogo ----------
  void _mostrarDialogo(
    BuildContext context,
    String nombreDelGrupo,
    String imagen,
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
                      _agregarAlCarrito(context, variante, '$nombreDelGrupo - $tamano', imagen, precio);
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
  void _agregarAlCarrito(BuildContext context, Map<String, dynamic> variante, String nombre, String imgUrl, double precio) {
    final assetFallback = 'assets/pasteles/${_slug(nombre)}.png';
    
    // Obtenemos seguros los IDs por si vienen como int o double o String
    int? idProd = int.tryParse(variante['id_producto']?.toString() ?? '');
    int? idVar = int.tryParse(variante['id_variante']?.toString() ?? '');

    Provider.of<CarritoProvider>(context, listen: false).agregarProducto(
      producto.Producto(
        nombre: nombre,
        imagen: (imgUrl != null && imgUrl.isNotEmpty) ? imgUrl : assetFallback,
        precio: precio,
        idProducto: idProd,
        idVariante: idVar,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$nombre agregado')),
    );
  }

  // ---------- Utils ----------
  static String _slug(String s) {
    s = s.trim().toLowerCase();
    const from = 'áéíóúüñ';
    const to   = 'aeiouun';
    for (int i = 0; i < from.length; i++) {
      s = s.replaceAll(from[i], to[i]);
    }
    return s.replaceAll(' ', '_');
  }
}