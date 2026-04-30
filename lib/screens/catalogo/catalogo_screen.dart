// catalogo_screen.dart
import 'package:flutter/material.dart';

// 🔗 Importa tus pantallas de destino
import 'catalogo_recetas.dart'; // class CatalogoRecetasScreen
import 'catalogo_foto.dart';    // class CatalogoFotoScreen
import 'package:flutter_animate/flutter_animate.dart';

class CatalogoScreen extends StatelessWidget {
  const CatalogoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 🎯 Opciones con estilo premium
    final List<Map<String, dynamic>> opciones = [
      {
        'titulo': 'Recetas',
        'icono': Icons.menu_book_sharp,
        'color': const Color(0xFF8E44AD), // Morado
        'pantalla': const CatalogoRecetasScreen(),
      },
      {
        'titulo': 'Fotos',
        'icono': Icons.photo_library_outlined,
        'color': const Color(0xFFF39C12), // Amarillo Mostaza
        'pantalla': const CatalogoFotoScreen(),
      }
    ];



    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo'),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          const double spacing = 20;
          double byHeight = (constraints.maxHeight - (spacing * 3)) / 2;
          double byWidth = (constraints.maxWidth - (spacing * 3)) / 2;
          double buttonSize = byHeight < byWidth ? byHeight : byWidth;
          buttonSize = buttonSize.clamp(120.0, 260.0);

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Wrap(
                    spacing: spacing,
                    runSpacing: spacing + 20,
                    alignment: WrapAlignment.center,
                    children: List.generate(opciones.length, (index) {
                      final opc = opciones[index];
                      return SizedBox(
                        width: buttonSize,
                        height: buttonSize,
                        child: _BigModuloCard(
                          titulo: opc['titulo'],
                          icono: opc['icono'],
                          colorIcono: opc['color'],
                          size: buttonSize,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => opc['pantalla'],
                              ),
                            );
                          },
                        ),
                      ).animate()
                       .fade(duration: 400.ms, delay: (100 * index).ms)
                       .scaleXY(begin: 0.9, duration: 400.ms, delay: (100 * index).ms);
                    }),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BigModuloCard extends StatefulWidget {
  final String titulo;
  final IconData icono;
  final Color colorIcono;
  final VoidCallback onTap;
  final double size;

  const _BigModuloCard({
    required this.titulo,
    required this.icono,
    required this.colorIcono,
    required this.onTap,
    required this.size,
  });

  @override
  State<_BigModuloCard> createState() => _BigModuloCardState();
}

class _BigModuloCardState extends State<_BigModuloCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          _controller.forward().then((_) => _controller.reverse());
          widget.onTap();
        },
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: _isHovered ? widget.colorIcono.withValues(alpha: 0.05) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _isHovered ? widget.colorIcono.withValues(alpha: 0.8) : Colors.grey.shade300,
                width: _isHovered ? 3.0 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered 
                    ? widget.colorIcono.withValues(alpha: 0.2) 
                    : Colors.black.withValues(alpha: 0.02),
                  blurRadius: _isHovered ? 15 : 8,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.all(_isHovered ? 16 : 12),
                  decoration: BoxDecoration(
                    color: _isHovered ? widget.colorIcono : widget.colorIcono.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.icono,
                    color: _isHovered ? Colors.white : widget.colorIcono,
                    size: widget.size * 0.35, 
                  ),
                ),
                SizedBox(height: widget.size * 0.1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    widget.titulo,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: (widget.size * 0.09).clamp(14.0, 20.0), 
                      fontWeight: FontWeight.w800,
                      color: _isHovered ? widget.colorIcono : Colors.grey.shade800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
