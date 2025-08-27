import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'carrito_provider.dart';
import 'carrito.dart'; // Tu pantalla Carrito
import 'producto.dart' as producto;

class VentasPasteles extends StatelessWidget {
  const VentasPasteles({super.key});

  static const List<String> saboresVainilla = [
    'Cajeta',
    'Durazno',
    'Fresa',
    'Limon',
    'PiñaCoco',
    'Zarzamora',
    'Crema Irlandesa',
    'Fresa con Nuez',
    'Durazno con Mango',
    'Durazno con Nuez',
    'Moka',
    'Nutella',
    'Rompope con Nuez',
    'Queso con Zarzamora',
    'Queso Revuelto',
  ];

  static const List<String> saboresChocolate = [
    'ChocoFresa',
    'ChocoMoka',
    'ChocoNuez',
    'ChocoNutella',
    'ChocoOreo',
    'ChocoZarzamora',
  ];

  static const double buttonSize = 100;
  static const double spacing = 20;
  static const double precioBase = 50; // Precio fijo por pastel

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Ventas Pasteles'),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Columna Vainilla
            Expanded(
              child: _buildSaborColumn(context, saboresVainilla, 'Vainilla',
                  const Color.fromARGB(255, 238, 232, 146)),
            ),
            const SizedBox(width: 16),
            // Columna Chocolate
            Expanded(
              child: _buildSaborColumn(context, saboresChocolate, 'Chocolate',
                  const Color.fromARGB(255, 142, 67, 67)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaborColumn(
      BuildContext context, List<String> sabores, String titulo, Color color) {
    return Column(
      children: [
        Text(
          titulo,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: sabores.map((sabor) {
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
                            nombre: sabor,
                            imagen: 'assets/pasteles/${_formatearNombre(sabor)}.png',
                            precio: precioBase,
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$sabor agregado al carrito')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: color,
                        side: const BorderSide(color: Colors.black, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0), // Ajusta este valor para cambiar el tamaño de la imagen
                        child: Image.asset(
                          'assets/pasteles/${_formatearNombre(sabor)}.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.image_not_supported, size: 50),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sabor,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  static String _formatearNombre(String nombre) {
    return nombre.toLowerCase()
        .replaceAll(" ", "_")
        .replaceAll("á", "a")
        .replaceAll("é", "e")
        .replaceAll("í", "i")
        .replaceAll("ó", "o")
        .replaceAll("ú", "u")
        .replaceAll("ñ", "n");
  }
}
