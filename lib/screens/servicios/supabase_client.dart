import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class SupabaseConfig {
  static String get url {
    if (kIsWeb) return 'https://wvogrcteltoljtjvneyv.supabase.co/'; // O tu URL de Supabase Cloud
    if (Platform.isAndroid) return 'https://wvogrcteltoljtjvneyv.supabase.co/';
    return 'https://wvogrcteltoljtjvneyv.supabase.co/';
  }

  static const String anonKey = 'sb_publishable_jTuZRwRohap9wJcfeJovlg_nzM2u-z-';
}

// Para inicializarlo en el main.dart
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
}

// Acceso rápido al cliente
final supabase = Supabase.instance.client;