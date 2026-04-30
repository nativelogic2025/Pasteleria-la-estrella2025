// catalogo_recetas.dart
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'nueva_receta.dart';

final supabase = Supabase.instance.client;

class CatalogoRecetasScreen extends StatefulWidget {
  const CatalogoRecetasScreen({super.key});

  @override
  State<CatalogoRecetasScreen> createState() => _CatalogoRecetasScreenState();
}

class _CatalogoRecetasScreenState extends State<CatalogoRecetasScreen> {
  List<Map<String, dynamic>> _recetasDisponibles = [];
  bool _cargandoDatos = true;
  bool _refrescando = false;

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  String? _selectedRecetaId;

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

  Future<void> _inicializarDatos() async {
    try {
      final results = await supabase.from('recetas').select('*').order('nombre');
      if (!mounted) return;
      setState(() {
        _recetasDisponibles = List<Map<String, dynamic>>.from(results);
        _cargandoDatos = false;
        if (_recetasDisponibles.isNotEmpty && _selectedRecetaId == null) {
          _selectedRecetaId = _recetasDisponibles.first['id_receta']?.toString() ?? _recetasDisponibles.first['id']?.toString();
        }
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
      final recetas = await supabase.from('recetas').select('*').order('nombre');
      if (!mounted) return;
      setState(() {
        _recetasDisponibles = List<Map<String, dynamic>>.from(recetas);
        // Si la seleccionada ya no existe, limpiamos
        if (!_recetasDisponibles.any((r) => (r['id_receta']?.toString() ?? r['id']?.toString()) == _selectedRecetaId)) {
          _selectedRecetaId = null;
        }
      });
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
      builder: (context) => DialogoCrearReceta(),
    );

    if (nuevaReceta != null && mounted) {
      setState(() {
        _recetasDisponibles.add(nuevaReceta);
        _recetasDisponibles.sort((a, b) => (a['nombre'] ?? '').toLowerCase().compareTo((b['nombre'] ?? '').toLowerCase()));
        _selectedRecetaId = nuevaReceta['id_receta']?.toString() ?? nuevaReceta['id']?.toString();
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
      final imagenUrl = receta['archivo_url'];
      final idProducto = receta['id_receta'] ?? receta['id'];

      final enUso = await supabase.from('receta_producto').select('*').eq('id_receta', idProducto).limit(1);

      if (enUso.isNotEmpty) {
        _mostrarSnack('No se puede eliminar: la receta está en uso por productos.', isError: true);
        return;
      }

      if (imagenUrl != null && imagenUrl.isNotEmpty) {
        await supabase.storage.from('recetas').remove([imagenUrl]); 
      }

      await supabase.from('recetas').delete().eq('id_receta', idProducto);

      if (_selectedRecetaId == idProducto.toString()) {
        setState(() => _selectedRecetaId = null);
      }
      
      _refrescar();
      if (mounted) _mostrarSnack('Receta eliminada correctamente');
    } catch (e) {
      _mostrarSnack('Error al eliminar: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoDatos) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final recetasFiltradas = _query.isEmpty
        ? _recetasDisponibles
        : _recetasDisponibles.where((r) => r['nombre'].toString().toLowerCase().contains(_query)).toList();

    Map<String, dynamic>? recetaSeleccionada;
    if (_selectedRecetaId != null) {
      try {
        recetaSeleccionada = _recetasDisponibles.firstWhere((r) => (r['id_receta']?.toString() ?? r['id']?.toString()) == _selectedRecetaId);
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
        titleSpacing: 20,
        title: Row(
          children: [
            const Icon(Icons.menu_book, color: Color(0xFF8C5535)),
            const SizedBox(width: 12),
            const Text('Catálogo de Recetas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(width: 30),
            
            // Search Bar
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 42,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar receta...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ),
            const Spacer(),
            
            ElevatedButton.icon(
              onPressed: _mostrarDialogoCrearReceta,
              icon: const Icon(Icons.add, size: 20),
              label: const Text("Nueva Receta", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8C5535),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PANEL IZQUIERDO (Lista de Recetas)
          Container(
            width: 320,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            child: RefreshIndicator(
              onRefresh: _refrescar,
              child: recetasFiltradas.isEmpty
                  ? const Center(child: Text('No hay recetas.', style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: recetasFiltradas.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final receta = recetasFiltradas[index];
                        final id = receta['id_receta']?.toString() ?? receta['id']?.toString();
                        final isSelected = id == _selectedRecetaId;
                        
                        return InkWell(
                          onTap: () => setState(() => _selectedRecetaId = id),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFCF5EE) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF8C5535).withValues(alpha: 0.5) : Colors.grey.shade200,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF8C5535) : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.receipt_long,
                                    size: 18,
                                    color: isSelected ? Colors.white : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    receta['nombre'] ?? 'Sin nombre',
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? const Color(0xFF8C5535) : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  onPressed: () => _eliminarReceta(receta),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                )
                              ],
                            ),
                          ),
                        ).animate(key: ValueKey(id))
                         .fade(duration: 300.ms, delay: (30 * index).ms)
                         .slideX(begin: -0.05, duration: 300.ms, delay: (30 * index).ms);
                      },
                    ),
            ),
          ),
          
          // PANEL DERECHO (Detalle)
          Expanded(
            child: recetaSeleccionada == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.menu_book, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('Selecciona una receta', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                      ],
                    ),
                  )
                : _RecetaDetalleView(
                    key: ValueKey(recetaSeleccionada['id_receta']?.toString() ?? recetaSeleccionada['id']?.toString()),
                    receta: recetaSeleccionada,
                    onUpdate: (updatedReceta) {
                      // Actualizar en la lista local para mantener sync
                      setState(() {
                        final id = updatedReceta['id_receta']?.toString() ?? updatedReceta['id']?.toString();
                        final idx = _recetasDisponibles.indexWhere((r) => (r['id_receta']?.toString() ?? r['id']?.toString()) == id);
                        if (idx != -1) _recetasDisponibles[idx] = updatedReceta;
                      });
                    },
                  ).animate(key: ValueKey(recetaSeleccionada['id_receta']?.toString() ?? recetaSeleccionada['id']?.toString()))
                   .fade(duration: 400.ms)
                   .slideY(begin: 0.05),
          ),
        ],
      ),
    );
  }
}

