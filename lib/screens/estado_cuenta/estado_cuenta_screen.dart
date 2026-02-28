// estado_cuenta_screen.dart
import 'package:flutter/material.dart';

// 👇 Ajusta las rutas si los archivos están en otra carpeta
import 'estado_cuenta_dinero.dart';
import 'estado_cuenta_productos.dart';

class EstadoCuentaScreen extends StatelessWidget {
  const EstadoCuentaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> botones = [
      'Dinero',
      'Productos',
    ];

    final List<IconData> iconos = [
      Icons.account_balance_wallet_outlined,
      Icons.inventory_2_outlined,
    ];

    final List<Widget> pantallas = const [
      EstadoCuentaDineroScreen(),
      EstadoCuentaProductosScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estado de Cuenta'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          const double spacing = 20;

          // Mantiene el mismo “look & feel” del menú principal
          // Calculamos un tamaño cuadrado agradable y centrado
          int filas = 2; // con 2 botones, 2 filas para centrar
          double buttonSize =
              (constraints.maxHeight - (spacing * (filas + 1))) / filas;

          // Si la pantalla permite 2 columnas, ajusta ancho máximo
          final bool twoCols = constraints.maxWidth >= 520;
          final int cols = twoCols ? 2 : 1;
          double maxWidthButton =
              (constraints.maxWidth - spacing * (cols + 1)) / cols;

          if (buttonSize > maxWidthButton) buttonSize = maxWidthButton;
          buttonSize = buttonSize.clamp(140.0, 260.0);

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Wrap(
                  spacing: spacing,
                  runSpacing: spacing + 20,
                  alignment: WrapAlignment.center,
                  children: List.generate(botones.length, (index) {
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
                                side: const BorderSide(
                                  color: Colors.black,
                                  width: 2,
                                ),
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
                            botones[index],
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
          );
        },
      ),
    );
  }
}
