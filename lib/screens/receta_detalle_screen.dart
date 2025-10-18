import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart'; // ✨ 1. IMPORTAR PAQUETE
import 'pb_client.dart';

// --- CLASE AUXILIAR PARA MANEJAR EL ESTADO DE EDICIÓN DE INGREDIENTES ---
class IngredienteEditable {
  String? id;
  final RecordModel matPrim;
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
  final RecordModel receta;
  const RecetaDetalleScreen({super.key, required this.receta});

  @override
  State<RecetaDetalleScreen> createState() => _RecetaDetalleScreenState();
}

class _RecetaDetalleScreenState extends State<RecetaDetalleScreen> {
  // --- ESTADO PARA VISUALIZACIÓN Y EDICIÓN DE PDF ---
  bool _isEditing = false;
  bool _isSaving = false;
  
  String? _pdfUrl;
  Key _pdfViewerKey = UniqueKey();

  // Para manejar el nuevo archivo PDF seleccionado por el usuario
  Uint8List? _nuevoPdfBytes;
  String? _nuevoPdfFilename;
  bool _eliminarPdfActual = false;

  // Lógica de ingredientes
  final _formKey = GlobalKey<FormState>();
  late Future<List<RecordModel>> _ingredientesFuture;
  final List<IngredienteEditable> _ingredientesEditables = [];
  final List<String> _idsIngredientesParaEliminar = [];
  List<RecordModel> _materiasPrimasDisponibles = [];

  @override
  void initState() {
    super.initState();
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

  // --- LÓGICA DE DATOS ---

  void _setPdfUrl() {
    final pdfFileName = widget.receta.data['descripcion']?.toString();
    setState(() {
      if (pdfFileName != null && pdfFileName.isNotEmpty) {
        _pdfUrl = pb.files.getUrl(widget.receta, pdfFileName).toString();
      } else {
        _pdfUrl = null;
      }
      _pdfViewerKey = UniqueKey();
    });
  }

  Future<List<RecordModel>> _cargarIngredientes() async {
    try {
      final records = await pb.collection('receta_matPrim').getFullList(
            filter: 'id_receta = "${widget.receta.id}"',
            expand: 'id_matPrim, id_matPrim.id_unidMed',
          );
      _poblarListaEditable(records);
      return records;
    } catch (e) {
      _mostrarError('Error al cargar ingredientes: $e');
      return [];
    }
  }

  Future<void> _cargarMateriasPrimas() async {
    try {
      _materiasPrimasDisponibles = await pb.collection('matPrim').getFullList(sort: 'nombre', expand: 'id_unidMed');
    } catch (e) {
      _mostrarError('No se pudieron cargar las materias primas: $e');
    }
  }

  void _poblarListaEditable(List<RecordModel> records) {
    for (var ing in _ingredientesEditables) {
      ing.dispose();
    }
    _ingredientesEditables.clear();
    _idsIngredientesParaEliminar.clear();

    for (final recordUnion in records) {
      final matPrim = recordUnion.expand['id_matPrim']?.first;
      if (matPrim != null) {
        _ingredientesEditables.add(IngredienteEditable(
          id: recordUnion.id,
          matPrim: matPrim,
          cantidad: (recordUnion.data['cantidad'] as num?)?.toDouble() ?? 0.0,
        ));
      }
    }
  }

  void _mostrarError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }
  
