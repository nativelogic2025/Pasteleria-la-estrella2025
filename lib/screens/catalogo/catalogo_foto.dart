// catalogo_foto.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'nueva_imagen.dart';
import 'nuevo_album.dart';
import 'editar_album.dart';
import 'package:flutter_animate/flutter_animate.dart';

final supabase = Supabase.instance.client;

class CatalogoFotoScreen extends StatefulWidget {
  const CatalogoFotoScreen({super.key});

  @override
  State<CatalogoFotoScreen> createState() => _CatalogoFotoScreenState();
}

class _CatalogoFotoScreenState extends State<CatalogoFotoScreen> {
  // Datos
  List<Map<String, dynamic>> _albums = [];
  Map<String, List<Map<String, dynamic>>> _fotosPorAlbum = {};

  // Estado
  bool _cargandoDatos = true;
  bool _refrescando = false;

  // Selección
  String? _selectedAlbumId;

  // Filtros Álbums
  final TextEditingController _searchAlbumCtrl = TextEditingController();
  String _queryAlbum = '';

  // Filtros Fotos
  final TextEditingController _searchFotoCtrl = TextEditingController();
  String _queryFoto = '';

  @override
  void initState() {
    super.initState();
    _inicializarAlbums();
    _searchAlbumCtrl.addListener(() {
      if (!mounted) return;
      setState(() => _queryAlbum = _searchAlbumCtrl.text.trim().toLowerCase());
    });
    _searchFotoCtrl.addListener(() {
      if (!mounted) return;
      setState(() => _queryFoto = _searchFotoCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchAlbumCtrl.dispose();
    _searchFotoCtrl.dispose();
    super.dispose();
  }

  void _mostrarSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }

  Future<void> _inicializarAlbums() async {
    try {
      final results = await supabase.from('albumes').select('*, fotos_album(count)').order('nombre');

      if (!mounted) return;
      setState(() {
        _albums = List<Map<String, dynamic>>.from(results);
        _cargandoDatos = false;
        if (_albums.isNotEmpty && _selectedAlbumId == null) {
          _seleccionarAlbum(_albums.first['id_album'].toString());
        } else if (_selectedAlbumId != null) {
          _seleccionarAlbum(_selectedAlbumId!); // recargar fotos del actual
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoDatos = false);
      _mostrarSnack('Error al cargar Álbums: $e', isError: true);
    }
  }

  Future<void> _seleccionarAlbum(String idAlbum) async {
    setState(() {
      _selectedAlbumId = idAlbum;
      _queryFoto = ''; // Limpiar busqueda de foto al cambiar album
      _searchFotoCtrl.clear();
    });

    try {
      final results = await supabase
          .from('fotos_album')
          .select('*')
          .eq('id_album', idAlbum)
          .order('titulo');

      if (!mounted) return;
      setState(() {
        _fotosPorAlbum[idAlbum] = List<Map<String, dynamic>>.from(results);
      });
    } catch (e) {
      _mostrarSnack('Error al cargar fotos: $e', isError: true);
    }
  }

  Future<void> _refrescar() async {
    if (_refrescando) return;
    _refrescando = true;
    await _inicializarAlbums();
    setState(() => _refrescando = false);
  }

  String? _iconUrl(Map<String, dynamic> r) {
    final file = r['imagen_url'];
    if (file == null || file.toString().isEmpty) return null;
    return supabase.storage.from('recetas').getPublicUrl('${file.toString()}');
  }

  String? _portadaUrl(Map<String, dynamic> r) {
    final file = r['portada_url'];
    if (file == null || file.toString().isEmpty) return null;
    return supabase.storage.from('recetas').getPublicUrl('${file.toString()}');
  }

  // --- ACCIONES ALBUM ---
  Future<void> _mostrarDialogoCrearCarpeta() async {
    final nuevoAlbum = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => DialogoCrearAlbum(),
    );

    if (nuevoAlbum != null && mounted) {
      await _refrescar();
      _seleccionarAlbum(nuevoAlbum['id_album'].toString());
      _mostrarSnack('Álbum creado correctamente');
    }
  }

  Future<void> _mostrarDialogoEditarCarpeta(Map<String, dynamic> r) async {
    final Map<String, dynamic>? resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => DialogoEditarAlbum(
        nombre: r['nombre'],
        urlImagen: _portadaUrl(r),
        descripcion: r['descripcion'],
        estado: r['activo'],
      ),
    );

    if (resultado != null) {
      try {
        final nuevaImagenFile = resultado.remove('nueva_imagen_file');
        final imagenBytesWeb = resultado.remove('imagen_bytes_web');
        final bool borrarImagen = resultado.remove('borrar_imagen_servidor') ?? false;

        final String? urlActual = r['portada_url'];
        String? nuevaUrlFinal = urlActual;

        if (borrarImagen && urlActual != null && urlActual.isNotEmpty) {
          await supabase.storage.from('recetas').remove([urlActual]);
          nuevaUrlFinal = null;
        }

        if (imagenBytesWeb != null || nuevaImagenFile != null) {
          if (urlActual != null && urlActual.isNotEmpty) {
            await supabase.storage.from('recetas').remove([urlActual]);
          }

          final String nombreArchivo = 'img_${DateTime.now().millisecondsSinceEpoch}.png';

          if (imagenBytesWeb != null) {
            await supabase.storage.from('recetas/albums').uploadBinary(
              nombreArchivo, imagenBytesWeb,
              fileOptions: const FileOptions(contentType: 'image/png', upsert: true),
            );
          } else {
            await supabase.storage.from('recetas/albums').upload(
              nombreArchivo, nuevaImagenFile,
              fileOptions: const FileOptions(contentType: 'image/png', upsert: true),
            );
          }
          nuevaUrlFinal = 'albums/$nombreArchivo';
        }

        resultado['portada_url'] = nuevaUrlFinal;
        await supabase.from('albumes').update(resultado).eq('id_album', r['id_album']);

        await _refrescar();
        _mostrarSnack('Álbum actualizado');
      } catch (e) {
        _mostrarSnack('Error al guardar: $e', isError: true);
      }
    }
  }

  Future<void> _confirmarEliminarAlbum(Map<String, dynamic> album) async {
    final id = album['id_album'].toString();
    final nombre = album['nombre'];
    final portada = album['portada_url'] ?? '';

    try {
      // 1. Obtener todas las fotos del álbum
      final fotos = await supabase.from('fotos_album').select().eq('id_album', id);
      final int conteo = fotos.length;

      if (!mounted) return;

      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Eliminar álbum?'),
          content: Text(
            conteo > 0 
            ? 'El álbum "$nombre" contiene $conteo foto(s).\n\n¿Estás seguro de que deseas eliminar el álbum y TODAS sus fotos permanentemente?'
            : 'Estás a punto de eliminar el álbum "$nombre". Esta acción no se puede deshacer.'
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: Text(conteo > 0 ? 'Sí, Eliminar Todo' : 'Eliminar'),
            )
          ],
        ),
      );

      if (confirmar == true) {
        // 2. Borrar las fotos del Storage si existen
        if (fotos.isNotEmpty) {
          final List<String> urlsParaBorrar = [];
          for (var f in fotos) {
            if (f['imagen_url'] != null && f['imagen_url'].toString().isNotEmpty) {
              urlsParaBorrar.add(f['imagen_url'].toString());
            }
          }
          if (urlsParaBorrar.isNotEmpty) {
            try {
              await supabase.storage.from('recetas').remove(urlsParaBorrar);
            } catch (e) {
              debugPrint('Error al borrar fotos del storage: $e');
            }
          }
          // Borrar registros de fotos_album
          await supabase.from('fotos_album').delete().eq('id_album', id);
        }

        // 3. Borrar la portada del Storage si existe
        if (portada.isNotEmpty) {
          try {
            await supabase.storage.from('recetas').remove([portada]);
          } catch (e) {
            debugPrint('Error al borrar portada del storage: $e');
          }
        }
        
        // 4. Borrar el álbum
        await supabase.from('albumes').delete().eq('id_album', id);
        
        if (_selectedAlbumId == id) {
          setState(() => _selectedAlbumId = null);
        }
        await _refrescar();
        if (mounted) _mostrarSnack('Álbum eliminado correctamente');
      }
    } catch (e) {
      if (mounted) _mostrarSnack('Error al eliminar álbum: $e', isError: true);
    }
  }

  // --- ACCIONES FOTO ---
  Future<void> _mostrarDialogoSubirImagen(String idAlbum) async {
    final nuevaImagen = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => DialogoSubirImagen(id_album: idAlbum),
    );

    if (nuevaImagen != null && mounted) {
      setState(() {
        if (_fotosPorAlbum[idAlbum] == null) _fotosPorAlbum[idAlbum] = [];
        _fotosPorAlbum[idAlbum]!.add(nuevaImagen);
        _fotosPorAlbum[idAlbum]!.sort((a, b) => (a['titulo'] ?? '').toLowerCase().compareTo((b['titulo'] ?? '').toLowerCase()));
      });
      // Actualizar el conteo en el álbum
      _refrescar();
      _mostrarSnack('Imagen subida correctamente');
    }
  }

  Future<void> _confirmarEliminarFoto(Map<String, dynamic> foto, String idAlbum) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar foto?'),
        content: Text('Estás a punto de eliminar "${foto['titulo']}". Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          )
        ],
      ),
    );

    if (confirmar == true) {
      try {
        final imagenUrl = foto['imagen_url'];
        if (imagenUrl != null && imagenUrl.toString().isNotEmpty) {
          await supabase.storage.from('recetas').remove([imagenUrl]);
        }
        await supabase.from('fotos_album').delete().eq('id_foto', foto['id_foto']);

        setState(() {
          _fotosPorAlbum[idAlbum]?.removeWhere((f) => f['id_foto'] == foto['id_foto']);
        });
        _refrescar(); // Actualizar count
        _mostrarSnack('Foto eliminada');
      } catch (e) {
        _mostrarSnack('Error al eliminar: $e', isError: true);
      }
    }
  }

  void _verEnGrande(String nombre, String imgUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: imgUrl != ''
                    ? Image.network(
                        imgUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40, color: Colors.white),
                      )
                    : const Icon(Icons.image, size: 40, color: Colors.white),
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
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoDatos) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Filtrar albums
    final albumsFiltrados = _albums.where((a) => (a['nombre'] ?? '').toString().toLowerCase().contains(_queryAlbum)).toList();

    // Album seleccionado
    Map<String, dynamic>? albumSeleccionado;
    if (_selectedAlbumId != null) {
      try {
        albumSeleccionado = _albums.firstWhere((a) => a['id_album'].toString() == _selectedAlbumId);
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
            const Icon(Icons.photo_album, color: Color(0xFF8C5535)),
            const SizedBox(width: 12),
            const Text('Álbums', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(width: 30),
            
            // Search Bar de Albums
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 42,
                child: TextField(
                  controller: _searchAlbumCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar álbum...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    suffixIcon: _queryAlbum.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => _searchAlbumCtrl.clear())
                        : null,
                  ),
                ),
              ),
            ),
            const Spacer(),
            
            ElevatedButton.icon(
              onPressed: _mostrarDialogoCrearCarpeta,
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: const Text("Nuevo Álbum", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
          // PANEL IZQUIERDO (Lista de Álbums)
          Container(
            width: 320,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            child: RefreshIndicator(
              onRefresh: _refrescar,
              child: albumsFiltrados.isEmpty
                  ? const Center(child: Text('No hay álbums.', style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: albumsFiltrados.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final album = albumsFiltrados[index];
                        final id = album['id_album'].toString();
                        final isSelected = id == _selectedAlbumId;
                        final nombre = album['nombre'] ?? 'Sin nombre';
                        final portada = _portadaUrl(album);
                        
                        int conteo = 0;
                        if (album['fotos_album'] != null && album['fotos_album'] is List && album['fotos_album'].isNotEmpty) {
                          conteo = int.tryParse(album['fotos_album'][0]['count'].toString()) ?? 0;
                        }

                        return InkWell(
                          onTap: () => _seleccionarAlbum(id),
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            child: Row(
                              children: [
                                // Portada en miniatura
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: portada != null
                                      ? Image.network(portada, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.broken_image, size: 20, color: Colors.grey))
                                      : const Icon(Icons.folder, color: Colors.grey),
                                ),
                                const SizedBox(width: 12),
                                // Nombre y conteo
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nombre,
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                          color: isSelected ? const Color(0xFF8C5535) : Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$conteo fotos',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                                // Menú de opciones del álbum
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert, size: 20, color: Colors.grey.shade600),
                                  tooltip: 'Opciones',
                                  onSelected: (val) {
                                    if (val == 'editar') _mostrarDialogoEditarCarpeta(album);
                                    if (val == 'eliminar') _confirmarEliminarAlbum(album);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'editar', child: ListTile(leading: Icon(Icons.edit, size: 20), title: Text('Editar', style: TextStyle(fontSize: 14)), contentPadding: EdgeInsets.zero, dense: true)),
                                    PopupMenuItem(value: 'eliminar', child: ListTile(leading: Icon(Icons.delete, color: Colors.red, size: 20), title: Text('Eliminar', style: TextStyle(color: Colors.red, fontSize: 14)), contentPadding: EdgeInsets.zero, dense: true)),
                                  ],
                                ),
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
          
          // PANEL DERECHO (Galería)
          Expanded(
            child: albumSeleccionado == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_library_outlined, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('Selecciona un álbum', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Cabecera Galería
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(albumSeleccionado['nombre'] ?? 'Álbum', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF8C5535))),
                                if (albumSeleccionado['descripcion'] != null && albumSeleccionado['descripcion'].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(albumSeleccionado['descripcion'], style: const TextStyle(color: Colors.grey)),
                                  )
                              ],
                            ),
                            const Spacer(),
                            // Buscador de fotos
                            SizedBox(
                              width: 250,
                              height: 38,
                              child: TextField(
                                controller: _searchFotoCtrl,
                                decoration: InputDecoration(
                                  hintText: 'Buscar foto...',
                                  prefixIcon: const Icon(Icons.search, size: 18),
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            FilledButton.icon(
                              onPressed: () => _mostrarDialogoSubirImagen(_selectedAlbumId!),
                              icon: const Icon(Icons.upload, size: 18),
                              label: const Text('Subir Foto'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            )
                          ],
                        ),
                      ),
                      
                      // Grid de fotos
                      Expanded(
                        child: _fotosPorAlbum[_selectedAlbumId] == null
                            ? const Center(child: CircularProgressIndicator())
                            : Builder(
                                builder: (context) {
                                  final fotos = _fotosPorAlbum[_selectedAlbumId]!;
                                  final filtradas = fotos.where((f) => (f['titulo'] ?? '').toString().toLowerCase().contains(_queryFoto)).toList();

                                  if (filtradas.isEmpty) {
                                    return Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.image_not_supported_outlined, size: 60, color: Colors.grey.shade300),
                                          const SizedBox(height: 12),
                                          Text('No hay fotos aquí', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                                        ],
                                      )
                                    );
                                  }

                                  return LayoutBuilder(
                                    builder: (context, c) {
                                      int cross = c.maxWidth >= 1200 ? 5 : c.maxWidth >= 800 ? 4 : c.maxWidth >= 500 ? 3 : 2;
                                      return GridView.builder(
                                        padding: const EdgeInsets.all(24),
                                        itemCount: filtradas.length,
                                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: cross,
                                          crossAxisSpacing: 16,
                                          mainAxisSpacing: 16,
                                        ),
                                        itemBuilder: (_, i) {
                                          final foto = filtradas[i];
                                          final String url = _iconUrl(foto) ?? '';
                                          final String titulo = foto['titulo'] ?? 'Sin título';

                                          return Card(
                                            clipBehavior: Clip.antiAlias,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            elevation: 2,
                                            child: InkWell(
                                              onTap: () => _verEnGrande(titulo, url),
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  url.isNotEmpty
                                                      ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.broken_image, size: 40))
                                                      : const Icon(Icons.image, size: 40),
                                                  Positioned(
                                                    top: 6,
                                                    right: 6,
                                                    child: CircleAvatar(
                                                      backgroundColor: Colors.black.withValues(alpha: 0.6),
                                                      radius: 14,
                                                      child: IconButton(
                                                        padding: EdgeInsets.zero,
                                                        icon: const Icon(Icons.delete, size: 16, color: Colors.white),
                                                        onPressed: () => _confirmarEliminarFoto(foto, _selectedAlbumId!),
                                                      ),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    bottom: 0, left: 0, right: 0,
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          begin: Alignment.bottomCenter,
                                                          end: Alignment.topCenter,
                                                          colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                                                        ),
                                                      ),
                                                      child: Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ).animate(key: ValueKey(foto['id_foto'].toString()))
                                           .fade(duration: 400.ms, delay: (20 * i).ms)
                                           .scaleXY(begin: 0.9, duration: 400.ms, delay: (20 * i).ms);
                                        },
                                      );
                                    }
                                  );
                                }
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
