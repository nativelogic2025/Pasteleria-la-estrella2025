import 'package:flutter/material.dart';

class VentasPostres extends StatelessWidget {
  const VentasPostres({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Postres'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(
        child: Text('Aquí va la pantalla de Postres'),
      ),
    );
  }
}
