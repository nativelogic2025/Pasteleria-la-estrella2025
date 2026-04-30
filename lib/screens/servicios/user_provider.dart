import 'package:flutter/material.dart';
import 'auth_service.dart';

class UserProvider extends ChangeNotifier {
  String? _rol;
  String? _nombre;

  String? get rol => _rol;
  String? get nombre => _nombre;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  final AuthService _auth = AuthService();

  /// Carga el rol y nombre desde la base de datos y notifica a la app
  Future<void> refreshRole() async {
    _isLoading = true;
    notifyListeners();

    final data = await _auth.getCurrentUserData();
    _rol = data?['rol'];
    _nombre = data?['nombre'];
    
    _isLoading = false;
    notifyListeners();
  }

  /// Limpiar al cerrar sesión
  void clear() {
    _rol = null;
    _nombre = null;
    notifyListeners();
  }
}