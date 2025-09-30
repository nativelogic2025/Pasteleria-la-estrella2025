import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'pb_client.dart';

// ✨ 1. IMPORTA el nuevo notificador
import '../product_notifier.dart';

import 'carrito_provider.dart';
import 'carrito.dart';
import 'producto.dart' as producto;

class VentasReposteria extends StatefulWidget {
  const VentasReposteria({super.key});

  @override
  State<VentasReposteria> createState() => _VentasReposteriaState();
}

class _VentasReposteriaState extends State<VentasReposteria> {
  List<RecordModel> _items = [];
  bool _loading = true;
  // ✨ 2. ELIMINA la variable _unsub
  // UnsubscribeFunc? _unsub;

  @override
  void initState() {
    super.initState();
    _cargar();
    
    // ✨ 3. REEMPLAZA la suscripción con un listener al notificador
    Provider.of<ProductNotifier>(context, listen: false)
        .addListener(_onProductsChanged);
  }

  // ✨ 4. ELIMINA la función _suscribirRealtime() por completo
  /*
  Future<void> _suscribirRealtime() async {
    // ... TODO ESTO SE VA ...
  }
  */

  // ✨ 5. AÑADE esta función que será llamada por el notificador
  void _onProductsChanged() {
    print(">>> Notificación recibida en VentasReposteria: Recargando productos...");
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
  // (La función _cargar ya estaba correcta, se queda igual)
  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final categoriaRecord = await pb.collection('categorias').getFirstListItem('nombre = "Reposteria"');
      final categoriaReposteriaId = categoriaRecord.id;

      final res = await pb.collection('productos').getList(
            perPage: 200,
            filter: 'Categoria = "$categoriaReposteriaId"',
            sort: 'Nombre',
          );
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar Repostería: $e')),
      );
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Repostería'),
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
                final visibles = _items.where((r) => _stock(r) > 0).toList();

                if (visibles.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay productos disponibles en Repostería',
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

    if (nombre == 'Tiramisú' || nombre == 'Pastel Imposible') {
      _mostrarOpcionesTamanio(context, r, precio);
      return;
    }
    if (nombre == 'Mousse') {
      _mostrarSaboresMousse(context, r, precio);
      return;
    }
    _agregarAlCarrito(context, r, nombre, precio);
  }

  void _mostrarOpcionesTamanio(
      BuildContext context, RecordModel r, double precioBase) {
    final nombre = _nombre(r);
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text('Elige el tamaño de $nombre'),
        children: ['Chico', 'Mediano', 'Grande'].map((tamanio) {
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              if (nombre == 'Pastel Imposible') {
                _mostrarOpcionesTipo(context, r, precioBase, tamanio);
              } else {
                _agregarAlCarrito(context, r, '$nombre $tamanio', precioBase);
              }
            },
            child: Text(tamanio),
          );
        }).toList(),
      ),
    );
  }

  void _mostrarOpcionesTipo(
      BuildContext context, RecordModel r, double precioBase, String tamanio) {
    final nombre = _nombre(r);
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Selecciona tipo'),
        children: ['Normal', 'Café'].map((tipo) {
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              _agregarAlCarrito(context, r, '$nombre $tamanio $tipo', precioBase);
            },
            child: Text(tipo),
          );
        }).toList(),
      ),
    );
  }

  void _mostrarSaboresMousse(
      BuildContext context, RecordModel r, double precioBase) {
    final sabores = ['Zarzamora', 'Fresa', 'Oreo', 'Guayaba', 'PiñaCoco', 'Mango'];
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Elige el sabor del Mousse'),
        children: sabores.map((sabor) {
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              _agregarAlCarrito(context, r, 'Mousse $sabor', precioBase);
            },
            child: Text(sabor),
          );
        }).toList(),
      ),
    );
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