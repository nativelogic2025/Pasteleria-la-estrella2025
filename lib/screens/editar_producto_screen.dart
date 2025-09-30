import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'pb_client.dart';

class EditarProductoScreen extends StatefulWidget {
  final RecordModel producto;
  const EditarProductoScreen({super.key, required this.producto});

  @override
  State<EditarProductoScreen> createState() => _EditarProductoScreenState();
}

class _EditarProductoScreenState extends State<EditarProductoScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombreController;
  late final TextEditingController _cantidadController;
  late final TextEditingController _precioController;
  String? _categoriaSeleccionadaId;

  Uint8List? _nuevaIconBytes;
  String? _nuevaIconFilename;
  bool _eliminarIconoActual = false;

  bool _isSaving = false;
  List<RecordModel> _categoriasDisponibles = [];
  bool _cargandoCategorias = true;

  @override
  void initState() {
    super.initState();
    final data = widget.producto.data;
    _nombreController = TextEditingController(text: data['Nombre']?.toString() ?? '');
    _cantidadController = TextEditingController(text: data['cantidad']?.toString() ?? '0');
    _precioController = TextEditingController(text: data['precio']?.toString() ?? '0.0');
    _categoriaSeleccionadaId = data['Categoria']?.toString();
    
    _cargarCategorias();
  }

  Future<void> _cargarCategorias() async {
    setState(() => _cargandoCategorias = true);
    try {
      final records = await pb.collection('categorias').getFullList(sort: 'nombre');
      if (mounted) {
        setState(() {
          _categoriasDisponibles = records;
          _cargandoCategorias = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar categorías: $e'), backgroundColor: Colors.red),
      );
    }
  }
  
  @override
  void dispose() {
    _nombreController.dispose();
    _cantidadController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _nuevaIconBytes = result.files.single.bytes;
        _nuevaIconFilename = result.files.single.name;
        _eliminarIconoActual = false;
      });
    }
  }

  String? _currentIconUrl() {
    final file = widget.producto.data['icon'];
    if (file == null || file.toString().isEmpty) return null;
    return pb.files.getUrl(widget.producto, file).toString();
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final body = <String, dynamic>{
        'Nombre': _nombreController.text.trim(),
        'cantidad': int.tryParse(_cantidadController.text.trim()) ?? 0,
        'precio': double.tryParse(_precioController.text.trim().replaceAll(',', '.')) ?? 0.0,
        'Categoria': _categoriaSeleccionadaId,
      };

      final files = <http.MultipartFile>[];

      if (_eliminarIconoActual && _nuevaIconBytes == null) {
        body['icon'] = null;
      } else if (_nuevaIconBytes != null && _nuevaIconFilename != null) {
        files.add(http.MultipartFile.fromBytes(
          'icon',
          _nuevaIconBytes!,
          filename: _nuevaIconFilename,
        ));
      }

      await pb.collection('productos').update(widget.producto.id, body: body, files: files);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto actualizado con éxito'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final idActualEsValido = _categoriasDisponibles.any((cat) => cat.id == _categoriaSeleccionadaId);
    
    Widget imageWidget;
    if (_nuevaIconBytes != null) {
      imageWidget = Image.memory(_nuevaIconBytes!, height: 150, fit: BoxFit.cover);
    } else if (_eliminarIconoActual) {
      imageWidget = const Icon(Icons.image_not_supported, size: 100, color: Colors.grey);
    } else if (_currentIconUrl() != null) {
      imageWidget = Image.network(
        _currentIconUrl()!,
        height: 150,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 100, color: Colors.red),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
      );
    } else {
      imageWidget = const Icon(Icons.image, size: 100, color: Colors.grey);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Editar "${widget.producto.data['Nombre']}"'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _SectionCard(
              title: 'Imagen (Opcional)',
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 150,
                      child: imageWidget,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image_outlined),
                        label: Text(_nuevaIconBytes == null ? 'Seleccionar Nueva' : 'Cambiar Imagen'),
                      ),
                      if (!_eliminarIconoActual && _currentIconUrl() != null) ...[
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _eliminarIconoActual = true;
                              _nuevaIconBytes = null;
                              _nuevaIconFilename = null;
                            });
                          },
                          icon: const Icon(Icons.delete_forever, color: Colors.red),
                          label: const Text('Eliminar Actual', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ],
                       if (_eliminarIconoActual && _currentIconUrl() != null) ...[
                        const SizedBox(width: 10),
                         OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _eliminarIconoActual = false;
                            });
                          },
                          icon: const Icon(Icons.undo),
                          label: const Text('Deshacer eliminación'),
                        ),
                       ]
                    ],
                  ),
                ],
              ),
            ),
            _SectionCard(
              title: 'Detalles del Producto',
              child: Column(
                children: [
                  TextFormField(
                    controller: _nombreController,
                    decoration: const InputDecoration(labelText: 'Nombre del Producto'),
                    validator: (value) => (value == null || value.isEmpty) ? 'El nombre es obligatorio' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: idActualEsValido ? _categoriaSeleccionadaId : null,
                    hint: _cargandoCategorias ? const Text('Cargando...') : const Text('Selecciona...'),
                    items: _categoriasDisponibles.map((catRecord) {
                      return DropdownMenuItem(
                        value: catRecord.id,
                        child: Text(catRecord.data['nombre'].toString()),
                      );
                    }).toList(),
                    onChanged: _cargandoCategorias ? null : (value) => setState(() => _categoriaSeleccionadaId = value),
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    validator: (value) => value == null ? 'Selecciona una categoría' : null,
                  ),
                ],
              ),
            ),
            _SectionCard(
              title: 'Inventario y Precio',
              child: Column(
                children: [
                  TextFormField(
                    controller: _cantidadController,
                    decoration: const InputDecoration(labelText: 'Cantidad en Stock'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'La cantidad es obligatoria';
                      if (int.tryParse(value) == null) return 'Ingresa un número válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _precioController,
                    decoration: const InputDecoration(labelText: 'Precio', prefixText: '\$'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'El precio es obligatorio';
                      if (double.tryParse(value.replaceAll(',', '.')) == null) return 'Ingresa un número válido';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FilledButton.icon(
          onPressed: _isSaving ? null : _guardarCambios,
          icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
          label: Text(_isSaving ? 'Guardando...' : 'Guardar Cambios'),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}