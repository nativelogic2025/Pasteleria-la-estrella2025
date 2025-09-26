import 'package:flutter/material.dart';
import 'ventas_screen.dart';
import 'pedido_screen.dart';
import 'catalogo_screen.dart';
import 'ver_pedidos_screen.dart';
import 'login_screen.dart'; // 👈 Importar login

class MenuColaborador extends StatelessWidget {
  const MenuColaborador({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> botones = [
      'Ventas',
      'Pedido',
      'Stock',
      'Catalogo',
      'Ver Pedidos',
    ];

    final List<IconData> iconos = [
      Icons.sell,
      Icons.shopping_cart_checkout,
      Icons.add_shopping_cart,
      Icons.book,
      Icons.assignment_turned_in,
    ];

    final List<Widget> pantallas = [
      const VentasScreen(),
      const PedidoScreen(),
      const CatalogoScreen(),
      const VerPedidosScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menú Colaborador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          double spacing = 20;
          int filas = 3;
          double buttonSize =
              (constraints.maxHeight - (spacing * (filas + 1))) / filas;
          double maxWidthButton =
              (constraints.maxWidth - spacing * 2 - 40) / 3;
          if (buttonSize > maxWidthButton) buttonSize = maxWidthButton;

          return Center(
            child: Wrap(
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
                                  builder: (context) => pantallas[index]),
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
          );
        },
      ),
    );
  }
}
