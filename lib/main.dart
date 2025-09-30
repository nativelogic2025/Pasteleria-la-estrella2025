import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 1. ✨ IMPORTA los archivos necesarios
import 'screens/splash_screen.dart';
import 'screens/carrito.dart';
import 'screens/carrito_provider.dart';
import 'product_notifier.dart'; // El nuevo notificador
import 'screens/pb_client.dart';        // Tu cliente centralizado de PocketBase

void main() {
  // 2. ✨ CREA una instancia de nuestro notificador
  final productNotifier = ProductNotifier();

  // 3. ✨ ¡NOS SUSCRIBIMOS UNA SOLA VEZ AQUÍ!
  // Esta suscripción vivirá mientras la app esté abierta.
  try {
    pb.collection('productos').subscribe('*', (e) {
      // Usamos un print para confirmar en la consola que los eventos llegan
      print('>>> Evento de Realtime recibido: ${e.action} en la colección ${e.record?.collectionName}');
      
      // Cuando hay un cambio, le decimos al notificador que avise a todas las pantallas.
      productNotifier.productsHaveChanged();
    });
    print("✅ Suscripción a Realtime exitosa.");
  } catch (e) {
    print("❌ Error al suscribirse a Realtime: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        // 4. ✨ AÑADE el notificador a la lista de providers
        ChangeNotifierProvider.value(value: productNotifier),
        
        // Tu provider del carrito se queda como estaba
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