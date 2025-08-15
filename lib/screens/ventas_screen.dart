import 'package:flutter/material.dart';

// Importa aquí tus pantallas externas
import 'ventas_pasteles.dart';
import 'ventas_postres.dart';
import 'ventas_velas.dart';
import 'ventas_reposteria.dart';
import 'ventas_extras.dart';
import 'carrito.dart'; // 👈 Importamos la nueva pantalla

class VentasScreen extends StatelessWidget {
  const VentasScreen({super.key});

  @override
  Widget build(BuildContext context) {
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

    final List<Widget> pantallas = [
      const VentasPasteles(),
      const VentasPostres(),
      const VentasVelas(),
      const VentasReposteria(),
      const VentasExtras(),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Ventas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context), // Regresa a la página anterior
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CarritoScreen())

              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          double spacing = 20;
          int filas = 3;
          double buttonSize = (constraints.maxHeight - (spacing * (filas + 1))) / filas;
          double maxWidthButton = (constraints.maxWidth - spacing * 2 - 40) / 3;
          if (buttonSize > maxWidthButton) buttonSize = maxWidthButton;

          return Center(
            child: Wrap(
              spacing: spacing,
              runSpacing: spacing + 20,
              alignment: WrapAlignment.center,
              children: List.generate(categorias.length, (index) {
                return SizedBox(
                  width: buttonSize,
                  child: Column(
                    children: [
                      SizedBox(
                        width: buttonSize,
                        height: buttonSize,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => pantallas[index]),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Colors.black, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Icon(
                            iconos[index],
                            size: buttonSize / 2,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        categorias[index],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}

