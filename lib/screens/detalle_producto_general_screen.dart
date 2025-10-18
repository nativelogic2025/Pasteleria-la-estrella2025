import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'pb_client.dart';

// --- MODELOS DE ESTADO PARA GESTIONAR LA UI ---

class IngredienteVarianteEditable {
  String? id; // ID del registro en 'variante_ingrediente'
  final RecordModel matPrim; // Registro completo de la materia prima
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
  String? id; // ID del registro en 'productoVariante'
  bool isNew; // Para saber si es una variante recién añadida en la UI
  final TextEditingController skuController;
  final TextEditingController stockController;
  final TextEditingController precioController;

  List<IngredienteVarianteEditable> ingredientes = [];
  List<String> ingredientesAEliminar = []; // IDs de 'variante_ingrediente' a borrar

  VarianteComplejaEditable({
    this.id,
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

class DetalleProductoGeneralScreen extends StatefulWidget {
  final RecordModel producto;
  const DetalleProductoGeneralScreen({super.key, required this.producto});

  @override
  State<DetalleProductoGeneralScreen> createState() =>
      _DetalleProductoGeneralScreenState();
}

class _DetalleProductoGeneralScreenState
    extends State<DetalleProductoGeneralScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores para Producto Base
  late TextEditingController _nombreController;
  String? _categoriaSeleccionadaId;
  String? _recetaSeleccionadaId;
  RecordModel? _recetaRelacionActual;

  // State para la Imagen
  Uint8List? _nuevaIconBytes;
  String? _nuevaIconFilename;
  bool _eliminarIconoActual = false;
  
  // Listas de datos y estados
  List<RecordModel> _categoriasDisponibles = [];
  List<RecordModel> _recetasDisponibles = [];
  final List<VarianteComplejaEditable> _variantes = [];
  final List<String> _variantesAEliminar = [];

  bool _productoManejaReceta = false;
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.producto.data['nombre']);
    _categoriaSeleccionadaId = widget.producto.data['id_categoria'];
    _cargarDatosCompletos();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    for (var v in _variantes) {
      v.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarDatosCompletos() async {
    setState(() => _cargando = true);
    try {
      await Future.wait([
        _cargarCategorias(),
        _cargarRecetas(),
        _cargarRelacionRecetaActual(),
      ]);
      await _verificarSiProductoUsaReceta();
      await _cargarVariantesConIngredientes();

    } catch (e) {
      _mostrarError('Error al cargar los datos: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }
  
  Future<void> _cargarCategorias() async {
    _categoriasDisponibles = await pb.collection('categoria').getFullList(sort: 'nombre');
  }

  Future<void> _cargarRecetas() async {
    _recetasDisponibles = await pb.collection('receta').getFullList(sort: 'nombre');
  }
  
  Future<void> _cargarRelacionRecetaActual() async {
    try {
      _recetaRelacionActual = await pb.collection('producto_receta').getFirstListItem('id_producto = "${widget.producto.id}"');
      _recetaSeleccionadaId = _recetaRelacionActual?.data['id_receta'];
    } on ClientException {
      _recetaRelacionActual = null;
      _recetaSeleccionadaId = null;
    }
  }

  Future<void> _cargarVariantesConIngredientes() async {
    final variantesRecords = await pb.collection('productoVariante').getFullList(
          filter: 'id_producto = "${widget.producto.id}"',
          sort: 'created',
        );

    for (final vRecord in variantesRecords) {
      final varianteEditable = VarianteComplejaEditable(
        id: vRecord.id,
        sku: vRecord.data['sku'] ?? '',
        stock: (vRecord.data['cantidadStock'] as num?)?.toInt() ?? 0,
        precio: (vRecord.data['precio_final'] as num?)?.toDouble() ?? 0.0,
      );

      if (_productoManejaReceta) {
        final ingredientesRecords =
            await pb.collection('variante_ingrediente').getFullList(
                  filter: 'id_productoVariante = "${vRecord.id}"',
                  expand: 'id_matPrim, id_matPrim.id_unidMed',
                );

        for (final iRecord in ingredientesRecords) {
          final matPrim = iRecord.expand['id_matPrim']?.first;
          if (matPrim != null) {
            varianteEditable.ingredientes.add(IngredienteVarianteEditable(
              id: iRecord.id,
              matPrim: matPrim,
              cantidad: (iRecord.data['cantidadNecesaria'] as num?)?.toDouble() ?? 0.0,
            ));
          }
        }
      }
      _variantes.add(varianteEditable);
    }
  }
  
  Future<void> _onCategoryChanged(String? newId) async {
    setState(() {
      _categoriaSeleccionadaId = newId;
      _verificarSiProductoUsaReceta();
    });
  }

  Future<void> _verificarSiProductoUsaReceta() async {
    if (_categoriaSeleccionadaId == null) {
      setState(() => _productoManejaReceta = false);
      return;
    }
    try {
      final categoriaRecord = _categoriasDisponibles.firstWhere((c) => c.id == _categoriaSeleccionadaId);
      setState(() => _productoManejaReceta = categoriaRecord.data['receta'] ?? false);
    } catch (e) {
      setState(() => _productoManejaReceta = false);
    }
  }
  
  Future<void> _onRecipeChanged(String? newRecetaId) async {
    if (newRecetaId == _recetaSeleccionadaId) return;

    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar Receta Maestra'),
        content: const Text('Esto reemplazará todos los ingredientes de las variantes existentes con los de la nueva receta. ¿Deseas continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continuar')),
        ],
      ),
    );

    if (confirmacion != true) return;

    setState(() {
      _cargando = true;
      _recetaSeleccionadaId = newRecetaId;
    });

    try {
      if (newRecetaId == null) {
        for (final variante in _variantes) {
          for (final ing in variante.ingredientes) {
            if (ing.id != null) variante.ingredientesAEliminar.add(ing.id!);
          }
          variante.ingredientes.clear();
        }
      } else {
        final nuevosIngredientesBase = await pb.collection('receta_matPrim').getFullList(
          filter: 'id_receta = "$newRecetaId"',
          expand: 'id_matPrim,id_matPrim.id_unidMed',
        );

        for (final variante in _variantes) {
          for (final ing in variante.ingredientes) {
            if (ing.id != null) variante.ingredientesAEliminar.add(ing.id!);
          }
          variante.ingredientes.clear();

          for (final nuevoIngBase in nuevosIngredientesBase) {
            final matPrim = nuevoIngBase.expand['id_matPrim']?.first;
            final cantidadBase = (nuevoIngBase.data['cantidad'] as num?)?.toDouble() ?? 0.0;
            if (matPrim != null) {
              variante.ingredientes.add(IngredienteVarianteEditable(
                matPrim: matPrim,
                cantidad: cantidadBase,
              ));
            }
          }
        }
      }
    } catch(e) {
      _mostrarError('Error al actualizar ingredientes: $e');
    } finally {
      if(mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) {
      _mostrarError('Por favor, corrige los errores en el formulario.');
      return;
    }

    setState(() => _guardando = true);
    try {
      final bodyProducto = <String, dynamic>{
        'nombre': _nombreController.text,
        'id_categoria': _categoriaSeleccionadaId,
      };
      final files = <http.MultipartFile>[];
      if (_eliminarIconoActual) {
        bodyProducto['icon'] = null;
      } else if (_nuevaIconBytes != null && _nuevaIconFilename != null) {
        files.add(http.MultipartFile.fromBytes('icon', _nuevaIconBytes!, filename: _nuevaIconFilename!));
      }
      await pb.collection('producto').update(widget.producto.id, body: bodyProducto, files: files);

      if (_productoManejaReceta) {
        if (_recetaSeleccionadaId != null) {
          final bodyRecetaRel = {'id_producto': widget.producto.id, 'id_receta': _recetaSeleccionadaId};
          if (_recetaRelacionActual != null) {
            await pb.collection('producto_receta').update(_recetaRelacionActual!.id, body: bodyRecetaRel);
          } else {
            final nuevaRelacion = await pb.collection('producto_receta').create(body: bodyRecetaRel);
            _recetaRelacionActual = nuevaRelacion;
          }
        } else if (_recetaRelacionActual != null) {
          await pb.collection('producto_receta').delete(_recetaRelacionActual!.id);
          _recetaRelacionActual = null;
        }
      } else if (_recetaRelacionActual != null) {
        await pb.collection('producto_receta').delete(_recetaRelacionActual!.id);
        _recetaRelacionActual = null;
      }

      for (final variante in _variantes) {
        String productoVarianteId;
        final bodyVariante = {
          'id_producto': widget.producto.id,
          'sku': variante.skuController.text,
          'cantidadStock': int.tryParse(variante.stockController.text) ?? 0,
          'precio_final': double.tryParse(variante.precioController.text.replaceAll(',', '.')) ?? 0.0,
        };

        if (variante.isNew) {
          final nuevaVarianteRecord = await pb.collection('productoVariante').create(body: bodyVariante);
          productoVarianteId = nuevaVarianteRecord.id;
        } else {
          await pb.collection('productoVariante').update(variante.id!, body: bodyVariante);
          productoVarianteId = variante.id!;
        }
        
        if (_productoManejaReceta) {
            for (final ingrediente in variante.ingredientes) {
                final bodyIngrediente = {
                    'id_productoVariante': productoVarianteId,
                    'id_matPrim': ingrediente.matPrim.id,
                    'cantidadNecesaria': double.tryParse(ingrediente.cantidadController.text.replaceAll(',', '.')) ?? 0.0
                };
                if (ingrediente.id == null) {
                    await pb.collection('variante_ingrediente').create(body: bodyIngrediente);
                } else {
                    await pb.collection('variante_ingrediente').update(ingrediente.id!, body: bodyIngrediente);
                }
            }
            for (final idIngrediente in variante.ingredientesAEliminar) {
                await pb.collection('variante_ingrediente').delete(idIngrediente);
            }
            variante.ingredientesAEliminar.clear();
        }
      }

      for (final idVariante in _variantesAEliminar) {
        await pb.collection('productoVariante').delete(idVariante);
      }
      _variantesAEliminar.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado con éxito'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      _mostrarError('Error al guardar los datos: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
  
  // detalle_producto_general_screen.dart
  Future<void> _eliminarProductoCompleto() async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text(
            '¿Estás seguro de que quieres eliminar "${widget.producto.data['nombre']}" y TODAS sus variantes? Esta acción es irreversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar Definitivamente'),
          ),
        ],
      ),
    );

