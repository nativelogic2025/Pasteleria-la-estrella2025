import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'pb_client.dart';

// --- MODELOS DE ESTADO (TRAÍDOS DE LA PANTALLA DE EDICIÓN PARA UNIFICAR LÓGICA) ---

class IngredienteVarianteEditable {
  String? id;
  final RecordModel matPrim;
  final TextEditingController cantidadController;

  IngredienteVarianteEditable({
    this.id,
    required this.matPrim,
    required double cantidad,
  }) : cantidadController = TextEditingController(text: cantidad.toString());

  void dispose() {
    cantidadController.dispose();
  }
}

class VarianteComplejaEditable {
  final String localId = UniqueKey().toString(); // ID local para el Key del widget
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

  // Controladores y estado del Paso 1
  final _nombreAutocompleteCtrl = TextEditingController();
  bool _esProductoExistente = false;
  String? _categoriaSelId;
  RecordModel? _categoriaSeleccionada;
  bool _mostrarSeccionReceta = false;
  Uint8List? _iconBytes;
  String? _iconFilename;
  String? _recetaSelId;
  String? _productoBaseId;

  final List<VarianteComplejaEditable> _variantes = [];

  // Listas de datos cacheados
  List<RecordModel> _productosExistentes = [];
  List<RecordModel> _categoriasDisponibles = [];
  List<RecordModel> _recetasDisponibles = [];
  List<RecordModel> _materiasPrimasDisponibles = [];
  List<RecordModel> _unidadesDeMedida = [];
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
    for (var v in _variantes) {
      v.dispose();
    }
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
    } catch(e) {
        _mostrarError('Error al cargar datos iniciales: $e');
    } finally {
        if (mounted) setState(() => _cargandoDatos = false);
    }
  }

  // --- LÓGICA DE CARGA DE DATOS (FETCH) ---
  Future<void> _cargarProductosExistentes() async {
    _productosExistentes = await pb.collection('producto').getFullList(sort: 'nombre');
  }
  Future<void> _cargarCategorias() async {
    _categoriasDisponibles = await pb.collection('categoria').getFullList(sort: 'nombre');
  }
  Future<void> _cargarRecetas() async {
    _recetasDisponibles = await pb.collection('receta').getFullList(sort: 'nombre');
  }
  Future<void> _cargarMateriasPrimas() async {
    _materiasPrimasDisponibles = await pb.collection('matPrim').getFullList(sort: 'nombre', expand: 'id_unidMed');
  }
  Future<void> _cargarUnidadesDeMedida() async {
    _unidadesDeMedida = await pb.collection('unidMed').getFullList(sort: 'nombre');
  }

  // --- LÓGICA DE NAVEGACIÓN DEL STEPPER ---

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
        // ✨ --- VERIFICACIÓN DE NOMBRE DUPLICADO --- ✨
        final esDuplicado = _productosExistentes.any((p) => p.data['nombre'].toString().toLowerCase() == nombreProducto.toLowerCase());
        if (esDuplicado) {
          _mostrarError('Ya existe un producto con este nombre. Por favor, elige otro.');
          return; // Detiene la ejecución
        }
        
        final productoBase = await pb.collection('producto').create(
              body: {'nombre': nombreProducto, 'id_categoria': _categoriaSelId},
              files: _buildMultipartFiles(),
            );
        _productoBaseId = productoBase.id;
        _productosExistentes.add(productoBase); // Actualiza la lista en memoria

        if (_recetaSelId != null) {
          await pb.collection('producto_receta').create(body: {'id_producto': _productoBaseId, 'id_receta': _recetaSelId});
        }
        
        await _prepararPaso2();
        setState(() => _currentStep += 1);

      } catch (e) {
        _productoBaseId = null;
        _mostrarError('Error al guardar el producto base: $e');
      } finally {
        if (mounted) setState(() => _guardando = false);
      }

    } else if (_currentStep == 1) {
      await _guardarTodo();
    }
  }
  
  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep -= 1;
        for (var v in _variantes) { v.dispose(); }
        _variantes.clear();
        if (_esProductoExistente) {
          _esProductoExistente = false;
          _nombreAutocompleteCtrl.clear();
          _categoriaSelId = widget.categoriaInicialId;
          _recetaSelId = null;
          _mostrarSeccionReceta = false;
          _productoBaseId = null;
        }
      });
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _prepararPaso2() async {
    for (var v in _variantes) { v.dispose(); }
    _variantes.clear();
    
    final primeraVariante = VarianteComplejaEditable(
      sku: _nombreAutocompleteCtrl.text.trim(), 
      stock: 0, 
      precio: 0.0, 
      isNew: true
    );
    
    if (_recetaSelId != null) {
      try {
        final ingredientesBase = await pb.collection('receta_matPrim').getFullList(
          filter: 'id_receta = "$_recetaSelId"',
          expand: 'id_matPrim,id_matPrim.id_unidMed',
        );
        for (final ingBase in ingredientesBase) {
          final matPrim = ingBase.expand['id_matPrim']?.first;
          if (matPrim != null) {
            primeraVariante.ingredientes.add(IngredienteVarianteEditable(
              matPrim: matPrim,
              cantidad: (ingBase.data['cantidad'] as num?)?.toDouble() ?? 0.0,
            ));
          }
        }
      } catch (e) {
        _mostrarError('Error al cargar ingredientes de la receta: $e');
      }
    }
    
    _variantes.add(primeraVariante);
  }

  Future<void> _guardarTodo() async {
    if (!_formKeyPaso2.currentState!.validate()) return;
    if (_variantes.isEmpty) {
        _mostrarError('Debes añadir al menos una variante.');
        return;
    }

    setState(() => _guardando = true);

    if (_productoBaseId == null) {
      _mostrarError('Error crítico: No se encontró el ID del producto base.');
      setState(() => _guardando = false);
      return;
    }
    try {
      for (final variante in _variantes) {
        final nuevaVarianteRecord = await pb.collection('productoVariante').create(body: {
          'id_producto': _productoBaseId,
          'sku': variante.skuController.text.trim(),
          'precio_final': double.tryParse(variante.precioController.text.replaceAll(',', '.')) ?? 0.0,
          'cantidadStock': int.tryParse(variante.stockController.text) ?? 0,
        });
        
        if (_mostrarSeccionReceta) {
            for (final ingrediente in variante.ingredientes) {
              final cantidad = double.tryParse(ingrediente.cantidadController.text.replaceAll(',', '.')) ?? 0.0;
              await pb.collection('variante_ingrediente').create(body: {
                  'id_productoVariante': nuevaVarianteRecord.id, 
                  'id_matPrim': ingrediente.matPrim.id, 
                  'cantidadNecesaria': cantidad
              });
            }
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto y variantes creados con éxito!'), backgroundColor: Colors.green));
      Navigator.pop(context, true);

    } catch (e) {
      _mostrarError('Error al guardar las variantes: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
  
  Future<void> _seleccionarProductoExistente(RecordModel producto) async {
    setState(() {
      _guardando = true;
      _esProductoExistente = true;
      _productoBaseId = producto.id;
      _onCategoryChanged(producto.data['id_categoria']);
    });
    try {
      final recetaRel = await pb.collection('producto_receta').getFirstListItem('id_producto = "${producto.id}"');
      _recetaSelId = recetaRel.data['id_receta'];
    } on ClientException {
      _recetaSelId = null;
    } catch (e) {
      _mostrarError("Error al buscar receta: $e");
    }
    
    await _prepararPaso2();

    if (mounted) {
      setState(() {
        _currentStep = 1;
        _guardando = false;
      });
    }
  }

  void _onCategoryChanged(String? newId) {
    if (newId == null) return;
    setState(() {
      _categoriaSelId = newId;
      try {
        _categoriaSeleccionada = _categoriasDisponibles.firstWhere((c) => c.id == newId);
        _mostrarSeccionReceta = _categoriaSeleccionada?.data['receta'] == true;
      } catch(e) { _mostrarSeccionReceta = false; }
      if (!_mostrarSeccionReceta) _recetaSelId = null;
    });
  }

  void _mostrarError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
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

  List<http.MultipartFile> _buildMultipartFiles() {
    final files = <http.MultipartFile>[];
    if (_iconBytes != null && _iconFilename != null) {
      files.add(http.MultipartFile.fromBytes('icon', _iconBytes!, filename: _iconFilename));
    }
    return files;
  }
  
  Future<void> _agregarNuevaVariante() async {
    final nuevaVariante = VarianteComplejaEditable(
      sku: _nombreAutocompleteCtrl.text.trim(), 
      stock: 0, 
      precio: 0.0, 
      isNew: true
    );
    if (_variantes.isNotEmpty) {
      final primeraVariante = _variantes.first;
      for (final ing in primeraVariante.ingredientes) {
        nuevaVariante.ingredientes.add(IngredienteVarianteEditable(
          matPrim: ing.matPrim, 
          cantidad: double.tryParse(ing.cantidadController.text.replaceAll(',', '.')) ?? 0.0
        ));
      }
    }
    setState(() => _variantes.add(nuevaVariante));
  }

  void _eliminarVariante(int index) {
    setState(() {
      _variantes[index].dispose();
      _variantes.removeAt(index);
    });
  }

  void _agregarIngredienteAVariante(VarianteComplejaEditable variante) async {
    final RecordModel? matPrimSeleccionada = await showDialog(
      context: context, 
      builder: (_) => _DialogoBuscarMatPrim(materiasPrimasExistentes: _materiasPrimasDisponibles)
    );

    if (matPrimSeleccionada != null) {
      if (variante.ingredientes.any((ing) => ing.matPrim.id == matPrimSeleccionada.id)) {
        _mostrarError('Este ingrediente ya está en la lista.');
        return;
      }
      setState(() {
        variante.ingredientes.add(IngredienteVarianteEditable(matPrim: matPrimSeleccionada, cantidad: 0.0));
      });
    }
  }

  void _eliminarIngredienteDeVariante(VarianteComplejaEditable variante, int ingIndex) {
    setState(() {
      variante.ingredientes[ingIndex].dispose();
      variante.ingredientes.removeAt(ingIndex);
    });
  }
  
  // --- WIDGETS ---
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_esProductoExistente ? 'Añadir Nueva Variante' : 'Agregar Nuevo Producto')),
      body: _cargandoDatos
          ? const Center(child: CircularProgressIndicator())
          : Stepper(
              type: StepperType.horizontal,
              currentStep: _currentStep,
              onStepContinue: _guardando ? null : _onStepContinue,
              onStepCancel: _guardando ? null : _onStepCancel,
              controlsBuilder: (context, details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: _guardando
                      ? const Center(child: CircularProgressIndicator())
                      : Row(children: [
                          if (!(_currentStep == 0 && _esProductoExistente))
                            FilledButton(onPressed: details.onStepContinue, child: Text(_currentStep == 0 ? 'Guardar y Continuar' : 'Guardar Todo')),
                          const SizedBox(width: 8),
                          TextButton(onPressed: details.onStepCancel, child: Text(_currentStep == 0 ? 'Cancelar' : 'Atrás')),
                        ]),
                );
              },
              steps: [
                Step(
                  title: const Text('Info Básica'),
                  isActive: _currentStep >= 0,
                  state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                  content: Form(key: _formKeyPaso1, child: _buildPaso1()),
                ),
                Step(
                  title: const Text('Variantes'),
                  isActive: _currentStep >= 1,
                  content: _buildPaso2(),
                ),
              ],
            ),
    );
  }

  // --- BUILDERS DE PASOS ---

  Widget _buildPaso1() {
      return AbsorbPointer(
      absorbing: _esProductoExistente,
      child: Column(
        children: [
          Autocomplete<RecordModel>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) return const Iterable<RecordModel>.empty();
              return _productosExistentes.where((p) => p.data['nombre'].toLowerCase().contains(textEditingValue.text.toLowerCase()));
            },
            displayStringForOption: (RecordModel option) => option.data['nombre'],
            fieldViewBuilder: (context, fieldController, fieldFocusNode, onFieldSubmitted) {
              return TextFormField(
                controller: fieldController,
                focusNode: fieldFocusNode,
                decoration: const InputDecoration(labelText: 'Nombre del producto (escribe o selecciona)', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                onChanged: (text) => _nombreAutocompleteCtrl.text = text,
              );
            },
            onSelected: (RecordModel selection) {
              _nombreAutocompleteCtrl.text = selection.data['nombre'];
              _seleccionarProductoExistente(selection);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _categoriaSelId,
            items: _categoriasDisponibles.map((c) => DropdownMenuItem(value: c.id, child: Text(c.data['nombre']))).toList(),
            onChanged: _onCategoryChanged,
            decoration: const InputDecoration(labelText: 'Categoría *', border: OutlineInputBorder()),
            validator: (v) => v == null ? 'Campo requerido' : null,
          ),
          const SizedBox(height: 16),
          Card(
              child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(children: [
              if (_iconBytes != null) Image.memory(_iconBytes!, height: 100),
              TextButton.icon(onPressed: _pickImage, icon: const Icon(Icons.image), label: Text(_iconBytes == null ? 'Seleccionar Imagen' : 'Cambiar Imagen'))
            ]),
          )),
          if (_mostrarSeccionReceta) _buildSeccionReceta(),
        ],
      ),
    );
  }

  Widget _buildSeccionReceta() {
      return Card(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          Text('Asignar Receta', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _recetasDisponibles.any((r) => r.id == _recetaSelId) ? _recetaSelId : null,
            items: _recetasDisponibles.map((r) => DropdownMenuItem(value: r.id, child: Text(r.data['nombre']))).toList(),
            onChanged: (v) => setState(() => _recetaSelId = v),
            decoration: const InputDecoration(labelText: 'Receta *', border: OutlineInputBorder()),
            validator: (v) => v == null ? 'Se requiere una receta' : null,
          ),
        ]),
      ),
    );
  }
  
  Widget _buildPaso2() {
    return Form(
      key: _formKeyPaso2,
      child: Column(
        children: [
          for (var i = 0; i < _variantes.length; i++)
            _buildCardVariante(_variantes[i], i),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _agregarNuevaVariante,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Añadir otra variante'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCardVariante(VarianteComplejaEditable variante, int index) {
    return Card(
      key: ValueKey(variante.localId),
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text('Variante ${index + 1}', style: Theme.of(context).textTheme.titleMedium)),
              if (_variantes.length > 1)
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _eliminarVariante(index), tooltip: 'Eliminar esta Variante')
            ]),
            const SizedBox(height: 10),
            TextFormField(
              controller: variante.skuController,
              decoration: const InputDecoration(labelText: 'SKU / Nombre de Variante *', border: OutlineInputBorder()),
              // ✨ --- VALIDACIÓN DE SKU MEJORADA --- ✨
              validator: (v) {
                final value = v?.trim();
                if (value == null || value.isEmpty) {
                  return 'Requerido';
                }
                if (value[0] != value[0].toUpperCase()) {
                  return 'Debe comenzar con mayúscula';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: variante.stockController, decoration: const InputDecoration(labelText: 'Stock *', border: OutlineInputBorder()), keyboardType: TextInputType.number, validator: (v) => (v == null || v.trim().isEmpty) ? 'Req.' : null)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: variante.precioController, decoration: const InputDecoration(labelText: 'Precio *', prefixText: '\$ ', border: OutlineInputBorder()), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => (v == null || v.trim().isEmpty) ? 'Req.' : null)),
            ]),
            
            if (_mostrarSeccionReceta) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ingredientes de esta Variante', style: TextStyle(fontWeight: FontWeight.bold)),
                  OutlinedButton.icon(icon: const Icon(Icons.add, size: 18), label: const Text('Añadir'), onPressed: () => _agregarIngredienteAVariante(variante))
                ],
              ),
              const SizedBox(height: 10),
              if (variante.ingredientes.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('Sin ingredientes específicos.', style: TextStyle(color: Colors.grey)))
              else
                for (var j = 0; j < variante.ingredientes.length; j++)
                  _buildRowIngrediente(variante, j),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildRowIngrediente(VarianteComplejaEditable variante, int ingIndex) {
    final ingrediente = variante.ingredientes[ingIndex];
    final matPrim = ingrediente.matPrim;
    final unidMed = matPrim.expand['id_unidMed']?.first;
    final nombreIngrediente = matPrim.data['nombre'] ?? 'N/A';
    final abreviatura = unidMed?.data['abreviatura'] ?? '-';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(nombreIngrediente)),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: ingrediente.cantidadController,
              decoration: InputDecoration(labelText: 'Cantidad', suffixText: abreviatura, border: const OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Req.';
                if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Inv.';
                return null;
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.deepOrange),
            onPressed: () => _eliminarIngredienteDeVariante(variante, ingIndex),
            tooltip: 'Quitar ingrediente',
          )
        ],
      ),
    );
  }
}

