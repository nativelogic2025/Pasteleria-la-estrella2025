// catalogo_screen.dart
import 'package:flutter/material.dart';

// 🔗 Importa tus pantallas de destino
import 'catalogo_recetas.dart'; // class CatalogoRecetasScreen
import 'catalogo_foto.dart';    // class CatalogoFotoScreen

class CatalogoScreen extends StatelessWidget {
  const CatalogoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> opciones = [
      'Recetas',
      'Fotos',
    ];

    // 🎯 Íconos tipo “menú administrativo”
    final List<IconData> iconos = [
      Icons.menu_book_sharp,       // Recetas
      Icons.photo_library_outlined // Fotos
    ];

    final List<Widget> pantallas = const [
      CatalogoRecetasScreen(),
      CatalogoFotoScreen(),
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
                                    MaterialPageRoute(
                                      builder: (_) => pantallas[index],
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.black, width: 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                  foregroundColor: Colors.black,
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
                              opciones[index],
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
