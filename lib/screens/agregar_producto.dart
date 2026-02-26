import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

// --- CONFIGURACIÓN GLOBAL DE SUPABASE ---
final supabase = Supabase.instance.client;

// --- MODELOS DE ESTADO (MIGRADOS A MAPAS) ---

class IngredienteVarianteEditable {
  String? id;
  final Map<String, dynamic> matPrim;
  final TextEditingController cantidadController;

  IngredienteVarianteEditable({
    this.id,
    required this.matPrim,
    required double cantidad,
  }) : cantidadController = TextEditingController(text: cantidad.toString());

  void dispose() => cantidadController.dispose();
}

class VarianteComplejaEditable {
  final String localId = UniqueKey().toString();
  bool isNew;
  final TextEditingController skuController;
  final TextEditingController stockController;
  final TextEditingController precioController;
  List<IngredienteVarianteEditable> ingredientes = [];

  VarianteComplejaEditable({
    this.isNew = false,
    required String sku,
    required int stock,
    required double precio,
  })  : skuController = TextEditingController(text: sku),
        stockController = TextEditingController(text: stock.toString()),
        precioController = TextEditingController(text: precio.toStringAsFixed(2));

  void dispose() {
    skuController.dispose();
    stockController.dispose();
    precioController.dispose();
    for (var ing in ingredientes) {
      ing.dispose();
    }
  }
}

// --- PANTALLA PRINCIPAL ---

class AgregarProductoScreen extends StatefulWidget {
  final String? categoriaInicialId;
  const AgregarProductoScreen({super.key, this.categoriaInicialId});

  @override
  State<AgregarProductoScreen> createState() => _AgregarProductoScreenState();
}

class _AgregarProductoScreenState extends State<AgregarProductoScreen> {
  int _currentStep = 0;
  bool _guardando = false;
  final _formKeyPaso1 = GlobalKey<FormState>();
  final _formKeyPaso2 = GlobalKey<FormState>();

  final _nombreAutocompleteCtrl = TextEditingController();
  bool _esProductoExistente = false;
  String? _categoriaSelId;
  Map<String, dynamic>? _categoriaSeleccionada;
  bool _mostrarSeccionReceta = false;
  
  Uint8List? _iconBytes;
  String? _iconFilename;
  String? _recetaSelId;
  String? _productoBaseId;

  final List<VarianteComplejaEditable> _variantes = [];

  List<Map<String, dynamic>> _productosExistentes = [];
  List<Map<String, dynamic>> _categoriasDisponibles = [];
  List<Map<String, dynamic>> _recetasDisponibles = [];
  List<Map<String, dynamic>> _materiasPrimasDisponibles = [];
  List<Map<String, dynamic>> _unidadesDeMedida = [];
  bool _cargandoDatos = true;

  @override
  void initState() {
    super.initState();
    _categoriaSelId = widget.categoriaInicialId;
    _inicializarDatos();
  }

  @override
  void dispose() {
    _nombreAutocompleteCtrl.dispose();
    for (var v in _variantes) { v.dispose(); }
    super.dispose();
  }

  Future<void> _inicializarDatos() async {
    setState(() => _cargandoDatos = true);
    try {
      await Future.wait([
        _cargarProductosExistentes(),
        _cargarCategorias(),
        _cargarRecetas(),
        _cargarMateriasPrimas(),
        _cargarUnidadesDeMedida(),
      ]);
      if (widget.categoriaInicialId != null) {
        _onCategoryChanged(widget.categoriaInicialId);
      }
    } catch (e) {
      _mostrarError('Error al cargar datos: $e');
    } finally {
      if (mounted) setState(() => _cargandoDatos = false);
    }
  }

