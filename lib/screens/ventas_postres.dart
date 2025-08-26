import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'carrito_provider.dart';
import 'carrito.dart';
import 'producto.dart' as producto;

class VentasPostres extends StatelessWidget {
  const VentasPostres({super.key});

  static const List<String> postres = [
    'Flan',
    'Pay de Limón',
    'Ensalada de Manzana',
    'Ensalada de Zanahoria',
    'Gelatina',
    'Fresas con Crema',
    'Arroz con Leche',
    'Pastelitos',
  ];

  static const double precioBase = 35; // Precio fijo por postre

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Ventas Postres'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CarritoScreen()),
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          double spacing = 20;
          int columnas = constraints.maxWidth > 600 ? 5 : 2; 
          // 👆 En pantallas grandes = 4 columnas, en móviles = 2
          double buttonSize =
              (constraints.maxWidth - (spacing * (columnas + 1))) / columnas;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: spacing,
              runSpacing: spacing,
              alignment: WrapAlignment.center,
              children: postres.map((postre) {
                return SizedBox(
                  width: buttonSize,
                  child: Column(
                    children: [
                      SizedBox(
                        width: buttonSize,
                        height: buttonSize,
                        child: OutlinedButton(
                          onPressed: () {
                            Provider.of<CarritoProvider>(context, listen: false)
                                .agregarProducto(
                              producto.Producto(
                                nombre: postre,
                                imagen:
                                    'assets/images/${_formatearNombre(postre)}.png',
                                precio: precioBase,
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('$postre agregado al carrito')),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 245, 225, 184),
                            side:
                                const BorderSide(color: Colors.black, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Image.asset(
                              'assets/images/${_formatearNombre(postre)}.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.image_not_supported,
                                      size: 50),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        postre,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  static String _formatearNombre(String nombre) {
    return nombre
        .toLowerCase()
        .replaceAll(" ", "_")
        .replaceAll("á", "a")
        .replaceAll("é", "e")
        .replaceAll("í", "i")
        .replaceAll("ó", "o")
        .replaceAll("ú", "u")
        .replaceAll("ñ", "n");
  }
}
