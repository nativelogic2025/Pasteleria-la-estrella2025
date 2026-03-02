import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'agregar_producto.dart';

final supabase = Supabase.instance.client;

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen>
    with TickerProviderStateMixin {

  List<Map<String, dynamic>> _productos = [];
  Map<String, List<Map<String, dynamic>>> _productosAgrupados = {};
  bool _cargando = true;

  final Map<String, TextEditingController> _stockCtrls = {};
  final Map<String, int> _stockOriginal = {};
  bool _hayCambios = false;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  @override
  void dispose() {
    for (var c in _stockCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }
  // --------------------- BD --------------------------
  Future<void> _cargarProductos() async {
    setState(() => _cargando = true);

    for (var c in _stockCtrls.values) {
      c.dispose();
    }
    _stockCtrls.clear();
    _stockOriginal.clear();
    _hayCambios = false;

    try {
      final response = await supabase
          .from('productos')
          .select('''
            *,
            producto_variantes (*)
          ''')
          .order('nombre');

      _productos = List<Map<String, dynamic>>.from(response);

      _agruparProductos();

      setState(() => _cargando = false);
    } catch (e) {
      setState(() => _cargando = false);
      _mostrarError('Error al cargar productos: $e');
    }
  }

  void _agruparProductos() {
    final Map<String, List<Map<String, dynamic>>> agrupado = {};

    for (final producto in _productos) {
      final idProducto = producto['id_producto'].toString();
      final variantes = List<Map<String, dynamic>>.from(
        producto['producto_variantes'] ?? [],
      );

      for (final variante in variantes) {
        final stock = (variante['stock'] as num?)?.toInt() ?? 0;
        final idVariante = variante['id_variante'].toString();

        _stockOriginal[idVariante] = stock;
        _stockCtrls[idVariante] =
            TextEditingController(text: stock.toString())
              ..addListener(() {
                final detectado = _detectarCambios();
                if (detectado != _hayCambios) {
                  setState(() => _hayCambios = detectado);
                }
              });
      }

      agrupado[idProducto] = variantes;
    }

    _productosAgrupados = agrupado;
  }

  bool _detectarCambios() {
    for (final entry in _stockCtrls.entries) {
      final original = _stockOriginal[entry.key];
      final actual = int.tryParse(entry.value.text);

      if (original != null && actual != null && original != actual) {
        return true;
      }
    }
    return false;
  }

  Future<void> _guardarCambiosStock() async {
    try {
      final futures = <Future>[];

      for (final entry in _stockCtrls.entries) {
        final idVariante = entry.key;
        final nuevo = int.tryParse(entry.value.text);
        final original = _stockOriginal[idVariante];

        if (nuevo != null && original != null && nuevo != original) {
          futures.add(
            supabase
                .from('producto_variantes')
                .update({'stock': nuevo})
                .eq('id_variante', idVariante),
          );
        }
      }

      await Future.wait(futures);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock actualizado'),
          backgroundColor: Colors.green,
        ),
      );

      _cargarProductos();
    } catch (e) {
      _mostrarError('Error al guardar cambios: $e');
    }
  }

  Future<void> _actualizarPrecio(
      Map<String, dynamic> variante, double nuevo) async {
    try {
      await supabase
          .from('producto_variantes')
          .update({'precio_venta': nuevo})
          .eq('id_variante', variante['id_variante']);

      _cargarProductos();
    } catch (e) {
      _mostrarError('Error al actualizar precio: $e');
    }
  }

  Future<void> _eliminarVariante(Map<String, dynamic> variante) async {
    try {
      await supabase
          .from('producto_variantes')
          .delete()
          .eq('id_variante', variante['id_variante']);

      _cargarProductos();
    } catch (e) {
      _mostrarError('Error al eliminar: $e');
    }
  }

  Future<void> _eliminarProducto(String idProducto, String? imagenUrl) async {
    try {

      // 1. ELIMINAR EL ARCHIVO DEL STORAGE (Si existe)
      if (imagenUrl != null && imagenUrl.isNotEmpty) {
        // Extraemos solo el nombre del archivo de la URL o usamos el path guardado
        // Si guardaste el nombre directo: 'pastel_chocolate.png'
        await supabase.storage
            .from('productos') // Nombre de tu bucket
            .remove([imagenUrl]); 
      }

      // 2. ELIMINAR EL REGISTRO DE LA BASE DE DATOS
      // Si configuraste ON DELETE CASCADE, esto borrará las variantes automáticamente
      await supabase
          .from('productos')
          .delete()
          .eq('id_producto', idProducto);

      // 3. ACTUALIZAR INTERFAZ
      _cargarProductos();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto e imagen eliminados con éxito'))
        );
      }
    } catch (e) {
      _mostrarError('Error al eliminar producto o imagen: $e');
    }
  }
  // ---------------------- FIN BD -------------------------

  // --------------------- FUNCIONES --------------------------
  Future<void> _confirmarEliminacion(BuildContext context, String idProducto) async {
    // Extraemos los datos necesarios del mapa de Supabase
    final String nombre = _nombreProducto(idProducto);
    final String? urlImagen = _imagen(idProducto);

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('¿Eliminar producto?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (urlImagen != null && urlImagen.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    urlImagen,
                    height: 120,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child; // Imagen cargada
                      return const Center(child: CircularProgressIndicator()); // Cargando...
                    },
                    errorBuilder: (context, error, stackTrace) => 
                        const Icon(Icons.broken_image, size: 50),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text('Estás a punto de eliminar "$nombre" y todos sus datos asociados, incluyendo su imagen en el servidor.'),
              const SizedBox(height: 8),
              const Text(
                'Esta acción es irreversible.',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('ELIMINAR DEFINITIVAMENTE'),
            ),
          ],
        );
      },
    );

    // Si el usuario confirmó, ejecutamos la lógica de borrado en Supabase
    if (confirmar == true) {
      await _eliminarProducto(idProducto, urlImagen);
    }
  }

  // Función para obtener la URL pública de la imagen desde Supabase Storage
  String? _iconUrl(Map<String, dynamic> r) {
    final file = r['imagen_url']; // En Repostería, 'icon' está en el primer nivel
    if (file == null || file.toString().isEmpty) return null;

    return supabase.storage
        .from('productos') 
        .getPublicUrl(file.toString());
  }
  
  String _imagen(String idProducto) {
    final producto = _productos
        .firstWhere((p) => p['id_producto'].toString() == idProducto);

    if (producto['imagen_url'] == null || producto['imagen_url'].toString().isEmpty) return 'Sin imagen';

    return supabase.storage
        .from('productos') 
        .getPublicUrl(producto['imagen_url'].toString());
  }
  // ---------------------- FIN FUNCIONES --------------------------

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  double _precio(Map<String, dynamic> v) {
    return (v['precio_venta'] as num?)?.toDouble() ?? 0.0;
  }

  String _nombreProducto(String idProducto) {
    final producto = _productos
        .firstWhere((p) => p['id_producto'].toString() == idProducto);
    return producto['nombre'] ?? 'Sin nombre';
  }

  

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        actions: [
          IconButton(
            tooltip: 'Añadir nuevo producto',
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AgregarProductoScreen(),
                ),
              ).then((_) => _cargarProductos());
            },
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: _productosAgrupados.entries.map((entry) {
          final idProducto = entry.key;
          final variantes = entry.value;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ExpansionTile(
              title: Text(
                _nombreProducto(idProducto),
                style: const TextStyle(fontWeight: FontWeight.bold),
                
              ),

              trailing:
              Row(
                mainAxisSize: MainAxisSize.min, // Vital para que no ocupe todo el ancho
                children: [
                  IconButton(
                    tooltip: 'Eliminar producto y sus variantes',
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmarEliminacion(context, idProducto),
                  ),
                  IconButton(
                    tooltip: 'Editar producto general',
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      // Aquí tu acción
                      print("Editar producto $idProducto");
                    },
                  ),
                  IconButton(
                    tooltip: 'Agregar nueva variante',
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      // Aquí tu acción
                      print("Agregar variante a $idProducto");
                    },
                  ),
                ],
              ),

              children: variantes.isEmpty
                  ? [
                      const ListTile(
                        title: Text('Sin variantes'),
                      )
                    ]
                  : [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Tamaño')),
                            DataColumn(label: Text('Stock')),
                            DataColumn(label: Text('Precio')),
                            DataColumn(label: Text('Eliminar')),
                          ],
                          rows: variantes.map((v) {
                            final idVariante =
                                v['id_variante'].toString();
                            final precio = _precio(v);

                            return DataRow(cells: [
                              DataCell(Text(v['tamaño'] ?? '-')),
                              DataCell(
                                SizedBox(
                                  width: 60,
                                  child: TextField(
                                    controller:
                                        _stockCtrls[idVariante],
                                    keyboardType:
                                        TextInputType.number,
                                    decoration:
                                        const InputDecoration(
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Row(
                                children: [
                                  Text(
                                      '\$${precio.toStringAsFixed(2)}'),
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        size: 18),
                                    onPressed: () async {
                                      final controller =
                                          TextEditingController(
                                              text: precio
                                                  .toStringAsFixed(2));

                                      final nuevo =
                                          await showDialog<double>(
                                        context: context,
                                        builder: (_) =>
                                            AlertDialog(
                                          title: const Text(
                                              'Actualizar precio'),
                                          content: TextField(
                                            controller: controller,
                                            keyboardType:
                                                const TextInputType
                                                    .numberWithOptions(
                                                    decimal: true),
                                          ),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(
                                                        context),
                                                child: const Text(
                                                    'Cancelar')),
                                            FilledButton(
                                              onPressed: () {
                                                final v =
                                                    double.tryParse(
                                                        controller
                                                            .text);
                                                if (v != null) {
                                                  Navigator.pop(
                                                      context, v);
                                                }
                                              },
                                              child:
                                                  const Text('Guardar'),
                                            )
                                          ],
                                        ),
                                      );

                                      if (nuevo != null) {
                                        _actualizarPrecio(
                                            v, nuevo);
                                      }
                                    },
                                  )
                                ],
                              )),
                              DataCell(IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.red),
                                onPressed: () =>
                                    _eliminarVariante(v),
                              )),
                            ]);
                          }).toList(),
                        ),
                      )
                    ],
            ),
          );
        }).toList(),
      ),
      floatingActionButton: _hayCambios
          ? FloatingActionButton.extended(
              onPressed: _guardarCambiosStock,
              icon: const Icon(Icons.save),
              label: const Text('Guardar cambios'),
            )
          : null,
    );
  }
}