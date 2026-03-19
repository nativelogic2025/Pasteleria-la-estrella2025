// catalogo_foto.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class CatalogoFotoScreen extends StatefulWidget {
  const CatalogoFotoScreen({super.key});

  @override
  State<CatalogoFotoScreen> createState() => _CatalogoFotoScreenState();
}

enum _Vista { carpetas, album }

class _CatalogoFotoScreenState extends State<CatalogoFotoScreen> {
  // Datos (Ahora como Mapas de Dart)
  List<Map<String, dynamic>> _albums = [];
  List<Map<String, dynamic>> _fotos = [];

  // Estado
  bool _cargandoDatos = true;
  bool _refrescando = false;

  @override
  void initState() {
    super.initState();
    _inicializarAlbums();
  }

  void _mostrarSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }

  /// Carga inicial usando PostgREST de Supabase
  Future<void> _inicializarAlbums() async {
    try {
      final results = await Future.wait([
        supabase.from('albumes').select('*').order('nombre'),
      ]);

      if (!mounted) return;
      setState(() {
        _albums = List<Map<String, dynamic>>.from(results[0]);
        print(_albums);
        _cargandoDatos = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoDatos = false);
      _mostrarSnack('Error al inicializar los Albums: $e', isError: true);
    }
  }

  Future<void> _cargarAlbum(String id_album) async {
    try {
      setState(() => _cargandoDatos = true);
      
      final results = await supabase
          .from('fotos_album')
          .select('*')
          .eq('id_album', id_album) // 🔥 Filtro indispensable
          .order('titulo');

      if (!mounted) return;
      setState(() {
        _fotos = List<Map<String, dynamic>>.from(results);
        _cargandoDatos = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoDatos = false);
      _mostrarSnack('Error al cargar fotos: $e', isError: true);
    }
  }

  // Traer la url completa del archivo
  String? _iconUrl(Map<String, dynamic> r) {
    final file = r['imagen_url']; 
    if (file == null || file.toString().isEmpty) return null;

    return supabase.storage
        .from('recetas') 
        .getPublicUrl('albums/${file.toString()}');
  }

  _Vista _vista = _Vista.carpetas;
  String? _albumActual;

  // UI state
  String _query = '';
  String _orden = 'Nombre (A–Z)';

  @override
  Widget build(BuildContext context) {
    final enAlbum = _vista == _Vista.album;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF5F6F8),
        centerTitle: true,
        title: Text(
          enAlbum ? (_albumActual ?? 'Álbum') : 'Catálogo de Álbums',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
            letterSpacing: .3,
          ),
        ),
        leading: enAlbum
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => setState(() {
                  _vista = _Vista.carpetas;
                  _albumActual = null;
                }),
              )
            : null,
        actions: [
          if (enAlbum)
            IconButton(
              tooltip: 'Eliminar álbum',
              icon: const Icon(Icons.delete_outline, color: Colors.black87),
              onPressed: () {
                // Buscamos el ID del álbum que coincide con el nombre actual
                final album = _albums.firstWhere((a) => a['nombre'] == _albumActual);
                _confirmarEliminarAlbum(album['id_album'].toString(), album['nombre']);
              },
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // Toolbar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _SearchField(
                    hint: enAlbum ? 'Buscar en este álbum…' : 'Buscar álbum…',
                    onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  ),
                ),
                const SizedBox(width: 10),
                _OrdenDropdown(
                  value: _orden,
                  items: const ['Nombre (A–Z)', 'Nombre (Z–A)', 'Fotos (↑)', 'Fotos (↓)'],
                  onChanged: (v) => setState(() => _orden = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: enAlbum ? _buildAlbumView(context) : _buildFolderView(context),
            ),
          ),
        ],
      ),
      floatingActionButton: enAlbum
          ? _PrimaryFAB(
              icon: Icons.upload_rounded,
              label: 'Subir imagen',
              onTap: () => print('_subirImagenes'),
            )
          : _PrimaryFAB(
              icon: Icons.create_new_folder_rounded,
              label: 'Nuevo álbum',
              onTap: () => _crearAlbum(),
            ),
    );
  }

  // ──────────────── Carpetas (álbums) ────────────────
  Widget _buildFolderView(BuildContext context) {
    // 1. Filtrar primero por la búsqueda del usuario
    var items = _albums.where((a) {
      final name = a['nombre']?.toString().toLowerCase() ?? '';
      return name.contains(_query);
    }).toList();

    // 2. Ordenar la lista filtrada
    items.sort((a, b) {
      final String nameA = a['nombre']?.toString().toLowerCase() ?? '';
      final String nameB = b['nombre']?.toString().toLowerCase() ?? '';
      
      switch (_orden) {
        case 'Nombre (Z–A)':
          return nameB.compareTo(nameA);
        case 'Fotos (↑)':
          // Si no tienes un conteo de fotos en la tabla, puedes usar 0 por ahora
          return (a['conteo_fotos'] ?? 0).compareTo(b['conteo_fotos'] ?? 0);
        case 'Fotos (↓)':
          return (b['conteo_fotos'] ?? 0).compareTo(a['conteo_fotos'] ?? 0);
        default: // Nombre (A–Z)
          return nameA.compareTo(nameB);
      }
    });

    if (items.isEmpty) {
      return const _Empty(
        icon: Icons.photo_library_outlined,
        text: 'No hay álbums.\nCrea uno con “Nuevo álbum”.',
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        // Cálculo de columnas responsivo
        int cross = c.maxWidth >= 1400 ? 6 : c.maxWidth >= 1100 ? 5 : c.maxWidth >= 900 ? 4 : c.maxWidth >= 650 ? 3 : 2;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (_, i) {
            final album = items[i];
            final String nombre = album['nombre'] ?? 'Sin nombre';
            final String idAlbum = album['id_album'].toString();
            
            // Aquí asumimos que tienes una forma de obtener miniaturas o el conteo
            return _WinFolderCard(
              name: nombre,
              count: album['conteo_fotos'] ?? 0, // Ajusta según tu DB
              thumbs: const [], // Puedes pasar URLs de imágenes aquí después
              onOpen: () {
                setState(() {
                  _albumActual = nombre;
                  _vista = _Vista.album;
                  _cargandoDatos = true; // Mostramos carga mientras bajamos fotos
                });
                _cargarAlbum(idAlbum); // Llamada a tu función de fotos
              },
              onMore: (accion) {
                if (accion == 'rename') print('_renombrarAlbum(album)');
                if (accion == 'delete') {
                  // ✅ NO uses _albumActual aquí, usa 'album' que es el item actual del loop
                  final String id = album['id_album'].toString();
                  final String nombre = album['nombre'] ?? 'Sin nombre';
                  
                  _confirmarEliminarAlbum(id, nombre);
                }
              },
            );
          },
        );
      },
    );
  }

  // ──────────────── Álbum (fotos) ────────────────
  Widget _buildAlbumView(BuildContext context) {
    if (_albumActual == null) return const SizedBox();

    // 1. Filtrar las fotos según la búsqueda (_query)
    // Buscamos coincidencia en el campo 'titulo' de la tabla 'fotos_album'
    var fotosFiltradas = _fotos.where((f) {
      final titulo = f['titulo']?.toString().toLowerCase() ?? '';
      return titulo.contains(_query);
    }).toList();

    // 2. Ordenar (puedes reutilizar la lógica de carpetas o simplificar)
    fotosFiltradas.sort((a, b) {
      final String titleA = a['titulo']?.toString().toLowerCase() ?? '';
      final String titleB = b['titulo']?.toString().toLowerCase() ?? '';
      return _orden == 'Nombre (Z–A)' ? titleB.compareTo(titleA) : titleA.compareTo(titleB);
    });

    if (fotosFiltradas.isEmpty) {
      return const _Empty(
        icon: Icons.image_outlined,
        text: 'No se encontraron fotos en este álbum.\nUsa “Subir imagen” para agregar.',
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        int cross = c.maxWidth >= 1400 ? 6 : c.maxWidth >= 1100 ? 5 : c.maxWidth >= 900 ? 4 : c.maxWidth >= 650 ? 3 : 2;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: fotosFiltradas.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (_, i) {
            final foto = fotosFiltradas[i];
            final String? url = _iconUrl(foto); // 👈 Usamos tu función auxiliar

            return _PhotoTile(
              heroTag: '$_albumActual|${foto['id_foto']}',
              // Si tu _PhotoTile acepta URL, usa Image.network. 
              // Si solo acepta bytes, habrá que ajustar el widget.
              imageUrl: url, 
              titulo: foto['titulo'] ?? '',
              onTap: () => print('_verEnGrande(context, foto)'),
              onRemove: () => print('_confirmarEliminarFoto(foto)'),
            );
          },
        );
      },
    );
  }

  // ──────────────── Fotos: subir / eliminar / ver ────────────────
  /*Future<void> _subirImagenes() async {
    if (_albumActual == null) return;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
      withData: true,
    );
    if (result == null) return;

    final nuevas = <Uint8List>[];
    for (final f in result.files) {
      if (f.bytes != null && f.bytes!.isNotEmpty) nuevas.add(f.bytes!);
    }
    if (nuevas.isEmpty) return;

    setState(() => _albums[_albumActual]!.addAll(nuevas));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Se agregaron ${nuevas.length} imagen(es) a “$_albumActual”.')),
    );
  }*/

  /*Future<void> _confirmarEliminarFoto(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar foto'),
        content: Text('¿Eliminar esta foto del álbum “$_albumActual”?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true && _albumActual != null) {
      setState(() => _albums[_albumActual]!.removeAt(index));
    }
  }*/

  /*void _verEnGrande(BuildContext context, int index) {
    final bytes = _fotosActuales[index];
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: Hero(
                tag: '$_albumActual|$index',
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }*/

  // ──────────────── Álbums: crear / editar / eliminar ────────────────
  Future<void> _crearAlbum() async {
    final controller = TextEditingController();
    
    // 1. Mostrar el diálogo para capturar el nombre
    final nombre = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuevo álbum'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.sentences,
          autofocus: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.photo_album_outlined),
            hintText: 'Ej. Pasteles de Boda',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('CANCELAR')
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('CREAR'),
          ),
        ],
      ),
    );

    // 2. Validaciones básicas
    if (nombre == null || nombre.isEmpty) return;

    // Verificar si ya existe localmente para ahorrar una consulta innecesaria
    final existe = _albums.any((a) => a['nombre'].toString().toLowerCase() == nombre.toLowerCase());
    if (existe) {
      _mostrarSnack('Ya existe un álbum llamado “$nombre”.', isError: true);
      return;
    }

    // 3. Lógica de inserción en Supabase
    try {
      setState(() => _cargandoDatos = true);

      // Insertamos y pedimos que nos devuelva el registro creado (.select().single())
      final nuevoAlbum = await supabase
          .from('albumes')
          .insert({'nombre': nombre})
          .select()
          .single();

      // 4. Actualizar el estado y navegar a la vista del álbum vacío
      setState(() {
        _albums.add(nuevoAlbum); // Agregamos el mapa que devolvió la DB (con su id_album)
        _albums.sort((a, b) => a['nombre'].compareTo(b['nombre'])); // Reordenar
        _albumActual = nombre;
        _fotos = []; // El álbum nuevo empieza vacío
        _vista = _Vista.album;
        _cargandoDatos = false;
      });

      _mostrarSnack('Álbum “$nombre” creado con éxito');

    } catch (e) {
      setState(() => _cargandoDatos = false);
      _mostrarSnack('No se pudo crear el álbum: $e', isError: true);
    }
  }

  Future<bool> _eliminarAlbum(String id_album, String? imagenUrl) async {
    try {

      // 1. ELIMINAR EL ARCHIVO DEL STORAGE (Si existe)
      /*if (imagenUrl != null && imagenUrl.isNotEmpty) {
        // Extraemos solo el nombre del archivo de la URL o usamos el path guardado
        // Si guardaste el nombre directo: 'pastel_chocolate.png'
        await supabase.storage
            .from('productos') // Nombre de tu bucket
            .remove([imagenUrl]); 
      }*/

      // 2. ELIMINAR EL REGISTRO DE LA BASE DE DATOS
      // Si configuraste ON DELETE CASCADE, esto borrará las variantes automáticamente
      await supabase
          .from('albumes')
          .delete()
          .eq('id_album', id_album);

      // 3. ACTUALIZAR INTERFAZ
      _inicializarAlbums();
 
      return true;

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar producto o imagen: $e'))
      );
      return false;
    }
  }  

  Future<void> _confirmarEliminarAlbum(String id, String nombre) async {
    final bool? eliminadoExitoso = await showDialog<bool>(
      context: context,
      barrierDismissible: false, 
      builder: (context) {
        bool eliminando = false;

        return StatefulBuilder(
          builder: (context, setStateInside) {
            return AlertDialog(
              title: Text(eliminando ? 'Eliminando...' : '¿Eliminar álbum?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (eliminando)
                    const SizedBox(
                      height: 80,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    Text('Estás a punto de eliminar el álbum "$nombre" y todas sus fotos. Esta acción no se puede deshacer.'),
                ],
              ),
              actions: eliminando ? [] : [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('CANCELAR'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () async {
                    setStateInside(() => eliminando = true);
                    // Llamamos a la lógica de Supabase
                    final resultado = await _eliminarAlbum(id, null);
                    if (context.mounted) Navigator.pop(context, resultado);
                  },
                  child: const Text('ELIMINAR'),
                ),
              ],
            );
          },
        );
      },
    );

    // Si se eliminó con éxito, volvemos a la vista de carpetas
    if (eliminadoExitoso == true) {
      setState(() {
        _vista = _Vista.carpetas;
        _albumActual = null;
      });
    }
  }
}

