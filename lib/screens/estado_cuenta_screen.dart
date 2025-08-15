import 'package:flutter/material.dart';

class EstadoCuentaScreen extends StatelessWidget {
  const EstadoCuentaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Estado de Cuenta')),
      body: const Center(child: Text('Aquí va la pantalla de Estado de Cuenta')),
    );
  }
}
