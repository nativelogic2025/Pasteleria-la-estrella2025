import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocketbase/pocketbase.dart';

import 'carrito_provider.dart';
import 'carrito.dart';
import 'producto.dart' as producto;

class VentasExtras extends StatefulWidget {
  const VentasExtras({super.key});

 @override
  State<VentasExtras> createState() => _VentasExtrasState();
}

  class _VentasExtrasState extends State<VentasExtras> {
  final pb = PocketBase('http://127.0.0.1:8090'); // 🔧 tu servidor PB

  List<RecordModel> _items = [];
  bool _loading = true;
  UnsubscribeFunc? _unsub;

  @override
  void initState() {
    super.initState();
    _cargar();
    _suscribirRealtime(); // 👈 sin warnings
  }

  Future<void> _suscribirRealtime() async {
    try {
      final fn = await pb.collection('productos').subscribe('*', (e) {
        if (!mounted) return;
        _cargar();
      });
      _unsub = fn;
    } catch (e) {
      // No pasa nada si falla la suscripción; solo registramos el error.
      debugPrint('No se pudo suscribir a realtime: $e');
      _unsub = null;
    }
  }

  @override
  void dispose() {
    try {
      _unsub?.call();
    } catch (_) {}
    _unsub = null;
    super.dispose();
  }

  // ---------- Lectura de campos ----------
  String _nombre(RecordModel r) =>
      (r.data['Nombre'] ?? r.data['producto'] ?? '').toString();

  double _precio(RecordModel r) {
    final v = r.data['precio'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '0') ?? 0.0;
    }

  int _stock(RecordModel r) {
    final v = r.data['cantidad'];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }

  String? _iconUrl(RecordModel r, {String size = '300x300'}) {
    final file = r.data['icon'];
    if (file == null || file.toString().isEmpty) return null;
    return pb.files.getUrl(r, file.toString(), thumb: size).toString();
  }

  // ---------- Data (PB) ----------
  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final res = await pb.collection('productos').getList(
            perPage: 200,
            filter: 'Categoria = "Extras"',
            sort: 'Nombre',
          );
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar Extras: $e')),
      );
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Extras'),
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
                // Solo mostrables: stock > 0
                final visibles = _items.where((r) => _stock(r) > 0).toList();

                if (visibles.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay productos disponibles en Extras',
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                // === Cálculo "como tu VentasPostres" ===
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
                      final precio = _precio(r) <= 0 ? 50.0 : _precio(r);
                      final stock = _stock(r);
                      final url = _iconUrl(r);
                      final assetFallback =
                          'assets/reposteria/${_slug(nombre)}.png';

                      return SizedBox(
                        width: buttonSize,
                        child: Column(
                          children: [
                            SizedBox(
                              width: buttonSize,
                              height: buttonSize,
                              child: OutlinedButton(
                                onPressed: () => _onTapProducto(context, r),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(
                                      255, 245, 225, 184),
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
                            Text(
                              'Stock: $stock   ·   \$${precio.toStringAsFixed(2)}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11),
                            ),
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
  void _onTapProducto(BuildContext context, RecordModel r) {
    final nombre = _nombre(r);
    final precio = _precio(r) <= 0 ? 50.0 : _precio(r);

    _agregarAlCarrito(context, r, nombre, precio);
  }

  // ---------- Agregar al carrito ----------
  void _agregarAlCarrito(
      BuildContext context, RecordModel r, String nombreMostrar, double precio) {
    final imgUrl = _iconUrl(r);
    final nombreBase = _nombre(r);
    final assetFallback = 'assets/reposteria/${_slug(nombreBase)}.png';

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
  static String _formatearNombre(String nombre) {
    return nombre
        .toLowerCase()
        .replaceAll(" ", "_")
        .replaceAll("á", "a")
        .replaceAll("é", "e")
        .replaceAll("í", "i")
        .replaceAll("ó", "o")
        .replaceAll("ú", "u")
        .replaceAll("ñ", "n");
  }

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
