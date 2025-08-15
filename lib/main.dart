import 'package:flutter/material.dart';
import 'screens/splash_screen.dart'; // Importa la pantalla que acabas de crear

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pastelería La Estrella',
      home: const SplashScreen(),
    );
  }
}
