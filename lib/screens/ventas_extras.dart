import 'package:flutter/material.dart';

class VentasExtras extends StatelessWidget {
  const VentasExtras({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extras'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(
        child: Text('Aquí va la pantalla de Extras'),
      ),
    );
  }
}
