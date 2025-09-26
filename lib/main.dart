import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/splash_screen.dart';
import 'screens/carrito.dart';
import 'screens/carrito_provider.dart';

// 👇 ahora StockScreen sigue en screens/
// pero StockProvider está en providers/


void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CarritoProvider()),

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
      debugShowCheckedModeBanner: false, // quita la cinta de debug
      title: 'Pastelería La Estrella',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.pink,
      ),
      home: const SplashScreen(),
      routes: {
        '/carrito': (context) => const CarritoScreen(),

      },
    );
  }
}
