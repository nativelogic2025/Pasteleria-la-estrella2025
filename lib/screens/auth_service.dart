import 'pb_client.dart';

class AuthService {
  /// Login con la colección Auth `users` de PocketBase
  Future<void> loginUser(String email, String password) async {
    await pb.collection('users').authWithPassword(email, password);
    // Refresca para garantizar datos actualizados del usuario
    await pb.collection('users').authRefresh();
  }

  /// Obtener el rol guardado en el modelo de auth (users)
  String? get currentRole {
    final m = pb.authStore.model;
    // `data` contiene los campos personalizados del usuario (como 'rol')
    if (m == null) return null;
    final val = m.data['rol'];
    return (val is String) ? val : null;
  }

  /// Cerrar sesión
  Future<void> logout() async => pb.authStore.clear();

  /// ¿Hay sesión válida?
  bool get isLoggedIn => pb.authStore.isValid;
}