    if (confirmacion != true) return;

    setState(() => _guardando = true);
    try {
      final productoId = widget.producto.id;

      // 1. Obtener todos los registros relacionados que necesitamos eliminar.
      final variantes = await pb.collection('productoVariante').getFullList(filter: 'id_producto = "$productoId"');
      final recetasRel = await pb.collection('producto_receta').getFullList(filter: 'id_producto = "$productoId"');

      // 2. Crear una lista para todas las operaciones de borrado (Futures).
      final deleteFutures = <Future>[];

      // 3. Añadir a la lista las operaciones para eliminar los ingredientes de cada variante.
      for (final variante in variantes) {
        final ingredientes = await pb.collection('variante_ingrediente').getFullList(
              filter: 'id_productoVariante = "${variante.id}"',
              // Solo necesitamos los IDs, así que pedimos un solo campo para ser más eficientes.
              fields: 'id', 
            );
        for (final ingrediente in ingredientes) {
          deleteFutures.add(pb.collection('variante_ingrediente').delete(ingrediente.id));
        }
      }

      // 4. Añadir las operaciones para eliminar las variantes y las relaciones de receta.
      for (final variante in variantes) {
        deleteFutures.add(pb.collection('productoVariante').delete(variante.id));
      }
      for (final rel in recetasRel) {
        deleteFutures.add(pb.collection('producto_receta').delete(rel.id));
      }

      // 5. Ejecutar todas las eliminaciones de dependencias en paralelo.
      await Future.wait(deleteFutures);

      // 6. Finalmente, una vez que todo lo demás se ha borrado, eliminamos el producto principal.
      await pb.collection('producto').delete(productoId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Producto eliminado con éxito'), backgroundColor: Colors.green));
        // Regresa a la pantalla anterior notificando que hubo un cambio.
        Navigator.pop(context, true);
      }
    } catch (e) {
      _mostrarError('Ocurrió un error al eliminar el producto: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
  // ✨ --- LÓGICA PARA AÑADIR/QUITAR VARIANTES E INGREDIENTES --- ✨

  /// Añade una nueva variante a la UI. Si el producto maneja una receta,
  /// precarga la variante con los ingredientes de esa receta.
  Future<void> _agregarNuevaVariante() async {
    setState(() => _cargando = true);
    
    final nuevaVariante = VarianteComplejaEditable(
      sku: _nombreController.text.trim(), 
      stock: 0, 
      precio: 0.0, 
      isNew: true,
    );

    try {
      // Si hay una receta seleccionada, cargamos sus ingredientes base.
      if (_recetaSeleccionadaId != null) {
        final ingredientesBase = await pb.collection('receta_matPrim').getFullList(
          filter: 'id_receta = "$_recetaSeleccionadaId"',
          expand: 'id_matPrim,id_matPrim.id_unidMed',
        );

        for (final ingBase in ingredientesBase) {
          final matPrim = ingBase.expand['id_matPrim']?.first;
          if (matPrim != null) {
            nuevaVariante.ingredientes.add(IngredienteVarianteEditable(
              matPrim: matPrim,
              cantidad: (ingBase.data['cantidad'] as num?)?.toDouble() ?? 0.0,
            ));
          }
        }
      }
      _variantes.add(nuevaVariante);
    } catch(e) {
        _mostrarError('No se pudieron cargar los ingredientes base: $e');
    } finally {
        if (mounted) setState(() => _cargando = false);
    }
  }

  /// Elimina una variante de la UI y la marca para ser eliminada de la DB al guardar.
  void _eliminarVariante(int index) {
    final variante = _variantes[index];
    if (!variante.isNew && variante.id != null) {
      _variantesAEliminar.add(variante.id!);
    }
    setState(() {
      variante.dispose();
      _variantes.removeAt(index);
    });
  }

  /// Abre un diálogo para buscar y añadir un nuevo ingrediente a una variante específica.
  void _agregarIngredienteAVariante(VarianteComplejaEditable variante) async {
    final RecordModel? matPrimSeleccionada = await showDialog(
      context: context, 
      builder: (_) => const _DialogoBuscarMatPrim()
    );

    if (matPrimSeleccionada != null) {
      // Evitar añadir duplicados
      if (variante.ingredientes.any((ing) => ing.matPrim.id == matPrimSeleccionada.id)) {
        _mostrarError('Este ingrediente ya está en la lista.');
        return;
      }
      setState(() {
        variante.ingredientes.add(IngredienteVarianteEditable(matPrim: matPrimSeleccionada, cantidad: 0.0));
      });
    }
  }

  /// Elimina un ingrediente de una variante específica en la UI y lo marca para ser eliminado de la DB.
  void _eliminarIngredienteDeVariante(VarianteComplejaEditable variante, int ingIndex) {
    final ingrediente = variante.ingredientes[ingIndex];
    if (ingrediente.id != null) {
      variante.ingredientesAEliminar.add(ingrediente.id!);
    }
    setState(() {
      ingrediente.dispose();
      variante.ingredientes.removeAt(ingIndex);
    });
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: Colors.red));
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _nuevaIconBytes = result.files.single.bytes;
        _nuevaIconFilename = result.files.single.name;
        _eliminarIconoActual = false;
      });
    }
  }

  String? _currentIconUrl() {
    final file = widget.producto.data['icon'];
    if (file == null || file.toString().isEmpty) return null;
    return pb.files.getUrl(widget.producto, file).toString();
  }

  // --- WIDGET BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edición Completa de Producto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _guardando ? null : _eliminarProductoCompleto,
            tooltip: 'Eliminar Producto Completo',
            color: Colors.red,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _guardando ? null : _guardarCambios,
            tooltip: 'Guardar Cambios',
          )
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _guardando
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,children: [CircularProgressIndicator(), SizedBox(height: 16), Text("Guardando cambios...")]))
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      _buildCardDatosGenerales(),
                      const Divider(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Variantes (SKU)', style: Theme.of(context).textTheme.titleLarge),
                          FilledButton.tonal(onPressed: _agregarNuevaVariante, child: const Text('Añadir Variante'))
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_variantes.isEmpty)
                        const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('Este producto no tiene variantes.')))
                      else
                        for (var i = 0; i < _variantes.length; i++)
                          _buildCardVariante(_variantes[i], i),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCardDatosGenerales() {
    Widget imageWidget;
    if (_nuevaIconBytes != null) {
      imageWidget = Image.memory(_nuevaIconBytes!, height: 150, fit: BoxFit.cover);
    } else if (_eliminarIconoActual) {
      imageWidget = const Icon(Icons.image_not_supported, size: 100, color: Colors.grey);
    } else if (_currentIconUrl() != null) {
      imageWidget = Image.network(_currentIconUrl()!, height: 150, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 100, color: Colors.red));
    } else {
      imageWidget = const Icon(Icons.image, size: 100, color: Colors.grey);
    }
    
    final idCategoriaValido = _categoriasDisponibles.any((cat) => cat.id == _categoriaSeleccionadaId);
    final idRecetaValido = _recetasDisponibles.any((rec) => rec.id == _recetaSeleccionadaId);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Datos Generales', style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 24),
            
            Center(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: double.infinity, height: 150, child: Center(child: imageWidget)))),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              OutlinedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.image_outlined), label: Text(_nuevaIconBytes == null ? 'Seleccionar' : 'Cambiar')),
              if (!_eliminarIconoActual && (_currentIconUrl() != null || _nuevaIconBytes != null)) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(onPressed: () => setState(() { _eliminarIconoActual = true; _nuevaIconBytes = null; _nuevaIconFilename = null; }), icon: const Icon(Icons.delete_forever, color: Colors.red), label: const Text('Eliminar'), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), foregroundColor: Colors.red)),
              ]
            ]),
            const SizedBox(height: 24),

            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Nombre del Producto', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: idCategoriaValido ? _categoriaSeleccionadaId : null,
              items: _categoriasDisponibles.map((c) => DropdownMenuItem(value: c.id, child: Text(c.data['nombre']))).toList(),
              onChanged: _onCategoryChanged,
              decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
              validator: (v) => v == null ? 'Requerido' : null,
            ),
            
            if (_productoManejaReceta) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: idRecetaValido ? _recetaSeleccionadaId : null,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Ninguna', style: TextStyle(fontStyle: FontStyle.italic))),
                  ..._recetasDisponibles.map((r) => DropdownMenuItem(value: r.id, child: Text(r.data['nombre']))),
                ],
                onChanged: _onRecipeChanged,
                decoration: const InputDecoration(labelText: 'Receta Asociada', border: OutlineInputBorder()),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildCardVariante(VarianteComplejaEditable variante, int index) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text('Variante ${index + 1}', style: Theme.of(context).textTheme.titleMedium)),
              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _eliminarVariante(index), tooltip: 'Eliminar esta Variante')
            ]),
            const SizedBox(height: 10),
            TextFormField(
              controller: variante.skuController,
              decoration: const InputDecoration(labelText: 'SKU / Nombre de Variante'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: variante.stockController, decoration: const InputDecoration(labelText: 'Stock', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: variante.precioController, decoration: const InputDecoration(labelText: 'Precio', prefixText: '\$ ', border: OutlineInputBorder()), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
            ]),
            
            if (_productoManejaReceta) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ingredientes de esta Variante', style: TextStyle(fontWeight: FontWeight.bold)),
                  // ✨ Botón para añadir un ingrediente nuevo a esta variante
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
          // ✨ Botón "X" para quitar este ingrediente de la variante
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

// ✨ --- NUEVO WIDGET: DIÁLOGO PARA BUSCAR MATERIA PRIMA --- ✨
class _DialogoBuscarMatPrim extends StatefulWidget {
  const _DialogoBuscarMatPrim();

  @override
  State<_DialogoBuscarMatPrim> createState() => _DialogoBuscarMatPrimState();
}

class _DialogoBuscarMatPrimState extends State<_DialogoBuscarMatPrim> {
  List<RecordModel> _materiasPrimas = [];
  List<RecordModel> _resultadosFiltrados = [];
  bool _cargando = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _cargarMateriasPrimas();
  }

  Future<void> _cargarMateriasPrimas() async {
    try {
      final records = await pb.collection('matPrim').getFullList(sort: 'nombre', expand: 'id_unidMed');
      if (mounted) {
        setState(() {
          _materiasPrimas = records;
          _resultadosFiltrados = records;
          _cargando = false;
        });
      }
    } catch (e) {
      if(mounted) {
          setState(() {
              _error = 'No se pudieron cargar las materias primas.';
              _cargando = false;
          });
      }
    }
  }

  void _filtrar(String query) {
    setState(() {
      _resultadosFiltrados = _materiasPrimas.where((mp) => mp.data['nombre'].toString().toLowerCase().contains(query.toLowerCase())).toList();
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
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _error.isNotEmpty
                      ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
                      : _resultadosFiltrados.isEmpty
                          ? const Center(child: Text('No se encontraron resultados.'))
                          : ListView.builder(
                              itemCount: _resultadosFiltrados.length,
                              itemBuilder: (context, index) {
                                final mp = _resultadosFiltrados[index];
                                return ListTile(
                                  title: Text(mp.data['nombre']),
                                  onTap: () {
                                    Navigator.pop(context, mp);
                                  },
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