// --- CLASE AUXILIAR ---
class IngredienteEditable {
  String? id;
  final Map<String, dynamic> matPrim;
  final TextEditingController cantidadController;

  IngredienteEditable({
    this.id,
    required this.matPrim,
    required double cantidad,
  }) : cantidadController = TextEditingController(text: cantidad.toString());

  void dispose() {
    cantidadController.dispose();
  }
}

// --- VISTA DETALLE DE RECETA ---
class _RecetaDetalleView extends StatefulWidget {
  final Map<String, dynamic> receta;
  final Function(Map<String, dynamic>) onUpdate;

  const _RecetaDetalleView({super.key, required this.receta, required this.onUpdate});

  @override
  State<_RecetaDetalleView> createState() => _RecetaDetalleViewState();
}

class _RecetaDetalleViewState extends State<_RecetaDetalleView> {
  bool _isEditing = false;
  bool _isSaving = false;
  String? _pdfUrl;
  Key _pdfViewerKey = UniqueKey();
  Uint8List? _nuevoPdfBytes;
  String? _nuevoPdfFilename;
  bool _eliminarPdfActual = false;

  late final PdfViewerController _pdfController;

  final _formKey = GlobalKey<FormState>();
  late Future<List<Map<String, dynamic>>> _ingredientesFuture;
  final List<IngredienteEditable> _ingredientesEditables = [];
  final List<String> _idsIngredientesParaEliminar = [];
  List<Map<String, dynamic>> _materiasPrimasDisponibles = [];