// ────────────────────── Widgets UI ──────────────────────

class _SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextField(
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black87, width: 1.2),
          ),
        ),
      ),
    );
  }
}

class _OrdenDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  const _OrdenDropdown({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButton<String>(
          value: value,
          onChanged: (v) => onChanged(v!),
          isDense: true,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          icon: const Icon(Icons.expand_more),
        ),
      ),
    );
  }
}

class _PrimaryFAB extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PrimaryFAB({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onTap,
      elevation: 2,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

/// ========= NUEVA TARJETA: Carpeta estilo Windows minimal =========
class _WinFolderCard extends StatefulWidget {
  final String name;
  final int count;
  final List<Uint8List> thumbs; // 0–4
  final VoidCallback onOpen;
  final void Function(String action) onMore;

  const _WinFolderCard({
    required this.name,
    required this.count,
    required this.thumbs,
    required this.onOpen,
    required this.onMore,
  });

  @override
  State<_WinFolderCard> createState() => _WinFolderCardState();
}

class _WinFolderCardState extends State<_WinFolderCard>
    with SingleTickerProviderStateMixin {
  bool _hover = false;

  // Paleta tipo Windows (suave/minimal)
  static const _folderTop = Color(0xFFFFE1A6);  // tapa suave
  static const _folderBody = Color(0xFFFAD084); // cuerpo
  static const _folderEdge = Color(0xFFE6B96A); // bordes sutiles

  @override
  Widget build(BuildContext context) {
    final hasThumbs = widget.thumbs.isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.01 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: InkWell(
          onTap: widget.onOpen,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  blurRadius: _hover ? 20 : 12,
                  offset: const Offset(0, 10),
                  color: Colors.black.withOpacity(_hover ? 0.14 : 0.08),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Lienzo neutro
                  Container(color: const Color(0xFFF5F6F8)),

                  // Carpeta recortada estilo Windows
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 42),
                      child: ClipPath(
                        clipper: _WindowsFolderClipper(),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Base del cuerpo
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [_folderTop, _folderBody],
                                ),
                              ),
                            ),

                            // Borde interior sutil
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _folderEdge.withOpacity(.35),
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),

                            // “Brillo” superior minimal
                            Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                height: 16,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.white.withOpacity(.35),
                                      Colors.transparent
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Contenido (collage) dentro de la carpeta
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 28, 14, 14),
                              child: hasThumbs
                                  ? _Collage(thumbs: widget.thumbs)
                                  : const _EmptyThumbWindows(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Menú ⋯
                  Positioned(
                    right: 10,
                    top: 10,
                    child: PopupMenuButton<String>(
                      tooltip: 'Más opciones',
                      elevation: 8,
                      onSelected: widget.onMore,
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'rename',
                          child: ListTile(
                            leading: Icon(Icons.drive_file_rename_outline),
                            title: Text('Renombrar'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete_outline),
                            title: Text('Eliminar'),
                          ),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: const Icon(Icons.more_horiz, size: 18),
                      ),
                    ),
                  ),

                  // Footer: nombre + badge
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 10,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const SizedBox(width: 4),
                        _CountBadgeWindows(count: widget.count),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Clip de carpeta “Windows-like”: cuerpo con pestaña
