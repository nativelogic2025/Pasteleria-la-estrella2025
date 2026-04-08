import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Importa el SDK

import 'screens/splash_screen.dart';
import 'screens/carrito/carrito.dart';
import 'screens/carrito/carrito_provider.dart';
import 'product_notifier.dart'; 
import 'screens/servicios/supabase_client.dart';

import 'screens/servicios/user_provider.dart';

void main() async {
  // 1. Obligatorio para inicializar servicios antes de runApp
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inicializamos Supabase (usa la función que creamos antes)
  await initSupabase();

  final productNotifier = ProductNotifier();

  // 3. ✨ REALTIME CON SUPABASE
  // Creamos un canal para escuchar cambios en la tabla 'productos'
  supabase
      .channel('public:productos') // Nombre del canal (puede ser cualquier string)
      .onPostgresChanges(
        event: PostgresChangeEvent.all, // Escucha INSERT, UPDATE y DELETE
        schema: 'public',
        table: 'productos',
        callback: (payload) {
          print('>>> Evento Realtime de Supabase: ${payload.eventType}');
          
          // Notificamos a la app que algo cambió
          productNotifier.productsHaveChanged();
        },
      )
      .subscribe();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: productNotifier),
        ChangeNotifierProvider(create: (_) => CarritoProvider()),

        ChangeNotifierProvider(create: (_) => UserProvider()),
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