// --- WIDGETS DE DIÁLOGO (COPIADOS DE LA PANTALLA DE EDICIÓN) ---

class _DialogoBuscarMatPrim extends StatefulWidget {
  final List<RecordModel> materiasPrimasExistentes;
  const _DialogoBuscarMatPrim({required this.materiasPrimasExistentes});

  @override
  State<_DialogoBuscarMatPrim> createState() => _DialogoBuscarMatPrimState();
}

class _DialogoBuscarMatPrimState extends State<_DialogoBuscarMatPrim> {
  late List<RecordModel> _resultadosFiltrados;

  @override
  void initState() {
    super.initState();
    _resultadosFiltrados = widget.materiasPrimasExistentes;
  }

  void _filtrar(String query) {
    setState(() {
      _resultadosFiltrados = widget.materiasPrimasExistentes.where((mp) => mp.data['nombre'].toString().toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Añadir Ingrediente'),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            TextField(
              onChanged: _filtrar,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Buscar materia prima...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _resultadosFiltrados.isEmpty
                  ? const Center(child: Text('No se encontraron resultados.'))
                  : ListView.builder(
                      itemCount: _resultadosFiltrados.length,
                      itemBuilder: (context, index) {
                        final mp = _resultadosFiltrados[index];
                        return ListTile(
                          title: Text(mp.data['nombre']),
                          onTap: () => Navigator.pop(context, mp),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      ],
    );
  }
}

// --- WIDGETS DE DIÁLOGO (COPIADOS DE LA PANTALLA DE EDICIÓN) ---

class _DialogoCrearReceta extends StatefulWidget {
  final List<RecordModel> materiasPrimas;
  final List<RecordModel> unidadesDeMedida;
  final Function(RecordModel) onIngredienteCreado;

  const _DialogoCrearReceta({
    required this.materiasPrimas,
    required this.unidadesDeMedida,
    required this.onIngredienteCreado,
  });

  @override
  State<_DialogoCrearReceta> createState() => _DialogoCrearRecetaState();
}

class _DialogoCrearRecetaState extends State<_DialogoCrearReceta> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  bool _guardando = false;
  Map<String, TextEditingController> _ingredientes = {};

  void _agregarIngrediente() async {
    final matPrimSeleccionada = await showDialog<RecordModel>(
        context: context,
        builder: (context) => SimpleDialog(
              title: const Text('Seleccionar Materia Prima'),
              children: [
                SimpleDialogOption(
                  onPressed: () async {
                    Navigator.pop(context);
                    final nuevoIngrediente = await showDialog<RecordModel>(
                      context: context,
                      builder: (_) => _DialogoCrearIngrediente(unidadesDeMedida: widget.unidadesDeMedida),
                    );
                    if (nuevoIngrediente != null) {
                      widget.onIngredienteCreado(nuevoIngrediente);
                      setState(() {
                         _ingredientes[nuevoIngrediente.id] = TextEditingController();
                      });
                    }
                  },
                  child: const ListTile(leading: Icon(Icons.add_circle_outline, color: Colors.blue), title: Text('Crear nuevo ingrediente')),
                ),
                const Divider(),
                ...widget.materiasPrimas
                    .map((mp) => SimpleDialogOption(onPressed: () => Navigator.pop(context, mp), child: Text(mp.data['nombre'])))
                    .toList(),
              ],
            ));

    if (matPrimSeleccionada != null && !_ingredientes.containsKey(matPrimSeleccionada.id)) {
      setState(() {
        _ingredientes[matPrimSeleccionada.id] = TextEditingController();
      });
    }
  }

  Future<void> _guardarReceta() async {
    if (!_formKey.currentState!.validate() || _ingredientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Completa el nombre y añade al menos un ingrediente.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    setState(() => _guardando = true);
    try {
      final nuevaReceta = await pb.collection('receta').create(body: {'nombre': _nombreCtrl.text.trim(), 'descripcion': _descripcionCtrl.text.trim()});
      for (final entry in _ingredientes.entries) {
        final cantidad = double.tryParse(entry.value.text) ?? 0.0;
        await pb.collection('receta_matPrim').create(body: {'id_receta': nuevaReceta.id, 'id_matPrim': entry.key, 'cantidad': cantidad});
      }
      if (mounted) Navigator.pop(context, nuevaReceta);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar receta: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear Nueva Receta'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre de la receta *'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
              TextFormField(controller: _descripcionCtrl, decoration: const InputDecoration(labelText: 'Descripción')),
              const Divider(height: 24),
              ..._ingredientes.entries.map((entry) {
                final matPrim = widget.materiasPrimas.firstWhere((mp) => mp.id == entry.key);
                
                // ✨ CAMBIO: Extraer la abreviatura de la unidad de medida
                String abreviatura = '';
                if (matPrim.expand.containsKey('id_unidMed') && matPrim.expand['id_unidMed']!.isNotEmpty) {
                  abreviatura = matPrim.expand['id_unidMed']!.first.data['abreviatura'] ?? '';
                }

                return Row(children: [
                  Expanded(child: Text(matPrim.data['nombre'])),
                  // La receta no tiene cantidades asociadas por que se asocia al producto en si
                  // SizedBox(width: 80, child: TextFormField(controller: entry.value, decoration: const InputDecoration(hintText: 'Cant.'), keyboardType: TextInputType.number)),
                  // ✨ CAMBIO: Añadir el texto de la abreviatura
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(abreviatura),
                  ),
                  IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => _ingredientes.remove(entry.key))),
                ]);
              }),
              TextButton.icon(onPressed: _agregarIngrediente, icon: const Icon(Icons.add), label: const Text('Añadir Ingrediente'))
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _guardando ? null : _guardarReceta, child: _guardando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar'))
      ],
    );
  }
}

