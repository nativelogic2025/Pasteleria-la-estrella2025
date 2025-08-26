import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'carrito_provider.dart';
import 'carrito.dart';
import 'producto.dart' as producto;

class VentasReposteria extends StatelessWidget {
  const VentasReposteria({super.key});

  static const List<String> productos = [
    'Tiramisú',
    'Pastel Imposible',
    'Mousse',
  ];

  static const double precioBase = 50; // Precio base, ajusta según necesites

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Repostería'),
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
          int columnas = constraints.maxWidth > 600 ? 3 : 2;
          double buttonSize =
              (constraints.maxWidth - (spacing * (columnas + 1))) / columnas;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: spacing,
              runSpacing: spacing,
              alignment: WrapAlignment.center,
              children: productos.map((nombre) {
                return SizedBox(
                  width: buttonSize,
                  child: Column(
                    children: [
                      SizedBox(
                        width: buttonSize,
                        height: buttonSize,
                        child: OutlinedButton(
                          onPressed: () {
                            if (nombre == 'Tiramisú' ||
                                nombre == 'Pastel Imposible') {
                              _mostrarOpcionesTamanio(context, nombre);
                            } else if (nombre == 'Mousse') {
                              _mostrarSaboresMousse(context);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 245, 225, 184),
                            side: const BorderSide(color: Colors.black, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Image.asset(
                              'assets/images/${_formatearNombre(nombre)}.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.image_not_supported, size: 50),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        nombre,
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

  // ---------------- Tiramisú y Pastel Imposible ----------------
static void _mostrarOpcionesTamanio(BuildContext context, String nombreProducto) {
  showDialog(
    context: context,
    builder: (context) {
      return SimpleDialog(
        title: Text("Elige el tamaño de $nombreProducto"),
        children: ['Chico', 'Mediano', 'Grande'].map((tamanio) {
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              if (nombreProducto == 'Pastel Imposible') {
                _mostrarOpcionesTipo(context, nombreProducto, tamanio);
              } else {
                // Para Tiramisú, se agrega directamente
                Provider.of<CarritoProvider>(context, listen: false)
                    .agregarProducto(
                  producto.Producto(
                    nombre: "$nombreProducto $tamanio",
                    imagen:
                        'assets/images/${_formatearNombre(nombreProducto)}.png',
                    precio: precioBase,
                  ),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$nombreProducto $tamanio agregado')),
                );
              }
            },
            child: Text(tamanio),
          );
        }).toList(),
      );
    },
  );
}


  static void _mostrarOpcionesTipo(
      BuildContext context, String nombreProducto, String tamanio) {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text("Selecciona tipo"),
          children: ['Normal', 'Café'].map((tipo) {
            return SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                Provider.of<CarritoProvider>(context, listen: false)
                    .agregarProducto(
                  producto.Producto(
                    nombre: "$nombreProducto $tamanio $tipo",
                    imagen:
                        'assets/images/${_formatearNombre(nombreProducto)}.png',
                    precio: precioBase,
                  ),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$nombreProducto $tamanio $tipo agregado')),
                );
              },
              child: Text(tipo),
            );
          }).toList(),
        );
      },
    );
  }

  // ---------------- Mousse ----------------
  static void _mostrarSaboresMousse(BuildContext context) {
    List<String> sabores = [
      'Zarzamora',
      'Fresa',
      'Oreo',
      'Guayaba',
      'PiñaCoco',
      'Mango'
    ];

    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text("Elige el sabor del Mousse"),
          children: sabores.map((sabor) {
            return SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                Provider.of<CarritoProvider>(context, listen: false)
                    .agregarProducto(
                  producto.Producto(
                    nombre: "Mousse $sabor",
                    imagen: 'assets/images/mousse.png',
                    precio: precioBase,
                  ),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Mousse $sabor agregado')),
                );
              },
              child: Text(sabor),
            );
          }).toList(),
        );
      },
    );
  }

  // ---------------- Formateador de nombres para imágenes ----------------
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
