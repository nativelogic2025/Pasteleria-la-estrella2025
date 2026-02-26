// catalogo_recetas.dart
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 👈 Migrado a Supabase
import 'receta_detalle_screen.dart';

// Cliente global de Supabase
final supabase = Supabase.instance.client;

class CatalogoRecetasScreen extends StatefulWidget {
  const CatalogoRecetasScreen({super.key});

  @override
  State<CatalogoRecetasScreen> createState() => _CatalogoRecetasScreenState();
}

class _CatalogoRecetasScreenState extends State<CatalogoRecetasScreen> {
  // Datos (Ahora como Mapas de Dart)
  List<Map<String, dynamic>> _recetasDisponibles = [];
  List<Map<String, dynamic>> _materiasPrimasDisponibles = [];
  List<Map<String, dynamic>> _unidadesDeMedida = [];

  // Estado
  bool _cargandoDatos = true;
  bool _refrescando = false;

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

  /// Carga inicial usando PostgREST de Supabase
  Future<void> _inicializarDatos() async {
    try {
      final results = await Future.wait([
        supabase.from('receta').select('*').order('nombre'),
        supabase.from('matPrim').select('*, id_unidMed(*)').order('nombre'),
        supabase.from('unidMed').select('*').order('nombre'),
      ]);

      if (!mounted) return;
      setState(() {
        _recetasDisponibles = List<Map<String, dynamic>>.from(results[0]);
        _materiasPrimasDisponibles = List<Map<String, dynamic>>.from(results[1]);
        _unidadesDeMedida = List<Map<String, dynamic>>.from(results[2]);
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
      final recetas = await supabase.from('receta').select('*').order('nombre');
      if (!mounted) return;
      setState(() => _recetasDisponibles = List<Map<String, dynamic>>.from(recetas));
    } catch (e) {
      if (mounted) _mostrarSnack('No se pudo actualizar: $e', isError: true);
    } finally {
      _refrescando = false;
    }
  }

  void _mostrarSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }

  Future<void> _mostrarDialogoCrearReceta() async {
    final nuevaReceta = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _DialogoCrearReceta(
        materiasPrimas: _materiasPrimasDisponibles,
        unidadesDeMedida: _unidadesDeMedida,
        onIngredienteCreado: (nuevoIngrediente) {
          if (!mounted) return;
          setState(() {
            _materiasPrimasDisponibles.add(nuevoIngrediente);
            _materiasPrimasDisponibles.sort((a, b) => (a['nombre'] ?? '').compareTo(b['nombre'] ?? ''));
          });
        },
      ),
    );

    if (nuevaReceta != null && mounted) {
      setState(() {
        _recetasDisponibles.add(nuevaReceta);
        _recetasDisponibles.sort((a, b) => (a['nombre'] ?? '').toLowerCase().compareTo((b['nombre'] ?? '').toLowerCase()));
      });
      _mostrarSnack('Receta creada correctamente');
    }
  }

  Future<void> _eliminarReceta(Map<String, dynamic> receta) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text('¿Eliminar la receta "${receta['nombre']}"?'),
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
      // Validar si está en uso
      final enUso = await supabase.from('producto_receta').select('id').eq('id_receta', receta['id']).limit(1);

      if (enUso.isNotEmpty) {
        _mostrarSnack('No se puede eliminar: la receta está en uso por productos.', isError: true);
        return;
      }

      // Supabase eliminará en cascada los ingredientes si configuraste FK Cascade en Postgres, 
      // si no, borramos manual:
      await supabase.from('receta_matPrim').delete().eq('id_receta', receta['id']);
      await supabase.from('receta').delete().eq('id', receta['id']);

      if (!mounted) return;
      setState(() => _recetasDisponibles.removeWhere((r) => r['id'] == receta['id']));
      _mostrarSnack('Receta eliminada correctamente');
    } catch (e) {
      _mostrarSnack('Error al eliminar: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recetasFiltradas = _query.isEmpty
        ? _recetasDisponibles
        : _recetasDisponibles.where((r) => r['nombre'].toString().toLowerCase().contains(_query)).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: const Text('Catálogo de Recetas'),
        actions: [IconButton(onPressed: _refrescar, icon: const Icon(Icons.refresh))],
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
                    filled: true,
                    fillColor: const Color(0xFFF6F6F6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
      ),
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> recetas) {
    if (_cargandoDatos) return const Center(child: CircularProgressIndicator());
    if (recetas.isEmpty) return const Center(child: Text('No hay recetas.'));

    return RefreshIndicator(
      onRefresh: _refrescar,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            itemCount: recetas.length,
            itemBuilder: (context, index) {
              final receta = recetas[index];
              return _RecipeCard(
                title: receta['nombre'] ?? 'Sin nombre',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecetaDetalleScreen(receta: receta))),
                onDelete: () => _eliminarReceta(receta),
              );
            },
          ),
        ),
      ),
    );
  }
}

// UI CARD
class _RecipeCard extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _RecipeCard({required this.title, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFEFEFEF))),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.menu_book, color: Colors.black87),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.arrow_outward_rounded), onPressed: onTap),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}

