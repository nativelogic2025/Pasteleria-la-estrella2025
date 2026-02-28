import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Cliente global de Supabase (asegúrate de que esté inicializado en tu main.dart)
final supabase = Supabase.instance.client;

// --- MODELOS DE ESTADO PARA GESTIONAR LA UI ---

class IngredienteVarianteEditable {
  String? id; 
  final Map<String, dynamic> matPrim; // Registro de materia prima como Mapa
  final TextEditingController cantidadController;

  IngredienteVarianteEditable({
    this.id,
    required this.matPrim,
    required double cantidad,
  }) : cantidadController = TextEditingController(text: cantidad.toString());

  void dispose() => cantidadController.dispose();
}

class VarianteComplejaEditable {
  String? id; 
  bool isNew; 
  final TextEditingController skuController;
  final TextEditingController stockController;
  final TextEditingController precioController;

  List<IngredienteVarianteEditable> ingredientes = [];
  List<String> ingredientesAEliminar = []; 

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

class DetalleProductoGeneralScreen extends StatefulWidget {
  final Map<String, dynamic> producto; // Ahora recibe un Mapa
  const DetalleProductoGeneralScreen({super.key, required this.producto});

  @override
  State<DetalleProductoGeneralScreen> createState() =>
      _DetalleProductoGeneralScreenState();
}

class _DetalleProductoGeneralScreenState
    extends State<DetalleProductoGeneralScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nombreController;
  String? _categoriaSeleccionadaId;
  String? _recetaSeleccionadaId;
  Map<String, dynamic>? _recetaRelacionActual;

  Uint8List? _nuevaIconBytes;
  String? _nuevaIconFilename;
  bool _eliminarIconoActual = false;
  
  List<Map<String, dynamic>> _categoriasDisponibles = [];
  List<Map<String, dynamic>> _recetasDisponibles = [];
  final List<VarianteComplejaEditable> _variantes = [];
  final List<String> _variantesAEliminar = [];