  // ✨ --- 2. NUEVA FUNCIÓN PARA ABRIR EL PDF --- ✨
  Future<void> _abrirPdfEnNuevaPestana() async {
    if (_pdfUrl == null) return;
    final uri = Uri.parse(_pdfUrl!);
    
    if (await canLaunchUrl(uri)) {
      // webOnlyWindowName: '_blank' es el comando para abrir en una nueva pestaña
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

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final futures = <Future>[];
      final body = <String, dynamic>{};
      
      if (_eliminarPdfActual) {
        body['descripcion'] = null;
      }
      
      final files = <http.MultipartFile>[];
      if (_nuevoPdfBytes != null && _nuevoPdfFilename != null) {
        files.add(http.MultipartFile.fromBytes('descripcion', _nuevoPdfBytes!, filename: _nuevoPdfFilename));
      }
      
      if (body.isNotEmpty || files.isNotEmpty) {
        final updatedReceta = await pb.collection('receta').update(widget.receta.id, body: body, files: files);
        widget.receta.data.addAll(updatedReceta.data);
      }

      for (final ingrediente in _ingredientesEditables) {
        final ingBody = {
          'id_receta': widget.receta.id,
          'id_matPrim': ingrediente.matPrim.id,
          'cantidad': double.tryParse(ingrediente.cantidadController.text.replaceAll(',', '.')) ?? 0.0,
        };
        if (ingrediente.id != null) {
          futures.add(pb.collection('receta_matPrim').update(ingrediente.id!, body: ingBody));
        } else {
          futures.add(pb.collection('receta_matPrim').create(body: ingBody));
        }
      }

      for (final id in _idsIngredientesParaEliminar) {
        futures.add(pb.collection('receta_matPrim').delete(id));
      }
      
      await Future.wait(futures);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receta guardada con éxito'), backgroundColor: Colors.green));
        _toggleEditMode(cancel: true);
        _setPdfUrl(); // ✨ Se asegura de llamar a la función que actualiza la key
        _ingredientesFuture = _cargarIngredientes();
      }

    } catch (e) {
      _mostrarError('Error al guardar los cambios: $e');
    } finally {
      if(mounted) setState(() => _isSaving = false);
    }
  }
  
  void _agregarIngrediente() async {
    final RecordModel? matPrimSeleccionada = await showDialog(
      context: context,
      builder: (_) => _DialogoBuscarMatPrim(materiasPrimas: _materiasPrimasDisponibles),
    );

    if (matPrimSeleccionada != null) {
      if (_ingredientesEditables.any((ing) => ing.matPrim.id == matPrimSeleccionada.id)) {
        _mostrarError('Este ingrediente ya está en la lista.');
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

  // --- BUILDERS DE WIDGETS ---

  @override
  Widget build(BuildContext context) {
    final nombreReceta = widget.receta.data['nombre']?.toString() ?? 'Detalle';
    return Scaffold(
      appBar: AppBar(
        title: Text(nombreReceta),
        actions: _isSaving ? [] : [
          if (_isEditing)
            TextButton(onPressed: () => _toggleEditMode(cancel: true), child: const Text('Cancelar')),
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: _isEditing ? _guardarCambios : _toggleEditMode,
            tooltip: _isEditing ? 'Guardar Cambios' : 'Editar Receta',
          ),
        ],
      ),
      body: _isSaving
        ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Guardando...')]))
        : Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildSeccionPdf(),
              const Divider(height: 32),
              _buildSeccionIngredientes(),
            ],
          ),
        ),
    );
  }

  Widget _buildSeccionPdf() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Procedimiento (PDF)', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        
        if (_isEditing)
          // MODO DE EDICIÓN (sin cambios)
          Card(
            color: Colors.grey.shade100,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // ... (contenido del card de edición es igual)
                ],
              ),
            ),
          )
        else 
          // MODO VISTA (con lógica de plataforma)
          SizedBox(
            // ✨ 3. LÓGICA DE VISUALIZACIÓN BASADA EN PLATAFORMA --- ✨
            height: kIsWeb ? 150 : 500, // Menos altura en web, ya que solo es un botón
            child: _pdfUrl != null
                ? (
                  kIsWeb 
                  // --- VISTA PARA WEB ---
                  ? Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Abrir PDF en una nueva pestaña'),
                        onPressed: _abrirPdfEnNuevaPestana,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    )
                  // --- VISTA PARA MÓVIL/ESCRITORIO ---
                  : Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: SfPdfViewer.network(
                        _pdfUrl!,
                        key: _pdfViewerKey,
                      ),
                    )
                )
                // Mensaje si no hay PDF
                : const Center(
                    child: Text(
                      'No hay un PDF asociado a esta receta.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
          ),
      ],
    );
  }

  // Descarga los bytes del PDF desde la URL (maneja status != 200 lanzando excepción)
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


  // Reutiliza la UI que tenías en el bloque de edición (subir/eliminar)
  Widget _buildPdfEditCard() {
    return Card(
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_nuevoPdfBytes != null)
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text(_nuevoPdfFilename ?? "Archivo seleccionado"),
                subtitle: const Text("Nuevo PDF listo para subir"),
              )
            else if (_eliminarPdfActual)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'El PDF actual se eliminará al guardar.',
                  style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
                ),
              )
            else
              const Text("Sube un nuevo archivo PDF para reemplazar el actual o elimínalo."),
            
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _seleccionarPdf,
                  icon: const Icon(Icons.upload_file),
                  label: Text(_nuevoPdfBytes == null ? 'Seleccionar' : 'Cambiar'),
                ),
                if (widget.receta.data['descripcion'] != null || _nuevoPdfBytes != null) ...[
                  const SizedBox(width: 10),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _eliminarPdfActual = true;
                      _nuevoPdfBytes = null;
                      _nuevoPdfFilename = null;
                    }),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Eliminar'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionIngredientes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ingredientes', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        
        if (_isEditing)
          _buildListaEditable()
        else
          _buildListaDeVista(),

        if (_isEditing) ...[
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: _agregarIngrediente,
              icon: const Icon(Icons.add),
              label: const Text('Añadir Ingrediente'),
            ),
          )
        ]
      ],
    );
  }

  Widget _buildListaEditable() {
    if (_ingredientesEditables.isEmpty) {
      return const Center(child: Text('Añade un ingrediente para empezar.'));
    }
    return Column(
      children: List.generate(_ingredientesEditables.length, (index) {
        final ingrediente = _ingredientesEditables[index];
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
                onPressed: () => _eliminarIngrediente(index),
                tooltip: 'Quitar ingrediente',
              )
            ],
          ),
        );
      }),
    );
  }

  Widget _buildListaDeVista() {
    return FutureBuilder<List<RecordModel>>(
      future: _ingredientesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Ocurrió un error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Esta receta no tiene ingredientes asignados.'));
        }

        final ingredientes = snapshot.data!;
        return Column(
          children: ingredientes.map((recordUnion) {
            final matPrim = recordUnion.expand['id_matPrim']?.first;
            final unidMed = matPrim?.expand['id_unidMed']?.first;
            final nombreIngrediente = matPrim?.data['nombre'] ?? 'Ingrediente desconocido';
            final cantidad = (recordUnion.data['cantidad'] as num?)?.toDouble() ?? 0.0;
            final abreviaturaUnidad = unidMed?.data['abreviatura'] ?? '-';

            return ListTile(
              leading: const Icon(Icons.circle, size: 12, color: Colors.grey),
              title: Text(nombreIngrediente),
              trailing: Text('$cantidad $abreviaturaUnidad', style: TextStyle(color: Colors.grey.shade600)),
            );
          }).toList(),
        );
      },
    );
  }
}

class _DialogoBuscarMatPrim extends StatefulWidget {
  final List<RecordModel> materiasPrimas;
  const _DialogoBuscarMatPrim({required this.materiasPrimas});

  @override
  State<_DialogoBuscarMatPrim> createState() => _DialogoBuscarMatPrimState();
}

class _DialogoBuscarMatPrimState extends State<_DialogoBuscarMatPrim> {
  late List<RecordModel> _resultadosFiltrados;

  @override
  void initState() {
    super.initState();
    _resultadosFiltrados = widget.materiasPrimas;
  }

  void _filtrar(String query) {
    setState(() {
      _resultadosFiltrados = widget.materiasPrimas.where((mp) => mp.data['nombre'].toString().toLowerCase().contains(query.toLowerCase())).toList();
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