// catalogo_recetas.dart
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'pb_client.dart';
import 'receta_detalle_screen.dart';

class CatalogoRecetasScreen extends StatefulWidget {
  const CatalogoRecetasScreen({super.key});

  @override
  State<CatalogoRecetasScreen> createState() => _CatalogoRecetasScreenState();
}

class _CatalogoRecetasScreenState extends State<CatalogoRecetasScreen> {
  // Datos
  List<RecordModel> _recetasDisponibles = [];
  List<RecordModel> _materiasPrimasDisponibles = [];
  List<RecordModel> _unidadesDeMedida = [];

  // Estado
  bool _cargandoDatos = true;
  bool _refrescando = false;

  // Búsqueda local (no pega al servidor)
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _inicializarDatos();
    _searchCtrl.addListener(() {
      if (!mounted) return;
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Carga todos los datos necesarios para la pantalla de una sola vez.
  Future<void> _inicializarDatos() async {
    try {
      final results = await Future.wait<List<RecordModel>>([
        pb.collection('receta').getFullList(sort: 'nombre'),
        pb.collection('matPrim').getFullList(sort: 'nombre', expand: 'id_unidMed'),
        pb.collection('unidMed').getFullList(sort: 'nombre'),
      ]);

      if (!mounted) return;
      setState(() {
        _recetasDisponibles = results[0];
        _materiasPrimasDisponibles = results[1];
        _unidadesDeMedida = results[2];
        _cargandoDatos = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoDatos = false);
      _mostrarSnack('Error al inicializar los datos: $e', isError: true);
    }
  }

  Future<void> _refrescar() async {
    if (_refrescando) return;
    _refrescando = true;
    try {
      final recetas = await pb.collection('receta').getFullList(sort: 'nombre');
      if (!mounted) return;
      setState(() => _recetasDisponibles = recetas);
    } catch (e) {
      if (mounted) _mostrarSnack('No se pudo actualizar: $e', isError: true);
    } finally {
      _refrescando = false;
    }
  }

  void _mostrarSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  /// Muestra el diálogo para crear receta (con PDF opcional).
  Future<void> _mostrarDialogoCrearReceta() async {
    final nuevaReceta = await showDialog<RecordModel>(
      context: context,
      builder: (context) => _DialogoCrearReceta(
        materiasPrimas: _materiasPrimasDisponibles,
        unidadesDeMedida: _unidadesDeMedida,
        onIngredienteCreado: (nuevoIngrediente) {
          if (!mounted) return;
          setState(() {
            _materiasPrimasDisponibles.add(nuevoIngrediente);
            _materiasPrimasDisponibles.sort(
              (a, b) => (a.data['nombre'] ?? '').compareTo(b.data['nombre'] ?? ''),
            );
          });
        },
      ),
    );

    if (nuevaReceta != null && mounted) {
      setState(() {
        _recetasDisponibles.add(nuevaReceta);
        _recetasDisponibles.sort((a, b) => (a.data['nombre'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b.data['nombre'] ?? '').toString().toLowerCase()));
      });
      _mostrarSnack('Receta creada correctamente');
    }
  }

  /// Eliminar receta (previa validación de uso)
  Future<void> _eliminarReceta(RecordModel receta) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text(
          '¿Eliminar la receta "${receta.data['nombre']}"?\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      // ¿Está en uso por algún producto?
      final result = await pb.collection('producto_receta').getList(
            page: 1,
            perPage: 1,
            filter: 'id_receta = "${receta.id}"',
          );

      if (result.items.isNotEmpty) {
        _mostrarSnack('No se puede eliminar: la receta está en uso.', isError: true);
        return;
      }

      // Borra ingredientes asociados
      final ingredientesAsociados = await pb
          .collection('receta_matPrim')
          .getFullList(filter: 'id_receta = "${receta.id}"');

      await Future.wait([
        for (final ing in ingredientesAsociados)
          pb.collection('receta_matPrim').delete(ing.id),
      ]);

      // Borra la receta
      await pb.collection('receta').delete(receta.id);

      if (!mounted) return;
      setState(() {
        _recetasDisponibles.removeWhere((r) => r.id == receta.id);
      });
      _mostrarSnack('Receta eliminada correctamente');
    } catch (e) {
      _mostrarSnack('Error al eliminar: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recetasFiltradas = _query.isEmpty
        ? _recetasDisponibles
        : _recetasDisponibles.where((r) {
            final nombre = (r.data['nombre'] ?? '').toString().toLowerCase();
            return nombre.contains(_query);
          }).toList();

    return Scaffold(
      backgroundColor: Colors.white, // 👈 fondo blanco
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: const Text('Catálogo de Recetas'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _refrescar,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar receta...',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF6F6F6),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.black87, width: 1.2),
                    ),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            onPressed: () => _searchCtrl.clear(),
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(recetasFiltradas),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogoCrearReceta,
        tooltip: 'Añadir Receta',
        backgroundColor: Colors.black,   // 👈 negro para acento
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
      ),
    );
  }

  Widget _buildBody(List<RecordModel> recetas) {
    if (_cargandoDatos) {
      return const Center(child: CircularProgressIndicator());
    }
    if (recetas.isEmpty) {
      return const Center(
        child: Text(
          'No hay recetas.\n¡Añade una para empezar!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      );
    }

    // 🧭 Contenido centrado y con ancho máximo (look profesional)
    return RefreshIndicator(
      onRefresh: _refrescar,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            itemCount: recetas.length,
            itemBuilder: (context, index) {
              final receta = recetas[index];
              final nombreReceta = receta.data['nombre']?.toString() ?? 'Receta sin nombre';

              return _RecipeCard(
                title: nombreReceta,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RecetaDetalleScreen(receta: receta)),
                  );
                },
                onDelete: () => _eliminarReceta(receta),
              );
            },
          ),
        ),
      ),
    );
  }
}

