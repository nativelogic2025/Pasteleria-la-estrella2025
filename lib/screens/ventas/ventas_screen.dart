import 'package:flutter/material.dart';

// Importa aquí tus pantallas externas
import 'ventas_pasteles.dart';
import 'ventas.dart';
import '../carrito/carrito.dart'; // 👈 Importamos la nueva pantalla

class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  int _selectedIndex = 0;

  final List<String> categorias = [
    'Pasteles',
    'Postres',
    'Velas',
    'Repostería',
    'Extras',
  ];

  final List<IconData> iconos = [
    Icons.cake,
    Icons.icecream,
    Icons.local_fire_department,
    Icons.cookie,
    Icons.shopping_bag,
  ];

  final List<Widget> pantallas = const [
    VentasPasteles(key: ValueKey('Pasteles')),
    Ventas(key: ValueKey('Postres'), categoria: 'Postres'),
    Ventas(key: ValueKey('Velas'), categoria: 'Velas'),
    Ventas(key: ValueKey('Repostería'), categoria: 'Repostería'),
    Ventas(key: ValueKey('Extras'), categoria: 'Extras'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Punto de Venta'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Row(
        children: [
          // LADO IZQUIERDO: Categorías y Productos
          Expanded(
            flex: 7,
            child: Column(
              children: [
                // Barra de Categorías
                Container(
                  height: 80,
                  color: Colors.white,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: categorias.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final isSelected = _selectedIndex == index;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedIndex = index;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.black : Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: isSelected ? Colors.black : Colors.grey.shade300,
                            ),
                            boxShadow: isSelected
                                ? [
                                    const BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    )
                                  ]
                                : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                iconos[index],
                                color: isSelected ? Colors.white : Colors.black54,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                categorias[index],
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Contenido de la categoría seleccionada
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    // Usamos IndexedStack o simplemente pantallas[_selectedIndex]
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.02, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: pantallas[_selectedIndex],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // LADO DERECHO: Carrito Permanente
          Container(
            width: 380, // Ancho fijo para el carrito en tablets/desktop
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                left: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(-5, 0),
                ),
              ],
            ),
            child: const CarritoWidget(), // Usamos el widget extraído
          ),
        ],
      ),
    );
  }
}

