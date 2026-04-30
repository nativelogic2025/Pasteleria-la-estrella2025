import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'servicios/user_provider.dart';
import 'ventas/ventas_screen.dart';
import 'pedido/pedido_screen.dart';
import 'catalogo/catalogo_screen.dart';
import 'ver_pedidos/ver_pedidos_screen.dart';
import 'produccion/produccion_screen.dart';
import 'login/login_screen.dart';
import 'widgets/notificaciones_panel.dart';

class MenuColaborador extends StatelessWidget {
  const MenuColaborador({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final nombre = userProvider.nombre ?? 'Usuario';

    // Definición de los módulos (Cards)
    final List<Map<String, dynamic>> modulos = [
      {
        'titulo': 'Ventas',
        'icono': Icons.point_of_sale_rounded,
        'color': const Color(0xFFE67E22), // Naranja pastelero
        'pantalla': const VentasScreen(),
      },
      {
        'titulo': 'Pedido',
        'icono': Icons.shopping_cart_checkout_rounded,
        'color': const Color(0xFF2980B9), // Azul
        'pantalla': const PedidoScreen(),
      },
      {
        'titulo': 'Producción',
        'icono': Icons.blender_rounded,
        'color': const Color(0xFF27AE60), // Verde
        'pantalla': const StockScreen(),
      },
      {
        'titulo': 'Catálogo',
        'icono': Icons.menu_book_rounded,
        'color': const Color(0xFF8E44AD), // Morado
        'pantalla': const CatalogoScreen(),
      },
      {
        'titulo': 'Ver Pedidos',
        'icono': Icons.calendar_month_rounded,
        'color': const Color(0xFFF39C12), // Amarillo mostaza
        'pantalla': const VerPedidosScreen(),
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      endDrawer: const Drawer(
        width: 400,
        child: NotificacionesPanel(rol: 'colaborador'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // =========================
            // HEADER PREMIUM
            // =========================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCF5EE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.bakery_dining_rounded, color: Color(0xFF8C5535), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '¡Qué bueno verte de vuelta, $nombre!',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8C5535),
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Menú Colaborador',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Builder(
                    builder: (context) => Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF8C5535), size: 28),
                          onPressed: () {
                            Scaffold.of(context).openEndDrawer();
                          },
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Cerrar Sesión'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),

            // =========================
            // GRID DE MÓDULOS (Botones Gigantes)
            // =========================
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double spacing = 20;
                  int filas = 2; 
                  if (constraints.maxHeight > 800) filas = 3;
                  
                  double buttonSize = (constraints.maxHeight - (spacing * (filas + 1))) / filas;
                  double maxWidthButton = (constraints.maxWidth - spacing * 3) / 4; 
                  if (buttonSize > maxWidthButton) buttonSize = maxWidthButton;
                  
                  buttonSize = buttonSize.clamp(140.0, 240.0);

                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        alignment: WrapAlignment.center,
                        children: modulos.map((m) {
                          return SizedBox(
                            width: buttonSize,
                            height: buttonSize,
                            child: _BigModuloCard(
                              titulo: m['titulo'],
                              icono: m['icono'],
                              colorIcono: m['color'],
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => m['pantalla']),
                                );
                              },
                              size: buttonSize,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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
                // Ícono Gigante Animado
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
                
                // Texto Centrado
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
