import 'carrito_provider.dart';
import 'carrito.dart';
import 'producto.dart' as producto;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'pb_client.dart';

// ✨ 1. IMPORTA el nuevo notificador
import '../product_notifier.dart';

class VentasVelas extends StatefulWidget {
  const VentasVelas({super.key});

 @override
  State<VentasVelas> createState() => _VentasVelasState();
}

class _VentasVelasState extends State<VentasVelas> {
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
    print(">>> Notificación recibida en VentasVelas: Recargando productos...");
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
      final categoriaRecord = await pb.collection('categorias').getFirstListItem('nombre = "Velas"');
      final categoriaVelasId = categoriaRecord.id;

      final res = await pb.collection('productos').getList(
        perPage: 200,
        filter: 'Categoria = "$categoriaVelasId"',
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
        SnackBar(content: Text('Error al cargar Velas: $e')),
      );
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    // ... (El resto de tu código de UI no necesita cambios)
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Velas'),
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
                final Map<String, RecordModel> itemsAgrupados = {};
                for (final item in _items) {
                  if (_stock(item) > 0) {
                    final nombreBase = _obtenerNombreBase(_nombre(item));
                    if (!itemsAgrupados.containsKey(nombreBase)) {
                      itemsAgrupados[nombreBase] = item;
                    }
                  }
                }
                
                final visibles = itemsAgrupados.values.toList();

                if (visibles.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay productos disponibles en Velas',
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
                      final nombreBase = _obtenerNombreBase(_nombre(r));
                      final precio = _precio(r) <= 0 ? 50.0 : _precio(r);
                      final url = _iconUrl(r);
                      final assetFallback =
                          'assets/velas/${_slug(nombreBase)}.png';

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
                              nombreBase,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '\$${precio.toStringAsFixed(2)}',
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
    
    if (nombre.toLowerCase().contains('no.')) {
      _mostrarDialogoNumeros(context, r);
    } else {
      final precio = _precio(r) <= 0 ? 50.0 : _precio(r);
      _agregarAlCarrito(context, r, nombre, precio);
    }
  }

  void _mostrarDialogoNumeros(BuildContext context, RecordModel r) {
    final velaBase = _obtenerNombreBase(_nombre(r));
    final precio = _precio(r) <= 0 ? 50.0 : _precio(r);

    final List<int> numerosDisponibles = [];
    for (final item in _items) {
      if (_obtenerNombreBase(_nombre(item)) == velaBase && _stock(item) > 0) {
        final numero = _extraerNumero(_nombre(item));
        if (numero != null) {
          numerosDisponibles.add(numero);
        }
      }
    }
    numerosDisponibles.sort();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$velaBase - Selecciona un número'),
          content: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              if (numerosDisponibles.isEmpty)
                const Text('No hay números disponibles en este momento.'),
              
              for (final numero in numerosDisponibles)
                ElevatedButton(
                  onPressed: () {
                    _agregarAlCarrito(context, r, "$velaBase $numero", precio);
                    Navigator.pop(context);
                  },
                  child: Text("$numero"),
                ),
              
              ElevatedButton(
                onPressed: () {
                  _agregarAlCarrito(context, r, "$velaBase ?", precio);
                  Navigator.pop(context);
                },
                child: const Text("?"),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------- Agregar al carrito ----------
  void _agregarAlCarrito(
      BuildContext context, RecordModel r, String nombreMostrar, double precio) {
    final imgUrl = _iconUrl(r);
    final nombreBase = _obtenerNombreBase(_nombre(r));
    final assetFallback = 'assets/velas/${_slug(nombreBase)}.png';

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
  String _obtenerNombreBase(String nombreCompleto) {
    final regex = RegExp(r'No\.\s*\d+\s*');
    return nombreCompleto.replaceAll(regex, 'No. ').trim();
  }
  
  int? _extraerNumero(String nombreCompleto) {
    final match = RegExp(r'No\.\s*(\d+)').firstMatch(nombreCompleto);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '');
    }
    return null;
  }

  static String _slug(String s) {
    s = s.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'no\.\s*'), '');
    const from = 'áéíóúüñ';
    const to =   'aeiouun';
    for (int i = 0; i < from.length; i++) {
      s = s.replaceAll(from[i], to[i]);
    }
    return s.replaceAll(' ', '_');
  }
}