// DIÁLOGO CREAR RECETA
class _DialogoCrearReceta extends StatefulWidget {
  final List<Map<String, dynamic>> materiasPrimas;
  final List<Map<String, dynamic>> unidadesDeMedida;
  final Function(Map<String, dynamic>) onIngredienteCreado;

  const _DialogoCrearReceta({required this.materiasPrimas, required this.unidadesDeMedida, required this.onIngredienteCreado});

  @override
  State<_DialogoCrearReceta> createState() => _DialogoCrearRecetaState();
}

class _DialogoCrearRecetaState extends State<_DialogoCrearReceta> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  bool _guardando = false;
  final Map<String, TextEditingController> _ingredientes = {};
  Uint8List? _pdfBytes;
  String? _pdfFilename;

  void _agregarIngrediente() async {
    final matPrimSeleccionada = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Seleccionar Materia Prima'),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(context);
              final nuevo = await showDialog<Map<String, dynamic>>(
                context: context,
                builder: (_) => _DialogoCrearIngrediente(unidadesDeMedida: widget.unidadesDeMedida),
              );
              if (nuevo != null) {
                widget.onIngredienteCreado(nuevo);
                setState(() => _ingredientes[nuevo['id'].toString()] = TextEditingController());
              }
            },
            child: const ListTile(leading: Icon(Icons.add_circle_outline), title: Text('Crear nuevo ingrediente')),
          ),
          ...widget.materiasPrimas.where((mp) => !_ingredientes.containsKey(mp['id'].toString())).map((mp) => SimpleDialogOption(
            onPressed: () => Navigator.pop(context, mp),
            child: Text(mp['nombre']),
          )),
        ],
      ),
    );

    if (matPrimSeleccionada != null) {
      setState(() => _ingredientes[matPrimSeleccionada['id'].toString()] = TextEditingController());
    }
  }

  Future<void> _guardarReceta() async {
    if (!_formKey.currentState!.validate() || _ingredientes.isEmpty) return;
    setState(() => _guardando = true);

    try {
      String? pdfPath;
      if (_pdfBytes != null) {
        pdfPath = 'receta_${DateTime.now().millisecondsSinceEpoch}.pdf';
        await supabase.storage.from('recetas_pdf').uploadBinary(pdfPath, _pdfBytes!, fileOptions: const FileOptions(contentType: 'application/pdf'));
      }

      final nuevaReceta = await supabase.from('receta').insert({
        'nombre': _nombreCtrl.text.trim(),
        'descripcion': pdfPath // En Supabase guardamos el nombre/ruta del archivo en el campo descripción
      }).select().single();

      final idReceta = nuevaReceta['id'];

      final List<Map<String, dynamic>> batchIngredientes = _ingredientes.entries.map((e) => {
        'id_receta': idReceta,
        'id_matPrim': e.key,
        'cantidad': double.tryParse(e.value.text.replaceAll(',', '.')) ?? 0.0
      }).toList();

      await supabase.from('receta_matPrim').insert(batchIngredientes);

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
      title: const Text('Crear Nueva Receta'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre *', border: OutlineInputBorder())),
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
              ..._ingredientes.entries.map((entry) {
                final mp = widget.materiasPrimas.firstWhere((m) => m['id'].toString() == entry.key);
                final abreviatura = mp['id_unidMed']?['abreviatura'] ?? '-';
                return Row(children: [
                  Expanded(child: Text(mp['nombre'])),
                  SizedBox(width: 80, child: TextFormField(controller: entry.value, decoration: const InputDecoration(hintText: 'Cant.'))),
                  Text(abreviatura),
                  IconButton(icon: const Icon(Icons.delete), onPressed: () => setState(() => _ingredientes.remove(entry.key))),
                ]);
              }),
              TextButton.icon(onPressed: _agregarIngrediente, icon: const Icon(Icons.add), label: const Text('Añadir Ingrediente')),
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

// DIÁLOGO INGREDIENTE
class _DialogoCrearIngrediente extends StatefulWidget {
  final List<Map<String, dynamic>> unidadesDeMedida;
  const _DialogoCrearIngrediente({required this.unidadesDeMedida});

  @override
  State<_DialogoCrearIngrediente> createState() => _DialogoCrearIngredienteState();
}

class _DialogoCrearIngredienteState extends State<_DialogoCrearIngrediente> {
  final _nombreCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '0');
  String? _unidadId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo Ingrediente'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
          TextField(controller: _stockCtrl, decoration: const InputDecoration(labelText: 'Stock')),
          DropdownButtonFormField<String>(
            value: _unidadId,
            items: widget.unidadesDeMedida.map((u) => DropdownMenuItem(value: u['id'].toString(), child: Text(u['nombre']))).toList(),
            onChanged: (v) => setState(() => _unidadId = v),
            decoration: const InputDecoration(labelText: 'Unidad'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () async {
            final res = await supabase.from('matPrim').insert({
              'nombre': _nombreCtrl.text.trim(),
              'stock': double.tryParse(_stockCtrl.text) ?? 0,
              'id_unidMed': _unidadId
            }).select('*, id_unidMed(*)').single();
            if (mounted) Navigator.pop(context, res);
          }, 
          child: const Text('Guardar')
        ),
      ],
    );
  }
}