  // Multiplicador visual (Simulador)
  double _multiplicadorSimulado = 1.0;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _ingredientesFuture = _cargarIngredientes();
    _cargarMateriasPrimas();
    _setPdfUrl();
  }

  @override
  void dispose() {
    for (var ing in _ingredientesEditables) {
      ing.dispose();
    }
    super.dispose();
  }

  void _setPdfUrl() {
    final pdfFileName = widget.receta['archivo_url']?.toString();
    setState(() {
      if (pdfFileName != null && pdfFileName.isNotEmpty) {
        _pdfUrl = supabase.storage.from('recetas').getPublicUrl(pdfFileName);
      } else {
        _pdfUrl = null;
      }
      _pdfViewerKey = UniqueKey();
    });
  }

  Future<void> _seleccionarPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _nuevoPdfBytes = result.files.single.bytes;
        _nuevoPdfFilename = result.files.single.name;
        _eliminarPdfActual = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _cargarIngredientes() async {
    try {
      final List<Map<String, dynamic>> records = await supabase
          .from('receta_ingrediente_variante')
          .select('*, recetas (*), ingredientes (*)')
          .eq('id_receta', widget.receta['id_receta'] ?? widget.receta['id']);
      _poblarListaEditable(records);
      return records;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar ingredientes: $e'), backgroundColor: Colors.red));
      }
      return [];
    }
  }

  Future<void> _cargarMateriasPrimas() async {
    try {
      final List<Map<String, dynamic>> records = await supabase.from('ingredientes').select('*').order('nombre', ascending: true);
      _materiasPrimasDisponibles = records;
    } catch (e) {
      // Ignorar error silenciado
    }
  }

  void _poblarListaEditable(List<Map<String, dynamic>> records) {
    for (var ing in _ingredientesEditables) {
      ing.dispose();
    }
    _ingredientesEditables.clear();
    _idsIngredientesParaEliminar.clear();

    for (final recordUnion in records) {
      final matPrim = recordUnion['ingredientes'] as Map<String, dynamic>?;
      if (matPrim != null) {
        _ingredientesEditables.add(
          IngredienteEditable(
            id: recordUnion['id']?.toString(), 
            matPrim: matPrim,
            cantidad: (recordUnion['cantidad'] as num?)?.toDouble() ?? 0.0,
          ),
        );
      }
    }
  }

  Future<void> _abrirPdfEnNuevaPestana() async {
    if (_pdfUrl == null) return;
    final uri = Uri.parse(_pdfUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, webOnlyWindowName: '_blank');
    }
  }

  void _toggleEditMode({bool cancel = false}) {
    if (cancel) {
      setState(() {
        _nuevoPdfBytes = null;
        _nuevoPdfFilename = null;
        _eliminarPdfActual = false;
        _ingredientesFuture = _cargarIngredientes();
      });
    }
    setState(() => _isEditing = !_isEditing);
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final futures = <Future>[];
      String? nombreArchivoPdf;
      final Map<String, dynamic> recetaActualizada = Map<String, dynamic>.from(widget.receta);

      if (_nuevoPdfBytes != null && _nuevoPdfFilename != null) {
        nombreArchivoPdf = 'receta_${DateTime.now().millisecondsSinceEpoch}.pdf';
        await supabase.storage.from('recetas_pdf').uploadBinary(
              nombreArchivoPdf,
              _nuevoPdfBytes!,
              fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
            );
      }

      final recetaUpdateBody = <String, dynamic>{};
      if (nombreArchivoPdf != null) recetaUpdateBody['descripcion'] = nombreArchivoPdf;
      if (_eliminarPdfActual) recetaUpdateBody['descripcion'] = null;

      if (recetaUpdateBody.isNotEmpty) {
        await supabase.from('recetas').update(recetaUpdateBody).eq('id_receta', widget.receta['id_receta'] ?? widget.receta['id']);
        recetaUpdateBody.forEach((key, value) {
          recetaActualizada[key] = value;
        });
        widget.onUpdate(recetaActualizada);
      }

      final idReceta = widget.receta['id_receta'] ?? widget.receta['id'];

      for (final ingrediente in _ingredientesEditables) {
        final ingBody = {
          'id_receta': idReceta,
          'id_ingrediente': ingrediente.matPrim['id_ingrediente'],
          'cantidad': double.tryParse(ingrediente.cantidadController.text.replaceAll(',', '.')) ?? 0.0,
        };

        if (ingrediente.id != null) {
          futures.add(supabase.from('receta_ingrediente_variante').update(ingBody).eq('id', ingrediente.id!));
        } else {
          futures.add(supabase.from('receta_ingrediente_variante').insert(ingBody));
        }
      }

      for (final id in _idsIngredientesParaEliminar) {
        futures.add(supabase.from('receta_ingrediente_variante').delete().eq('id', id));
      }

      await Future.wait(futures);

      if (mounted) {
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Receta guardada con éxito'), backgroundColor: Colors.green));
        _nuevoPdfBytes = null;
        _nuevoPdfFilename = null;
        _eliminarPdfActual = false;
        _toggleEditMode(cancel: true);
        _setPdfUrl(); 
        _ingredientesFuture = _cargarIngredientes();
      }
    } catch (e) {
      if (mounted) scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _agregarIngrediente() async {
    final Map<String, dynamic>? matPrimSeleccionada = await showDialog(
      context: context,
      builder: (_) => _DialogoBuscarMatPrim(materiasPrimas: _materiasPrimasDisponibles),
    );

    if (matPrimSeleccionada != null) {
      if (_ingredientesEditables.any((ing) => ing.matPrim['id_ingrediente'] == matPrimSeleccionada['id_ingrediente'])) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este ingrediente ya está en la lista.')));
        return;
      }
      setState(() {
        _ingredientesEditables.add(IngredienteEditable(matPrim: matPrimSeleccionada, cantidad: 0.0));
      });
    }
  }

  void _eliminarIngrediente(int index) {
    final ingrediente = _ingredientesEditables[index];
    if (ingrediente.id != null) {
      _idsIngredientesParaEliminar.add(ingrediente.id!);
    }
    setState(() {
      ingrediente.dispose();
      _ingredientesEditables.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final nombreReceta = widget.receta['nombre']?.toString() ?? 'Detalle de Receta';

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Header de la Vista Detalle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombreReceta, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF8C5535))),
                      const SizedBox(height: 4),
                      const Text('Detalles de preparación y lista de ingredientes', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                if (!_isSaving) ...[
                  if (_isEditing)
                    TextButton(
                      onPressed: () => _toggleEditMode(cancel: true),
                      child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                    ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: Icon(_isEditing ? Icons.save : Icons.edit, size: 18),
                    label: Text(_isEditing ? 'Guardar Cambios' : 'Editar Receta'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _isEditing ? Colors.green : const Color(0xFF8C5535),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isEditing ? _guardarCambios : _toggleEditMode,
                  ),
                ],
              ],
            ),
          ),
          
          // TabBar
          Container(
            color: Colors.white,
            child: const TabBar(
              indicatorColor: Color(0xFF8C5535),
              labelColor: Color(0xFF8C5535),
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(icon: Icon(Icons.list_alt), text: 'Ingredientes Base'),
                Tab(icon: Icon(Icons.picture_as_pdf), text: 'Procedimiento PDF'),
              ],
            ),
          ),
          
          // TabBarView
          Expanded(
            child: _isSaving
                ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Guardando cambios...')]))
                : Form(
                    key: _formKey,
                    child: TabBarView(
                      children: [
                        _buildIngredientesTab(),
                        _buildPdfTab(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientesTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Aviso de Receta Base
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBDEFB)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF1976D2)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Modo de Receta Base (Individual)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
                    SizedBox(height: 4),
                    Text('Ingresa las cantidades para un producto base (Ej. Tamaño Individual). El sistema multiplicará estos valores automáticamente al registrar producciones de tamaños grandes (Familiar, Plancha, etc.) según el multiplicador de la variante.', style: TextStyle(color: Color(0xFF1976D2), fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        // Simulador de Multiplicador (Visual)
        if (!_isEditing)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              children: [
                const Icon(Icons.calculate_outlined, color: Colors.grey),
                const SizedBox(width: 8),
                const Text('Simular tamaño:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<double>(
                      value: _multiplicadorSimulado,
                      isDense: true,
                      items: const [
                        DropdownMenuItem(value: 1.0, child: Text('Individual (x1)')),
                        DropdownMenuItem(value: 10.0, child: Text('Chico (x10)')),
                        DropdownMenuItem(value: 15.0, child: Text('Mediano (x15)')),
                        DropdownMenuItem(value: 20.0, child: Text('Familiar (x20)')),
                        DropdownMenuItem(value: 30.0, child: Text('Plancha (x30)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _multiplicadorSimulado = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

        Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isEditing) _buildListaEditable() else _buildListaDeVista(),
                if (_isEditing) ...[
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _agregarIngrediente,
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir Ingrediente'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListaEditable() {
    if (_ingredientesEditables.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Sin ingredientes.', style: TextStyle(color: Colors.grey))));
    }
    return Column(
      children: List.generate(_ingredientesEditables.length, (index) {
        final ingrediente = _ingredientesEditables[index];
        final matPrim = ingrediente.matPrim;
        final nombre = matPrim['nombre'] ?? 'N/A';
        final abrev = matPrim['unidad_medida']?.toString() ?? '-';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold))),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: ingrediente.cantidadController,
                  decoration: InputDecoration(
                    labelText: 'Cantidad',
                    suffixText: abrev,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Req.';
                    if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Inv.';
                    return null;
                  },
                ),
              ),
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _eliminarIngrediente(index)),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildListaDeVista() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _ingredientesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Esta receta no tiene ingredientes.', style: TextStyle(color: Colors.grey))));

        final ingredientes = snapshot.data!;
        return Column(
          children: ingredientes.map((r) {
            final matPrim = r['ingredientes'];
            final nombre = matPrim?['nombre'] ?? 'Desconocido';
            final baseCant = (r['cantidad'] as num?)?.toDouble() ?? 0.0;
            final abrev = matPrim?['unidad_medida']?.toString() ?? '-';

            final cantSimulada = baseCant * _multiplicadorSimulado;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFFCF5EE), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.egg_alt_outlined, size: 18, color: Color(0xFF8C5535)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${cantSimulada.toStringAsFixed(2)} $abrev', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                      if (_multiplicadorSimulado > 1.0)
                        Text('Base: $baseCant', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPdfTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Procedimiento (PDF)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (_pdfUrl != null && !kIsWeb && !_isEditing)
                TextButton.icon(
                  onPressed: () => setState(() => _pdfViewerKey = UniqueKey()),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Recargar'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _isEditing ? _buildPdfEdit() : _buildPdfView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfView() {
    if (_pdfUrl == null) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No hay PDF adjunto a esta receta.', style: TextStyle(color: Colors.grey))));
    }
    if (kIsWeb) {
      return Column(
        children: [
          const Text('Visor interno deshabilitado en Web.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _abrirPdfEnNuevaPestana,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Abrir PDF en nueva pestaña'),
          ),
        ],
      );
    }
    return SizedBox(
      height: 500,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SfPdfViewer.network(_pdfUrl!, key: _pdfViewerKey, controller: _pdfController, onDocumentLoaded: (_) => _pdfController.zoomLevel = 0.9),
      ),
    );
  }

  Widget _buildPdfEdit() {
    final tieneActual = widget.receta['descripcion'] != null && widget.receta['descripcion'].toString().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_nuevoPdfBytes != null)
          ListTile(leading: const Icon(Icons.picture_as_pdf, color: Colors.red), title: Text(_nuevoPdfFilename ?? 'Archivo seleccionado'), subtitle: const Text('Nuevo PDF listo para subir'))
        else if (_eliminarPdfActual)
          const Text('El PDF se eliminará al guardar.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
        else if (tieneActual)
          ListTile(leading: const Icon(Icons.picture_as_pdf), title: const Text('PDF actual'), subtitle: Text(widget.receta['descripcion'].toString()), trailing: TextButton(onPressed: _abrirPdfEnNuevaPestana, child: const Text('Abrir')))
        else
          const Text('Sin PDF adjunto.', style: TextStyle(color: Colors.grey)),
        
        const SizedBox(height: 16),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _seleccionarPdf,
              icon: const Icon(Icons.upload_file),
              label: Text(_nuevoPdfBytes == null ? 'Seleccionar PDF' : 'Cambiar PDF'),
            ),
            const SizedBox(width: 8),
            if (tieneActual || _nuevoPdfBytes != null)
              OutlinedButton.icon(
                onPressed: () => setState(() { _eliminarPdfActual = true; _nuevoPdfBytes = null; _nuevoPdfFilename = null; }),
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text('Eliminar', style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ],
    );
  }
}

class _DialogoBuscarMatPrim extends StatefulWidget {
  final List<Map<String, dynamic>> materiasPrimas;
  const _DialogoBuscarMatPrim({required this.materiasPrimas});
  @override
  State<_DialogoBuscarMatPrim> createState() => _DialogoBuscarMatPrimState();
}
class _DialogoBuscarMatPrimState extends State<_DialogoBuscarMatPrim> {
  late List<Map<String, dynamic>> _resultadosFiltrados;
  @override
  void initState() { super.initState(); _resultadosFiltrados = widget.materiasPrimas; }
  void _filtrar(String query) {
    setState(() { _resultadosFiltrados = widget.materiasPrimas.where((mp) => mp['nombre'].toString().toLowerCase().contains(query.toLowerCase())).toList(); });
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Añadir Ingrediente'),
      content: SizedBox(
        width: 420, height: 520,
        child: Column(
          children: [
            TextField(onChanged: _filtrar, autofocus: true, decoration: const InputDecoration(labelText: 'Buscar materia prima...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 10),
            Expanded(child: _resultadosFiltrados.isEmpty ? const Center(child: Text('Sin resultados')) : ListView.builder(itemCount: _resultadosFiltrados.length, itemBuilder: (context, index) {
              final mp = _resultadosFiltrados[index];
              return ListTile(title: Text(mp['nombre']), onTap: () => Navigator.pop(context, mp));
            })),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar'))],
    );
  }
}