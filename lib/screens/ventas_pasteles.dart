import 'package:flutter/material.dart';
import 'carrito.dart'; // Importa la página externa Carrito

class VentasPasteles extends StatelessWidget {
  const VentasPasteles({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> saboresVainilla = [
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
      'Queso con Zarzmora',
      'Queso Revuelto',
    ];

    final List<String> saboresChocolate = [
      'ChocoFresa',
      'ChocoMoka',
      'ChocoNuez',
      'ChocoNutella',
      'ChocoOreo',
      'ChocoZarzamora',
    ];

    final Map<String, String> emojisPorSabor = {
      'Cajeta': '🍬',
      'Durazno': '🍑',
      'Fresa': '🍓',
      'Limon': '🍋',
      'PiñaCoco': '🍍🥥',
      'Zarzamora': '🫐',
      'Crema Irlandesa': '🥛',
      'Fresa con Nuez': '🍓🌰',
      'Durazno con Mango': '🍑🥭',
      'Durazno con Nuez': '🍑🌰',
      'Moka': '☕',
      'Nutella': '🍫',
      'Rompope con Nuez': '🥚🌰',
      'Queso con Zarzmora': '🧀🫐',
      'Queso Revuelto': '🧀',
      'ChocoFresa': '🍓',
      'ChocoMoka': '☕',
      'ChocoNuez': '🌰',
      'ChocoNutella': '🍫',
      'ChocoOreo': '🍪',
      'ChocoZarzamora': '🫐',
    };

    final Map<String, double> tamanoEmoji = {
      'Cajeta': 40,
      'Durazno': 50,
      'Fresa': 45,
      'Limon': 40,
      'PiñaCoco': 35,
      'Zarzamora': 45,
      'Crema Irlandesa': 40,
      'Fresa con Nuez': 35,
      'Durazno con Mango': 35,
      'Durazno con Nuez': 35,
      'Moka': 40,
      'Nutella': 40,
      'Rompope con Nuez': 35,
      'Queso con Zarzmora': 35,
      'Queso Revuelto': 40,
      'ChocoFresa': 40,
      'ChocoMoka': 40,
      'ChocoNuez': 40,
      'ChocoNutella': 40,
      'ChocoOreo': 40,
      'ChocoZarzamora': 40,
    };

    double buttonSize = 100;
    double spacing = 30;

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
              // Navega a la página Carrito
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Carrito()),
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
              child: Column(
                children: [
                  const Text(
                    'Vainilla',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: saboresVainilla.map((sabor) {
                      return SizedBox(
                        width: buttonSize,
                        child: Column(
                          children: [
                            SizedBox(
                              width: buttonSize,
                              height: buttonSize,
                              child: OutlinedButton(
                                onPressed: () {},
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(255, 238, 232, 146),
                                  side: const BorderSide(color: Colors.black, width: 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    emojisPorSabor[sabor] ?? '🎂',
                                    style: TextStyle(
                                        fontSize: tamanoEmoji[sabor] ?? 40),
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
              ),
            ),
            const SizedBox(width: 16),
            // Columna Chocolate
            Expanded(
              child: Column(
                children: [
                  const Text(
                    'Chocolate',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: saboresChocolate.map((sabor) {
                      return SizedBox(
                        width: buttonSize,
                        child: Column(
                          children: [
                            SizedBox(
                              width: buttonSize,
                              height: buttonSize,
                              child: OutlinedButton(
                                onPressed: () {},
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(255, 142, 67, 67),
                                  side: const BorderSide(color: Colors.black, width: 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    emojisPorSabor[sabor] ?? '🎂',
                                    style: TextStyle(
                                        fontSize: tamanoEmoji[sabor] ?? 40),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
