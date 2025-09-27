// pb_client.dart (CORREGIDO)

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb; // ✅ Importa kIsWeb
import 'package:pocketbase/pocketbase.dart';

String getBaseUrl() {
  // Primero, comprueba si la plataforma es web
  if (kIsWeb) {
    return 'http://127.0.0.1:8090'; // ✅ Usa localhost para la web
  }

  // Si no es web, ahora sí puedes usar Platform de forma segura
  if (Platform.isAndroid) {
    return 'http://10.0.2.2:8090'; // 🤖 IP especial para el emulador de Android
  }

  // Para cualquier otra plataforma (Windows, iOS, etc.)
  return 'http://127.0.0.1:8090';
}

final pb = PocketBase(getBaseUrl());