  bool _productoManejaReceta = false;
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.producto['nombre']);
    _categoriaSeleccionadaId = widget.producto['id_categoria']?.toString();
    _cargarDatosCompletos();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    for (var v in _variantes) { v.dispose(); }
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
    _categoriasDisponibles = await supabase.from('categoria').select('*').order('nombre');
  }

  Future<void> _cargarRecetas() async {
    _recetasDisponibles = await supabase.from('receta').select('*').order('nombre');
  }
  
  Future<void> _cargarRelacionRecetaActual() async {
    final data = await supabase
        .from('producto_receta')
        .select('*')
        .eq('id_producto', widget.producto['id'])
        .maybeSingle();
    
    if (data != null) {
      _recetaRelacionActual = data;
      _recetaSeleccionadaId = data['id_receta']?.toString();
    }
  }

  Future<void> _cargarVariantesConIngredientes() async {
    final variantesRecords = await supabase
        .from('productoVariante')
        .select('*')
        .eq('id_producto', widget.producto['id'])
        .order('created_at');

    for (final vRecord in variantesRecords) {
      final varianteEditable = VarianteComplejaEditable(
        id: vRecord['id'].toString(),
        sku: vRecord['sku'] ?? '',
        stock: (vRecord['cantidadStock'] as num?)?.toInt() ?? 0,
        precio: (vRecord['precio_final'] as num?)?.toDouble() ?? 0.0,
      );

      if (_productoManejaReceta) {
        final ingredientesRecords = await supabase
            .from('variante_ingrediente')
            .select('*, id_matPrim(*, id_unidMed(*))')
            .eq('id_productoVariante', vRecord['id']);

        for (final iRecord in ingredientesRecords) {
          final matPrim = iRecord['id_matPrim'] as Map<String, dynamic>?;
          if (matPrim != null) {
            varianteEditable.ingredientes.add(IngredienteVarianteEditable(
              id: iRecord['id'].toString(),
              matPrim: matPrim,
              cantidad: (iRecord['cantidadNecesaria'] as num?)?.toDouble() ?? 0.0,
            ));
          }
        }
      }
      _variantes.add(varianteEditable);
    }
  }
  
  Future<void> _verificarSiProductoUsaReceta() async {
    if (_categoriaSeleccionadaId == null) {
      setState(() => _productoManejaReceta = false);
      return;
    }
    try {
      final categoriaRecord = _categoriasDisponibles.firstWhere((c) => c['id'].toString() == _categoriaSeleccionadaId);
      setState(() => _productoManejaReceta = categoriaRecord['receta'] ?? false);
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
        content: const Text('Esto reemplazará los ingredientes de todas las variantes. ¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continuar')),
        ],
      ),
    );

    if (confirmacion != true) return;

    setState(() { _cargando = true; _recetaSeleccionadaId = newRecetaId; });

    try {
      if (newRecetaId == null) {
        for (final v in _variantes) {
          for (final ing in v.ingredientes) { if (ing.id != null) v.ingredientesAEliminar.add(ing.id!); }
          v.ingredientes.clear();
        }
      } else {
        final nuevosIngBase = await supabase
            .from('receta_matPrim')
            .select('*, id_matPrim(*, id_unidMed(*))')
            .eq('id_receta', newRecetaId);

        for (final v in _variantes) {
          for (final ing in v.ingredientes) { if (ing.id != null) v.ingredientesAEliminar.add(ing.id!); }
          v.ingredientes.clear();

          for (final row in nuevosIngBase) {
            final matPrim = row['id_matPrim'] as Map<String, dynamic>?;
            if (matPrim != null) {
              v.ingredientes.add(IngredienteVarianteEditable(
                matPrim: matPrim,
                cantidad: (row['cantidad'] as num?)?.toDouble() ?? 0.0,
              ));
            }
          }
        }
      }
    } catch(e) {
      _mostrarError('Error al actualizar: $e');
    } finally {
      if(mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      String? iconPath = widget.producto['icon'];

      // 1. Manejo de Imagen en Storage
      if (_eliminarIconoActual) {
        iconPath = null;
      } else if (_nuevaIconBytes != null) {
        iconPath = 'icon_${DateTime.now().millisecondsSinceEpoch}.png';
        await supabase.storage.from('productos').uploadBinary(
          iconPath, 
          _nuevaIconBytes!,
          fileOptions: const FileOptions(contentType: 'image/png', upsert: true),
        );
      }

      // 2. Actualizar Producto
      await supabase.from('producto').update({
        'nombre': _nombreController.text,
        'id_categoria': _categoriaSeleccionadaId,
        'icon': iconPath,
      }).eq('id', widget.producto['id']);

      // 3. Relación de Receta
      if (_productoManejaReceta && _recetaSeleccionadaId != null) {
        await supabase.from('producto_receta').upsert({
          if (_recetaRelacionActual != null) 'id': _recetaRelacionActual!['id'],
          'id_producto': widget.producto['id'],
          'id_receta': _recetaSeleccionadaId,
        });
      } else if (_recetaRelacionActual != null) {
        await supabase.from('producto_receta').delete().eq('id', _recetaRelacionActual!['id']);
      }

      // 4. Variantes e Ingredientes
      for (final variante in _variantes) {
        final varData = {
          'id_producto': widget.producto['id'],
          'sku': variante.skuController.text,
          'cantidadStock': int.tryParse(variante.stockController.text) ?? 0,
          'precio_final': double.tryParse(variante.precioController.text.replaceAll(',', '.')) ?? 0.0,
        };

        dynamic vId;
        if (variante.isNew) {
          final res = await supabase.from('productoVariante').insert(varData).select().single();
          vId = res['id'];
        } else {
          vId = variante.id;
          await supabase.from('productoVariante').update(varData).eq('id', vId);
        }
        
        if (_productoManejaReceta) {
          for (final ing in variante.ingredientes) {
            final ingData = {
              'id_productoVariante': vId,
              'id_matPrim': ing.matPrim['id'],
              'cantidadNecesaria': double.tryParse(ing.cantidadController.text.replaceAll(',', '.')) ?? 0.0
            };
            if (ing.id == null) {
              await supabase.from('variante_ingrediente').insert(ingData);
            } else {
              await supabase.from('variante_ingrediente').update(ingData).eq('id', ing.id!);
            }
          }
          for (final idDel in variante.ingredientesAEliminar) {
            await supabase.from('variante_ingrediente').delete().eq('id', idDel);
          }
        }
      }

      for (final idVar in _variantesAEliminar) {
        await supabase.from('productoVariante').delete().eq('id', idVar);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _mostrarError('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
  
  Future<void> _eliminarProductoCompleto() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar producto?'),
        content: const Text('Se borrarán todas las variantes e ingredientes de forma permanente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Eliminar')),
        ],
      ),
    );

    if (ok != true) return;
    setState(() => _guardando = true);
    try {
      // En Supabase, si configuraste ON DELETE CASCADE en Postgres, 
      // solo necesitas borrar el producto base. 
      // Si no, borramos manual:
      final variantes = await supabase.from('productoVariante').select('id').eq('id_producto', widget.producto['id']);
      for (var v in variantes) {
        await supabase.from('variante_ingrediente').delete().eq('id_productoVariante', v['id']);
      }
      await supabase.from('productoVariante').delete().eq('id_producto', widget.producto['id']);
      await supabase.from('producto_receta').delete().eq('id_producto', widget.producto['id']);
      await supabase.from('producto').delete().eq('id', widget.producto['id']);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _mostrarError('Error al eliminar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _agregarNuevaVariante() async {
    setState(() => _cargando = true);
    final nuevaV = VarianteComplejaEditable(
      sku: _nombreController.text.trim(), stock: 0, precio: 0.0, isNew: true,
    );
    try {
      if (_recetaSeleccionadaId != null) {
        final rows = await supabase
            .from('receta_matPrim')
            .select('*, id_matPrim(*, id_unidMed(*))')
            .eq('id_receta', _recetaSeleccionadaId!);
        for (var row in rows) {
          final mp = row['id_matPrim'] as Map<String, dynamic>?;
          if (mp != null) {
            nuevaV.ingredientes.add(IngredienteVarianteEditable(
              matPrim: mp, cantidad: (row['cantidad'] as num?)?.toDouble() ?? 0.0,
            ));
          }
        }
      }
      _variantes.add(nuevaV);
    } catch(e) { _mostrarError('Error: $e'); }
    finally { if (mounted) setState(() => _cargando = false); }
  }

  void _eliminarVariante(int index) {
    final v = _variantes[index];
    if (!v.isNew && v.id != null) _variantesAEliminar.add(v.id!);
    setState(() { v.dispose(); _variantes.removeAt(index); });
  }

  void _agregarIngredienteAVariante(VarianteComplejaEditable variante) async {
    final Map<String, dynamic>? mp = await showDialog(
      context: context, 
      builder: (_) => const _DialogoBuscarMatPrim()
    );
    if (mp != null) {
      if (variante.ingredientes.any((i) => i.matPrim['id'] == mp['id'])) return;
      setState(() {
        variante.ingredientes.add(IngredienteVarianteEditable(matPrim: mp, cantidad: 0.0));
      });
    }
  }

  void _eliminarIngredienteDeVariante(VarianteComplejaEditable v, int idx) {
    final ing = v.ingredientes[idx];
    if (ing.id != null) v.ingredientesAEliminar.add(ing.id!);
    setState(() { ing.dispose(); v.ingredientes.removeAt(idx); });
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  // --- WIDGET BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edición de Producto'),
        actions: [
          IconButton(icon: const Icon(Icons.delete_forever, color: Colors.red), onPressed: _guardando ? null : _eliminarProductoCompleto),
          IconButton(icon: const Icon(Icons.save), onPressed: _guardando ? null : _guardarCambios)
        ],
      ),
      body: _cargando 
          ? const Center(child: CircularProgressIndicator())
          : _guardando 
              ? const Center(child: Text("Guardando..."))
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      _buildCardDatosGenerales(),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Variantes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          FilledButton(onPressed: _agregarNuevaVariante, child: const Text('Añadir'))
                        ],
                      ),
                      for (var i = 0; i < _variantes.length; i++)
                        _buildCardVariante(_variantes[i], i),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCardDatosGenerales() {
    String? iconUrl = widget.producto['icon'];
    if (iconUrl != null && iconUrl.isNotEmpty) {
      iconUrl = supabase.storage.from('productos').getPublicUrl(iconUrl);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          if (_nuevaIconBytes != null) Image.memory(_nuevaIconBytes!, height: 120)
          else if (!_eliminarIconoActual && iconUrl != null) Image.network(iconUrl, height: 120)
          else const Icon(Icons.image, size: 80),
          
          TextButton(
            onPressed: () async {
              final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
              if (res != null) setState(() { _nuevaIconBytes = res.files.single.bytes; _eliminarIconoActual = false; });
            }, 
            child: const Text("Cambiar imagen")
          ),
          
          TextFormField(controller: _nombreController, decoration: const InputDecoration(labelText: 'Nombre')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _categoriaSeleccionadaId,
            items: _categoriasDisponibles.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['nombre']))).toList(),
            onChanged: (v) => setState(() { _categoriaSeleccionadaId = v; _verificarSiProductoUsaReceta(); }),
            decoration: const InputDecoration(labelText: 'Categoría'),
          ),
          if (_productoManejaReceta)
            DropdownButtonFormField<String>(
              value: _recetaSeleccionadaId,
              items: [
                const DropdownMenuItem(value: null, child: Text('Ninguna')),
                ..._recetasDisponibles.map((r) => DropdownMenuItem(value: r['id'].toString(), child: Text(r['nombre']))),
              ],
              onChanged: _onRecipeChanged,
              decoration: const InputDecoration(labelText: 'Receta'),
            ),
        ]),
      ),
    );
  }

  Widget _buildCardVariante(VarianteComplejaEditable v, int idx) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Expanded(child: TextFormField(controller: v.skuController, decoration: const InputDecoration(labelText: 'SKU'))),
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _eliminarVariante(idx))
          ]),
          Row(children: [
            Expanded(child: TextFormField(controller: v.stockController, decoration: const InputDecoration(labelText: 'Stock'))),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(controller: v.precioController, decoration: const InputDecoration(labelText: 'Precio'))),
          ]),
          if (_productoManejaReceta) ...[
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("Ingredientes", style: TextStyle(fontWeight: FontWeight.bold)),
              TextButton(onPressed: () => _agregarIngredienteAVariante(v), child: const Text("Añadir"))
            ]),
            for (var j = 0; j < v.ingredientes.length; j++)
              Row(children: [
                Expanded(child: Text(v.ingredientes[j].matPrim['nombre'])),
                SizedBox(width: 80, child: TextFormField(controller: v.ingredientes[j].cantidadController)),
                IconButton(icon: const Icon(Icons.remove_circle), onPressed: () => _eliminarIngredienteDeVariante(v, j))
              ])
          ]
        ]),
      ),
    );
  }
}

class _DialogoBuscarMatPrim extends StatefulWidget {
  const _DialogoBuscarMatPrim();
  @override
  State<_DialogoBuscarMatPrim> createState() => _DialogoBuscarMatPrimState();
}

class _DialogoBuscarMatPrimState extends State<_DialogoBuscarMatPrim> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  _load() async {
    final data = await supabase.from('matPrim').select('*').order('nombre');
    setState(() { _items = List<Map<String, dynamic>>.from(data); _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buscar ingrediente'),
      content: SizedBox(
        height: 300, width: 300,
        child: _loading ? const CircularProgressIndicator() : ListView(
          children: _items.map((i) => ListTile(title: Text(i['nombre']), onTap: () => Navigator.pop(context, i))).toList(),
        ),
      ),
    );
  }
}