import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math; // 👈 para pi
import 'package:pos_pasteleria_la_estrella/screens/login_screen.dart';
import 'package:confetti/confetti.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // 🎉 Seis controladores: top/bottom en izquierda, centro y derecha
  late final List<ConfettiController> _controllers;

  @override
  void initState() {
    super.initState();

    _controllers = List.generate(
      6,
      (_) => ConfettiController(duration: const Duration(seconds: 2)),
    );

    for (final c in _controllers) {
      c.play();
    }

    // Simular carga de datos
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  // 🔧 Helper para no repetir configuración
  Widget _confetti({
    required Alignment alignment,
    required ConfettiController controller,
    required double direction, // en radianes
  }) {
    final size = MediaQuery.of(context).size;
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: alignment,
          child: ConfettiWidget(
            confettiController: controller,
            blastDirectionality: BlastDirectionality.directional,
            blastDirection: direction,
            emissionFrequency: 0.25,
            numberOfParticles: 20, // menor por emisor → cobertura pareja
            gravity: 0.05, // [0..1]
            canvas: size,   // ocupa toda la pantalla
            colors: const [
              Colors.pink,
              Colors.orange,
              Colors.purple,
              Colors.yellow,
              Colors.green,
              Colors.blue,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Índices de controladores (solo para legibilidad)
    final bottomLeft = _controllers[3];
    final bottomRight = _controllers[5];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          

          // 🧨 Abajo (disparan hacia arriba)
          _confetti(
            alignment: Alignment.bottomLeft,
            controller: bottomLeft,
            direction: -math.pi / 2, // ⬆️
          ),
          _confetti(
            alignment: Alignment.bottomRight,
            controller: bottomRight,
            direction: -math.pi / 2, // ⬆️
          ),

          // 🔽 Tu contenido original intacto
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/logo.png', width: 500),
                const SizedBox(height: 20),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
