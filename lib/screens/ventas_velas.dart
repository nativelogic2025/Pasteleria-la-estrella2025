import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocketbase/pocketbase.dart';

import 'carrito_provider.dart';
import 'carrito.dart';
import 'producto.dart' as producto;

class VentasVelas extends StatefulWidget {
  const VentasVelas({super.key});

 @override
  State<VentasVelas> createState() => _VentasVelasState();
}

class _VentasVelasState extends State<VentasVelas> {
  final pb = PocketBase('http://127.0.0.1:8090'); // 🔧 tu servidor PB

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
        filter: 'Categoria = "Velas"',
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
        SnackBar(content: Text('Error al cargar Velas: $e')),
      );
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
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
                // --- INICIO DE LA LÓGICA DE AGRUPAMIENTO ---
                final Map<String, RecordModel> itemsAgrupados = {};

                for (final item in _items) {
                  // Solo consideramos agrupar si el item tiene stock
                  if (_stock(item) > 0) {
                    final nombreBase = _obtenerNombreBase(_nombre(item));
                    // Si el grupo aún no ha sido agregado, lo añadimos.
                    // Usamos el primer item que encontramos como "representante" del grupo.
                    if (!itemsAgrupados.containsKey(nombreBase)) {
                      itemsAgrupados[nombreBase] = item;
                    }
                  }
                }
                
                final visibles = itemsAgrupados.values.toList();
                // --- FIN DE LA LÓGICA DE AGRUPAMIENTO ---

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
                      // Usamos el nombre base para el slug de la imagen de respaldo
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
                              // Mostramos el nombre base en la UI
                              nombreBase,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              // Ya no mostramos el stock aquí, es irrelevante
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

  // --- FUNCIÓN MODIFICADA ---
  void _mostrarDialogoNumeros(BuildContext context, RecordModel r) {
    final velaBase = _obtenerNombreBase(_nombre(r));
    final precio = _precio(r) <= 0 ? 50.0 : _precio(r);

    // 1. Encontrar todos los números disponibles para este grupo de velas
    final List<int> numerosDisponibles = [];
    for (final item in _items) {
      if (_obtenerNombreBase(_nombre(item)) == velaBase && _stock(item) > 0) {
        final numero = _extraerNumero(_nombre(item));
        if (numero != null) {
          numerosDisponibles.add(numero);
        }
      }
    }
    numerosDisponibles.sort(); // Opcional: para que los números aparezcan en orden

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
  
  // NUEVA FUNCIÓN para extraer el número de un nombre
  int? _extraerNumero(String nombreCompleto) {
    final match = RegExp(r'No\.\s*(\d+)').firstMatch(nombreCompleto);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '');
    }
    return null;
  }

  static String _slug(String s) {
    s = s.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'no\.\s*'), ''); // Quitar "no. " para el slug
    const from = 'áéíóúüñ';
    const to =   'aeiouun';
    for (int i = 0; i < from.length; i++) {
      s = s.replaceAll(from[i], to[i]);
    }
    return s.replaceAll(' ', '_');
  }
}