import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'pb_client.dart';
import 'receta_detalle_screen.dart';

class CatalogoScreen extends StatefulWidget {
  const CatalogoScreen({super.key});

  @override
  State<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen> {
  List<RecordModel> _recetasDisponibles = [];
  List<RecordModel> _materiasPrimasDisponibles = [];
  List<RecordModel> _unidadesDeMedida = [];
  bool _cargandoDatos = true;

  @override
  void initState() {
    super.initState();
    _inicializarDatos();
  }

  /// Carga todos los datos necesarios para la pantalla de una sola vez.
  Future<void> _inicializarDatos() async {
    try {
      final results = await Future.wait([
        pb.collection('receta').getFullList(sort: 'nombre'),
        pb.collection('matPrim').getFullList(sort: 'nombre', expand: 'id_unidMed'),
        pb.collection('unidMed').getFullList(sort: 'nombre'),
      ]);

      if (mounted) {
        setState(() {
          _recetasDisponibles = results[0];
          _materiasPrimasDisponibles = results[1];
          _unidadesDeMedida = results[2];
          _cargandoDatos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargandoDatos = false);
        _mostrarError('Error al inicializar los datos: $e');
      }
    }
  }

  void _mostrarError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  /// Muestra un diálogo para añadir una nueva receta.
  Future<void> _mostrarDialogoCrearReceta() async {
    final nuevaReceta = await showDialog<RecordModel>(
        context: context,
        builder: (context) => _DialogoCrearReceta(
              materiasPrimas: _materiasPrimasDisponibles,
              unidadesDeMedida: _unidadesDeMedida,
              onIngredienteCreado: (nuevoIngrediente) {
                setState(() {
                  _materiasPrimasDisponibles.add(nuevoIngrediente);
                  _materiasPrimasDisponibles.sort((a, b) => (a.data['nombre'] ?? '').compareTo(b.data['nombre'] ?? ''));
                });
              },
            ));

    if (nuevaReceta != null && mounted) {
      setState(() {
        _recetasDisponibles.add(nuevaReceta);
        _recetasDisponibles.sort((a, b) => (a.data['nombre'] ?? '').toLowerCase().compareTo((b.data['nombre'] ?? '').toLowerCase()));
      });
    }
  }

  /// Lógica para eliminar una receta, con validación previa.
  Future<void> _eliminarReceta(RecordModel receta) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text('¿Estás seguro de que deseas eliminar la receta "${receta.data['nombre']}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final result = await pb.collection('producto_receta').getList(page: 1, perPage: 1, filter: 'id_receta = "${receta.id}"');

      if (result.items.isNotEmpty) {
        if (mounted) _mostrarError('No se puede eliminar: La receta está en uso por al menos un producto.');
        return;
      }

      final ingredientesAsociados = await pb.collection('receta_matPrim').getFullList(filter: 'id_receta = "${receta.id}"');

      // ✨ MEJORA: Se ejecutan todas las eliminaciones en paralelo para mayor eficiencia.
      final deleteFutures = <Future>[];
      for (final ingrediente in ingredientesAsociados) {
        deleteFutures.add(pb.collection('receta_matPrim').delete(ingrediente.id));
      }
      await Future.wait(deleteFutures);
      
      await pb.collection('receta').delete(receta.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receta eliminada correctamente'), backgroundColor: Colors.green),
        );
        // ✨ CORRECCIÓN: Se elimina la receta de la lista local y se actualiza la UI.
        setState(() {
          _recetasDisponibles.removeWhere((r) => r.id == receta.id);
        });
      }
    } catch (e) {
      _mostrarError('Error inesperado al eliminar: $e');
    }
  }

  // ✨ COMPLETADO: Se construye el widget principal basado en el estado de carga y la lista de recetas.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Recetas'),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogoCrearReceta,
        tooltip: 'Añadir Receta',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_cargandoDatos) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_recetasDisponibles.isEmpty) {
      return const Center(
        child: Text('No hay recetas creadas.\n¡Añade una para empezar!',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey)),
      );
    }
    return ListView.builder(
      itemCount: _recetasDisponibles.length,
      itemBuilder: (context, index) {
        final receta = _recetasDisponibles[index];
        final nombreReceta = receta.data['nombre']?.toString() ?? 'Receta sin nombre';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            title: Text(nombreReceta),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RecetaDetalleScreen(receta: receta)),
              );
            },
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _eliminarReceta(receta),
            ),
          ),
        );
      },
    );
  }
}

