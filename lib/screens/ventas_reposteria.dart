import 'package:flutter/material.dart';

class VentasReposteria extends StatelessWidget {
  const VentasReposteria({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Repostería'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(
        child: Text('Aquí va la pantalla de Repostería'),
      ),
    );
  }
}
