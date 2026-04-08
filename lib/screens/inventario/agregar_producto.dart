import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

final supabase = Supabase.instance.client;

class AgregarProductoScreen extends StatefulWidget {
  final String? categoriaInicialId;
  const AgregarProductoScreen({super.key, this.categoriaInicialId});

  @override
  State<AgregarProductoScreen> createState() =>
      _AgregarProductoScreenState();
}

class _AgregarProductoScreenState
    extends State<AgregarProductoScreen> {

  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _saborCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _unidadCtrl = TextEditingController();

  String? _categoriaSelId;
  Uint8List? _iconBytes;

  List<Map<String, dynamic>> _categorias = [];
  List<Map<String, dynamic>> _productos = [];

  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _categoriaSelId = widget.categoriaInicialId;
    _inicializar();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _inicializar() async {
    setState(() => _cargando = true);
    try {
      _categorias =
          await supabase.from('categorias').select('*').order('nombre');

      _productos =
          await supabase.from('productos').select('*').order('nombre');
    } catch (e) {
      _mostrarError('Error al cargar datos: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardarProducto() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      final nombre = _nombreCtrl.text.trim();
      final descripcion = _descripcionCtrl.text.trim();
      final sabor = _saborCtrl.text.trim();
      final unidad = _unidadCtrl.text.trim();

      // Validar duplicados
      if (_productos.any((p) =>
          p['nombre'].toString().toLowerCase() ==
          nombre.toLowerCase())) {
        _mostrarError('Ya existe un producto con ese nombre.');
        return;
      }

      if (_categoriaSelId == null) {
        _mostrarError("Selecciona una categoría");
        return;
      }

      final data = await supabase
          .from('categorias')
          .select('nombre')
          .eq('id_categoria', _categoriaSelId!)
          .single();

      String carpeta = _slug(data['nombre']);

      String? nombreIcono;

      if (_iconBytes != null) {
        nombreIcono =
            'icon_${DateTime.now().millisecondsSinceEpoch}.png';

        await supabase.storage.from('productos/$carpeta').uploadBinary(
              nombreIcono,
              _iconBytes!,
              fileOptions: const FileOptions(
                contentType: 'image/png',
                upsert: true,
              ),
            );
      }

      await supabase.from('productos').insert({
        'nombre': nombre,
        'id_categoria': _categoriaSelId,
        'imagen_url': '$carpeta/$nombreIcono',
        'descripcion': descripcion.isEmpty ? null : descripcion,
        'sabor': sabor.isEmpty ? null : sabor,
        'unidad_medida': unidad.isEmpty ? null : unidad,
      });

      if (mounted) Navigator.pop(context, true);

    } catch (e) {
      _mostrarError('Error al guardar producto: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _pickImage() async {
    final result =
        await FilePicker.platform.pickFiles(type: FileType.image, withData: true);

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _iconBytes = result.files.single.bytes;
      });
    }
  }

  void _mostrarError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Producto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _guardando ? null : _guardarProducto,
          )
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _guardando
              ? const Center(child: Text("Guardando..."))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        TextFormField(
                          controller: _nombreCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del producto',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty
                                  ? 'Requerido'
                                  : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _categoriaSelId,
                          items: _categorias
                              .map(
                                (c) => DropdownMenuItem(
                                  value:
                                      c['id_categoria'].toString(),
                                  child: Text(c['nombre']),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _categoriaSelId = v),
                          decoration: const InputDecoration(
                            labelText: 'Categoría',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descripcionCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Descripción (opcional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _saborCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Sabor (opcional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _unidadCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Unidad de medida (opcional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_iconBytes != null)
                          Image.memory(_iconBytes!, height: 120),
                        TextButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.image),
                          label: const Text('Subir imagen'),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

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