class _WindowsFolderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    // Parámetros de la forma
    final r = 10.0; // radio esquinas
    final tabW = size.width * 0.36; // ancho pestaña
    final tabH = 16.0; // alto pestaña
    final tabInset = 12.0; // separación izquierda

    final path = Path();

    // Pestaña (parte superior izquierda)
    path.moveTo(tabInset, tabH);
    path.lineTo(tabInset, r); // subir cerca de esquina sup-izq
    path.quadraticBezierTo(tabInset, 0, tabInset + r, 0);
    path.lineTo(tabInset + tabW - r, 0);
    path.quadraticBezierTo(tabInset + tabW, 0, tabInset + tabW, r);
    path.lineTo(tabInset + tabW, tabH);

    // Línea superior del cuerpo (de pestaña hacia derecha)
    path.lineTo(size.width - r, tabH);
    path.quadraticBezierTo(size.width, tabH, size.width, tabH + r);

    // Derecha
    path.lineTo(size.width, size.height - r);
    path.quadraticBezierTo(size.width, size.height, size.width - r, size.height);

    // Abajo
    path.lineTo(r, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - r);

    // Izquierda
    path.lineTo(0, tabH + r);
    path.quadraticBezierTo(0, tabH, r, tabH);

    // Cerrar al inicio de pestaña
    path.lineTo(tabInset, tabH);

    return path;
  }

  @override
  bool shouldReclip(covariant _WindowsFolderClipper oldClipper) => false;
}

