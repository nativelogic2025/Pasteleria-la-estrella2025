import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../servicios/supabase_client.dart';
import 'package:flutter_animate/flutter_animate.dart';

final supabase = Supabase.instance.client;

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _usuarios = [];
  List<Map<String, dynamic>> _roles = [];
  Map<String, int?> _userRoleIdMap = {}; // userId -> roleId
  Map<int, String> _roleNameMap = {}; // roleId -> roleName

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      // 1. Obtener todos los roles
      var rolesResponse = await supabase.from('roles').select();
      var allRoles = List<Map<String, dynamic>>.from(rolesResponse);
      
      // Verificar si existen los roles básicos y crearlos si no
      bool hasAdmin = allRoles.any((r) => r['nombre'].toString().trim().toLowerCase() == 'administrador');
      bool hasColab = allRoles.any((r) => r['nombre'].toString().trim().toLowerCase() == 'colaborador');

      if (!hasAdmin || !hasColab) {
        if (!hasAdmin) await supabase.from('roles').insert({'nombre': 'Administrador', 'descripcion': 'Acceso total'});
        if (!hasColab) await supabase.from('roles').insert({'nombre': 'Colaborador', 'descripcion': 'Acceso limitado'});
        
        rolesResponse = await supabase.from('roles').select();
        allRoles = List<Map<String, dynamic>>.from(rolesResponse);
      }

      // Filtrar para que solo existan Administrador y Colaborador
      _roles = allRoles.where((r) {
        final nombre = r['nombre'].toString().trim().toLowerCase();
        return nombre == 'administrador' || nombre == 'colaborador';
      }).toList();

      for (var r in _roles) {
        _roleNameMap[r['id'] as int] = r['nombre'].toString();
      }

      // 2. Obtener usuarios y sus roles asignados (si los tienen)
      final usersResponse = await supabase.from('usuarios').select().order('creado_en', ascending: false);
      _usuarios = List<Map<String, dynamic>>.from(usersResponse);

      final userRolesResponse = await supabase.from('usuarios_rol').select();
      final userRoles = List<Map<String, dynamic>>.from(userRolesResponse);

      _userRoleIdMap.clear();
      for (var ur in userRoles) {
        final uid = ur['id_usuario'].toString();
        final rid = ur['id_rol'] as int;
        _userRoleIdMap[uid] = rid;
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cambiarEstado(String userId, bool nuevoEstado) async {
    try {
      final res = await supabase.from('usuarios').update({'activo': nuevoEstado}).eq('id', userId).select();
      if (res.isEmpty) {
        throw Exception('No se pudo cambiar el estado. Verifica tus permisos o si el usuario existe.');
      }
      
      // Actualizar localmente para no recargar todo
      setState(() {
        final index = _usuarios.indexWhere((u) => u['id'].toString() == userId);
        if (index != -1) {
          _usuarios[index]['activo'] = nuevoEstado;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(nuevoEstado ? 'Usuario activado' : 'Usuario desactivado'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cambiar estado: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _asignarRol(String userId, int? roleId) async {
    if (roleId == null) return;
    try {
      // Upsert: Si ya tiene un rol, lo actualizamos. Si no, lo insertamos.
      final existe = await supabase.from('usuarios_rol').select().eq('id_usuario', userId).maybeSingle();
      
      if (existe != null) {
        final res = await supabase.from('usuarios_rol').update({'id_rol': roleId}).eq('id_usuario', userId).select();
        if (res.isEmpty) throw Exception('No se pudo actualizar el rol. Verifica permisos.');
      } else {
        final res = await supabase.from('usuarios_rol').insert({'id_usuario': userId, 'id_rol': roleId}).select();
        if (res.isEmpty) throw Exception('No se pudo asignar el rol. Verifica permisos.');
      }

      setState(() {
        _userRoleIdMap[userId] = roleId;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rol actualizado correctamente'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al asignar rol: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _actualizarUsuario(String userId, String newName, String newPhone) async {
    try {
      final res = await supabase.from('usuarios').update({
        'nombre_completo': newName,
        'telefono': newPhone,
      }).eq('id', userId).select();

      if (res.isEmpty) {
        throw Exception('No se pudo actualizar el usuario. Verifica permisos.');
      }

      setState(() {
        final index = _usuarios.indexWhere((u) => u['id'].toString() == userId);
        if (index != -1) {
          _usuarios[index]['nombre_completo'] = newName;
          _usuarios[index]['telefono'] = newPhone;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario actualizado correctamente'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar usuario: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _eliminarUsuario(String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Usuario'),
        content: Text('¿Estás seguro de que deseas eliminar a "$userName"?\n\nSi el usuario ya ha registrado ventas o producción, no se podrá eliminar. En ese caso, te recomendamos usar el interruptor para desactivarlo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Sí, Eliminar')
          ),
        ],
      )
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      // Eliminar rol primero
      await supabase.from('usuarios_rol').delete().eq('id_usuario', userId);
      
      // Eliminar de usuarios
      final res = await supabase.from('usuarios').delete().eq('id', userId).select();
      
      if (res.isEmpty) {
        throw Exception('No se pudo eliminar el usuario. Verifica permisos.');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario eliminado correctamente'), backgroundColor: Colors.green),
        );
        _cargarDatos();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No se puede eliminar porque tiene historial (ventas, etc). Usa el botón para desactivarlo.'), 
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  void _mostrarDialogoEditar(String userId, String currentName, String currentPhone) {
    final nameCtrl = TextEditingController(text: currentName);
    final phoneCtrl = TextEditingController(text: currentPhone);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Editar Usuario'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre Completo', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
            ].animate(interval: 50.ms).fade(duration: 400.ms).slideY(begin: 0.05),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8C5535)),
              onPressed: () {
                final newName = nameCtrl.text.trim();
                final newPhone = phoneCtrl.text.trim();
                if (newName.isNotEmpty) {
                  Navigator.pop(ctx);
                  _actualizarUsuario(userId, newName, newPhone);
                }
              },
              child: const Text('Guardar Cambios'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarDialogoAsignarRol(String userId, String userName) {
    int? selectedRoleId = _userRoleIdMap[userId];

    showDialog(
      context: context,
      builder: (ctx) {
        int? tempRoleId = selectedRoleId;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Asignar Rol'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Usuario: $userName', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('Selecciona el nuevo rol:'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: tempRoleId,
                        hint: const Text('Sin rol asignado'),
                        isExpanded: true,
                        items: _roles.map((r) {
                          return DropdownMenuItem<int>(
                            value: r['id'] as int,
                            child: Text(r['nombre'].toString()),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setStateDialog(() {
                            tempRoleId = val;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8C5535)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (tempRoleId != selectedRoleId) {
                      _asignarRol(userId, tempRoleId);
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _mostrarDialogoCrearUsuario() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    int? selectedRoleId;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Crear Nuevo Usuario'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre Completo', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Correo Electrónico', border: OutlineInputBorder()),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Teléfono (Opcional)', border: OutlineInputBorder()),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passCtrl,
                      decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedRoleId,
                          hint: const Text('Seleccionar Rol'),
                          isExpanded: true,
                          items: _roles.map((r) {
                            return DropdownMenuItem<int>(
                              value: r['id'] as int,
                              child: Text(r['nombre'].toString()),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setStateDialog(() => selectedRoleId = val);
                          },
                        ),
                      ),
                    ),
                  ].animate(interval: 50.ms).fade(duration: 400.ms).slideY(begin: 0.05),
                ),
              ),
              actions: [
                if (!isSaving)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8C5535)),
                  onPressed: isSaving ? null : () async {
                    final name = nameCtrl.text.trim();
                    final email = emailCtrl.text.trim();
                    final phone = phoneCtrl.text.trim();
                    final pass = passCtrl.text;

                    if (name.isEmpty || email.isEmpty || pass.isEmpty || selectedRoleId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Por favor llena todos los campos y selecciona un rol'), backgroundColor: Colors.orange),
                      );
                      return;
                    }

                    if (pass.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres'), backgroundColor: Colors.orange),
                      );
                      return;
                    }

                    setStateDialog(() => isSaving = true);

                    try {
                      final secondaryClient = SupabaseClient(
                        SupabaseConfig.url, 
                        SupabaseConfig.anonKey,
                        authOptions: const AuthClientOptions(
                          authFlowType: AuthFlowType.implicit,
                        ),
                      );
                      final res = await secondaryClient.auth.signUp(email: email, password: pass);
                      secondaryClient.dispose();

                      if (res.user != null) {
                        final newUserId = res.user!.id;
                        
                        // Intentamos actualizar primero (por si un trigger ya lo creó)
                        var userRes = await supabase.from('usuarios').update({
                          'nombre_completo': name,
                          'correo': email,
                          'telefono': phone,
                          'activo': true,
                        }).eq('id', newUserId).select();

                        // Si no se actualizó nada, significa que no hay trigger, entonces insertamos
                        if (userRes.isEmpty) {
                          userRes = await supabase.from('usuarios').insert({
                            'id': newUserId,
                            'nombre_completo': name,
                            'correo': email,
                            'telefono': phone,
                            'activo': true,
                          }).select();
                        }

                        if (userRes.isEmpty) {
                           throw Exception('No se pudo guardar la información del usuario en la base de datos (Error de permisos).');
                        }

                        // Intentamos insertar el rol
                        // Usamos upsert por si un trigger también asignó un rol por defecto
                        final rolRes = await supabase.from('usuarios_rol').upsert({
                          'id_usuario': newUserId,
                          'id_rol': selectedRoleId,
                        }).select();
                        
                        if (rolRes.isEmpty) {
                           throw Exception('El usuario se creó, pero no se le pudo asignar el rol.');
                        }

                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Usuario creado exitosamente'), backgroundColor: Colors.green),
                          );
                          _cargarDatos();
                        }
                      } else {
                        throw Exception('No se devolvió usuario de Supabase');
                      }
                    } catch (e) {
                      setStateDialog(() => isSaving = false);
                      
                      String errorMsg = e.toString();
                      if (errorMsg.contains('usuarios_auth_uid_fkey') || errorMsg.contains('23503')) {
                        errorMsg = 'El correo electrónico ya está registrado en el sistema. (Si eliminaste a este usuario recientemente de la lista, debes eliminarlo completamente desde el panel web de Supabase en Authentication > Users).';
                      } else if (errorMsg.contains('over_email_send_rate_limit') || errorMsg.contains('rate limit exceeded')) {
                        errorMsg = 'Has alcanzado el límite de correos de Supabase (Límite por hora). Solución: Ve a Supabase > Authentication > Providers > Email y desactiva "Confirm email" para evitar este límite en el futuro.';
                      } else if (errorMsg.contains('email_provider_disabled')) {
                        errorMsg = 'Has desactivado por completo el registro por correo en Supabase. Solución: Ve a Supabase > Authentication > Providers > Email y asegúrate de que "Enable Email provider" esté encendido (verde), y SOLO apagues "Confirm email".';
                      } else if (errorMsg.contains('AuthException')) {
                        errorMsg = 'Error de autenticación al registrar el correo.';
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(errorMsg), 
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 8),
                            action: SnackBarAction(
                              label: 'Entendido',
                              textColor: Colors.white,
                              onPressed: () {},
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: isSaving 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Crear Usuario'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.people_alt_rounded, color: Color(0xFF8C5535)),
            const SizedBox(width: 12),
            const Text('Gestión de Usuarios', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: FilledButton.icon(
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Nuevo Usuario'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8C5535),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _mostrarDialogoCrearUsuario,
            ),
          )
        ],
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF8C5535)))
        : Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCF5EE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF8C5535).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFF8C5535)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Aquí puedes gestionar los accesos al sistema. Asigna roles de Administrador o Colaborador, y desactiva las cuentas de quienes ya no laboran en la pastelería.',
                          style: TextStyle(color: Colors.grey.shade800),
                        ),
                      ),
                    ],
                  ),
                ).animate().fade(duration: 400.ms).slideY(begin: -0.05),
                const SizedBox(height: 24),
                // Resumen / KPIs
                Row(
                  children: [
                    _buildKpiCard('Total Usuarios', _usuarios.length.toString(), Icons.people_alt, Colors.blue),
                    const SizedBox(width: 16),
                    _buildKpiCard('Activos', _usuarios.where((u) => u['activo'] == true).length.toString(), Icons.check_circle, Colors.green),
                    const SizedBox(width: 16),
                    _buildKpiCard('Inactivos', _usuarios.where((u) => u['activo'] != true).length.toString(), Icons.cancel, Colors.red),
                  ],
                ).animate().fade(duration: 400.ms, delay: 100.ms).slideY(begin: 0.05),
                const SizedBox(height: 24),

                // Lista de usuarios moderna
                Expanded(
                  child: ListView.builder(
                    itemCount: _usuarios.length,
                    itemBuilder: (context, index) {
                      final u = _usuarios[index];
                      final userId = u['id'].toString();
                      final nombre = u['nombre_completo']?.toString() ?? 'Sin nombre';
                      final telefono = u['telefono']?.toString() ?? '';
                      final correo = u['correo']?.toString() ?? 'Sin correo';
                      final activo = (u['activo'] == true);
                      final roleId = _userRoleIdMap[userId];
                      final roleName = roleId != null ? _roleNameMap[roleId] ?? 'Desconocido' : 'Sin rol';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        color: activo ? Colors.white : Colors.red.shade50.withValues(alpha: 0.3),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              // Avatar
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFF8C5535).withValues(alpha: 0.1),
                                child: Text(nombre.isNotEmpty ? nombre[0].toUpperCase() : '?', 
                                  style: const TextStyle(color: Color(0xFF8C5535), fontWeight: FontWeight.bold, fontSize: 20)),
                              ),
                              const SizedBox(width: 16),
                              
                              // Info principal
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(correo, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                    if (telefono.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(telefono, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                    ]
                                  ],
                                ),
                              ),
                              
                              // Rol
                              Expanded(
                                flex: 1,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: roleId != null ? const Color(0xFF8C5535).withValues(alpha: 0.1) : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      roleName,
                                      style: TextStyle(
                                        color: roleId != null ? const Color(0xFF8C5535) : Colors.grey.shade700,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              
                              // Estado
                              Expanded(
                                flex: 1,
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8, height: 8,
                                        decoration: BoxDecoration(
                                          color: activo ? Colors.green : Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(activo ? 'Activo' : 'Inactivo', 
                                        style: TextStyle(color: activo ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ),
                              
                              // Acciones
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, color: Color(0xFF8C5535), size: 20),
                                    onPressed: () => _mostrarDialogoEditar(userId, nombre, telefono),
                                    tooltip: 'Editar Datos',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.manage_accounts_rounded, color: Colors.blue, size: 20),
                                    onPressed: () => _mostrarDialogoAsignarRol(userId, nombre),
                                    tooltip: 'Asignar Rol',
                                  ),
                                  Switch(
                                    value: activo,
                                    activeColor: Colors.green,
                                    onChanged: (val) => _cambiarEstado(userId, val),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                    onPressed: () => _eliminarUsuario(userId, nombre),
                                    tooltip: 'Eliminar Usuario',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ).animate(key: ValueKey(userId)).fade(duration: 300.ms, delay: (50 * index).ms).slideX(begin: 0.05, delay: (50 * index).ms);
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }


  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.8))),
                Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
