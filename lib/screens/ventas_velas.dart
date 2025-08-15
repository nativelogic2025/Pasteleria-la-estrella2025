import 'package:flutter/material.dart';

class VentasVelas extends StatelessWidget {
  const VentasVelas({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Velas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(
        child: Text('Aquí va la pantalla de Velas'),
      ),
    );
  }
}
