// receta_detalle_screen.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../servicios/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- CLASE AUXILIAR PARA MANEJAR EL ESTADO DE EDICIÓN DE INGREDIENTES ---
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

// --- PANTALLA PRINCIPAL ---
class RecetaDetalleScreen extends StatefulWidget {
  final Map<String, dynamic> receta;
  const RecetaDetalleScreen({super.key, required this.receta});

  @override
  State<RecetaDetalleScreen> createState() => _RecetaDetalleScreenState();
}

class _RecetaDetalleScreenState extends State<RecetaDetalleScreen> {
  // PDF / edición
  bool _isEditing = false;
  bool _isSaving = false;
  String? _pdfUrl;
  Key _pdfViewerKey = UniqueKey();
  Uint8List? _nuevoPdfBytes;
  String? _nuevoPdfFilename;
  bool _eliminarPdfActual = false;

  // 🔎 NUEVO: controlador para ajustar zoom inicial
  late final PdfViewerController _pdfController;

  // Para centrar/limitar tamaño del PDF
  static const double _pdfMaxWidth = 820; // ancho máximo “cómodo”
  static const double _pdfFixedHeight = 520; // altura compacta

  // Ingredientes
  final _formKey = GlobalKey<FormState>();
  late Future<List<Map<String, dynamic>>> _ingredientesFuture;
  final List<IngredienteEditable> _ingredientesEditables = [];
  final List<String> _idsIngredientesParaEliminar = [];
  List<Map<String, dynamic>> _materiasPrimasDisponibles = [];

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
      });
    }
  }

  // --- LÓGICA DE DATOS ---
  void _setPdfUrl() {
    // 1. Extraemos el nombre del archivo guardado en la columna 'descripcion'
    final pdfFileName = widget.receta['archivo_url']?.toString();

    setState(() {
      if (pdfFileName != null && pdfFileName.isNotEmpty) {
        // 2. Generamos la URL pública desde el bucket de Supabase
        // Asegúrate de que el nombre del bucket coincida con el que creaste ('recetas_pdf')
        _pdfUrl = supabase.storage
            .from('recetas')
            .getPublicUrl(pdfFileName);
      } else {
        _pdfUrl = null;
      }
      
      // 3. Forzamos la reconstrucción del visor de PDF
      _pdfViewerKey = UniqueKey();
    });
  }

  Future<List<Map<String, dynamic>>> _cargarIngredientes() async {
    try {
      // 1. Realizamos la consulta con JOINS anidados
      // id_matPrim (...) trae los datos de la materia prima
      // id_matPrim ( id_unidMed (...) ) trae la unidad de medida dentro de la materia prima
      final List<Map<String, dynamic>> records = await supabase
          .from('receta_ingrediente_variante')
          .select('''
            *,
            id_receta(
              *
            ),
            id_ingrediente(
              *
            )
          ''')
          .eq('id_receta', widget.receta['id_receta']); // Acceso a mapa con ['id']

      // 2. Poblamos la lista para la interfaz de edición
      _poblarListaEditable(records);
      
      return records;
    } catch (e) {
      _mostrarError('Error al cargar ingredientes: $e');
      return [];
    }
  }

  Future<void> _cargarMateriasPrimas() async {
    try {
      // 1. Realizamos la consulta trayendo la relación con la unidad de medida
      final List<Map<String, dynamic>> records = await supabase
          .from('ingredientes')
          .select('''
            *,
            id_tipo (
              *
            ),
            id_categoria(
              *
            )
          ''')
          .order('nombre', ascending: true);

      // 2. Guardamos la lista de mapas en nuestra variable local
      _materiasPrimasDisponibles = records;
      
    } catch (e) {
      _mostrarError('No se pudieron cargar las materias primas: $e');
    }
  }

  void _poblarListaEditable(List<Map<String, dynamic>> records) {
    // 1. Limpieza de controladores para evitar fugas de memoria
    for (var ing in _ingredientesEditables) {
      ing.dispose();
    }
    _ingredientesEditables.clear();
    _idsIngredientesParaEliminar.clear();

    // 2. Procesamiento de los registros de Supabase
    for (final recordUnion in records) {
      // En Supabase, el objeto relacionado viene directamente como un Map
      final matPrim = recordUnion['id_matPrim'] as Map<String, dynamic>?;

      if (matPrim != null) {
        _ingredientesEditables.add(
          IngredienteEditable(
            // Acceso directo a las llaves del mapa
            id: recordUnion['id']?.toString(), 
            matPrim: matPrim,
            cantidad: (recordUnion['cantidad'] as num?)?.toDouble() ?? 0.0,
          ),
        );
      }
    }
  }

  void _mostrarError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> _abrirPdfEnNuevaPestana() async {
    if (_pdfUrl == null) return;
    final uri = Uri.parse(_pdfUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, webOnlyWindowName: '_blank');
    } else {
      _mostrarError('No se pudo abrir el PDF en una nueva pestaña.');
    }
  }

  // --- LÓGICA DE EDICIÓN ---
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

    try {
      final futures = <Future>[];
      String? nombreArchivoPdf;

      // 1. --- MANEJO DE ARCHIVO (PDF) ---
      // --- MANEJO DE ARCHIVO (PDF) ---
      if (_nuevoPdfBytes != null && _nuevoPdfFilename != null) {
        nombreArchivoPdf = 'receta_${DateTime.now().millisecondsSinceEpoch}.pdf';
        
        await supabase.storage.from('recetas_pdf').uploadBinary(
              nombreArchivoPdf,
              _nuevoPdfBytes!,
              // ✅ En las versiones actuales, usamos FileOptions así:
              fileOptions: FileOptions(
                contentType: 'application/pdf',
                upsert: true,
              ),
            );
      }

      // 2. --- ACTUALIZAR REGISTRO DE RECETA EN BASE DE DATOS ---
      final recetaUpdateBody = <String, dynamic>{};
      if (nombreArchivoPdf != null) recetaUpdateBody['descripcion'] = nombreArchivoPdf;
      if (_eliminarPdfActual) recetaUpdateBody['descripcion'] = null;

      if (recetaUpdateBody.isNotEmpty) {
        await supabase
            .from('receta')
            .update(recetaUpdateBody)
            .eq('id', widget.receta['id']);
        
        // ✨ IMPORTANTE: Actualizamos el mapa local para que la UI sepa que cambió
        // Esto reemplaza el .addAll() que hacías en PocketBase
        recetaUpdateBody.forEach((key, value) {
          widget.receta[key] = value;
        });
      }

      // 3. --- MANEJO DE INGREDIENTES ---
      for (final ingrediente in _ingredientesEditables) {
        final ingBody = {
          'id_receta': widget.receta['id'],
          'id_matPrim': ingrediente.matPrim['id'],
          'cantidad': double.tryParse(
                  ingrediente.cantidadController.text.replaceAll(',', '.')) ??
              0.0,
        };

        if (ingrediente.id != null) {
          futures.add(supabase.from('receta_matPrim').update(ingBody).eq('id', ingrediente.id!));
        } else {
          futures.add(supabase.from('receta_matPrim').insert(ingBody));
        }
      }

      // 4. --- ELIMINAR INGREDIENTES ---
      for (final id in _idsIngredientesParaEliminar) {
        futures.add(supabase.from('receta_matPrim').delete().eq('id', id));
      }

      // Ejecutamos todas las operaciones de ingredientes en paralelo
      await Future.wait(futures);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receta guardada con éxito'), 
            backgroundColor: Colors.green
          ),
        );
        
        // Limpiamos variables de archivos temporales
        _nuevoPdfBytes = null;
        _nuevoPdfFilename = null;
        _eliminarPdfActual = false;

        _toggleEditMode(cancel: true);
        _setPdfUrl(); // Ahora usará el nombre actualizado en widget.receta['descripcion']
        _ingredientesFuture = _cargarIngredientes();
      }
    } catch (e) {
      _mostrarError('Error al guardar los cambios: $e');
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
      // Comparamos usando la llave ['id'] del mapa
      if (_ingredientesEditables.any((ing) => ing.matPrim['id'] == matPrimSeleccionada['id'])) {
        _mostrarError('Este ingrediente ya está en la lista.');
        return;
      }
      
      setState(() {
        _ingredientesEditables.add(
          IngredienteEditable(
            matPrim: matPrimSeleccionada, // matPrim ahora es un Map<String, dynamic>
            cantidad: 0.0,
          ),
        );
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

  // --- UI con pestañas (Solución 2) ---
  @override
  Widget build(BuildContext context) {
    final nombreReceta = widget.receta['nombre']?.toString() ?? 'Detalle';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
          title: Text(nombreReceta),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.picture_as_pdf), text: 'Procedimiento'),
              Tab(icon: Icon(Icons.list), text: 'Ingredientes'),
            ],
          ),
          actions: _isSaving
              ? []
              : [
                  if (_isEditing)
                    TextButton(
                      onPressed: () => _toggleEditMode(cancel: true),
                      child: const Text('Cancelar'),
                    ),
                  IconButton(
                    icon: Icon(_isEditing ? Icons.save : Icons.edit),
                    onPressed: _isEditing ? _guardarCambios : _toggleEditMode,
                    tooltip: _isEditing ? 'Guardar Cambios' : 'Editar Receta',
                  ),
                ],
        ),
        body: _isSaving
            ? const _SavingOverlay()
            : Form(
                key: _formKey,
                child: const TabBarView(
                  physics: ClampingScrollPhysics(),
                  children: [
                    _PdfTab(),
                    _IngredientesTab(),
                  ],
                ),
              ),
      ),
    );
  }

  // === PDF CARD: vista y edición en una presentación limpia ===
  Widget _buildSeccionPdfCard() {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFEFEFEF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _isEditing ? _buildPdfEditCard() : _buildPdfView(),
      ),
    );
  }

  Widget _buildPdfView() {
    if (_pdfUrl == null) {
      return const _EmptyState(
        icon: Icons.picture_as_pdf,
        title: 'Sin PDF adjunto',
        subtitle: 'Puedes agregar un procedimiento en PDF al editar la receta.',
      );
    }

    // En web: botón centrado para abrir en nueva pestaña
    if (kIsWeb) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'El visor interno de PDF está deshabilitado en web.',
            style: TextStyle(color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Center(
            child: FilledButton.icon(
              onPressed: _abrirPdfEnNuevaPestana,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir PDF en una nueva pestaña'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
            ),
          ),
        ],
      );
    }

    // 📄 Móvil/desktop: visor embebido centrado y compacto
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: _pdfMaxWidth, // evita que se haga enorme en pantallas grandes
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E5E5)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SizedBox(
              height: _pdfFixedHeight, // altura contenida
              child: SfPdfViewer.network(
                _pdfUrl!,
                key: _pdfViewerKey,
                controller: _pdfController,
                onDocumentLoaded: (_) {
                  // 🔍 Zoom inicial un poco menor para que “se vea más chico”
                  _pdfController.zoomLevel = 0.9;
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Descarga y validación por si quieres usar bytes (opcional)
  Future<Uint8List> _descargarPdfBytes(String url) async {
    final uri = Uri.parse(url);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('pdf')) {
        throw Exception('El archivo no es un PDF válido. Content-Type: $contentType');
      }
      return response.bodyBytes;
    } else {
      throw Exception('Error ${response.statusCode} al obtener PDF');
    }
  }

  // UI de edición de PDF (subir / eliminar)
  Widget _buildPdfEditCard() {
    final tieneActual = widget.receta['descripcion'] != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_nuevoPdfBytes != null)
          ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
            title: Text(_nuevoPdfFilename ?? 'Archivo seleccionado'),
            subtitle: const Text('Nuevo PDF listo para subir'),
          )
        else if (_eliminarPdfActual)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'El PDF actual se eliminará al guardar.',
              style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
            ),
          )
        else if (tieneActual)
          ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: Colors.black87),
            title: const Text('PDF actual'),
            subtitle: Text(
              widget.receta['descripcion'].toString(),
              overflow: TextOverflow.ellipsis,
            ),
            trailing: FilledButton.tonal(
              onPressed: _abrirPdfEnNuevaPestana,
              child: const Text('Abrir'),
            ),
          )
        else
          const _EmptyState(
            icon: Icons.picture_as_pdf,
            title: 'Sin PDF adjunto',
            subtitle: 'Puedes subir un PDF para el procedimiento.',
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: _seleccionarPdf,
              icon: const Icon(Icons.upload_file),
              label: Text(_nuevoPdfBytes == null ? 'Seleccionar PDF' : 'Cambiar PDF'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
            ),
            if (tieneActual || _nuevoPdfBytes != null)
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _eliminarPdfActual = true;
                  _nuevoPdfBytes = null;
                  _nuevoPdfFilename = null;
                }),
                icon: const Icon(Icons.delete_forever),
                label: const Text('Eliminar PDF'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              ),
          ],
        ),
      ],
    );
  }

  // === INGREDIENTES CARD ===
  Widget _buildSeccionIngredientesCard() {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFEFEFEF)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isEditing)
              _buildListaEditable()
            else
              _buildListaDeVista(),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _agregarIngrediente,
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir Ingrediente'),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildListaEditable() {
    if (_ingredientesEditables.isEmpty) {
      return const _EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Sin ingredientes',
        subtitle: 'Añade un ingrediente para empezar.',
      );
    }
    return Column(
      children: List.generate(_ingredientesEditables.length, (index) {
        final ingrediente = _ingredientesEditables[index];
        final matPrim = ingrediente.matPrim;
        final unidMed = matPrim['id_unidMed'];
        final nombreIngrediente = matPrim['nombre'] ?? 'N/A';
        final abreviatura = unidMed?['abreviatura'] ?? '-';

        return Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFF0F0F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    nombreIngrediente,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: ingrediente.cantidadController,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Cantidad',
                      suffixText: abreviatura,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Req.';
                      if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Inv.';
                      return null;
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.deepOrange),
                  onPressed: () => _eliminarIngrediente(index),
                  tooltip: 'Quitar ingrediente',
                )
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildListaDeVista() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _ingredientesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text('Ocurrió un error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const _EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Sin ingredientes',
            subtitle: 'Esta receta no tiene ingredientes asignados.',
          );
        }

        final ingredientes = snapshot.data!;
        return Column(
          children: ingredientes.map((recordUnion) {
            final matPrim = recordUnion['id_matPrim']?.first;
            final unidMed = matPrim?['id_unidMed'];
            final nombreIngrediente =
                matPrim?['nombre'] ?? 'Ingrediente desconocido';
            final cantidad =
                (recordUnion['cantidad'] as num?)?.toDouble() ?? 0.0;
            final abreviaturaUnidad = unidMed?.data['abreviatura'] ?? '-';

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 6),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F3F3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEAEAEA)),
                ),
                child: const Icon(Icons.restaurant, size: 18, color: Colors.black54),
              ),
              title: Text(
                nombreIngrediente,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F6F6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEAEAEA)),
                ),
                child: Text(
                  '$cantidad $abreviaturaUnidad',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ======= P E S T A Ñ A S   (TabBarView) =======

class _PdfTab extends StatelessWidget {
  const _PdfTab();

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_RecetaDetalleScreenState>()!;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              title: 'Procedimiento (PDF)',
              trailing: state._pdfUrl != null && !kIsWeb
                  ? FilledButton.tonalIcon(
                      onPressed: () {
                        state.setState(() => state._pdfViewerKey = UniqueKey());
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Actualizar visor'),
                    )
                  : null,
            ),
            state._buildSeccionPdfCard(),
          ],
        ),
      ),
    );
  }
}