  // --- LÓGICA DE CARGA (SUPABASE) ---
  Future<void> _cargarProductosExistentes() async {
    _productosExistentes = await supabase.from('producto').select('*').order('nombre');
  }
  Future<void> _cargarCategorias() async {
    _categoriasDisponibles = await supabase.from('categoria').select('*').order('nombre');
  }
  Future<void> _cargarRecetas() async {
    _recetasDisponibles = await supabase.from('receta').select('*').order('nombre');
  }
  Future<void> _cargarMateriasPrimas() async {
    _materiasPrimasDisponibles = await supabase.from('matPrim').select('*, id_unidMed(*)').order('nombre');
  }
  Future<void> _cargarUnidadesDeMedida() async {
    _unidadesDeMedida = await supabase.from('unidMed').select('*').order('nombre');
  }

  // --- NAVEGACIÓN ---

  Future<void> _onStepContinue() async {
    if (_currentStep == 0) {
      if (_esProductoExistente) return;
      if (!_formKeyPaso1.currentState!.validate()) return;
      
      if (_productoBaseId != null) {
        await _prepararPaso2();
        setState(() => _currentStep += 1);
        return;
      }
      
      setState(() => _guardando = true);
      try {
        final nombreProducto = _nombreAutocompleteCtrl.text.trim();
        
        // Verificación duplicados
        if (_productosExistentes.any((p) => p['nombre'].toString().toLowerCase() == nombreProducto.toLowerCase())) {
          _mostrarError('Ya existe un producto con este nombre.');
          return;
        }

        // Subida de Icono a Storage
        String? nombreIcono;
        if (_iconBytes != null) {
          nombreIcono = 'icon_${DateTime.now().millisecondsSinceEpoch}.png';
          await supabase.storage.from('productos').uploadBinary(
            nombreIcono, _iconBytes!, 
            fileOptions: const FileOptions(contentType: 'image/png', upsert: true)
          );
        }
        
        // Crear Producto
        final nuevoProd = await supabase.from('producto').insert({
          'nombre': nombreProducto, 
          'id_categoria': _categoriaSelId,
          'icon': nombreIcono
        }).select().single();

        _productoBaseId = nuevoProd['id'].toString();
        _productosExistentes.add(nuevoProd);

        if (_recetaSelId != null) {
          await supabase.from('producto_receta').insert({
            'id_producto': _productoBaseId, 
            'id_receta': _recetaSelId
          });
        }
        
        await _prepararPaso2();
        setState(() => _currentStep += 1);

      } catch (e) {
        _mostrarError('Error al guardar producto base: $e');
      } finally {
        if (mounted) setState(() => _guardando = false);
      }
    } else if (_currentStep == 1) {
      await _guardarTodo();
    }
  }

  Future<void> _prepararPaso2() async {
    for (var v in _variantes) { v.dispose(); }
    _variantes.clear();
    
    final primeraVariante = VarianteComplejaEditable(
      sku: _nombreAutocompleteCtrl.text.trim(), 
      stock: 0, precio: 0.0, isNew: true
    );
    
    if (_recetaSelId != null) {
      try {
        final ingredientesBase = await supabase.from('receta_matPrim')
            .select('*, id_matPrim(*, id_unidMed(*))')
            .eq('id_receta', _recetaSelId!);

        for (final ing in ingredientesBase) {
          final matPrim = ing['id_matPrim'] as Map<String, dynamic>?;
          if (matPrim != null) {
            primeraVariante.ingredientes.add(IngredienteVarianteEditable(
              matPrim: matPrim,
              cantidad: (ing['cantidad'] as num?)?.toDouble() ?? 0.0,
            ));
          }
        }
      } catch (e) {
        _mostrarError('Error al cargar receta: $e');
      }
    }
    _variantes.add(primeraVariante);
  }

