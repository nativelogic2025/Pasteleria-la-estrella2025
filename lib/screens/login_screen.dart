import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'menu_administrativo.dart';
import 'menu_colaborador.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  final storage = const FlutterSecureStorage();

  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _guardarUsuarios();
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _guardarUsuarios() async {
    final adminPass = _hashPassword("1999");
    final colabPass = _hashPassword("2025");

    String? adminGuardado = await storage.read(key: 'admin');
    if (adminGuardado == null) {
      await storage.write(key: 'admin', value: adminPass);
    }

    String? colabGuardado = await storage.read(key: 'colaborador');
    if (colabGuardado == null) {
      await storage.write(key: 'colaborador', value: colabPass);
    }
  }

  Future<void> _login() async {
    final usuario = _usuarioController.text.trim().toLowerCase();
    final passwordHash = _hashPassword(_passwordController.text);

    String? storedHash = await storage.read(key: usuario);

    // 👇 después del await, revisamos si el widget sigue montado
    if (!mounted) return;

    if (storedHash != null && storedHash == passwordHash) {
      // Usuario correcto, navegar según rol
      if (usuario == "admin") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MenuAdministrativo()),
        );
      } else if (usuario == "colaborador") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MenuColaborador()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Usuario o contraseña incorrectos")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Fondo blanco agregado
      body: Row(
        children: [
          Expanded(
            flex: 1,
            child: Center(
              child: Image.asset(
                'assets/logo.png',
                width: 500,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Login",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),
                  const Text("Usuario"),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _usuarioController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Ingrese su usuario',
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("Contraseña"),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: 'Ingrese su contraseña',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 106, 224, 143),
                      ),
                      child: const Text(
                        "Iniciar sesión",
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
