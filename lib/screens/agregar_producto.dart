import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'pb_client.dart';

class AgregarProductoScreen extends StatefulWidget {
  final String? categoriaInicialId;
  const AgregarProductoScreen({super.key, this.categoriaInicialId});

  @override
  State<AgregarProductoScreen> createState() => _AgregarProductoScreenState();
}

class _AgregarProductoScreenState extends State<AgregarProductoScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController(text: '0');
  String? _categoriaSelId;

  Uint8List? _iconBytes;
  String? _iconFilename;
  bool _guardando = false;

  List<RecordModel> _categoriasDisponibles = [];
  bool _cargandoCategorias = true;

  @override
  void initState() {
    super.initState();
    _categoriaSelId = widget.categoriaInicialId;
    _cargarCategorias();
  }

  Future<void> _cargarCategorias() async {
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
        SnackBar(content: Text('Error al cargar categorías: $e')),
      );
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    _cantidadCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _iconBytes = result.files.single.bytes;
        _iconFilename = result.files.single.name;
      });
    }
  }

  void _incCant() {
    int current = int.tryParse(_cantidadCtrl.text) ?? 0;
    _cantidadCtrl.text = (current + 1).toString();
  }

  void _decCant() {
    int current = int.tryParse(_cantidadCtrl.text) ?? 0;
    if (current > 0) {
      _cantidadCtrl.text = (current - 1).toString();
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      final files = <http.MultipartFile>[];
      if (_iconBytes != null && _iconFilename != null) {
        files.add(http.MultipartFile.fromBytes(
          'icon',
          _iconBytes!,
          filename: _iconFilename,
        ));
      }

      await pb.collection('productos').create(
            body: {
              'Nombre': _nombreCtrl.text.trim(),
              'Categoria': _categoriaSelId,
              'precio': double.tryParse(_precioCtrl.text.trim().replaceAll(',', '.')) ?? 0.0,
              'cantidad': int.tryParse(_cantidadCtrl.text.trim()) ?? 0,
            },
            files: files,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto agregado con éxito'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Nuevo Producto'),
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
                  if (_iconBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(_iconBytes!, height: 150, fit: BoxFit.cover),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(_iconBytes == null ? 'Seleccionar Imagen' : 'Cambiar Imagen'),
                  ),
                ],
              ),
            ),
            _SectionCard(
              title: 'Detalles del Producto',
              child: Column(
                children: [
                  TextFormField(
                    controller: _nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del producto *',
                      prefixIcon: Icon(Icons.cake_outlined),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'El nombre es obligatorio' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _categoriaSelId,
                    hint: _cargandoCategorias ? const Text('Cargando...') : const Text('Selecciona...'),
                    items: _categoriasDisponibles.map((catRecord) {
                      return DropdownMenuItem(
                        value: catRecord.id,
                        child: Text(catRecord.data['nombre'].toString()),
                      );
                    }).toList(),
                    onChanged: _cargandoCategorias ? null : (v) => setState(() => _categoriaSelId = v),
                    decoration: const InputDecoration(
                      labelText: 'Categoría *',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Selecciona una categoría' : null,
                  ),
                ],
              ),
            ),
            _SectionCard(
              title: 'Inventario y Precio',
              child: Column(
                children: [
                  TextFormField(
                    controller: _precioCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Precio *',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'El precio es obligatorio';
                      if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Ingresa un precio válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Cantidad inicial:', style: TextStyle(fontSize: 16)),
                      const Spacer(),
                      IconButton.outlined(onPressed: _decCant, icon: const Icon(Icons.remove)),
                      SizedBox(
                        width: 70,
                        child: TextFormField(
                          controller: _cantidadCtrl,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(border: InputBorder.none),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Requerido';
                            if (int.tryParse(v) == null) return 'Inválido';
                            return null;
                          },
                        ),
                      ),
                      IconButton.outlined(onPressed: _incCant, icon: const Icon(Icons.add)),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FilledButton.icon(
          onPressed: _guardando ? null : _guardar,
          icon: _guardando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
          label: Text(_guardando ? 'Guardando...' : 'Guardar Producto'),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        ),
      ),
    );
  }
}

// Widget de ayuda para organizar el formulario en tarjetas
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