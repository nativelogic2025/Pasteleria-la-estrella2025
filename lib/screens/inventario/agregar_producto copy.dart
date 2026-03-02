import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

final supabase = Supabase.instance.client;

class VarianteEditable {
  final TextEditingController skuController;
  final TextEditingController stockController;
  final TextEditingController precioController;

  VarianteEditable({
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

class AgregarProductoScreen extends StatefulWidget {
  final String? categoriaInicialId;
  const AgregarProductoScreen({super.key, this.categoriaInicialId});

  @override
  State<AgregarProductoScreen> createState() =>
      _AgregarProductoScreenState();
}

class _AgregarProductoScreenState
    extends State<AgregarProductoScreen> {

  int _currentStep = 0;
  bool _guardando = false;

  final _formKeyPaso1 = GlobalKey<FormState>();
  final _formKeyPaso2 = GlobalKey<FormState>();

  final _nombreCtrl = TextEditingController();
  String? _categoriaSelId;
  String? _productoBaseId;

  Uint8List? _iconBytes;

  final List<VarianteEditable> _variantes = [];

  List<Map<String, dynamic>> _categorias = [];
  List<Map<String, dynamic>> _productos = [];

  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _categoriaSelId = widget.categoriaInicialId;
    _inicializar();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    for (var v in _variantes) {
      v.dispose();
    }
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

  Future<void> _onStepContinue() async {
    if (_currentStep == 0) {
      if (!_formKeyPaso1.currentState!.validate()) return;

      setState(() => _guardando = true);

      try {
        final nombre = _nombreCtrl.text.trim();

        if (_productos.any((p) =>
            p['nombre'].toString().toLowerCase() ==
            nombre.toLowerCase())) {
          _mostrarError('Ya existe un producto con ese nombre.');
          return;
        }

        String? nombreIcono;

        if (_iconBytes != null) {
          nombreIcono =
              'icon_${DateTime.now().millisecondsSinceEpoch}.png';

          await supabase.storage.from('productos').uploadBinary(
                nombreIcono,
                _iconBytes!,
                fileOptions: const FileOptions(
                  contentType: 'image/png',
                  upsert: true,
                ),
              );
        }

        final nuevo = await supabase
            .from('productos')
            .insert({
              'nombre': nombre,
              'id_categoria': _categoriaSelId,
              'imagen_url': nombreIcono,
            })
            .select()
            .single();

        _productoBaseId = nuevo['id_producto'].toString();

        _variantes.clear();
        _variantes.add(
          VarianteEditable(
            sku: nombre,
            stock: 0,
            precio: 0.0,
          ),
        );

        setState(() => _currentStep = 1);
      } catch (e) {
        _mostrarError('Error al guardar producto: $e');
      } finally {
        if (mounted) setState(() => _guardando = false);
      }
    } else {
      await _guardarVariantes();
    }
  }

  Future<void> _guardarVariantes() async {
    if (!_formKeyPaso2.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      for (final v in _variantes) {
        await supabase.from('producto_variantes').insert({
          'id_producto': _productoBaseId,
          'sku': v.skuController.text.trim(),
          'stock': int.tryParse(v.stockController.text) ?? 0,
          'precio_venta':
              double.tryParse(
                    v.precioController.text.replaceAll(',', '.'),
                  ) ??
                  0.0,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producto guardado con éxito'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      _mostrarError('Error al guardar variantes: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _pickImage() async {
    final result =
        await FilePicker.platform.pickFiles(type: FileType.image);

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
      appBar: AppBar(title: const Text('Nuevo Producto')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Stepper(
              type: StepperType.horizontal,
              currentStep: _currentStep,
              onStepContinue: _guardando ? null : _onStepContinue,
              onStepCancel: () => Navigator.pop(context),
              steps: [
                Step(
                  title: const Text('Básico'),
                  content: _buildPaso1(),
                ),
                Step(
                  title: const Text('Variantes'),
                  content: _buildPaso2(),
                ),
              ],
            ),
    );
  }

  Widget _buildPaso1() {
    return Form(
      key: _formKeyPaso1,
      child: Column(
        children: [
          TextFormField(
            controller: _nombreCtrl,
            decoration: const InputDecoration(
              labelText: 'Nombre del producto',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                v == null || v.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _categorias.any(
                    (c) => c['id_categoria'].toString() == _categoriaSelId)
                ? _categoriaSelId
                : null,
            items: _categorias
                .map(
                  (c) => DropdownMenuItem(
                    value: c['id_categoria'].toString(),
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
          if (_iconBytes != null)
            Image.memory(_iconBytes!, height: 80),
          TextButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.image),
            label: const Text('Subir imagen'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaso2() {
    return Form(
      key: _formKeyPaso2,
      child: Column(
        children: [
          for (var v in _variantes) _buildCardVariante(v),
        ],
      ),
    );
  }

  Widget _buildCardVariante(VarianteEditable v) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextFormField(
              controller: v.skuController,
              decoration:
                  const InputDecoration(labelText: 'SKU'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: v.stockController,
                    decoration:
                        const InputDecoration(labelText: 'Stock'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: v.precioController,
                    decoration:
                        const InputDecoration(labelText: 'Precio'),
                    keyboardType:
                        const TextInputType.numberWithOptions(
                            decimal: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}