// Badge minimal acorde a la carpeta Windows
class _CountBadgeWindows extends StatelessWidget {
  final int count;
  const _CountBadgeWindows({required this.count});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: .2,
        ),
      ),
    );
  }
}

// Portada vacía dentro de la carpeta Windows
class _EmptyThumbWindows extends StatelessWidget {
  const _EmptyThumbWindows();
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: const Center(
        child: Icon(Icons.insert_photo_outlined, size: 36, color: Colors.black54),
      ),
    );
  }
}

class _Collage extends StatelessWidget {
  final List<Uint8List> thumbs; // 1–4
  const _Collage({required this.thumbs});

  @override
  Widget build(BuildContext context) {
    final t = thumbs.take(4).toList();
    switch (t.length) {
      case 1:
        return _thumb(t[0]);
      case 2:
        return Row(children: [
          Expanded(child: _thumb(t[0])),
          const SizedBox(width: 4),
          Expanded(child: _thumb(t[1])),
        ]);
      case 3:
        return Row(children: [
          Expanded(child: _thumb(t[0])),
          const SizedBox(width: 4),
          Expanded(child: Column(children: [
            Expanded(child: _thumb(t[1])),
            const SizedBox(height: 4),
            Expanded(child: _thumb(t[2])),
          ])),
        ]);
      default:
        return Column(children: [
          Expanded(child: Row(children: [
            Expanded(child: _thumb(t[0])),
            const SizedBox(width: 4),
            Expanded(child: _thumb(t[1])),
          ])),
          const SizedBox(height: 4),
          Expanded(child: Row(children: [
            Expanded(child: _thumb(t[2])),
            const SizedBox(width: 4),
            Expanded(child: _thumb(t[3])),
          ])),
        ]);
    }
  }

  Widget _thumb(Uint8List b) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          b,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFFF1F3F6),
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image, color: Colors.black38),
          ),
        ),
      );
}

class _PhotoTile extends StatelessWidget {
  final String heroTag;
  final String? imageUrl;
  final String titulo;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _PhotoTile({
    required this.heroTag,
    this.imageUrl,
    required this.titulo,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Imagen desde la URL de Supabase
            Hero(
              tag: heroTag,
              child: imageUrl != null
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => 
                          const Icon(Icons.broken_image, size: 40),
                    )
                  : const Icon(Icons.image, size: 40),
            ),
            // Botón de eliminar (opcional, en una esquina)
            Positioned(
              top: 4,
              right: 4,
              child: CircleAvatar(
                backgroundColor: Colors.black26,
                radius: 14,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close, size: 16, color: Colors.white),
                  onPressed: onRemove,
                ),
              ),
            ),
            // Pie con el título
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                color: Colors.black45,
                child: Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
