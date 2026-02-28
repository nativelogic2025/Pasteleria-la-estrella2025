// catalogo_foto.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class CatalogoFotoScreen extends StatefulWidget {
  const CatalogoFotoScreen({super.key});

  @override
  State<CatalogoFotoScreen> createState() => _CatalogoFotoScreenState();
}

enum _Vista { carpetas, album }

class _CatalogoFotoScreenState extends State<CatalogoFotoScreen> {
  // Álbum -> lista de bytes
  final Map<String, List<Uint8List>> _albums = {
    'Bautizo': [],
    'Boda': [],
    'Confirmación': [],
    'Cumpleaños niña': [],
    'Cumpleaños niño': [],
    'Pasteles de venta': [],
    'Primera comunión': [],
    'XV': [],
  };

  _Vista _vista = _Vista.carpetas;
  String? _albumActual;

  // UI state
  String _query = '';
  String _orden = 'Nombre (A–Z)';

  List<Uint8List> get _fotosActuales =>
      _albumActual == null ? [] : (_albums[_albumActual] ?? []);

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
              onPressed: _eliminarAlbumActual,
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
              onTap: _subirImagenes,
            )
          : _PrimaryFAB(
              icon: Icons.create_new_folder_rounded,
              label: 'Nuevo álbum',
              onTap: _crearAlbum,
            ),
    );
  }

  // ──────────────── Carpetas (álbums) ────────────────
  Widget _buildFolderView(BuildContext context) {
    var items = _albums.entries
        .where((e) => e.key.toLowerCase().contains(_query))
        .toList();

    items.sort((a, b) {
      switch (_orden) {
        case 'Nombre (Z–A)':
          return b.key.toLowerCase().compareTo(a.key.toLowerCase());
        case 'Fotos (↑)':
          return a.value.length.compareTo(b.value.length);
        case 'Fotos (↓)':
          return b.value.length.compareTo(a.value.length);
        default:
          return a.key.toLowerCase().compareTo(b.key.toLowerCase());
      }
    });

    if (items.isEmpty) {
      return const _Empty(
        icon: Icons.photo_library_outlined,
        text: 'No hay álbums que coincidan.\nCrea uno con “Nuevo álbum”.',
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        int cross = 2;
        if (c.maxWidth >= 1400) cross = 6;
        else if (c.maxWidth >= 1100) cross = 5;
        else if (c.maxWidth >= 900) cross = 4;
        else if (c.maxWidth >= 650) cross = 3;

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
            final nombre = items[i].key;
            final fotos = items[i].value;
            final thumbs = fotos.take(4).toList();

            // ✅ Ahora usamos la tarjeta estilo Windows
            return _WinFolderCard(
              name: nombre,
              count: fotos.length,
              thumbs: thumbs,
              onOpen: () => setState(() {
                _albumActual = nombre;
                _vista = _Vista.album;
              }),
              onMore: (a) {
                if (a == 'rename') _renombrarAlbum(nombre);
                if (a == 'delete') _confirmarEliminarAlbum(nombre);
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
    final fotos = _fotosActuales;

    if (fotos.isEmpty) {
      return const _Empty(
        icon: Icons.image_outlined,
        text: 'Este álbum no tiene fotos.\nUsa “Subir imagen” para agregar.',
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        int cross = 2;
        if (c.maxWidth >= 1400) cross = 6;
        else if (c.maxWidth >= 1100) cross = 5;
        else if (c.maxWidth >= 900) cross = 4;
        else if (c.maxWidth >= 650) cross = 3;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: fotos.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (_, i) => _PhotoTile(
            heroTag: '$_albumActual|$i',
            bytes: fotos[i],
            onTap: () => _verEnGrande(context, i),
            onRemove: () => _confirmarEliminarFoto(i),
          ),
        );
      },
    );
  }

  // ──────────────── Fotos: subir / eliminar / ver ────────────────
  Future<void> _subirImagenes() async {
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
  }

  Future<void> _confirmarEliminarFoto(int index) async {
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
  }

  void _verEnGrande(BuildContext context, int index) {
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
  }

  // ──────────────── Álbums: crear / renombrar / eliminar ────────────────
  Future<void> _crearAlbum() async {
    final controller = TextEditingController();
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
            hintText: 'Nombre del álbum',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Crear')),
        ],
      ),
    );

    if (nombre == null || nombre.isEmpty) return;
    if (_albums.containsKey(nombre)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ya existe un álbum llamado “$nombre”.')),
      );
      return;
    }

    setState(() {
      _albums[nombre] = [];
      _vista = _Vista.album;
      _albumActual = nombre;
    });
  }

  Future<void> _renombrarAlbum(String actual) async {
    final controller = TextEditingController(text: actual);
    final nuevo = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renombrar álbum'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.sentences,
          autofocus: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.drive_file_rename_outline),
            hintText: 'Nuevo nombre',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Guardar')),
        ],
      ),
    );

    if (nuevo == null || nuevo.isEmpty || nuevo == actual) return;
    if (_albums.containsKey(nuevo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ya existe un álbum llamado “$nuevo”.')),
      );
      return;
    }

    setState(() {
      final fotos = _albums.remove(actual)!;
      _albums[nuevo] = fotos;
      if (_albumActual == actual) _albumActual = nuevo;
    });
  }

  Future<void> _confirmarEliminarAlbum(String nombre) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar álbum'),
        content: Text('¿Eliminar el álbum “$nombre” y todas sus fotos?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        _albums.remove(nombre);
        if (_albumActual == nombre) {
          _albumActual = null;
          _vista = _Vista.carpetas;
        }
      });
    }
  }

  Future<void> _eliminarAlbumActual() async {
    final a = _albumActual;
    if (a == null) return;
    await _confirmarEliminarAlbum(a);
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
  final Uint8List bytes;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const _PhotoTile({
    required this.heroTag,
    required this.bytes,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              blurRadius: 14,
              offset: const Offset(0, 8),
              color: Colors.black.withOpacity(0.06),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: heroTag,
                child: Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFF1F3F6),
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image, size: 40),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: InkWell(
                  onTap: onRemove,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.delete_outline, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
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
