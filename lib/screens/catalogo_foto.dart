// catalogo_foto.dart
import 'package:flutter/material.dart';

class CatalogoFotoScreen extends StatefulWidget {
  const CatalogoFotoScreen({super.key});

  @override
  State<CatalogoFotoScreen> createState() => _CatalogoFotoScreenState();
}

class _CatalogoFotoScreenState extends State<CatalogoFotoScreen> {
  // 👇 Arrancamos con algunos ejemplos. Reemplaza por tus assets/URLs.
  // - Si es asset: usa 'asset:assets/pasteles/chocomoka.jpg'
  // - Si es url:   usa 'url:https://.../foto.jpg'
  final List<String> _fotos = [
    'asset:assets/pasteles/chocomoka.jpg',
    'asset:assets/pasteles/limon.jpg',
    'url:https://picsum.photos/600/400?random=1',
    'url:https://picsum.photos/600/400?random=2',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo • Fotos'),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // 📐 Grid responsive: 2–4 columnas según ancho
          int crossAxisCount = 2;
          if (constraints.maxWidth >= 1200) {
            crossAxisCount = 4;
          } else if (constraints.maxWidth >= 800) {
            crossAxisCount = 3;
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _fotos.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final src = _fotos[index];
              final isAsset = src.startsWith('asset:');
              final clean = src.replaceFirst(RegExp(r'^(asset:|url:)'), '');

              return GestureDetector(
                onTap: () => _verEnGrande(context, index),
                onLongPress: () => _confirmarEliminar(context, index),
                child: Hero(
                  tag: 'foto_$index',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 📷 Muestra la imagen desde asset o red
                        isAsset
                            ? Image.asset(
                                clean,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _errorTile(),
                              )
                            : Image.network(
                                clean,
                                fit: BoxFit.cover,
                                loadingBuilder: (c, w, p) => p == null
                                    ? w
                                    : const Center(child: CircularProgressIndicator()),
                                errorBuilder: (_, __, ___) => _errorTile(),
                              ),
                        // 📌 Etiqueta sutil arriba a la izquierda (asset/url)
                        Positioned(
                          left: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isAsset ? 'Asset' : 'URL',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarPorUrl,
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('Agregar URL'),
      ),
    );
  }

  Widget _errorTile() => Container(
        color: Colors.grey.shade300,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image, size: 40),
      );

  Future<void> _agregarPorUrl() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar foto por URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://mis-fotos.com/imagen.jpg',
            prefixIcon: Icon(Icons.link),
          ),
          keyboardType: TextInputType.url,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );

    if (url != null && url.isNotEmpty) {
      setState(() {
        _fotos.add('url:$url');
      });
    }
  }

  void _verEnGrande(BuildContext context, int index) {
    final src = _fotos[index];
    final isAsset = src.startsWith('asset:');
    final clean = src.replaceFirst(RegExp(r'^(asset:|url:)'), '');

    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: Hero(
                tag: 'foto_$index',
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: isAsset
                      ? Image.asset(clean, fit: BoxFit.contain)
                      : Image.network(clean, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Cerrar',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarEliminar(BuildContext context, int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar foto'),
        content: const Text('¿Deseas eliminar esta foto de la vista? (solo local)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (ok == true) {
      setState(() {
        _fotos.removeAt(index);
      });
    }
  }
}
