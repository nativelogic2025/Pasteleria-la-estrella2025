import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class VarianteEditable {
  String? id;
  bool isNew;

  final TextEditingController skuController;
  final TextEditingController stockController;
  final TextEditingController precioController;

  VarianteEditable({
    this.id,
    this.isNew = false,
    required String sku,
    required int stock,
    required double precio,
  })  : skuController = TextEditingController(text: sku),
        stockController = TextEditingController(text: stock.toString()),
        precioController =
            TextEditingController(text: precio.toStringAsFixed(2));

  void dispose() {
    skuController.dispose();
    stockController.dispose();
    precioController.dispose();
  }
}

class DetalleProductoGeneralScreen extends StatefulWidget {
  final Map<String, dynamic> producto;
  const DetalleProductoGeneralScreen({super.key, required this.producto});

  @override
  State<DetalleProductoGeneralScreen> createState() =>
      _DetalleProductoGeneralScreenState();
}

class _DetalleProductoGeneralScreenState
    extends State<DetalleProductoGeneralScreen> {

  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nombreController;
  String? _categoriaSeleccionadaId;

  Uint8List? _nuevaIconBytes;
  bool _eliminarIconoActual = false;

  List<Map<String, dynamic>> _categoriasDisponibles = [];
  final List<VarianteEditable> _variantes = [];
  final List<String> _variantesAEliminar = [];

  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombreController =
        TextEditingController(text: widget.producto['nombre']);
    _categoriaSeleccionadaId =
        widget.producto['id_categoria']?.toString();
    _cargarDatos();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    for (var v in _variantes) {
      v.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      _categoriasDisponibles =
          await supabase.from('categoria').select('*').order('nombre');

      final variantesRecords = await supabase
          .from('productoVariante')
          .select('*')
          .eq('id_producto', widget.producto['id'])
          .order('created_at');

      for (final v in variantesRecords) {
        _variantes.add(
          VarianteEditable(
            id: v['id'].toString(),
            sku: v['sku'] ?? '',
            stock: (v['cantidadStock'] as num?)?.toInt() ?? 0,
            precio: (v['precio_final'] as num?)?.toDouble() ?? 0.0,
          ),
        );
      }
    } catch (e) {
      _mostrarError('Error al cargar datos: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      String? iconPath = widget.producto['icon'];

      if (_eliminarIconoActual) {
        iconPath = null;
      } else if (_nuevaIconBytes != null) {
        iconPath =
            'icon_${DateTime.now().millisecondsSinceEpoch}.png';
        await supabase.storage.from('productos').uploadBinary(
              iconPath,
              _nuevaIconBytes!,
              fileOptions: const FileOptions(
                contentType: 'image/png',
                upsert: true,
              ),
            );
      }

      await supabase.from('producto').update({
        'nombre': _nombreController.text.trim(),
        'id_categoria': _categoriaSeleccionadaId,
        'icon': iconPath,
      }).eq('id', widget.producto['id']);

      for (final variante in _variantes) {
        final data = {
          'id_producto': widget.producto['id'],
          'sku': variante.skuController.text.trim(),
          'cantidadStock':
              int.tryParse(variante.stockController.text) ?? 0,
          'precio_final': double.tryParse(
                  variante.precioController.text.replaceAll(',', '.')) ??
              0.0,
        };

        if (variante.isNew) {
          await supabase.from('productoVariante').insert(data);
        } else {
          await supabase
              .from('productoVariante')
              .update(data)
              .eq('id', variante.id!);
        }
      }

      for (final id in _variantesAEliminar) {
        await supabase
            .from('productoVariante')
            .delete()
            .eq('id', id);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _mostrarError('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminarProductoCompleto() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar producto?'),
        content: const Text(
            'Se eliminarán todas las variantes permanentemente.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.red),
              child: const Text('Eliminar')),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _guardando = true);

    try {
      await supabase
          .from('productoVariante')
          .delete()
          .eq('id_producto', widget.producto['id']);

      await supabase
          .from('producto')
          .delete()
          .eq('id', widget.producto['id']);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _mostrarError('Error al eliminar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _agregarNuevaVariante() {
    setState(() {
      _variantes.add(
        VarianteEditable(
          sku: _nombreController.text.trim(),
          stock: 0,
          precio: 0.0,
          isNew: true,
        ),
      );
    });
  }

  void _eliminarVariante(int index) {
    final v = _variantes[index];
    if (!v.isNew && v.id != null) {
      _variantesAEliminar.add(v.id!);
    }
    setState(() {
      v.dispose();
      _variantes.removeAt(index);
    });
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    String? iconUrl = widget.producto['icon'];
    if (iconUrl != null && iconUrl.isNotEmpty) {
      iconUrl =
          supabase.storage.from('productos').getPublicUrl(iconUrl);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edición de Producto'),
        actions: [
          IconButton(
              icon: const Icon(Icons.delete_forever,
                  color: Colors.red),
              onPressed:
                  _guardando ? null : _eliminarProductoCompleto),
          IconButton(
              icon: const Icon(Icons.save),
              onPressed:
                  _guardando ? null : _guardarCambios),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          if (_nuevaIconBytes != null)
                            Image.memory(_nuevaIconBytes!,
                                height: 120)
                          else if (!_eliminarIconoActual &&
                              iconUrl != null)
                            Image.network(iconUrl,
                                height: 120)
                          else
                            const Icon(Icons.image, size: 80),
                          TextButton(
                              onPressed: () async {
                                final res =
                                    await FilePicker.platform
                                        .pickFiles(
                                            type: FileType.image,
                                            withData: true);
                                if (res != null) {
                                  setState(() {
                                    _nuevaIconBytes =
                                        res.files.single.bytes;
                                    _eliminarIconoActual = false;
                                  });
                                }
                              },
                              child:
                                  const Text("Cambiar imagen")),
                          TextFormField(
                              controller: _nombreController,
                              decoration:
                                  const InputDecoration(
                                      labelText: 'Nombre')),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _categoriaSeleccionadaId,
                            items:
                                _categoriasDisponibles.map((c) {
                              return DropdownMenuItem(
                                value:
                                    c['id'].toString(),
                                child:
                                    Text(c['nombre']),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setState(() =>
                                    _categoriaSeleccionadaId =
                                        v),
                            decoration:
                                const InputDecoration(
                                    labelText:
                                        'Categoría'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Variantes',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.bold)),
                      FilledButton(
                          onPressed: _agregarNuevaVariante,
                          child: const Text('Añadir'))
                    ],
                  ),
                  for (var i = 0;
                      i < _variantes.length;
                      i++)
                    Card(
                      margin:
                          const EdgeInsets.symmetric(
                              vertical: 8),
                      child: Padding(
                        padding:
                            const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller:
                                        _variantes[i]
                                            .skuController,
                                    decoration:
                                        const InputDecoration(
                                            labelText:
                                                'SKU'),
                                  ),
                                ),
                                IconButton(
                                    icon: const Icon(
                                        Icons.delete,
                                        color:
                                            Colors.red),
                                    onPressed: () =>
                                        _eliminarVariante(
                                            i))
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller:
                                        _variantes[i]
                                            .stockController,
                                    decoration:
                                        const InputDecoration(
                                            labelText:
                                                'Stock'),
                                  ),
                                ),
                                const SizedBox(
                                    width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller:
                                        _variantes[i]
                                            .precioController,
                                    decoration:
                                        const InputDecoration(
                                            labelText:
                                                'Precio'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}