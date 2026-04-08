import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

final supabase = Supabase.instance.client;

class DialogoEditarAlbum extends StatefulWidget {
  final String nombre;
  final String? urlImagen;
  final String? descripcion;
  final bool estado;

  const DialogoEditarAlbum({
    super.key,
    required this.nombre,
    this.urlImagen,
    this.descripcion,
    required this.estado
  });

  @override
  State<DialogoEditarAlbum> createState() => _DialogoEditarAlbumState();
}

class _DialogoEditarAlbumState extends State<DialogoEditarAlbum> {
  // 1. LLAVE PARA VALIDAR EL FORMULARIO
  final _formKey = GlobalKey<FormState>();

  // 2. CONTROLADORES PARA CAPTURAR EL TEXTO
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  bool _estado = true;  

  @override
  void initState() {
    super.initState();
    _nombreCtrl.text = widget.nombre;
    _descripcionCtrl.text = widget.descripcion ?? '';
    _estado = widget.estado;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.photo_album_outlined),
          SizedBox(width: 10),
          Text("Editar Album"),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child:
          Form( // ✅ ENVOLVEMOS EN UN FORM
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
                _buildField(label: 'Descripción (opcional)', controller: _descripcionCtrl, isRequired: false),
                const SizedBox(height: 16),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    border: OutlineInputBorder(),
                    // Reducimos un poco el padding interno para que el Switch encaje bien
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4), 
                  ),
                  child: SwitchListTile(
                    title: const Text('¿Activo?', style: TextStyle(fontSize: 14)),
                    value: _estado,
                    activeColor: const Color.fromARGB(255, 165, 106, 224), // Tu color morado (opcional)
                    contentPadding: EdgeInsets.zero, // Quita márgenes extra del SwitchListTile
                    onChanged: (bool valor) {
                      setState(() {
                        _estado = valor;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
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
                'descripcion': _descripcionCtrl.text,
                'activo': _estado,
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