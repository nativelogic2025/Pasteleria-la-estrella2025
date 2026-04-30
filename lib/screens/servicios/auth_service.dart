import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart'; // Importa tu cliente donde definiste 'final supabase = ...'

class AuthService {
  final _supabase = Supabase.instance.client;

  /// Login con Supabase Auth
  Future<void> loginUser(String email, String password) async {
    await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    // Nota: Supabase refresca la sesión automáticamente, no necesitas un "authRefresh" manual.
  }

  /// Obtener el rol y nombre desde la base de datos
  Future<Map<String, String?>?> getCurrentUserData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      // 1. Verificar si el usuario está activo y obtener su nombre
      final userRecord = await _supabase
          .from('usuarios')
          .select('activo, nombre_completo')
          .eq('id', user.id)
          .maybeSingle();
          
      if (userRecord != null && userRecord['activo'] == false) {
        await logout();
        throw Exception('Cuenta desactivada');
      }

      // 2. Obtener el rol
      final data = await _supabase
          .from('usuarios_rol')
          .select('''
            roles (
              nombre
            )
          ''')
          .eq('id_usuario', user.id)
          .maybeSingle();

      String? roleName;
      if (data != null) {
        final roleData = data['roles'] as Map<String, dynamic>?;
        roleName = roleData?['nombre'] as String?;
      }
      
      return {
        'rol': roleName,
        'nombre': userRecord?['nombre_completo'] as String?,
      };
    } catch (e) {
      print('Error obteniendo datos del usuario: $e');
      if (e.toString().contains('Cuenta desactivada')) {
        rethrow;
      }
      return null;
    }
  }

  /// Cerrar sesión
  Future<void> logout() async => await supabase.auth.signOut();

  /// ¿Hay sesión válida?
  bool get isLoggedIn => supabase.auth.currentSession != null;
  
  /// Obtener el ID del usuario actual
  String? get userId => supabase.auth.currentUser?.id;
}