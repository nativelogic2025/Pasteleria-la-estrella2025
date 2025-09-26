import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocketbase/pocketbase.dart';

import 'carrito_provider.dart';
import 'carrito.dart';
import 'producto.dart' as producto;

class VentasPasteles extends StatefulWidget {
  const VentasPasteles({super.key});

  @override
  State<VentasPasteles> createState() => _VentasPastelesState();
}

class _VentasPastelesState extends State<VentasPasteles> {
  // 🔧 Ajusta a tu servidor PB (10.0.2.2 para Android emulador si PB corre en tu PC)
  final pb = PocketBase('http://127.0.0.1:8090');

  List<RecordModel> _items = [];
  bool _loading = true;
  UnsubscribeFunc? _unsub;

  @override
  void initState() {
    super.initState();
    _cargar();
    _suscribirRealtime();
  }

  Future<void> _suscribirRealtime() async {
    try {
      final fn = await pb.collection('productos').subscribe('*', (e) {
        if (!mounted) return;
        _cargar();
      });
      _unsub = fn;
    } catch (e) {
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

  // ---------- Helpers lectura ----------
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
            filter: 'Categoria = "Pasteles"', // 👈 colección/flag de pasteles
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
        SnackBar(content: Text('Error al cargar Pasteles: $e')),
      );
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Pasteles'),
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
                final todosConStock = _items.where((r) => _stock(r) > 0).toList();

                // División automática por nombre:
                final chocolate = todosConStock.where((r) {
                  final n = _nombre(r).trim();
                  return n.toLowerCase().startsWith('choco');
                }).toList();

                final vainilla = todosConStock.where((r) {
                  final n = _nombre(r).trim();
                  return !n.toLowerCase().startsWith('choco');
                }).toList();

                if (todosConStock.isEmpty) {
                  return const Center(
                    child: Text('No hay pasteles disponibles', style: TextStyle(fontSize: 16)),
                  );
                }

                // Tamaño de botones (similar a tu estilo)
                const double spacing = 20;
                final int columnas = constraints.maxWidth > 700 ? 3 : 2;
                final double buttonSize =
                    (constraints.maxWidth / 2 - (spacing * (columnas + 1)) / 2);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ------------ Columna Vainilla ------------
                      Expanded(
                        child: _buildColumnaSabores(
                          titulo: 'Vainilla',
                          color: const Color.fromARGB(255, 237, 233, 175),
                          productos: vainilla,
                          buttonSize: buttonSize,
                          columnas: columnas,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // ------------ Columna Chocolate ------------
                      Expanded(
                        child: _buildColumnaSabores(
                          titulo: 'Chocolate',
                          color: const Color.fromARGB(255, 192, 130, 130),
                          productos: chocolate,
                          buttonSize: buttonSize,
                          columnas: columnas,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildColumnaSabores({
    required String titulo,
    required Color color,
    required List<RecordModel> productos,
    required double buttonSize,
    required int columnas,
  }) {
    return Column(
      children: [
        Text(titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 20,
          runSpacing: 20,
          children: productos.map((r) {
            final nombre = _nombre(r);
            final precio = _precio(r) <= 0 ? 50.0 : _precio(r); // default 50 si no hay precio
            final stock = _stock(r);
            final url = _iconUrl(r);
            final assetFallback = 'assets/pasteles/${_slug(nombre)}.png';

            return SizedBox(
              width: buttonSize,
              child: Column(
                children: [
                  SizedBox(
                    width: buttonSize,
                    height: buttonSize,
                    child: OutlinedButton(
                      onPressed: () => _agregarAlCarrito(context, r, nombre, precio),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: color,
                        side: const BorderSide(color: Colors.black, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.zero,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: (url != null && url.isNotEmpty)
                            ? Image.network(
                                url,
                                fit: BoxFit.contain,
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
                  const SizedBox(height: 8),
                  Text(
                    nombre,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
      ],
    );
  }

  // ---------- Agregar al carrito ----------
  void _agregarAlCarrito(BuildContext context, RecordModel r, String nombre, double precio) {
    final imgUrl = _iconUrl(r);
    final assetFallback = 'assets/pasteles/${_slug(nombre)}.png';

    Provider.of<CarritoProvider>(context, listen: false).agregarProducto(
      producto.Producto(
        nombre: nombre,
        imagen: (imgUrl != null && imgUrl.isNotEmpty) ? imgUrl : assetFallback,
        precio: precio,
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
