import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'carrito_provider.dart';
import 'carrito.dart';
import 'producto.dart' as producto;

class VentasVelas extends StatelessWidget {
  const VentasVelas({super.key});

  static const double precioBase = 15; // Precio base de cada vela

  static const List<String> velas = [
    'Chispas pequeñas',
    'Chispas grandes',
    'No. Rosa',
    'No. Azul',
    'No. Arcoiris',
    'Mágicas',
    'Personalizadas',
    'Felicidades',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Velas'),
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
          double buttonSize =
              (constraints.maxWidth - (spacing * (columnas + 1))) / columnas;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: spacing,
              runSpacing: spacing,
              alignment: WrapAlignment.center,
              children: velas.map((vela) {
                return SizedBox(
                  width: buttonSize,
                  child: Column(
                    children: [
                      SizedBox(
                        width: buttonSize,
                        height: buttonSize,
                        child: OutlinedButton(
                          onPressed: () {
                            if (vela.startsWith("No.")) {
                              _mostrarDialogoNumeros(context, vela);
                            } else {
                              _agregarAlCarrito(context, vela);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 240, 215, 250),
                            side:
                                const BorderSide(color: Colors.black, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Icon(
                            _getIconForVela(vela),
                            size: buttonSize / 2,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        vela,
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

  static void _agregarAlCarrito(BuildContext context, String nombre) {
    Provider.of<CarritoProvider>(context, listen: false).agregarProducto(
      producto.Producto(
        nombre: nombre,
        imagen: 'assets/images/${_formatearNombre(nombre)}.png',
        precio: precioBase,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$nombre agregado al carrito')),
    );
  }

  static void _mostrarDialogoNumeros(BuildContext context, String velaBase) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$velaBase - Selecciona un número'),
          content: SizedBox(
            width: double.maxFinite,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                for (int i = 1; i <= 9; i++)
                  ElevatedButton(
                    onPressed: () {
                      _agregarAlCarrito(context, "$velaBase $i");
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Colors.black, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size(50, 50),
                    ),
                    child: Text(
                      "$i",
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ElevatedButton(
                  onPressed: () {
                    _agregarAlCarrito(context, "$velaBase ?");
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Colors.black, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(50, 50),
                  ),
                  child: const Text(
                    "?",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static IconData _getIconForVela(String vela) {
    if (vela.contains("Chispas")) return Icons.auto_awesome;
    if (vela.contains("Rosa")) return Icons.filter_1;
    if (vela.contains("Azul")) return Icons.filter_2;
    if (vela.contains("Arcoiris")) return Icons.filter_3;
    if (vela.contains("Mágicas")) return Icons.local_fire_department;
    if (vela.contains("Personalizadas")) return Icons.brush;
    if (vela.contains("Felicidades")) return Icons.cake;
    return Icons.star;
  }

  static String _formatearNombre(String nombre) {
    return nombre
        .toLowerCase()
        .replaceAll(" ", "_")
        .replaceAll(".", "")
        .replaceAll("á", "a")
        .replaceAll("é", "e")
        .replaceAll("í", "i")
        .replaceAll("ó", "o")
        .replaceAll("ú", "u")
        .replaceAll("ñ", "n");
  }
}
