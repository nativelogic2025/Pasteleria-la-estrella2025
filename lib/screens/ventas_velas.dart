import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'carrito_provider.dart';
import 'carrito.dart';
import 'producto.dart' as producto_model;
import '../product_notifier.dart';
import 'pb_client.dart';

class VentasVelas extends StatefulWidget {
  const VentasVelas({super.key});

  @override
  State<VentasVelas> createState() => _VentasVelasState();
}

class _VentasVelasState extends State<VentasVelas> {
  List<RecordModel> _items = [];
  bool _loading = true;

  // 👇 FIX: guardamos la ref al notifier para no leer Inheriteds en dispose()
  late final ProductNotifier _notifier;
  bool _listenerAttached = false;

  @override
  void initState() {
    super.initState();
    _cargar();
    // ✅ Puedes usar read() en initState sin suscribirte al árbol
    // (alternativa: hacerlo en didChangeDependencies una sola vez)
    // ignore: use_build_context_synchronously
    _notifier = context.read<ProductNotifier>();
    _notifier.addListener(_onProductsChanged);
    _listenerAttached = true;
  }

  // (Opcional) Si prefieres absoluto safety, mueve el attach aquí:
  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  //   if (!_listenerAttached) {
  //     _notifier = context.read<ProductNotifier>();
  //     _notifier.addListener(_onProductsChanged);
  //     _listenerAttached = true;
  //   }
  // }

  void _onProductsChanged() {
    if (mounted) {
      _cargar();
    }
  }

  @override
  void dispose() {
    // ❌ NO uses Provider.of/read aquí
    if (_listenerAttached) {
      _notifier.removeListener(_onProductsChanged);
    }
    super.dispose();
  }

  // ---------- Lectura de campos ----------
  RecordModel? _getProductoRecord(RecordModel r) {
    if (r.expand.containsKey('id_producto') && r.expand['id_producto']!.isNotEmpty) {
      return r.expand['id_producto']!.first;
    }
    return null;
  }

  String _nombreBase(RecordModel r) {
    final productoBase = _getProductoRecord(r);
    return productoBase?.data['nombre']?.toString() ?? 'Producto';
  }

  double _precio(RecordModel r) {
    final v = r.data['precio_final'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '0') ?? 0.0;
  }

  int _stock(RecordModel r) {
    final v = r.data['cantidadStock'];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }

  String? _iconUrl(RecordModel r, {String size = '300x300'}) {
    final productoBase = _getProductoRecord(r);
    if (productoBase == null) return null;

    final file = productoBase.data['icon'];
    if (file == null || file.toString().isEmpty) return null;
    return pb.files.getUrl(productoBase, file.toString(), thumb: size).toString();
  }

  // ---------- Data (PB) ----------
  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final categoriaRecord =
          await pb.collection('categoria').getFirstListItem('nombre = "Velas"');
      final categoriaVelasId = categoriaRecord.id;

      final res = await pb.collection('productoVariante').getList(
        perPage: 500,
        filter: 'id_producto.id_categoria = "$categoriaVelasId"',
        sort: 'sku',
        expand: 'id_producto',
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
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CarritoScreen()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final Map<String, List<RecordModel>> itemsAgrupados = {};
                for (final item in _items) {
                  if (_stock(item) > 0) {
                    final productoBase = _getProductoRecord(item);
                    if (productoBase != null) {
                      itemsAgrupados.putIfAbsent(productoBase.id, () => []).add(item);
                    }
                  }
                }

                final gruposVisibles = itemsAgrupados.values.toList();

                if (gruposVisibles.isEmpty) {
                  return const Center(
                    child: Text('No hay productos disponibles en Velas',
                        style: TextStyle(fontSize: 16)),
                  );
                }

                const double spacing = 20;
                final int columnas = constraints.maxWidth > 600 ? 5 : 3;
                final double buttonSize =
                    (constraints.maxWidth - (spacing * (columnas + 1))) / columnas;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    alignment: WrapAlignment.center,
                    children: gruposVisibles.map((grupo) {
                      final primerItem = grupo.first;
                      final nombreDelGrupo = _nombreBase(primerItem);
                      final precio =
                          _precio(primerItem) <= 0 ? 50.0 : _precio(primerItem);
                      final url = _iconUrl(primerItem);
                      const assetFallback = 'assets/generic_icon.png';

                      return SizedBox(
                        width: buttonSize,
                        child: Column(
                          children: [
                            SizedBox(
                              width: buttonSize,
                              height: buttonSize,
                              child: OutlinedButton(
                                onPressed: () => _mostrarDialogoNumeros(
                                    context, nombreDelGrupo, grupo),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor:
                                      const Color.fromARGB(255, 245, 225, 184),
                                  side: const BorderSide(
                                      color: Colors.black, width: 2),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  padding: EdgeInsets.zero,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: (url != null && url.isNotEmpty)
                                      ? Image.network(
                                          url,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              Image.asset(assetFallback,
                                                  fit: BoxFit.contain),
                                        )
                                      : Image.asset(
                                          assetFallback,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.image_not_supported,
                                                  size: 40),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              nombreDelGrupo,
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

  // ---------- Diálogo ----------
  void _mostrarDialogoNumeros(
    BuildContext context,
    String nombreDelGrupo,
    List<RecordModel> variantesDisponibles,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogCtx) {
        return AlertDialog(
          title: Text(nombreDelGrupo),
          content: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: variantesDisponibles.map((variante) {
              final sku = variante.data['sku']?.toString() ?? '';
              final numero = _extraerNumeroDeSku(sku) ?? sku;
              final precio = _precio(variante);
              final nombreCompleto = '$nombreDelGrupo $numero';

              return ElevatedButton(
                onPressed: () {
                  _agregarAlCarrito(context, variante, nombreCompleto, precio);
                  Navigator.pop(dialogCtx);
                },
                child: Text("$numero"),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ---------- Agregar al carrito ----------
  void _agregarAlCarrito(
      BuildContext context, RecordModel r, String nombreMostrar, double precio) {
    final imgUrl = _iconUrl(r);
    const assetFallback = 'assets/generic_icon.png';

    context.read<CarritoProvider>().agregarProducto(
          producto_model.Producto(
            nombre: nombreMostrar,
            imagen: (imgUrl != null && imgUrl.isNotEmpty) ? imgUrl : assetFallback,
            precio: precio,
          ),
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$nombreMostrar agregado')),
    );
  }

  // ---------- Helper SKU ----------
  int? _extraerNumeroDeSku(String sku) {
    final match = RegExp(r'(\d+)$').firstMatch(sku);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '');
    }
    return null;
  }
}
