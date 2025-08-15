import 'package:flutter/material.dart';
import 'login_screen.dart'; // Pantalla de login
import 'ventas_screen.dart';
import 'pedido_screen.dart';
import 'stock_screen.dart';
import 'catalogo_screen.dart';
import 'ver_pedidos_screen.dart';
import 'estado_cuenta_screen.dart';
import 'agregar_inventario_screen.dart';

class MenuAdministrativo extends StatelessWidget {
  const MenuAdministrativo({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> botones = [
      'Ventas',
      'Pedido',
      'Stock',
      'Catalogo',
      'Ver Pedidos',
      'Estado de Cuenta',
      'Agregar inventario',
    ];

    final List<IconData> iconos = [
      Icons.sell,
      Icons.shopping_cart_checkout,
      Icons.add_shopping_cart,
      Icons.book,
      Icons.assignment_turned_in,
      Icons.account_balance,
      Icons.inventory_2,
    ];

    final List<Widget> pantallas = [
      const VentasScreen(),
      const PedidoScreen(),
      const StockScreen(),
      const CatalogoScreen(),
      const VerPedidosScreen(),
      const EstadoCuentaScreen(),
      const AgregarInventarioScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menú Administrativo'),
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
          double buttonSize = (constraints.maxHeight - (spacing * (filas + 1))) / filas;
          double maxWidthButton = (constraints.maxWidth - spacing * 2 - 40) / 3;
          if (buttonSize > maxWidthButton) buttonSize = maxWidthButton;

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Wrap(
                  spacing: spacing,
                  runSpacing: spacing + 20,
                  alignment: WrapAlignment.center,
                  children: List.generate(6, (index) {
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
                const SizedBox(height: 20),
                // Último botón centrado
                SizedBox(
                  width: buttonSize,
                  height: buttonSize,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => pantallas[6]),
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
                      iconos[6],
                      size: buttonSize / 2,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: buttonSize,
                  child: Text(
                    botones[6],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