class _IngredientesTab extends StatelessWidget {
  const _IngredientesTab();

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_RecetaDetalleScreenState>()!;
    return SafeArea(
      child: ListView(
        key: const PageStorageKey('ingredientes-list'),
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        physics: const ClampingScrollPhysics(),
        children: [
          const _SectionTitle(title: 'Ingredientes'),
          state._buildSeccionIngredientesCard(),
        ],
      ),
    );
  }
}

// ======= W I D G E T S   D E   A P O Y O =======

class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionTitle({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const _EmptyState({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEFEFEF)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 6),
          Icon(icon, color: Colors.black38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: Colors.black87)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: const TextStyle(color: Colors.black54)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _SavingOverlay extends StatelessWidget {
  const _SavingOverlay();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Guardando...'),
        ],
      ),
    );
  }
}

// ======= D I Á L O G O   B U S C A R   M A T P R I M =======

class _DialogoBuscarMatPrim extends StatefulWidget {
  final List<Map<String, dynamic>> materiasPrimas;
  const _DialogoBuscarMatPrim({required this.materiasPrimas});

  @override
  State<_DialogoBuscarMatPrim> createState() => _DialogoBuscarMatPrimState();
}

class _DialogoBuscarMatPrimState extends State<_DialogoBuscarMatPrim> {
  late List<Map<String, dynamic>> _resultadosFiltrados;

  @override
  void initState() {
    super.initState();
    _resultadosFiltrados = widget.materiasPrimas;
  }

  void _filtrar(String query) {
    setState(() {
      _resultadosFiltrados = widget.materiasPrimas
          .where((mp) => mp['nombre']
              .toString()
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Añadir Ingrediente'),
      content: SizedBox(
        width: 420,
        height: 520,
        child: Column(
          children: [
            TextField(
              onChanged: _filtrar,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Buscar materia prima...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
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
                          title: Text(mp['nombre']),
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
