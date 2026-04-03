import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

final supabase = Supabase.instance.client;

class DialogoSubirImagen extends StatefulWidget {
  final String id_album;

  const DialogoSubirImagen({
    super.key,
    required this.id_album,
  });

  @override
  State<DialogoSubirImagen> createState() => DialogoSubirImagenState();
}

class DialogoSubirImagenState extends State<DialogoSubirImagen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  bool _esDestacado = false; // Por defecto no estará destacado

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
        ImagenPath = 'foto_${DateTime.now().millisecondsSinceEpoch}.png';
        await supabase.storage.from('recetas/albums').uploadBinary(ImagenPath, _ImagenBytes!, fileOptions: const FileOptions(contentType: 'image/png'));
      }

      final nuevaReceta = await supabase.from('fotos_album').insert({
        'id_album': int.tryParse(widget.id_album) ,
        'titulo': _tituloCtrl.text.trim(),
        'imagen_url': ImagenPath != '' && ImagenPath != null ? 'albums/$ImagenPath' : null,
        'descripcion': _descripcionCtrl.text.trim(),
        'precio': double.tryParse(_precioCtrl.text.trim()),
        'destacado': _esDestacado,
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
          Icon(Icons.image),
          SizedBox(width: 10),
          Text("Subir Imagen"),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FormField<Uint8List>(
                validator: (value) {
                  if (_ImagenBytes == null) {
                    return 'La imagen es obligatoria';
                  }
                  return null;
                },
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
                        state.didChange(_ImagenBytes);
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
                              _ImagenFilename ?? 'Seleccionar Imagen...',
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
              TextFormField(controller: _tituloCtrl, validator: (v) => v == null || v.isEmpty ? 'Requerido' : null, decoration: const InputDecoration(labelText: 'Titulo', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextFormField(controller: _descripcionCtrl, decoration: const InputDecoration(labelText: 'Descripción (opcional)', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextFormField(controller: _precioCtrl, 
                            decoration: const InputDecoration(labelText: 'Precio (opcional)', 
                            border: OutlineInputBorder()), 
                            keyboardType: TextInputType.numberWithOptions(decimal: true), 
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))]),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Destacado',
                  border: OutlineInputBorder(),
                  // Reducimos un poco el padding interno para que el Switch encaje bien
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4), 
                ),
                child: SwitchListTile(
                  title: const Text('¿Mostrar en la sección principal?', style: TextStyle(fontSize: 14)),
                  value: _esDestacado,
                  activeColor: const Color.fromARGB(255, 165, 106, 224), // Tu color morado (opcional)
                  contentPadding: EdgeInsets.zero, // Quita márgenes extra del SwitchListTile
                  onChanged: (bool valor) {
                    setState(() {
                      _esDestacado = valor;
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