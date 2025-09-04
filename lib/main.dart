import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/splash_screen.dart';
import 'screens/carrito.dart';
import 'screens/carrito_provider.dart';

// 👇 Agrega estos dos si seguiste mi ejemplo de Stock
import 'screens/stock_screen.dart';
import 'screens/stock_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CarritoProvider()),
        ChangeNotifierProvider(create: (_) => StockProvider()), // 👈 nuevo
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pastelería La Estrella',
      // Opcional: tema Material 3
      // theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.pink),
      home: const SplashScreen(),
      routes: {
        '/carrito': (context) => const CarritoScreen(),
        '/stock':  (context) => const StockScreen(), // 👈 acceso directo al inventario
      },
    );
  }
}
