import 'package:supabase_flutter/supabase_flutter.dart';
import './supabase_client.dart'; // Importa tu cliente donde definiste 'final supabase = ...'

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

  /// Obtener el rol desde la tabla 'perfiles'
  Future<String?> getCurrentRoleName() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      // 🧠 EXPLICACIÓN:
      // .select('..., roles(nombre)') le dice a Supabase:
      // "Tráeme el perfil, pero también entra a la tabla 'roles' 
      // vinculada y dame solo el campo 'nombre'".
      final data = await _supabase
          .from('usuarios_rol')
          .select('''
            id_rol,
            roles (
              nombre
            )
          ''')
          .eq('id_usuario', user.id)
          .single();

      // El resultado viene como un Map anidado:
      // data = { "rol_id": 1, "roles": { "nombre": "admin" } }
      
      final roleData = data['roles'] as Map<String, dynamic>?;
      return roleData?['nombre'] as String?;
    } catch (e) {
      print('Error obteniendo rol: $e');
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