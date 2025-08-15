import 'package:flutter/material.dart';

class PedidoScreen extends StatelessWidget {
  const PedidoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pedido')),
      body: const Center(child: Text('Aquí va la pantalla de Pedido')),
    );
  }
}