class _DialogoCrearIngrediente extends StatefulWidget {
  final List<RecordModel> unidadesDeMedida;
  const _DialogoCrearIngrediente({required this.unidadesDeMedida});

  @override
  State<_DialogoCrearIngrediente> createState() => _DialogoCrearIngredienteState();
}

class _DialogoCrearIngredienteState extends State<_DialogoCrearIngrediente> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '0');
  String? _unidadMedidaId;
  bool _guardando = false;

  Future<void> _guardarIngrediente() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final nuevoIngrediente = await pb.collection('matPrim').create(body: {
        'nombre': _nombreCtrl.text.trim(),
        'stock': int.tryParse(_stockCtrl.text) ?? 0,
        'id_unidMed': _unidadMedidaId,
      });
      // ✨ CAMBIO: Se expande la unidad de medida al devolver el ingrediente creado
      final recordConExpand = await pb.collection('matPrim').getOne(nuevoIngrediente.id, expand: 'id_unidMed');
      if(mounted) Navigator.pop(context, recordConExpand);
    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar ingrediente: $e'), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear Nuevo Ingrediente'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre del ingrediente *'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
            const SizedBox(height: 16),
            TextFormField(controller: _stockCtrl, decoration: const InputDecoration(labelText: 'Stock Inicial'), keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _unidadMedidaId,
              items: widget.unidadesDeMedida.map((u) => DropdownMenuItem(value: u.id, child: Text(u.data['nombre']))).toList(),
              onChanged: (v) => setState(() => _unidadMedidaId = v),
              decoration: const InputDecoration(labelText: 'Unidad de Medida *'),
              validator: (v) => v == null ? 'Requerido' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _guardando ? null : _guardarIngrediente, child: _guardando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar')),
      ],
    );
  }
}