  Future<void> _guardarTodo() async {
    if (!_formKeyPaso2.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      for (final variante in _variantes) {
        final nuevaV = await supabase.from('productoVariante').insert({
          'id_producto': _productoBaseId,
          'sku': variante.skuController.text.trim(),
          'precio_final': double.tryParse(variante.precioController.text.replaceAll(',', '.')) ?? 0.0,
          'cantidadStock': int.tryParse(variante.stockController.text) ?? 0,
        }).select().single();
        
        if (_mostrarSeccionReceta) {
          final ingInserts = variante.ingredientes.map((ing) => {
            'id_productoVariante': nuevaV['id'],
            'id_matPrim': ing.matPrim['id'],
            'cantidadNecesaria': double.tryParse(ing.cantidadController.text.replaceAll(',', '.')) ?? 0.0
          }).toList();
          
          if (ingInserts.isNotEmpty) {
            await supabase.from('variante_ingrediente').insert(ingInserts);
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado con éxito'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      _mostrarError('Error al guardar variantes: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _onCategoryChanged(String? newId) {
    if (newId == null) return;
    setState(() {
      _categoriaSelId = newId;
      try {
        _categoriaSeleccionada = _categoriasDisponibles.firstWhere((c) => c['id'].toString() == newId);
        _mostrarSeccionReceta = _categoriaSeleccionada?['receta'] == true;
      } catch(e) { _mostrarSeccionReceta = false; }
    });
  }

  // --- UI HELPERS ---
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _iconBytes = result.files.single.bytes;
        _iconFilename = result.files.single.name;
      });
    }
  }

  void _mostrarError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_esProductoExistente ? 'Nueva Variante' : 'Nuevo Producto')),
      body: _cargandoDatos 
        ? const Center(child: CircularProgressIndicator())
        : Stepper(
            type: StepperType.horizontal,
            currentStep: _currentStep,
            onStepContinue: _guardando ? null : _onStepContinue,
            onStepCancel: () => Navigator.pop(context),
            steps: [
              Step(title: const Text('Básico'), content: _buildPaso1()),
              Step(title: const Text('Variantes'), content: _buildPaso2()),
            ],
          ),
    );
  }

  Widget _buildPaso1() {
    return Form(
      key: _formKeyPaso1,
      child: Column(children: [
        TextFormField(
          controller: _nombreAutocompleteCtrl,
          decoration: const InputDecoration(labelText: 'Nombre del producto', border: OutlineInputBorder()),
          validator: (v) => v!.isEmpty ? 'Requerido' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _categoriaSelId,
          items: _categoriasDisponibles.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['nombre']))).toList(),
          onChanged: _onCategoryChanged,
          decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        if (_iconBytes != null) Image.memory(_iconBytes!, height: 80),
        TextButton.icon(onPressed: _pickImage, icon: const Icon(Icons.image), label: const Text('Subir Icono')),
        if (_mostrarSeccionReceta) _buildSeccionReceta(),
      ]),
    );
  }

  Widget _buildSeccionReceta() {
    return DropdownButtonFormField<String>(
      value: _recetaSelId,
      items: _recetasDisponibles.map((r) => DropdownMenuItem(value: r['id'].toString(), child: Text(r['nombre']))).toList(),
      onChanged: (v) => setState(() => _recetaSelId = v),
      decoration: const InputDecoration(labelText: 'Receta Base', border: OutlineInputBorder()),
    );
  }

  Widget _buildPaso2() {
    return Form(
      key: _formKeyPaso2,
      child: Column(children: [
        for (var i = 0; i < _variantes.length; i++) _buildCardVariante(_variantes[i], i),
      ]),
    );
  }

  Widget _buildCardVariante(VarianteComplejaEditable v, int index) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          TextFormField(controller: v.skuController, decoration: const InputDecoration(labelText: 'SKU')),
          Row(children: [
            Expanded(child: TextFormField(controller: v.stockController, decoration: const InputDecoration(labelText: 'Stock'))),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(controller: v.precioController, decoration: const InputDecoration(labelText: 'Precio'))),
          ]),
          if (_mostrarSeccionReceta) ...[
            const Divider(),
            ...v.ingredientes.map((ing) => ListTile(
              title: Text(ing.matPrim['nombre']),
              trailing: SizedBox(width: 100, child: TextFormField(controller: ing.cantidadController)),
            )),
          ]
        ]),
      ),
    );
  }
}