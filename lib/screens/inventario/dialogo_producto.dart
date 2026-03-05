import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

final supabase = Supabase.instance.client;

class DialogoEditarProducto extends StatefulWidget {
  final String? categoriaInicialId;
  final String nombreProducto;
  final String? urlImagen;
  final String? descripcion;
  final String? sabor;
  final String? unidadMedida;

  const DialogoEditarProducto({
    super.key,
    required this.nombreProducto,
    this.urlImagen,
    this.categoriaInicialId,
    this.descripcion,
    this.sabor,
    this.unidadMedida,
  });

  @override
  State<DialogoEditarProducto> createState() => _DialogoEditarProductoState();
}

class _DialogoEditarProductoState extends State<DialogoEditarProducto> {
  // 1. LLAVE PARA VALIDAR EL FORMULARIO
  final _formKey = GlobalKey<FormState>();

  // 2. CONTROLADORES PARA CAPTURAR EL TEXTO
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _saborCtrl = TextEditingController();
  final _unidadCtrl = TextEditingController();

  String? _categoriaSelId;

  List<Map<String, dynamic>> _categorias = [];

  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _nombreCtrl.text = widget.nombreProducto;
    _categoriaSelId = widget.categoriaInicialId;
    _descripcionCtrl.text = widget.descripcion ?? '';
    _saborCtrl.text = widget.sabor ?? '';
    _unidadCtrl.text = widget.unidadMedida ?? '';
    _inicializar();
  }

  Future<void> _inicializar() async {
    setState(() => _cargando = true);
    try {
      _categorias =
          await supabase.from('categorias').select('*').order('nombre');

    } catch (e) {
      _mostrarError('Error al cargar datos: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  File? _nuevaImagenLocal; // Para guardar la foto que elija el usuario
  Uint8List? _imagenBytesWeb;
  bool _imagenEliminada = false; // Flag por si decide borrar la foto actual
  final ImagePicker _picker = ImagePicker();

  // Función para seleccionar imagen
  Future<void> _seleccionarImagen() async {
  final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      // Leemos los bytes para que funcione en Web
      final bytes = await image.readAsBytes();
      setState(() {
        _imagenBytesWeb = bytes;
        if (!kIsWeb) {
          _nuevaImagenLocal = File(image.path);
        }
        _imagenEliminada = false;
      });
    }
  }

  // Menú de opciones para la imagen
  void _mostrarOpcionesImagen() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Cambiar imagen (Galería)'),
            onTap: () {
              Navigator.pop(context);
              _seleccionarImagen();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Eliminar imagen actual'),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _nuevaImagenLocal = null;
                _imagenEliminada = true;
              });
            },
          ),
        ],
      ),
    );
  }

  void _mostrarError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    // Limpieza de memoria
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _saborCtrl.dispose();
    _unidadCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar producto'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Form( // ✅ ENVOLVEMOS EN UN FORM
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- SECCIÓN DE IMAGEN INTERACTIVA ---
                GestureDetector(
                  onTap: _mostrarOpcionesImagen, // Abre el menú al tocar
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _construirVistaImagen(),
                      ),
                      // Icono indicador de que es editable
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          radius: 18,
                          child: Icon(
                            _imagenEliminada ? Icons.add_a_photo : Icons.edit, 
                            size: 18, 
                            color: Colors.white
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildField(label: 'Nombre', controller: _nombreCtrl, isRequired: true),
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
                const SizedBox(height: 12),
                _buildField(label: 'Descripción (opcional)', controller: _descripcionCtrl, isRequired: false),
                _buildField(label: 'Sabor (opcional)', controller: _saborCtrl, isRequired: false),
                _buildField(label: 'Unidad de Medida (opcional)', controller: _unidadCtrl, isRequired: false),
     
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null), // Retorna null si cancela
          child: const Text('CANCELAR'),
        ),
        FilledButton(
          onPressed: () {
            // 3. VALIDAR Y RETORNAR EL MAPA DE DATOS
            if (_formKey.currentState!.validate()) {
              final Map<String, dynamic> datos = {
                'nombre': _nombreCtrl.text,
                'id_categoria': _categoriaSelId,
                'categoria_nombre': _categorias.firstWhere((c) => c['id_categoria'].toString() == _categoriaSelId)?['nombre'] ?? '',
                'descripcion': _descripcionCtrl.text,
                'sabor': _saborCtrl.text,
                'unidad_medida': _unidadCtrl.text,
                'nueva_imagen_file': _nuevaImagenLocal, // Puede ser null si no se cambió
                'borrar_imagen_servidor': _imagenEliminada, // Flag para indicar si se
                'imagen_bytes_web': _imagenBytesWeb, // Para web
              };
              Navigator.pop(context, datos); // ✅ RETORNA EL MAPA
            }
          },
          style: FilledButton.styleFrom(backgroundColor: Colors.blueGrey),
          child: const Text('GUARDAR'),
        ),
      ],
    );
  }

  Widget _buildField({
    required String label, 
    required TextEditingController controller, // ✅ RECIBE EL CONTROLADOR
    String? prefix, 
    bool isNumeric = false, 
    bool onlyInt = false,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller, // ✅ VINCULACIÓN
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefix,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        keyboardType: isNumeric ? TextInputType.numberWithOptions(decimal: !onlyInt) : TextInputType.text,
        inputFormatters: isNumeric 
          ? [FilteringTextInputFormatter.allow(RegExp(onlyInt ? r'^\d+$' : r'^\d+\.?\d{0,2}'))] 
          : null,
        validator: (v) => isRequired && (v == null || v.isEmpty) ? 'Requerido' : null,
      ),
    );
  }

  // Helper para decidir qué mostrar en el cuadro de imagen
  Widget _construirVistaImagen() {
    if (_imagenEliminada) {
      return Container(
        height: 120, width: 120, color: Colors.grey[200],
        child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
      );
    }

    // ✅ SOLUCIÓN PARA WEB Y MÓVIL
    if (_imagenBytesWeb != null) {
      return Image.memory(_imagenBytesWeb!, height: 120, width: 120, fit: BoxFit.cover);
    }

    if (widget.urlImagen != null && widget.urlImagen!.isNotEmpty) {
      return Image.network(
        widget.urlImagen!, height: 120, width: 120, fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => const Icon(Icons.broken_image, size: 50),
      );
    }

    return Container(
      height: 120, width: 120, color: Colors.grey[200],
      child: const Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
    );
  }
}