// =========================
// C O M P O N E N T E  U I
// =========================

class _RecipeCard extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RecipeCard({
    required this.title,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFEFEFEF)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Ícono leading con fondo sutil
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F3F3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEAEAEA)),
                ),
                child: const Icon(Icons.menu_book, color: Colors.black87, size: 26),
              ),
              const SizedBox(width: 12),
              // Título
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Botones de acción
              IconButton(
                tooltip: 'Abrir',
                onPressed: onTap,
                icon: const Icon(Icons.arrow_outward_rounded, color: Colors.black54),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Eliminar',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================
// D I Á L O G O S
// =========================

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

  // idMateriaPrima -> controller(cantidad)
  final Map<String, TextEditingController> _ingredientes = {};

  // PDF opcional
  Uint8List? _pdfBytes;
  String? _pdfFilename;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _ingredientes.forEach((_, c) => c.dispose());
    super.dispose();
  }

  void _agregarIngrediente() async {
    // Selector / Creador
    final matPrimSeleccionada = await showDialog<RecordModel>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Seleccionar Materia Prima'),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(context); // cierra selección
              final nuevoIngrediente = await showDialog<RecordModel>(
                context: context,
                builder: (_) => _DialogoCrearIngrediente(unidadesDeMedida: widget.unidadesDeMedida),
              );
              if (nuevoIngrediente != null) {
                widget.onIngredienteCreado(nuevoIngrediente);
                if (!mounted) return;
                setState(() {
                  _ingredientes[nuevoIngrediente.id] = TextEditingController();
                });
              }
            },
            child: const ListTile(
              leading: Icon(Icons.add_circle_outline, color: Colors.blueAccent),
              title: Text('Crear nuevo ingrediente'),
            ),
          ),
          const Divider(),
          ...widget.materiasPrimas
              .where((mp) => !_ingredientes.containsKey(mp.id))
              .map((mp) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, mp),
                    child: Text(mp.data['nombre']),
                  )),
        ],
      ),
    );

    if (matPrimSeleccionada != null && !_ingredientes.containsKey(matPrimSeleccionada.id)) {
      setState(() {
        _ingredientes[matPrimSeleccionada.id] = TextEditingController();
      });
    }
  }

  Future<void> _seleccionarPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true, // necesario para Web
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _pdfBytes = result.files.single.bytes;
        _pdfFilename = result.files.single.name;
      });
    }
  }

  Future<void> _guardarReceta() async {
    if (!_formKey.currentState!.validate()) return;

    if (_ingredientes.isEmpty) {
      _snackLocal('Debes añadir al menos un ingrediente.');
      return;
    }

    setState(() => _guardando = true);

    try {
      final body = {'nombre': _nombreCtrl.text.trim()};
      final files = <http.MultipartFile>[];

      if (_pdfBytes != null && _pdfFilename != null) {
        files.add(http.MultipartFile.fromBytes(
          'descripcion', // campo file en la colección 'receta'
          _pdfBytes!,
          filename: _pdfFilename!,
        ));
      }

      final nuevaReceta = await pb.collection('receta').create(body: body, files: files);

      // Guardar ingredientes de la receta
      await Future.wait([
        for (final entry in _ingredientes.entries)
          pb.collection('receta_matPrim').create(body: {
            'id_receta': nuevaReceta.id,
            'id_matPrim': entry.key,
            'cantidad': double.tryParse(entry.value.text.replaceAll(',', '.')) ?? 0.0,
          }),
      ]);

      if (!mounted) return;
      Navigator.pop(context, nuevaReceta);
    } catch (e) {
      _snackLocal('Error al guardar receta: $e', error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _snackLocal(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : Colors.orange),
    );
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
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la receta *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
              ),

              const SizedBox(height: 16),
              const Text('Procedimiento (Opcional)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                color: const Color(0xFFF7F7F7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      if (_pdfBytes != null)
                        ListTile(
                          leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
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

              ..._ingredientes.entries.map((entry) {
                final matPrim = widget.materiasPrimas.firstWhere((mp) => mp.id == entry.key);
                final unidMed = matPrim.expand['id_unidMed']?.first;
                final abreviatura = unidMed?.data['abreviatura'] ?? '-';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      Expanded(child: Text(matPrim.data['nombre'])),
                      SizedBox(
                        width: 100,
                        child: TextFormField(
                          controller: entry.value,
                          decoration: const InputDecoration(
                            hintText: 'Cant.',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          textAlign: TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Req.';
                            if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Inv.';
                            return null;
                          },
                        ),
                      ),
                      SizedBox(
                        width: 56,
                        child: Text(abreviatura, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => setState(() => _ingredientes.remove(entry.key)),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _agregarIngrediente,
                icon: const Icon(Icons.add),
                label: const Text('Añadir Ingrediente', style: TextStyle(fontWeight: FontWeight.w600)),
              )
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _guardando ? null : _guardarReceta,
          style: FilledButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
          child: _guardando
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar'),
        )
      ],
    );
  }
}

// =========================
// D I Á L O G O  I N G R E D I E N T E
// =========================

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

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarIngrediente() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final nuevoIngrediente = await pb.collection('matPrim').create(body: {
        'nombre': _nombreCtrl.text.trim(),
        'stock': num.tryParse(_stockCtrl.text.replaceAll(',', '.')) ?? 0,
        'id_unidMed': _unidadMedidaId,
      });

      // Traer con expand para tener 'id_unidMed' listo
      final recordConExpand =
          await pb.collection('matPrim').getOne(nuevoIngrediente.id, expand: 'id_unidMed');

      if (!mounted) return;
      Navigator.pop(context, recordConExpand);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar ingrediente: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
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
            TextFormField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(labelText: 'Nombre del ingrediente *', border: OutlineInputBorder()),
              validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _stockCtrl,
              decoration: const InputDecoration(labelText: 'Stock Inicial', border: OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _unidadMedidaId,
              items: widget.unidadesDeMedida
                  .map((u) => DropdownMenuItem(value: u.id, child: Text(u.data['nombre'])))
                  .toList(),
              onChanged: (v) => setState(() => _unidadMedidaId = v),
              decoration: const InputDecoration(labelText: 'Unidad de Medida *', border: OutlineInputBorder()),
              validator: (v) => v == null ? 'Requerido' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _guardando ? null : _guardarIngrediente,
          style: FilledButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
          child: _guardando
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
