import 'package:flutter/material.dart';
import 'auth_service.dart';

class UserProvider extends ChangeNotifier {
  String? _rol;
  String? get rol => _rol;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  final AuthService _auth = AuthService();

  /// Carga el rol desde la base de datos y notifica a la app
  Future<void> refreshRole() async {
    _isLoading = true;
    notifyListeners();

    _rol = await _auth.getCurrentRoleName();
    
    _isLoading = false;
    notifyListeners();
  }

  /// Limpiar al cerrar sesión
  void clear() {
    _rol = null;
    notifyListeners();
  }
}