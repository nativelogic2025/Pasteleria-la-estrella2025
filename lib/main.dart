import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'screens/carrito.dart';
import 'screens/carrito_provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => CarritoProvider(),
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
      home: const SplashScreen(),
      routes: {
        '/carrito': (context) => const CarritoScreen(),
      },
    );
  }
}