// --- WIDGETS DE DIÁLOGO ---

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
  bool _guardando = false;
  final Map<String, TextEditingController> _ingredientes = {};

  // ✨ --- NUEVO ESTADO PARA MANEJAR EL PDF --- ✨
  Uint8List? _pdfBytes;
  String? _pdfFilename;

  void _agregarIngrediente() async {
    final matPrimSeleccionada = await showDialog<RecordModel>(
        context: context,
        builder: (context) => SimpleDialog(
              title: const Text('Seleccionar Materia Prima'),
              children: [
                SimpleDialogOption(
                  onPressed: () async {
                    Navigator.pop(context); // Cierra el diálogo de selección
                    final nuevoIngrediente = await showDialog<RecordModel>(
                      context: context,
                      builder: (_) => _DialogoCrearIngrediente(unidadesDeMedida: widget.unidadesDeMedida),
                    );
                    if (nuevoIngrediente != null) {
                      widget.onIngredienteCreado(nuevoIngrediente);
                      // Añade el nuevo ingrediente a la lista de la receta actual.
                      setState(() {
                         _ingredientes[nuevoIngrediente.id] = TextEditingController();
                      });
                    }
                  },
                  child: const ListTile(leading: Icon(Icons.add_circle_outline, color: Colors.blue), title: Text('Crear nuevo ingrediente')),
                ),
                const Divider(),
                ...widget.materiasPrimas
                    .where((mp) => !_ingredientes.containsKey(mp.id)) // No mostrar ingredientes ya añadidos
                    .map((mp) => SimpleDialogOption(onPressed: () => Navigator.pop(context, mp), child: Text(mp.data['nombre'])))
                    ,
              ],
            ));

    if (matPrimSeleccionada != null && !_ingredientes.containsKey(matPrimSeleccionada.id)) {
      setState(() {
        _ingredientes[matPrimSeleccionada.id] = TextEditingController();
      });
    }
  }

  // ✨ --- NUEVA FUNCIÓN PARA SELECCIONAR EL PDF --- ✨
  Future<void> _seleccionarPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true, // Importante para compatibilidad web
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _pdfBytes = result.files.single.bytes;
        _pdfFilename = result.files.single.name;
      });
    }
  }

  // ✨ --- FUNCIÓN DE GUARDADO MODIFICADA --- ✨
  Future<void> _guardarReceta() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_ingredientes.isEmpty) {
      _mostrarError('Debes añadir al menos un ingrediente.');
      return;
    }

    setState(() => _guardando = true);

    try {
      final body = {'nombre': _nombreCtrl.text.trim()};
      final files = <http.MultipartFile>[];

      // Si se seleccionó un PDF, lo añadimos a la lista de archivos para subir
      if (_pdfBytes != null && _pdfFilename != null) {
        files.add(http.MultipartFile.fromBytes(
          'descripcion', // El nombre del campo en PocketBase
          _pdfBytes!,
          filename: _pdfFilename!,
        ));
      }

      final nuevaReceta = await pb.collection('receta').create(body: body, files: files);
      
      final crearIngredientesFutures = <Future>[];
      for (final entry in _ingredientes.entries) {
        final cantidad = double.tryParse(entry.value.text.replaceAll(',', '.')) ?? 0.0;
        crearIngredientesFutures.add(
          pb.collection('receta_matPrim').create(body: {
            'id_receta': nuevaReceta.id, 
            'id_matPrim': entry.key, 
            'cantidad': cantidad
          })
        );
      }
      await Future.wait(crearIngredientesFutures);
      
      if (mounted) Navigator.pop(context, nuevaReceta);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar receta: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _mostrarError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.orange));
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _ingredientes.forEach((_, controller) => controller.dispose());
    super.dispose();
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre de la receta *', border: OutlineInputBorder()), validator: (v) => v!.trim().isEmpty ? 'Requerido' : null),
              
              // ✨ --- NUEVA UI PARA SUBIR EL PDF --- ✨
              const SizedBox(height: 16),
              const Text('Procedimiento (Opcional)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                color: Colors.grey.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      if (_pdfBytes != null)
                        ListTile(
                          leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                          title: Text(_pdfFilename ?? "Archivo", overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() {
                              _pdfBytes = null;
                              _pdfFilename = null;
                            }),
                          ),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: _seleccionarPdf,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Seleccionar PDF'),
                        ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 24),
              const Text('Ingredientes', style: TextStyle(fontWeight: FontWeight.bold)),
              
              // ✨ --- WIDGET DE INGREDIENTE CORREGIDO --- ✨
              ..._ingredientes.entries.map((entry) {
                final matPrim = widget.materiasPrimas.firstWhere((mp) => mp.id == entry.key);
                final unidMed = matPrim.expand['id_unidMed']?.first;
                final abreviatura = unidMed?.data['abreviatura'] ?? '-';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(children: [
                    Expanded(child: Text(matPrim.data['nombre'])),
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        controller: entry.value,
                        decoration: const InputDecoration(hintText: 'Cant.'),
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Req.';
                          if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Inv.';
                          return null;
                        },
                      ),
                    ),
                    SizedBox(width: 40, child: Text(abreviatura, textAlign: TextAlign.center)),
                    IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => setState(() => _ingredientes.remove(entry.key))),
                  ]),
                );
              }),
              const SizedBox(height: 8),
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
        'stock': num.tryParse(_stockCtrl.text.replaceAll(',', '.')) ?? 0,
        'id_unidMed': _unidadMedidaId,
      });
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
            TextFormField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre del ingrediente *'), validator: (v) => v!.trim().isEmpty ? 'Requerido' : null),
            const SizedBox(height: 16),
            TextFormField(controller: _stockCtrl, decoration: const InputDecoration(labelText: 'Stock Inicial'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _unidadMedidaId,
              items: widget.unidadesDeMedida.map((u) => DropdownMenuItem(value: u.id, child: Text(u.data['nombre']))).toList(),
              onChanged: (v) => setState(() => _unidadMedidaId = v),
              decoration: const InputDecoration(labelText: 'Unidad de Medida *', border: OutlineInputBorder()),
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