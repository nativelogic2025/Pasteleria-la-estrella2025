import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

final supabase = Supabase.instance.client;

class DialogoCrearReceta extends StatefulWidget {

  const DialogoCrearReceta({
    super.key
  });

  @override
  State<DialogoCrearReceta> createState() => _DialogoCrearRecetaState();
}

class _DialogoCrearRecetaState extends State<DialogoCrearReceta> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _tipoCtrl = TextEditingController();
  final _versionCtrl = TextEditingController();
  final _autorCtrl = TextEditingController();

  bool _guardando = false;
  Uint8List? _pdfBytes;
  String? _pdfFilename;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _guardarReceta() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      String? pdfPath;
      if (_pdfBytes != null) {
        pdfPath = 'receta_${DateTime.now().millisecondsSinceEpoch}.pdf';
        await supabase.storage.from('recetas/pdf').uploadBinary(pdfPath, _pdfBytes!, fileOptions: const FileOptions(contentType: 'application/pdf'));
      }

      final nuevaReceta = await supabase.from('recetas').insert({
        'nombre': _nombreCtrl.text.trim(),
        'archivo_url': pdfPath != '' && pdfPath != null ? 'pdf/$pdfPath' : null,
        'descripcion': _descripcionCtrl.text.trim(),
        'tipo': _tipoCtrl.text.trim(),
        'version': _versionCtrl.text.trim(),
        'autor': _autorCtrl.text.trim()
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
          Icon(Icons.book),
          SizedBox(width: 10),
          Text("Agregar Receta"),
        ],
      ),
      content: SizedBox(
        width: 950,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _nombreCtrl, validator: (v) => v == null || v.isEmpty ? 'Requerido' : null, decoration: const InputDecoration(labelText: 'Nombre de la receta', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextFormField(controller: _descripcionCtrl, decoration: const InputDecoration(labelText: 'Descripción (opcional)', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextFormField(controller: _tipoCtrl, decoration: const InputDecoration(labelText: 'Tipo (opcional)', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextFormField(controller: _versionCtrl, validator: (v) => v == null || v.isEmpty ? 'Requerido' : null, decoration: const InputDecoration(labelText: 'Version', border: OutlineInputBorder()), keyboardType: TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 16),
              TextFormField(controller: _autorCtrl, decoration: const InputDecoration(labelText: 'Autor (opcional)', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
                  if (res != null) setState(() { _pdfBytes = res.files.single.bytes; _pdfFilename = res.files.single.name; });
                },
                icon: const Icon(Icons.upload_file),
                label: Text(_pdfFilename ?? 'Seleccionar PDF (Opcional)'),
              ),
              const Divider(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _guardando ? null : _guardarReceta, child: const Text('Guardar')),
      ],
    );
  }
}