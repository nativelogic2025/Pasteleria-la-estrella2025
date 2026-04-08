import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

final supabase = Supabase.instance.client;

class DialogoCrearAlbum extends StatefulWidget {

  const DialogoCrearAlbum({
    super.key
  });

  @override
  State<DialogoCrearAlbum> createState() => _DialogoCrearAlbumState();
}

class _DialogoCrearAlbumState extends State<DialogoCrearAlbum> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  bool _estado = true; // Por defecto no estará destacado

  bool _guardando = false;
  Uint8List? _ImagenBytes;
  String? _ImagenFilename;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _guardarImagen() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      String? ImagenPath;
      if (_ImagenBytes != null) {
        ImagenPath = 'album_${DateTime.now().millisecondsSinceEpoch}.png';
        await supabase.storage.from('recetas/albums').uploadBinary(ImagenPath, _ImagenBytes!, fileOptions: const FileOptions(contentType: 'application/png'));
      }

      final nuevaReceta = await supabase.from('albumes').insert({
        'nombre': _nombreCtrl.text.trim(),
        'portada_url': ImagenPath != '' && ImagenPath != null ? 'albums/$ImagenPath' : null,
        'descripcion': _descripcionCtrl.text.trim(),
        'activo': _estado,
      }).select().single();

      if (!mounted) return;
      Navigator.pop(context, nuevaReceta);
    } catch (e) {
      _snackLocal('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _snackLocal(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : Colors.orange));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.photo_album_outlined),
          SizedBox(width: 10),
          Text("Crear Album"),
        ],
      ),
      content: SizedBox(
        width: 950,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _nombreCtrl, validator: (v) => v == null || v.isEmpty ? 'Requerido' : null, decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              FormField<Uint8List>(
                builder: (FormFieldState<Uint8List> state) {
                  return GestureDetector(
                    // Movemos el onTap al GestureDetector para que todo el recuadro sea clickeable
                    onTap: () async {
                      final res = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['png', 'jpg'],
                        withData: true,
                      );

                      if (res != null) {
                        // Asumo que tienes un setState disponible en tu clase
                        setState(() {
                          _ImagenBytes = res.files.single.bytes;
                          _ImagenFilename = res.files.single.name;
                        });

                        // Le avisamos al FormField para que quite el error
                        // state.didChange(_ImagenBytes);
                      }
                    },
                    child: InputDecorator(
                      // Aquí le damos el mismo diseño que un TextFormField
                      decoration: InputDecoration(
                        labelText: 'Imagen',
                        border: const OutlineInputBorder(),
                        // state.errorText maneja automáticamente el borde rojo y el texto inferior
                        errorText: state.errorText, 
                        // Opcional: Ajusta el padding para que coincida con tus otros campos
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      // Lo que va dentro del recuadro
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _ImagenFilename ?? 'Seleccionar Imagen (opcional)...',
                              style: TextStyle(
                                // Si no hay imagen, mostramos texto gris como si fuera un "hint"
                                color: _ImagenFilename == null 
                                    ? Colors.grey.shade600 
                                    : Colors.black87,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.image,
                            color: state.hasError ? Colors.red.shade700 : Colors.grey.shade600,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(controller: _descripcionCtrl, decoration: const InputDecoration(labelText: 'Descripción (opcional)', border: OutlineInputBorder())),
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
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _guardando ? null : _guardarImagen, child: const Text('Guardar')),
      ],
    );
  }
}