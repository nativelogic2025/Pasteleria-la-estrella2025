import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

class AgregarProductoScreen extends StatefulWidget {
  const AgregarProductoScreen({super.key, this.categoriaInicial});
  final String? categoriaInicial;

  @override
  State<AgregarProductoScreen> createState() => _AgregarProductoScreenState();
}

class _AgregarProductoScreenState extends State<AgregarProductoScreen> {
  final pb = PocketBase('http://127.0.0.1:8090'); // 🔧 tu servidor PB

  // --- Form ---
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController(text: '0');
  String? _categoriaSel;

  // Imagen (icon)
  Uint8List? _iconBytes;
  String? _iconFilename;

  bool _guardando = false;

  final _categorias = const ['Pasteles', 'Postres', 'Velas', 'Reposteria', 'Extras'];

  @override
  void initState() {
    super.initState();
    _categoriaSel = widget.categoriaInicial;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    _cantidadCtrl.dispose();
    super.dispose();
  }

  // --- Acciones ---
  Future<void> _pickImage() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      withData: true, // obtener bytes directamente
    );
    if (res != null && res.files.isNotEmpty) {
      final f = res.files.single;
      if (f.bytes != null) {
        setState(() {
          _iconBytes = f.bytes!;
          _iconFilename = f.name;
        });
      }
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);
    try {
      final nombre = _nombreCtrl.text.trim();
      final precio = double.tryParse(_precioCtrl.text.replaceAll(',', '.')) ?? 0;
      final cantidad = int.tryParse(_cantidadCtrl.text) ?? 0;

      // Prepara lista de archivos (¡siempre lista, nunca null!)
      final List<http.MultipartFile> files = [];
      if (_iconBytes != null && _iconBytes!.isNotEmpty) {
        files.add(http.MultipartFile.fromBytes(
          'icon', // 👈 nombre del campo archivo en PocketBase
          _iconBytes!,
          filename: _iconFilename ?? 'icon.png',
        ));
      }

      await pb.collection('productos').create(
        body: {
          'Nombre': nombre,
          'Categoria': _categoriaSel,
          'precio': precio,
          'cantidad': cantidad,
        },
        files: files, // ✅ pasa lista (vacía o con 1 archivo)
      );

      if (!mounted) return;
      Navigator.pop(context, true); // avisa a StockScreen que se creó
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear: $e')),
      );
    }
  }

  void _incCant() {
    final n = int.tryParse(_cantidadCtrl.text) ?? 0;
    _cantidadCtrl.text = (n + 1).toString();
    setState(() {});
  }

  void _decCant() {
    final n = int.tryParse(_cantidadCtrl.text) ?? 0;
    _cantidadCtrl.text = (n > 0 ? n - 1 : 0).toString();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Paleta y tema tipo Google Forms
    const bg = Color(0xFFFAFAFA);
    final divider = DividerThemeData(
      thickness: 1,
      space: 24,
      color: Colors.grey.shade200,
    );

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        foregroundColor: Colors.black,
        centerTitle: true,
        title: const Text('Agregar producto'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerTheme: divider,
                inputDecorationTheme: InputDecorationTheme(
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.black87, width: 1.2),
                  ),
                  labelStyle: TextStyle(color: Colors.grey.shade700),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    _HeaderCard(
                      title: 'Nuevo producto',
                      subtitle: 'Completa la información. Los campos con * son obligatorios.',
                    ),
                    const SizedBox(height: 16),

                    // Sección principal
                    _SectionCard(
                      title: 'Detalles',
                      children: [
                        TextFormField(
                          controller: _nombreCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nombre *',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio' : null,
                        ),
                        DropdownButtonFormField<String>(
                          value: _categoriaSel,
                          items: _categorias
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) => setState(() => _categoriaSel = v),
                          decoration: const InputDecoration(
                            labelText: 'Categoría *',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Selecciona una categoría' : null,
                        ),

                        // Imagen (icon): previsualización + botón elegir
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ImagePreview(bytes: _iconBytes),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickImage,
                                icon: const Icon(Icons.upload_file_outlined),
                                label: Text(_iconFilename == null ? 'Subir imagen' : 'Cambiar imagen'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Precio
                        TextFormField(
                          controller: _precioCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Precio *',
                            prefixText: '\$ ',
                            prefixIcon: Icon(Icons.attach_money_outlined),
                          ),
                          validator: (v) {
                            final t = (v ?? '').replaceAll(',', '.').trim();
                            final n = double.tryParse(t);
                            if (n == null || n < 0) return 'Precio inválido';
                            return null;
                          },
                        ),

                        // Cantidad con steppers
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _cantidadCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Cantidad *',
                                  prefixIcon: Icon(Icons.inventory_2_outlined),
                                ),
                                validator: (v) {
                                  final n = int.tryParse(v ?? '');
                                  if (n == null || n < 0) return 'Cantidad inválida';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            _RoundIconButton(icon: Icons.remove, onTap: _decCant),
                            const SizedBox(width: 8),
                            _RoundIconButton(icon: Icons.add, onTap: _incCant),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Botones inferior
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: _guardando ? null : () => Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.tonal(
                            style: ButtonStyle(
                              shape: WidgetStateProperty.all(
                                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              backgroundColor: const WidgetStatePropertyAll(Colors.black),
                              foregroundColor: const WidgetStatePropertyAll(Colors.white),
                              padding: const WidgetStatePropertyAll(
                                EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                            onPressed: _guardando ? null : _guardar,
                            child: _guardando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Guardar'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ======= Widgets de apoyo (estilo Google Forms) =======

class _HeaderCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _HeaderCard({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(color: Colors.grey.shade700, height: 1.25),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            ..._withGaps(children, 12),
          ],
        ),
      ),
    );
  }

  List<Widget> _withGaps(List<Widget> items, double gap) {
    if (items.isEmpty) return items;
    return [
      for (int i = 0; i < items.length; i++) ...[
        items[i],
        if (i != items.length - 1) SizedBox(height: gap),
      ]
    ];
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final Uint8List? bytes;
  const _ImagePreview({this.bytes});

  @override
  Widget build(BuildContext context) {
    const double size = 96;
    final border = Border.all(color: Colors.grey.shade300);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: border,
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes == null
          ? const Center(child: Icon(Icons.image_outlined))
          : Image.memory(bytes!, fit: BoxFit.cover),
    );
  }
}
